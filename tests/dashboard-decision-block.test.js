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

// gh375 Step 14: quiz attestation on the approve route. Prints an
// "OK   <label>" line on success (grepped by acceptance criteria) in
// addition to this file's existing "Test .../✓ ok" convention.
function checkOk(okLabel, fn) {
  console.log(`Test ${okLabel}...`);
  try {
    fn();
    console.log('OK   ' + okLabel);
  } catch (err) {
    console.log('  ✗ ' + err.message);
    failures.push(`${okLabel}: ${err.message}`);
  }
}

checkOk('approve emits quiz line after by', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    quiz: 'passed-self-check',
  });
  const lines = result.text.split('\n');
  const byIdx = lines.findIndex((l) => l === 'by: Sebastian');
  assert(byIdx !== -1, 'expected a by: line in composed text');
  assert(lines[byIdx + 1] === 'quiz: passed-self-check', `expected quiz line immediately after by:, got "${lines[byIdx + 1]}"`);
});

checkOk('quiz passed-self-check composes', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', quiz: 'passed-self-check',
  });
  assert(result.text.includes('quiz: passed-self-check'), 'expected quiz: passed-self-check in composed text');
});

checkOk('quiz skipped composes', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', quiz: 'skipped',
  });
  assert(result.text.includes('quiz: skipped'), 'expected quiz: skipped in composed text');
});

checkOk('quiz none-offered composes', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', quiz: 'none-offered',
  });
  assert(result.text.includes('quiz: none-offered'), 'expected quiz: none-offered in composed text');
});

checkOk('quiz bogus-token rejected', () => {
  throws(() => composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', quiz: 'bogus-token',
  }), 'expected a bogus quiz token to throw');
});

checkOk('reject never emits quiz', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'reject', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', quiz: 'passed-self-check', reason: 'not ready',
  });
  assert(!result.text.includes('quiz:'), `expected no quiz: line on reject, got "${result.text}"`);
});

checkOk('direct never emits quiz', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'direct', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', quiz: 'none-offered',
  });
  assert(!result.text.includes('quiz:'), `expected no quiz: line on direct, got "${result.text}"`);
});

checkOk('omitted quiz composes unchanged body', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian',
  });
  const bodyLines = result.text.split("<<'EOF'\n")[1].split('\nEOF\n')[0].split('\n');
  assert(bodyLines.length === 2, `expected exactly 2 body lines (DECISION, by) when quiz omitted, got ${bodyLines.length}: ${JSON.stringify(bodyLines)}`);
  assert(bodyLines[0].startsWith('DECISION gh375 '), 'expected DECISION line unchanged');
  assert(bodyLines[1] === 'by: Sebastian', 'expected by: line unchanged');
  assert(!result.text.includes('quiz:'), 'expected no quiz: line when quiz omitted');
});

console.log('\n' + '='.repeat(60));
if (failures.length === 0) {
  console.log('All decision-block acceptance cases (a)-(j) plus quiz cases passed!');
  process.exit(0);
} else {
  console.log(`${failures.length} test(s) failed:`);
  failures.forEach((f) => console.log(`  - ${f}`));
  process.exit(1);
}
