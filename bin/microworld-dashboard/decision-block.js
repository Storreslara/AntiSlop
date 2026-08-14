'use strict';

// Pure composer for the four dashboard decision touchpoints. Composes
// command/block text only -- never executes and never writes to disk (D-1
// of docs/plans/2026-08-13-dashboard-decision-approval-surface.md).
//
// Dual-environment, single implementation, same shape as feedback-block.js
// in this directory: required directly by the test suite via CommonJS, and
// injected verbatim by server.js's `GET /` handler into a classic <script>
// tag ahead of index.html's module script (see the
// `__DECISION_BLOCK_SOURCE__` placeholder there), becoming a page global.

const ID_RE = /^[A-Za-z0-9][A-Za-z0-9._#-]*$/;
const MAX_ID_LEN = 64;
const ROUTES = ['approve', 'reject', 'direct'];
const HEREDOC_DELIM = 'EOF';

function validateId(value, label) {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_ID_LEN || !ID_RE.test(value)) {
    throw new Error(`${label} does not match the protocol id grammar: ${JSON.stringify(value)}`);
  }
  return value;
}

// D-6 rule 1: no command substitution anywhere in composed content.
function assertNoCommandSubstitution(text) {
  if (text.indexOf('$(') !== -1 || text.indexOf('`') !== -1 || text.indexOf('${') !== -1) {
    throw new Error('composed content would contain a forbidden command-substitution sequence');
  }
}

function bodyHasDelimiterLine(body) {
  return body.split('\n').some((line) => line === HEREDOC_DELIM);
}

// D-6 rule 2: multi-line bodies use a single-quoted heredoc.
function composeHeredocCommand(targetPath, body) {
  return `cat > ${targetPath} <<'${HEREDOC_DELIM}'\n${body}\n${HEREDOC_DELIM}\n`;
}

function composeEscalationDecision(context) {
  const { taskId, route, escalationTimestamp, by = '', reason = '' } = context || {};

  if (escalationTimestamp === undefined || escalationTimestamp === null || escalationTimestamp === '') {
    throw new Error('escalation-decision requires context.escalationTimestamp (the .escalated marker timestamp)');
  }
  if (ROUTES.indexOf(route) === -1) {
    throw new Error(`route must be one of ${ROUTES.join('|')}, got ${JSON.stringify(route)}`);
  }
  validateId(taskId, 'taskId');

  const decisionTimestamp = new Date().toISOString();
  const lines = [
    `DECISION ${taskId} ${decisionTimestamp} route: ${route} escalation: ${escalationTimestamp}`,
    `by: ${by}`,
  ];
  if (reason) lines.push(`reason: ${reason}`);
  const body = lines.join('\n');

  if (bodyHasDelimiterLine(body)) {
    return { kind: 'command', text: null, warnings: [`body contains a line equal to the heredoc delimiter "${HEREDOC_DELIM}"; refusing to compose`] };
  }

  const text = composeHeredocCommand(`.claude/human-review/${taskId}/DECISION`, body);
  assertNoCommandSubstitution(text);
  return { kind: 'command', text, warnings: [] };
}

function composePendingReviewFlag(action, context) {
  const { agentId, reason } = context || {};
  validateId(agentId, 'agentId');

  if (typeof reason !== 'string' || reason.trim() === '') {
    return { kind: 'command', text: null, warnings: [`${action} requires a non-empty reason (matches stop-gate.sh's own rejection of an empty reason)`] };
  }

  const body = `${action}: ${reason}`;
  if (bodyHasDelimiterLine(body)) {
    return { kind: 'command', text: null, warnings: [`reason contains a line equal to the heredoc delimiter "${HEREDOC_DELIM}"; refusing to compose`] };
  }

  const text = composeHeredocCommand(`.claude/.pending-review.${agentId}`, body);
  assertNoCommandSubstitution(text);

  const result = { kind: 'command', text, warnings: [] };
  if (action === 'skip') {
    result.consequence = 'This deletes the pending-review flag and abandons the review for this unit -- the reviewer will not run against it.';
  }
  return result;
}

function composeMilestoneFindingsResponse(context) {
  const { planSlug, findingsText = '' } = context || {};
  if (typeof planSlug !== 'string' || planSlug === '') {
    throw new Error('milestone-findings-response requires context.planSlug');
  }

  const text = [
    `## Milestone findings response -- ${planSlug}`,
    '',
    findingsText,
    '',
    'Decision: [fill in the decision text and paste this block back]',
  ].join('\n');
  assertNoCommandSubstitution(text);
  return { kind: 'block', text, warnings: [] };
}

function composeDecisionBlock(kind, context) {
  switch (kind) {
    case 'escalation-decision':
      return composeEscalationDecision(context);
    case 'pending-review-defer':
      return composePendingReviewFlag('defer', context);
    case 'pending-review-skip':
      return composePendingReviewFlag('skip', context);
    case 'milestone-findings-response':
      return composeMilestoneFindingsResponse(context);
    default:
      throw new Error(`unknown decision kind: ${JSON.stringify(kind)}`);
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { composeDecisionBlock };
}
