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

check('AC-D5: agents/lead-programmer.md frontmatter reads model: sonnet', () => {
  assert.strictEqual(frontmatterModel(read('agents/lead-programmer.md')), 'sonnet');
});

check('AC-D5: .claude/agents/lead-programmer.md mirror reads model: sonnet', () => {
  assert.strictEqual(frontmatterModel(read('.claude/agents/lead-programmer.md')), 'sonnet');
});

check('AC-D5: README.md persona table lists lead-programmer as sonnet', () => {
  const text = read('README.md');
  const row = text.split('\n').find((l) => l.includes('`lead-programmer`'));
  assert.ok(row, 'lead-programmer row not found in README.md');
  assert.ok(/\|\s*sonnet\s*\|/.test(row), `expected sonnet in README row, got: ${row}`);
});

check('AC-D5: agents/task-master.md default tag is sonnet, not haiku', () => {
  const text = read('agents/task-master.md');
  assert.ok(text.includes('`sonnet` is\n  the default for every unit'), 'task-master.md does not state sonnet as the default tag');
  assert.ok(!text.includes('`haiku` is\n  the default'), 'task-master.md still states haiku as the default tag');
});

check('AC-D6: no surface instructs pre-emptive "looks mechanical" tier tagging', () => {
  for (const rel of ['agents/task-master.md', 'agents/orchestrator.md', 'agents/lead-programmer.md']) {
    const text = read(rel);
    assert.ok(!/looks mechanical/i.test(text), `${rel} contains a "looks mechanical" pre-emptive tagging reference`);
  }
});

check('AC-D7: orchestrator.md escalation ladder starts sonnet -> opus, not haiku -> sonnet', () => {
  const text = read('agents/orchestrator.md');
  assert.ok(
    /Sonnet units escalate on first FAIL/.test(text),
    'orchestrator.md does not state the sonnet-first-FAIL escalation rule',
  );
  assert.ok(
    !/Haiku units escalate on first FAIL/.test(text),
    'orchestrator.md still states the stale haiku-first-FAIL escalation rule',
  );
});

console.log(failures === 0 ? '\nAll writer-tier-consistency checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
