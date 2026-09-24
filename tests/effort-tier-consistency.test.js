#!/usr/bin/env node
'use strict';

// Coverage for cost-governance-step4-effort-tiers (spec #476, Step 4 of
// 2026-09-23-cost-governance-output-cap-and-effort-tiers): effort:
// frontmatter tiers must read the same literal across source and mirror,
// reviewer's `high` is a floor (mutation-proof, not merely "a valid value"),
// and milestone-auditor stays undeclared per the user's settled decision.

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const AGENTS_DIRS = ['agents', path.join('.claude', 'agents')];
const VALID_TIERS = new Set(['low', 'medium', 'high', 'xhigh', 'max']);

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

function frontmatterEffort(text) {
  const m = text.match(/^---\n[\s\S]*?\n---/);
  if (!m) return null;
  const line = m[0].match(/^effort:\s*(\S+)$/m);
  return line ? line[1] : null;
}

function isValidEffort(v) {
  return VALID_TIERS.has(v) || /^-?\d+$/.test(v);
}

const TIERS = { explorer: 'low', 'task-master': 'medium', reviewer: 'high' };

for (const [persona, tier] of Object.entries(TIERS)) {
  check(`AC1: agents/${persona}.md declares effort: ${tier}`, () => {
    assert.strictEqual(frontmatterEffort(read(`agents/${persona}.md`)), tier);
  });
  check(`AC1: .claude/agents/${persona}.md mirror declares effort: ${tier}`, () => {
    assert.strictEqual(frontmatterEffort(read(`.claude/agents/${persona}.md`)), tier);
  });
}

check('AC3: reviewer effort is literally high, a floor not a tuning (mutation-proof)', () => {
  assert.strictEqual(frontmatterEffort(read('agents/reviewer.md')), 'high');
  assert.strictEqual(frontmatterEffort(read('.claude/agents/reviewer.md')), 'high');
});

check('AC7: agents/milestone-auditor.md declares no effort: key', () => {
  assert.strictEqual(frontmatterEffort(read('agents/milestone-auditor.md')), null);
});

check('AC7: .claude/agents/milestone-auditor.md mirror declares no effort: key', () => {
  assert.strictEqual(frontmatterEffort(read('.claude/agents/milestone-auditor.md')), null);
});

check('AC2: every declared effort: value in agents/ and .claude/agents/ is a valid tier or integer', () => {
  for (const dir of AGENTS_DIRS) {
    const files = fs.readdirSync(path.join(REPO_ROOT, dir)).filter((f) => f.endsWith('.md'));
    for (const f of files) {
      const v = frontmatterEffort(read(path.join(dir, f)));
      if (v !== null) {
        assert.ok(isValidEffort(v), `${dir}/${f} declares invalid effort: ${v}`);
      }
    }
  }
});

console.log(failures === 0 ? '\nAll effort-tier-consistency checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
