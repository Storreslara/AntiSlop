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
// gh379 Step 2 advisory: legal via: authorship-route values, mirroring the
// EXAMPLES_TOKENS allowlist pattern below. Closes the newline-injection
// vector (an unvalidated via containing "\nexamples: reviewed" could forge
// an examples attestation) since only these two exact literal strings pass.
const VIA_ROUTES = ['terminal', 'dashboard'];
// gh375 Step 14 (comprehension-check token retired in favor of worked
// examples): the three legal examples-attestation tokens. R6 ("never
// graded, never a gate") means this module never reads or judges
// EXAMPLES.md -- these are self-report tokens only.
const EXAMPLES_TOKENS = ['reviewed', 'skipped', 'none-offered'];

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

// gh380: free-text fields must fail closed on unexpected type. A validator
// gated on `typeof value === 'string' &&` silently no-ops for every other
// JSON type while the sink -- template interpolation at `by: ${by}` /
// `reason: ${reason}` -- coerces back to a string anyway (an array's
// toString rejoins its elements and restores the newline). The type
// predicate therefore belongs in the reject condition, never as a
// precondition on whether to check at all. The allowlisted neighbours
// (route/via/examples) get this for free from `.indexOf()`; by/reason are free
// text and have to state it explicitly.
function assertStringField(value, label) {
  if (typeof value !== 'string') {
    throw new Error(`${label} must be a string, got ${JSON.stringify(value)}`);
  }
}

// gh380 D2: by/reason are composed into the body as single lines. A newline
// (or CR) in either forges extra DECISION body lines -- e.g. a `by` of
// "agent\nexamples: reviewed" fabricates an examples attestation that was
// never supplied. Type first (fail closed), then content.
function assertNoNewline(value, label) {
  assertStringField(value, label);
  if (/[\r\n]/.test(value)) {
    throw new Error(`${label} may not contain a newline: ${JSON.stringify(value)}`);
  }
}

// D-6 rule 2: multi-line bodies use a single-quoted heredoc.
function composeHeredocCommand(targetPath, body) {
  return `cat > ${targetPath} <<'${HEREDOC_DELIM}'\n${body}\n${HEREDOC_DELIM}\n`;
}

function composeEscalationDecisionBody(context) {
  const { taskId, route, escalationTimestamp, by = '', reason = '', examples, via, now } = context || {};

  if (escalationTimestamp === undefined || escalationTimestamp === null || escalationTimestamp === '') {
    throw new Error('escalation-decision requires context.escalationTimestamp (the .escalated marker timestamp)');
  }
  if (ROUTES.indexOf(route) === -1) {
    throw new Error(`route must be one of ${ROUTES.join('|')}, got ${JSON.stringify(route)}`);
  }
  validateId(taskId, 'taskId');
  // by is always a name/identity -- never legitimately multi-line, on
  // either the terminal or dashboard path.
  assertNoNewline(by, 'by');
  // reason legitimately supports multi-line free text on the terminal
  // copy-paste path (D-6 rule 2's heredoc wrapping exists precisely for
  // this, and Test (e) in tests/dashboard-decision-block.test.js pins a
  // "line one\nline two" reason as intentional). The newline-injection
  // risk is specific to via: 'dashboard' -- the server-side write sink
  // (server.js POST /api/decision/arm) fed by untrusted HTTP JSON, where
  // the human never previews the composed body before confirming via the
  // /dev/tty code (gh380 D2).
  // The *type* check is unconditional on both paths; only the *content*
  // (newline) check is via: 'dashboard'-only, so the terminal path keeps
  // its legitimately multi-line reason (Test (e)) while a non-string still
  // fails closed everywhere (gh380).
  if (via === 'dashboard') {
    assertNoNewline(reason, 'reason');
  } else {
    assertStringField(reason, 'reason');
  }

  // gh379 Step 2: the timestamp is injectable via context.now so callers
  // (notably this test suite's byte-identity check) can pin two separate
  // invocations to the identical instant instead of racing the millisecond
  // clock. Defaults to the live clock, matching prior behaviour exactly.
  const decisionTimestamp = now !== undefined ? now : new Date().toISOString();
  const lines = [
    `DECISION ${taskId} ${decisionTimestamp} route: ${route} escalation: ${escalationTimestamp}`,
    `by: ${by}`,
  ];

  const warnings = [];

  // Add via: line only when context.via is explicitly defined. Validated
  // against VIA_ROUTES, mirroring the examples guard immediately below.
  if (via !== undefined) {
    if (VIA_ROUTES.indexOf(via) === -1) {
      throw new Error(`via must be one of ${VIA_ROUTES.join('|')}, got ${JSON.stringify(via)}`);
    }
    lines.push(`via: ${via}`);
  }

  // examples: approve-route only (gh375 Step 14). Omitting examples
  // composes exactly today's body. On reject/direct the value is ignored,
  // never validated and never emitted -- the same form state carries a
  // leftover examples field across route switches, and that must not
  // throw.
  if (examples !== undefined) {
    if (route === 'approve') {
      if (EXAMPLES_TOKENS.indexOf(examples) === -1) {
        throw new Error(`examples must be one of ${EXAMPLES_TOKENS.join('|')}, got ${JSON.stringify(examples)}`);
      }
      lines.push(`examples: ${examples}`);
    } else {
      warnings.push(`examples is ignored on route: ${route}`);
    }
  }

  if (reason) lines.push(`reason: ${reason}`);
  const body = lines.join('\n');

  if (bodyHasDelimiterLine(body)) {
    return { body: null, warnings: [...warnings, `body contains a line equal to the heredoc delimiter "${HEREDOC_DELIM}"; refusing to compose`] };
  }

  return { body, warnings };
}

function composeEscalationDecision(context) {
  const { taskId } = context || {};
  const bodyResult = composeEscalationDecisionBody(context);

  if (bodyResult.body === null) {
    return { kind: 'command', text: null, warnings: bodyResult.warnings };
  }

  const text = composeHeredocCommand(`.claude/human-review/${taskId}/DECISION`, bodyResult.body);
  assertNoCommandSubstitution(text);
  return { kind: 'command', text, warnings: bodyResult.warnings };
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
  module.exports = { composeDecisionBlock, composeEscalationDecisionBody, assertNoNewline, ID_RE };
}
