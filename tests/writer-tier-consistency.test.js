#!/usr/bin/env node
'use strict';

// Coverage for Unit D (2026-08-25-agent-throughput-performance-dampeners,
// spec2-unitD): the writer-tier reversal from haiku to sonnet (ADR-0026,
// amending ADR-0010) must read the same literal everywhere it's stated.
// AC-D5: the literal is "sonnet", not merely "the same value" as everywhere
// else. AC-D6: no surface reintroduces pre-emptive "looks mechanical"
// tagging. AC-D7: the escalation ladder starts one rung higher.

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');

let failures = 0;
function check(name, fn) {
  try {
    fn();
    console.log(`OK   ${name}`);
  } catch (err) {
    console.log(`FAIL ${name}: ${err.message}`);
    failures++;
  }
}

function read(rel) {
  return fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
}

function frontmatterModel(text) {
  const m = text.match(/^---\n[\s\S]*?\nmodel:\s*(\S+)\n[\s\S]*?\n---/);
  return m ? m[1] : null;
}

check('AC-D5: agents/lead-programmer.md frontmatter reads model: haiku', () => {
  assert.strictEqual(frontmatterModel(read('agents/lead-programmer.md')), 'haiku');
});

check('AC-D5: .claude/agents/lead-programmer.md mirror reads model: haiku', () => {
  assert.strictEqual(frontmatterModel(read('.claude/agents/lead-programmer.md')), 'haiku');
});

check('AC-D5: README.md persona table lists lead-programmer as haiku', () => {
  const text = read('README.md');
  const row = text.split('\n').find((l) => l.includes('`lead-programmer`'));
  assert.ok(row, 'lead-programmer row not found in README.md');
  assert.ok(/\|\s*haiku\s*\|/.test(row), `expected haiku in README row, got: ${row}`);
});

check('AC-D5: agents/task-master.md default tag is haiku, not sonnet', () => {
  const text = read('agents/task-master.md');
  assert.ok(text.includes('`haiku` is\n  the default for every unit'), 'task-master.md does not state haiku as the default tag');
  assert.ok(!text.includes('`sonnet` is\n  the default'), 'task-master.md still states sonnet as the default tag');
});

check('AC-D5: CONTEXT.md Implementer-tier ratchet reads two attempts per tier, haiku→sonnet→opus', () => {
  const text = read('CONTEXT.md');
  assert.ok(text.includes('two attempts per tier, `haiku`→`sonnet`→`opus`'), 'CONTEXT.md does not state the two-attempts-per-tier ratchet');
  assert.ok(!text.includes('`sonnet`→`opus` on re-attempt'), 'CONTEXT.md still states the stale sonnet→opus re-attempt ratchet');
});

check('AC-D6: no surface instructs pre-emptive "looks mechanical" tier tagging', () => {
  for (const rel of ['agents/task-master.md', 'agents/orchestrator.md', 'agents/lead-programmer.md',
    'adapters/cursor/agents/lead-programmer.md', 'adapters/codex/agents/lead-programmer.toml',
    '.claude/agents/task-master.md', '.claude/agents/orchestrator.md', '.claude/agents/lead-programmer.md']) {
    const text = stripWhitespace(read(rel));
    assert.ok(!/looksmechanical/i.test(text),`${rel} contains a "looks mechanical" pre-emptive tagging reference`);
  }
});

check('AC-D7: orchestrator.md states the two-attempts-per-tier Escalation ladder, not a first-FAIL escalation', () => {
  const text = read('agents/orchestrator.md');
  assert.ok(/\*\*Escalation ladder\.\*\* Each implementer tier gets two attempts/.test(text), 'orchestrator.md does not state the Escalation ladder rule');
  assert.ok(!/Sonnet units escalate on first FAIL/.test(text), 'orchestrator.md still states the stale sonnet-first-FAIL escalation rule');
  assert.ok(!/Haiku units escalate on first FAIL/.test(text), 'orchestrator.md still states the stale haiku-first-FAIL escalation rule');
});

check('AC-D8: ADR-0026 pins the pre-registered forward-verification rule by substring', () => {
  const text = read('docs/adr/0026-writer-tier-reversed-to-sonnet.md');
  assert.ok(text.includes('≥60 units'), 'ADR-0026 does not state the >=60 units threshold');
  assert.ok(text.includes('32.5%'), 'ADR-0026 does not state the 32.5% FAIL-rate threshold');
  assert.ok(text.includes('must not materially worsen'), 'ADR-0026 does not state the spend-neutrality condition');
});

check('AC-D8b: the haiku-default ADR pins its forward rule, and ADR-0026 names it', () => {
  const dir = path.join(REPO_ROOT, 'docs', 'adr');
  const hits = fs.readdirSync(dir).filter((f) => /^\d{4}-implementer-tier-haiku-default\.md$/.test(f));
  assert.strictEqual(hits.length, 1, `expected exactly one *-implementer-tier-haiku-default.md ADR, got ${hits.length}`);
  const text = fs.readFileSync(path.join(dir, hits[0]), 'utf8');
  for (const s of ['Amends: ADR-0026', '≥60 units dispatched under the `haiku` default', 'fail-rate ≤ 0.35',
    'escalation-rate ≤ 0.15', 'exhaustion-rate ≤ 0.02', 'tripwire']) {
    assert.ok(text.includes(s), `${hits[0]} does not state ${s}`);
  }
  assert.ok(/^Superseded-in-part-by: ADR-\d{4} /m.test(read('docs/adr/0026-writer-tier-reversed-to-sonnet.md')), 'ADR-0026 lacks its Superseded-in-part-by line');
});

check('AC-D10: this repo\'s own defaultImplementerModel resolves to the lead-programmer frontmatter default', () => {
  const cli = require(path.join(REPO_ROOT, 'bin', 'cli.js'));
  const config = JSON.parse(read(path.join('.claude', 'persona-config.json')));
  const fm = frontmatterModel(read('agents/lead-programmer.md'));
  assert.strictEqual(cli.resolveDefaultImplementerModel(config, fm), fm);
});

check('AC-D11: orchestrator.md states exactly one Haiku-default cutover timestamp', () => {
  const hits = read('agents/orchestrator.md').match(/\*\*Haiku-default cutover: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\.\*\*/g) || [];
  assert.strictEqual(hits.length, 1, `expected one cutover line, got ${hits.length}`);
});

// AC-D9 checks match with ALL whitespace stripped (not just collapsed) from
// both haystack and needle, so a banned phrase can't be evaded by wrapping
// it across a line break — regardless of whether the wrap point falls on a
// pre-existing space (e.g. "haiku →\nFAIL") or splits two tokens that had no
// space between them at all (e.g. "haiku|\nsonnet|opus").
function stripWhitespace(text) {
  return text.replace(/\s+/g, '');
}

check('AC-D9: agents/orchestrator.md states the three-tier vocabulary and no stale default or ladder', () => {
  const text = stripWhitespace(read('agents/orchestrator.md'));
  assert.ok(!text.includes(stripWhitespace('`model: sonnet` frontmatter is the')), 'orchestrator.md still claims sonnet frontmatter is the default');
  assert.ok(text.includes(stripWhitespace('`Suggested model: haiku|sonnet|opus`')), 'orchestrator.md does not list the haiku|sonnet|opus Suggested model vocabulary');
  assert.ok(!text.includes(stripWhitespace('sonnet → FAIL → opus → FAIL')), 'orchestrator.md still states the ADR-0026 sonnet-first cap path');
  assert.ok(!text.includes(stripWhitespace('never dispatch on `haiku`')), 'orchestrator.md still contains the vacuous never-dispatch-on-haiku clause');
});

check('AC-D9: agents/spec-master.md never tags the re-scoped step for haiku', () => {
  const text = stripWhitespace(read('agents/spec-master.md'));
  assert.ok(!text.includes(stripWhitespace('never tags the re-scoped step')), 'spec-master.md still contains the vacuous never-tags-the-re-scoped-step clause');
});

// AC-D9b: the banned-literal checks above only look at orchestrator.md and
// spec-master.md in isolation. The real invariant is that orchestrator.md's
// stated `Suggested model` vocabulary must agree with task-master.md's
// actual vocabulary line — pin that agreement explicitly, rather than a
// standalone ban, so a future change to task-master.md's vocabulary (e.g.
// re-adding haiku) is caught even if orchestrator.md is never touched.
function suggestedModelVocabulary(text, label) {
  const m = stripWhitespace(text).match(/Suggestedmodel:([a-z]+(?:\|[a-z]+)+)/);
  assert.ok(m, `could not find a Suggested model vocabulary list in ${label}`);
  return m[1];
}

check('AC-D9b: agents/orchestrator.md Suggested model vocabulary agrees with agents/task-master.md', () => {
  const taskMasterVocab = suggestedModelVocabulary(read('agents/task-master.md'), 'agents/task-master.md');
  const orchestratorVocab = suggestedModelVocabulary(read('agents/orchestrator.md'), 'agents/orchestrator.md');
  assert.strictEqual(
    orchestratorVocab,
    taskMasterVocab,
    `orchestrator.md states "${orchestratorVocab}" but task-master.md's actual vocabulary is "${taskMasterVocab}"`,
  );
});

// AC-T1 / AC-A1 (rgh-h8, contract-hardening H8).
// fc-4 G1: read a key from the frontmatter block only (shaped like default-implementer-model's frontmatterModel).
function frontmatterKey(text, key) {
  const fm = text.match(/^---\n([\s\S]*?)\n---/);
  const m = fm && fm[1].match(new RegExp(`^${key}:\\s*(\\S+)$`, 'm'));
  return m ? m[1] : null;
}

check('AC-T1: spec-master and task-master run with maxTurns: 120', () => {
  for (const rel of ['agents/spec-master.md', 'agents/task-master.md']) {
    assert.strictEqual(frontmatterKey(read(rel), 'maxTurns'), '120', `${rel} frontmatter does not pin maxTurns: 120`);
  }
});

function contractPrecedence(rel) {
  const lines = read(rel).split('\n');
  // fc-4 G2: exactly one Contract precedence bullet.
  assert.strictEqual(lines.filter((l) => l.startsWith('- **Contract precedence.**')).length, 1, `${rel} must have exactly one Contract precedence bullet`);
  const start = lines.findIndex((l) => l.startsWith('- **Contract precedence.**'));
  assert.ok(start >= 0, `${rel} has no Contract precedence bullet`);
  let end = lines.findIndex((l, i) => i > start && l.startsWith('- **'));
  if (end < 0) end = lines.length;
  return stripWhitespace(lines.slice(start, end).join('\n'));
}

check('AC-A1: Contract precedence paragraph is identical in lead-programmer and its two ports', () => {
  const src = contractPrecedence('agents/lead-programmer.md');
  for (const rel of ['adapters/cursor/agents/lead-programmer.md', 'adapters/codex/agents/lead-programmer.toml', '.claude/agents/lead-programmer.md']) {
    assert.strictEqual(contractPrecedence(rel), src, `${rel} differs from agents/lead-programmer.md`);
  }
});

// fc-4 G4: presence pins, matched with all whitespace stripped (the item06-3 NOTE[spec] convention).
function hasAll(rel, needles) {
  const text = stripWhitespace(read(rel));
  for (const n of needles) assert.ok(text.includes(stripWhitespace(n)), `${rel} lacks ${n}`);
}

check('AC-P1: orchestrator.md keeps its guarded text and the fc-2 rules', () => {
  hasAll('agents/orchestrator.md', ['At the 2-FAIL cap', '**Escalation ladder.**',
    '**`fable` is excluded for `task-master`**', '## Milestone audit gate', 'starts with neither', 'Gate for item 3']);
});

check('AC-P2: task-master.md names the nine dispatch-contract markers H4 checks', () => {
  hasAll('agents/task-master.md', ['Unit:', '## Objective', '## Retrieval', '## Affected files', '## Ordered edits',
    '## Do NOT touch', '## Acceptance criteria', '## Pre-resolved context', '## Escalation']);
});

check('AC-P3: scribe and lead-programmer keep their contract bullets', () => {
  hasAll('agents/scribe.md', ['**Contract-only doc edits.**']);
  hasAll('agents/lead-programmer.md', ['- **Contract precedence.**']);
});

console.log(failures === 0 ? '\nAll writer-tier-consistency checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
