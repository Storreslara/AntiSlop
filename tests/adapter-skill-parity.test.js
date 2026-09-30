#!/usr/bin/env node
'use strict';

// Byte-parity guard: each Codex/Cursor port inlines the SKILL.md bodies its
// Claude counterpart preloads, between sentinel lines. Fails CLOSED on a
// missing or duplicated sentinel. SKILL_PARITY_SKILLS_DIR points the source
// side at a temp copy (mutation proof).

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const SKILLS_DIR = process.env.SKILL_PARITY_SKILLS_DIR || path.join(REPO_ROOT, 'skills');

const ROWS = [
  ['adapters/codex/agents/lead-programmer.toml', 'coding-discipline'],
  ['adapters/codex/agents/lead-programmer.toml', 'tdd'],
  ['adapters/cursor/agents/lead-programmer.md', 'coding-discipline'],
  ['adapters/cursor/agents/lead-programmer.md', 'tdd'],
  ['adapters/codex/agents/reviewer.toml', 'roast-work'],
  ['adapters/cursor/agents/reviewer.md', 'roast-work'],
];

function skillBody(name) {
  const text = fs.readFileSync(path.join(SKILLS_DIR, name, 'SKILL.md'), 'utf8');
  const m = /^---\n[\s\S]*?\n---\n/.exec(text);
  if (!m) throw new Error(`${name}/SKILL.md has no frontmatter`);
  return text.slice(m[0].length);
}

function inlinedBlock(text, name) {
  const begin = `<!-- BEGIN inlined-skill: ${name} -->\n`;
  const end = `<!-- END inlined-skill: ${name} -->`;
  const count = (s) => text.split(s).length - 1;
  if (count(begin) !== 1) throw new Error(`BEGIN sentinel for ${name} found ${count(begin)} times, expected 1`);
  if (count(end) !== 1) throw new Error(`END sentinel for ${name} found ${count(end)} times, expected 1`);
  const from = text.indexOf(begin) + begin.length;
  const to = text.indexOf(end);
  if (to < from) throw new Error(`END sentinel precedes BEGIN for ${name}`);
  return text.slice(from, to);
}

module.exports = { skillBody, inlinedBlock };

if (require.main === module) {
  let failures = 0;
  for (const [port, name] of ROWS) {
    const label = `${port} inlines ${name}`;
    try {
      const text = fs.readFileSync(path.join(REPO_ROOT, port), 'utf8');
      assert.strictEqual(inlinedBlock(text, name), skillBody(name), 'inlined block differs from SKILL.md body');
      console.log(`OK   ${label}`);
    } catch (err) {
      console.log(`FAIL ${label}: ${err.message}`);
      failures++;
    }
  }
  process.exit(failures ? 1 : 0);
}
