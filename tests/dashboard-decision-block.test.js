#!/usr/bin/env node
'use strict';

// Test suite for bin/microworld-dashboard/decision-block.js (gh351): the pure
// four-kind decision composer. Covers acceptance cases (a)-(j) from
// docs/plans/2026-08-13-dashboard-decision-approval-surface.md Step 2.

const { composeDecisionBlock } = require('../bin/microworld-dashboard/decision-block');

const failures = [];

function check(label, fn) {
  console.log(`Test ${label}...`);
  try {
    fn();
    console.log('  ✓ ok');
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push(`${label} ${err.message}`);
  }
}

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

function throws(fn, message) {
  try {
    fn();
  } catch (err) {
    return err;
  }
  throw new Error(message || 'expected function to throw, it did not');
}

// (a) escalation-decision composes content whose first line matches the
// protocol grammar.
check('(a) escalation-decision route-grammar first line', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh351',
    route: 'approve',
    escalationTimestamp: '2026-08-13T10:00:00Z',
    by: 'Sebastian',
  });
  assert(result.kind === 'command', 'expected kind: command');
  const bodyFirstLine = result.text.split('\n')[1];
  const re = /^DECISION [A-Za-z0-9][A-Za-z0-9._#-]* \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z route: (approve|reject|direct) escalation: \S+$/;
  assert(re.test(bodyFirstLine), `body first line "${bodyFirstLine}" does not match protocol grammar`);
});

// (b) composed escalation: value equals context's timestamp; missing throws.
check('(b) escalation timestamp fidelity + missing-context throw', () => {
  const ts = '2026-08-01T00:00:00Z';
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh351',
    route: 'reject',
    escalationTimestamp: ts,
    by: 'Sebastian',
  });
  const bodyFirstLine = result.text.split('\n')[1];
  assert(bodyFirstLine.endsWith(`escalation: ${ts}`), `expected escalation: ${ts} in "${bodyFirstLine}"`);

  throws(() => composeDecisionBlock('escalation-decision', {
    taskId: 'gh351',
    route: 'approve',
    by: 'Sebastian',
  }), 'expected missing escalationTimestamp to throw');
});

// (c) an invalid route throws.
check('(c) invalid route throws', () => {
  throws(() => composeDecisionBlock('escalation-decision', {
    taskId: 'gh351',
    route: 'sabotage',
    escalationTimestamp: '2026-08-13T10:00:00Z',
    by: 'Sebastian',
  }));
});

// (d) no command substitution in composed content (D-6 rule 1).
check('(d) no command substitution in composed text', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh351',
    route: 'direct',
    escalationTimestamp: '2026-08-13T10:00:00Z',
    by: 'Sebastian',
    reason: 'proceed as planned',
  });
  assert(!result.text.includes('$('), 'composed text contains $(');
  assert(!result.text.includes('`'), 'composed text contains a backtick');
  assert(!result.text.includes('${'), 'composed text contains ${');
});

// (e) multi-line body uses a single-quoted heredoc; a body containing a line
// equal to the delimiter is refused.
check('(e) heredoc wraps multi-line body; delimiter-collision refused', () => {
  const okResult = composeDecisionBlock('escalation-decision', {
    taskId: 'gh351',
    route: 'reject',
    escalationTimestamp: '2026-08-13T10:00:00Z',
    by: 'Sebastian',
    reason: 'line one\nline two',
  });
  assert(/<<'[A-Za-z0-9_]+'/.test(okResult.text), 'expected a single-quoted heredoc delimiter');
  assert(okResult.text.includes('line one\nline two'), 'multi-line reason not embedded verbatim');

  const collision = composeDecisionBlock('escalation-decision', {
    taskId: 'gh351',
    route: 'reject',
    escalationTimestamp: '2026-08-13T10:00:00Z',
    by: 'Sebastian',
    reason: 'line one\nEOF\nline three',
  });
  assert(collision.text === null, 'expected no command composed on delimiter collision');
  assert(collision.warnings.length >= 1, 'expected a warnings entry on delimiter collision');
});

// (f) id grammar validation: a shell-metacharacter case and a >64-char case.
check('(f) id grammar validation throws', () => {
  throws(() => composeDecisionBlock('escalation-decision', {
    taskId: 'gh351;rm -rf /',
    route: 'approve',
    escalationTimestamp: '2026-08-13T10:00:00Z',
    by: 'Sebastian',
  }), 'expected shell-metacharacter taskId to throw');

  throws(() => composeDecisionBlock('pending-review-defer', {
    agentId: 'a'.repeat(65),
    reason: 'still working',
  }), 'expected >64-char agentId to throw');
});

// (g) pending-review-defer/skip compose the flag-write command; empty or
// whitespace-only reason refuses to compose.
check('(g) defer/skip compose command; empty reason refused', () => {
  const defer = composeDecisionBlock('pending-review-defer', {
    agentId: 'agent-1',
    reason: 'still investigating',
  });
  assert(defer.text.includes('.claude/.pending-review.agent-1'), 'defer command missing target path');
  assert(defer.text.includes('defer: still investigating'), 'defer command missing defer: line');

  const skip = composeDecisionBlock('pending-review-skip', {
    agentId: 'agent-1',
    reason: 'abandoning this unit',
  });
  assert(skip.text.includes('.claude/.pending-review.agent-1'), 'skip command missing target path');
  assert(skip.text.includes('skip: abandoning this unit'), 'skip command missing skip: line');

  const emptyDefer = composeDecisionBlock('pending-review-defer', { agentId: 'agent-1', reason: '   ' });
  assert(emptyDefer.text === null, 'expected no command for whitespace-only reason');
  assert(emptyDefer.warnings.length >= 1, 'expected a warnings entry for whitespace-only reason');
});

// (h) pending-review-skip carries a consequence string (D-5).
check('(h) skip result carries a consequence string', () => {
  const skip = composeDecisionBlock('pending-review-skip', {
    agentId: 'agent-1',
    reason: 'abandoning this unit',
  });
  assert(typeof skip.consequence === 'string' && skip.consequence.length > 0, 'expected a non-empty consequence string');
  assert(/delet/i.test(skip.consequence) && /abandon/i.test(skip.consequence), 'consequence string should state the flag is deleted and the review abandoned');
});

// (i) milestone-findings-response returns a block, not a command.
check('(i) findings-response is a block with no redirection/heredoc syntax', () => {
  const result = composeDecisionBlock('milestone-findings-response', {
    planSlug: '2026-08-13-dashboard-decision-approval-surface',
    findingsText: '- finding one\n- finding two',
  });
  assert(result.kind === 'block', 'expected kind: block');
  assert(!result.text.includes('>'), 'findings-response text contains a > redirection character');
  assert(!result.text.includes('cat <<'), 'findings-response text contains cat << heredoc syntax');
});

// (j) an unknown kind throws.
check('(j) unknown kind throws', () => {
  throws(() => composeDecisionBlock('not-a-real-kind', {}));
});

console.log('\n' + '='.repeat(60));
if (failures.length === 0) {
  console.log('All 10 acceptance cases (a)-(j) passed!');
  process.exit(0);
} else {
  console.log(`${failures.length} test(s) failed:`);
  failures.forEach((f) => console.log(`  - ${f}`));
  process.exit(1);
}
