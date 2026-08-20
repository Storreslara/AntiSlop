#!/usr/bin/env node
'use strict';

// Test suite for bin/microworld-dashboard/decision-block.js (gh351): the pure
// four-kind decision composer. Covers acceptance cases (a)-(j) from
// docs/plans/2026-08-13-dashboard-decision-approval-surface.md Step 2.

const { composeDecisionBlock, composeEscalationDecisionBody } = require('../bin/microworld-dashboard/decision-block');

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

// gh375 Step 14: examples attestation on the approve route. Prints an
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

checkOk('approve emits examples line after by', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    examples: 'reviewed',
  });
  const lines = result.text.split('\n');
  const byIdx = lines.findIndex((l) => l === 'by: Sebastian');
  assert(byIdx !== -1, 'expected a by: line in composed text');
  assert(lines[byIdx + 1] === 'examples: reviewed', `expected examples line immediately after by:, got "${lines[byIdx + 1]}"`);
});

checkOk('examples reviewed composes', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', examples: 'reviewed',
  });
  assert(result.text.includes('examples: reviewed'), 'expected examples: reviewed in composed text');
});

checkOk('examples skipped composes', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', examples: 'skipped',
  });
  assert(result.text.includes('examples: skipped'), 'expected examples: skipped in composed text');
});

checkOk('examples none-offered composes', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', examples: 'none-offered',
  });
  assert(result.text.includes('examples: none-offered'), 'expected examples: none-offered in composed text');
});

checkOk('examples bogus-token rejected', () => {
  throws(() => composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', examples: 'bogus-token',
  }), 'expected a bogus examples token to throw');
});

checkOk('reject never emits examples', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'reject', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', examples: 'reviewed', reason: 'not ready',
  });
  assert(!result.text.includes('examples:'), `expected no examples: line on reject, got "${result.text}"`);
});

checkOk('direct never emits examples', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'direct', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian', examples: 'none-offered',
  });
  assert(!result.text.includes('examples:'), `expected no examples: line on direct, got "${result.text}"`);
});

checkOk('omitted examples composes unchanged body', () => {
  const result = composeDecisionBlock('escalation-decision', {
    taskId: 'gh375', route: 'approve', escalationTimestamp: '2026-08-15T10:00:00Z', by: 'Sebastian',
  });
  const bodyLines = result.text.split("<<'EOF'\n")[1].split('\nEOF\n')[0].split('\n');
  assert(bodyLines.length === 2, `expected exactly 2 body lines (DECISION, by) when examples omitted, got ${bodyLines.length}: ${JSON.stringify(bodyLines)}`);
  assert(bodyLines[0].startsWith('DECISION gh375 '), 'expected DECISION line unchanged');
  assert(bodyLines[1] === 'by: Sebastian', 'expected by: line unchanged');
  assert(!result.text.includes('examples:'), 'expected no examples: line when examples omitted');
});

// gh379 advisory: via: is validated against an allowlist (VIA_ROUTES),
// mirroring the examples field's EXAMPLES_TOKENS guard. This also closes a
// newline-injection vector: an unvalidated via containing a newline could
// forge extra DECISION body lines (e.g. a bogus examples: attestation).
checkOk('via: unlisted plain value rejected', () => {
  throws(() => composeEscalationDecisionBody({
    taskId: 'gh379',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    via: 'carrier-pigeon',
  }), 'expected an unlisted via value to throw');
});

checkOk('via: newline-injection payload rejected, not just unlisted string', () => {
  const err = throws(() => composeEscalationDecisionBody({
    taskId: 'gh379',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    via: 'dashboard\nexamples: reviewed',
  }), 'expected a newline-containing via value to throw');
  assert(/via must be one of/.test(err.message), `expected the VIA_ROUTES rejection message, got "${err.message}"`);
});

// gh380 D2: by is always a name/identity, never legitimately multi-line
// (unlike reason, which Test (e) above pins as intentionally multi-line
// for the terminal copy-paste path).
checkOk('by: newline-injection payload rejected', () => {
  const err = throws(() => composeEscalationDecisionBody({
    taskId: 'gh380',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'agent\nexamples: reviewed\nnote: forged',
    via: 'dashboard',
  }), 'expected a newline-containing by value to throw');
  assert(/by may not contain a newline/.test(err.message), `expected the by-newline rejection message, got "${err.message}"`);
});

// gh380 D2: reason newline-injection is rejected specifically on the
// via: 'dashboard' path -- the server-side write sink fed by untrusted
// HTTP JSON (server.js POST /api/decision/arm), where the human never
// previews the composed body before confirming via the /dev/tty code.
checkOk('reason: newline-injection payload rejected on via: dashboard', () => {
  const err = throws(() => composeEscalationDecisionBody({
    taskId: 'gh380',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    reason: 'looks fine\nexamples: reviewed',
    via: 'dashboard',
  }), 'expected a newline-containing reason value to throw on via: dashboard');
  assert(/reason may not contain a newline/.test(err.message), `expected the reason-newline rejection message, got "${err.message}"`);
});

// gh380: legitimate multi-line reason on the terminal path (no via, or
// via: 'terminal') must still compose -- this is Test (e)'s exact shape,
// re-asserted here at the composeEscalationDecisionBody level to pin that
// the D2 fix did not regress it.
checkOk('reason: multi-line still composes without via: dashboard', () => {
  const result = composeEscalationDecisionBody({
    taskId: 'gh380',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    reason: 'line one\nline two',
  });
  assert(result.body.includes('reason: line one\nline two'), 'expected multi-line reason to compose unchanged when via is not dashboard');
});

// gh380 debug spec C5: the same multi-line reason must also survive an
// explicit via: 'terminal' -- the type check is unconditional, the content
// check is via: 'dashboard'-only.
checkOk('reason: multi-line still composes with via: terminal', () => {
  const result = composeEscalationDecisionBody({
    taskId: 'gh380',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    reason: 'line one\nline two',
    via: 'terminal',
  });
  assert(result.body.includes('reason: line one\nline two'), 'expected multi-line reason to compose unchanged on via: terminal');
});

// gh380 debug spec C2/C7: the defect was JSON type confusion, not "arrays".
// `typeof value === 'string' &&` as a precondition skipped the guard for the
// entire complement of string, and `${value}` interpolation coerced the value
// back into the body. Enumerate the shape list once and iterate it for both
// free-text fields, so a future free-text field inherits full coverage from
// one name added to COMPOSER_FREE_TEXT_FIELDS.
const COMPOSER_NON_STRING_SHAPES = [
  { label: 'array-wrapped', value: ['agent\nexamples: reviewed\nnote: forged'] },
  { label: 'nested-array', value: [['agent\nexamples: reviewed']] },
  { label: 'plain object', value: { forged: 'agent\nexamples: reviewed' } },
  { label: 'number', value: 42 },
  { label: 'boolean', value: true },
  { label: 'null', value: null },
];
const COMPOSER_FREE_TEXT_FIELDS = ['by', 'reason'];

COMPOSER_FREE_TEXT_FIELDS.forEach((field) => {
  COMPOSER_NON_STRING_SHAPES.forEach((shape) => {
    checkOk(`${field}: non-string (${shape.label}) rejected on via: dashboard`, () => {
      const context = {
        taskId: 'gh380',
        route: 'approve',
        escalationTimestamp: '2026-08-15T10:00:00Z',
        by: 'Sebastian',
        reason: 'ok',
        via: 'dashboard',
      };
      context[field] = shape.value;
      const err = throws(() => composeEscalationDecisionBody(context), `expected a non-string ${field} (${shape.label}) to throw`);
      assert(new RegExp(`^${field} must be a string`).test(err.message), `expected the ${field} type rejection message, got "${err.message}"`);
    });
  });

  // The type half is unconditional: a non-string must also fail on the
  // terminal path, where only the *content* check is relaxed.
  checkOk(`${field}: non-string (array-wrapped) rejected on the terminal path too`, () => {
    const context = {
      taskId: 'gh380',
      route: 'approve',
      escalationTimestamp: '2026-08-15T10:00:00Z',
      by: 'Sebastian',
      reason: 'ok',
    };
    context[field] = ['agent\nexamples: reviewed'];
    const err = throws(() => composeEscalationDecisionBody(context), `expected a non-string ${field} to throw with no via`);
    assert(new RegExp(`^${field} must be a string`).test(err.message), `expected the ${field} type rejection message, got "${err.message}"`);
  });
});

// gh380 debug spec C3: assertNoNewline tests /[\r\n]/ but every existing test
// only ever sent \n, leaving the \r half unproven.
COMPOSER_FREE_TEXT_FIELDS.forEach((field) => {
  checkOk(`${field}: carriage-return injection payload rejected on via: dashboard`, () => {
    const context = {
      taskId: 'gh380',
      route: 'approve',
      escalationTimestamp: '2026-08-15T10:00:00Z',
      by: 'Sebastian',
      reason: 'ok',
      via: 'dashboard',
    };
    context[field] = 'agent\rexamples: reviewed';
    const err = throws(() => composeEscalationDecisionBody(context), `expected a \\r-containing ${field} to throw`);
    assert(new RegExp(`^${field} may not contain a newline`).test(err.message), `expected the ${field} newline rejection message, got "${err.message}"`);
  });
});

// gh380 debug spec C4: undefined (omitted) and '' stay legal -- the
// destructuring default `= ''` is depended upon -- while an explicit null is
// rejected. A fix conflating the two fails in one direction or the other.
checkOk('by/reason omitted compose (the = \'\' destructuring default is load-bearing)', () => {
  const result = composeEscalationDecisionBody({
    taskId: 'gh380',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    via: 'dashboard',
  });
  assert(result.body.includes('by: '), 'expected an empty by: line when by is omitted');
  assert(!result.body.includes('reason:'), 'expected no reason: line when reason is omitted');
});

checkOk('by/reason as empty strings compose', () => {
  const result = composeEscalationDecisionBody({
    taskId: 'gh380',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: '',
    reason: '',
    via: 'dashboard',
  });
  assert(result.body.includes('by: '), 'expected an empty by: line for by: ""');
});

checkOk('by: null rejected even though by: undefined is legal', () => {
  const err = throws(() => composeEscalationDecisionBody({
    taskId: 'gh380',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: null,
    via: 'dashboard',
  }), 'expected by: null to throw');
  assert(/^by must be a string/.test(err.message), `expected the by type rejection message, got "${err.message}"`);
});

// gh379 Step 2: composeEscalationDecisionBody() extracts and exports the body
// composition logic, returning { body, warnings }. The via: field records
// authorship route.

checkOk('composeEscalationDecisionBody is exported', () => {
  assert(typeof composeEscalationDecisionBody === 'function', 'composeEscalationDecisionBody must be exported');
});

checkOk('composeEscalationDecisionBody returns { body, warnings }', () => {
  const result = composeEscalationDecisionBody({
    taskId: 'gh379',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
  });
  assert(typeof result.body === 'string', 'expected body to be a string');
  assert(Array.isArray(result.warnings), 'expected warnings to be an array');
  assert(result.body.includes('DECISION gh379'), 'expected DECISION line in body');
  assert(result.body.includes('by: Sebastian'), 'expected by: line in body');
  assert(!result.body.includes('via:'), 'expected no via: line when via is omitted');
});

checkOk('via: dashboard emits via line after by:', () => {
  const result = composeEscalationDecisionBody({
    taskId: 'gh379',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    via: 'dashboard',
  });
  const lines = result.body.split('\n');
  const byIdx = lines.findIndex((l) => l === 'by: Sebastian');
  assert(byIdx !== -1, 'expected a by: line in body');
  assert(lines[byIdx + 1] === 'via: dashboard', `expected via: dashboard line immediately after by:, got "${lines[byIdx + 1]}"`);
  const viaLines = lines.filter((l) => l.startsWith('via:'));
  assert(viaLines.length === 1, `expected exactly one via: line, got ${viaLines.length}`);
});

checkOk('via: terminal emits via line after by:', () => {
  const result = composeEscalationDecisionBody({
    taskId: 'gh379',
    route: 'reject',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    via: 'terminal',
  });
  const lines = result.body.split('\n');
  const byIdx = lines.findIndex((l) => l === 'by: Sebastian');
  assert(byIdx !== -1, 'expected a by: line in body');
  assert(lines[byIdx + 1] === 'via: terminal', `expected via: terminal line immediately after by:, got "${lines[byIdx + 1]}"`);
  const viaLines = lines.filter((l) => l.startsWith('via:'));
  assert(viaLines.length === 1, `expected exactly one via: line, got ${viaLines.length}`);
});

checkOk('omitting via: produces no via line in body', () => {
  const result = composeEscalationDecisionBody({
    taskId: 'gh379',
    route: 'direct',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
  });
  const lines = result.body.split('\n');
  const viaLines = lines.filter((l) => l.startsWith('via:'));
  assert(viaLines.length === 0, `expected no via: lines when via is omitted, got ${viaLines.length}`);
});

checkOk('via: appears after by: but before examples and reason', () => {
  const result = composeEscalationDecisionBody({
    taskId: 'gh379',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Sebastian',
    via: 'dashboard',
    examples: 'reviewed',
    reason: 'looks good',
  });
  const lines = result.body.split('\n');
  const byIdx = lines.findIndex((l) => l === 'by: Sebastian');
  const viaIdx = lines.findIndex((l) => l === 'via: dashboard');
  const examplesIdx = lines.findIndex((l) => l === 'examples: reviewed');
  const reasonIdx = lines.findIndex((l) => l === 'reason: looks good');
  assert(byIdx < viaIdx && viaIdx < examplesIdx && examplesIdx < reasonIdx, 'expected order: by, via, examples, reason');
});

checkOk('composeEscalationDecisionBody body is byte-identical to heredoc payload', () => {
  // gh379 Step 2 fix: pin both invocations to the identical instant via
  // context.now. Without this, composeEscalationDecisionBody() and
  // composeDecisionBlock() each independently evaluate
  // `new Date().toISOString()` and can straddle a millisecond boundary,
  // making this byte-equality assertion flaky (measured 3 failures in
  // ~1000 runs pre-fix). The whole-body equality itself stays intact -- it
  // is the load-bearing proof that there is genuinely one implementation.
  const context = {
    taskId: 'gh379-verify',
    route: 'approve',
    escalationTimestamp: '2026-08-15T10:00:00Z',
    by: 'Reviewer Name',
    via: 'dashboard',
    examples: 'reviewed',
    reason: 'approved the work',
    now: '2026-08-15T22:00:00.000Z',
  };

  // Get body from composeEscalationDecisionBody
  const bodyResult = composeEscalationDecisionBody(context);
  const composedBody = bodyResult.body;

  // Get heredoc from composeDecisionBlock and extract the payload
  const commandResult = composeDecisionBlock('escalation-decision', context);
  // Extract body from the heredoc command: `cat > path <<'EOF'\n<body>\nEOF\n`
  const match = commandResult.text.match(/<<'EOF'\n([\s\S]*?)\nEOF\n/);
  assert(match && match[1], 'failed to extract body from heredoc command');
  const heredocBody = match[1];

  // Bodies must be byte-identical
  assert(composedBody === heredocBody, `bodies differ:\ncomposeEscalationDecisionBody: ${JSON.stringify(composedBody)}\nheredoc payload: ${JSON.stringify(heredocBody)}`);
});

console.log('\n' + '='.repeat(60));
if (failures.length === 0) {
  // Banner text is the repo-wide suite convention and is what the gh380
  // debug spec's C1 greps for; the other dashboard suites already print it.
  console.log('All tests passed!');
  process.exit(0);
} else {
  console.log(`${failures.length} test(s) failed:`);
  failures.forEach((f) => console.log(`  - ${f}`));
  process.exit(1);
}
