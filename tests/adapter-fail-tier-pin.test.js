#!/usr/bin/env node
'use strict';

// Adapter FAIL-block tier pin (rnf-2): each hand-maintained adapter port that
// describes the reviewer's FAIL record says a block's second line is the `tier:`
// line, with `unknown` when the dispatch names no implementer tier. Whitespace is
// flattened first, so rewrapping a port does not break the check.

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const PORTS = [
  'adapters/codex/agents/reviewer.toml',
  'adapters/codex/agents-md-fragment.md',
  'adapters/cursor/agents/reviewer.md',
  'adapters/cursor/rules/persona-protocol.mdc',
];
const PHRASES = [
  'then a second line `tier: <haiku|sonnet|opus|unknown>`',
  '(`unknown` when the dispatch names no implementer tier)',
];

let failures = 0;
for (const rel of PORTS) {
  let flat;
  try {
    flat = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').replace(/\s+/g, ' ');
  } catch (e) {
    console.log(`FAIL ${rel}: unreadable (${e.code || e.message})`);
    failures++;
    continue;
  }
  for (const phrase of PHRASES) {
    if (flat.includes(phrase)) {
      console.log(`OK   ${rel}: ${phrase}`);
    } else {
      console.log(`FAIL ${rel}: missing ${phrase}`);
      failures++;
    }
  }
}

console.log(failures === 0
  ? 'All adapter-fail-tier-pin checks passed.'
  : `${failures} adapter-fail-tier-pin check(s) FAILED.`);
process.exit(failures === 0 ? 0 : 1);
