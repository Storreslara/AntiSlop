#!/usr/bin/env node
'use strict';

// Reviewer dispatch line-order pin (rnf-5): agents/orchestrator.md **Review routing**
// gives a reviewer dispatch's opening lines in order. `Unit: <task-id>` is first. A
// verdict-owning dispatch has `Implementer tier: <t>` second; an advisory one has
// `Mode: advisory` second and the tier line third. Whitespace is flattened first, so
// rewrapping the paragraph does not break the check. A missing file is a FAIL line.

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const REL = 'agents/orchestrator.md';
const PHRASES = [
  'That dispatch opens with `Unit: <task-id>` as its **literal first non-blank line**',
  'Unless the dispatch is advisory (below), its second non-blank line is `Implementer tier: <t>`',
  'add `Mode: advisory` as the **literal second non-blank line**, immediately after `Unit: <id>`, and move the `Implementer tier:` line to third.',
];

let failures = 0;
let flat = null;
try {
  flat = fs.readFileSync(path.join(REPO_ROOT, REL), 'utf8').replace(/\s+/g, ' ');
} catch (e) {
  console.log(`FAIL ${REL}: unreadable (${e.code || e.message})`);
  failures++;
}
if (flat !== null) {
  for (const phrase of PHRASES) {
    if (flat.includes(phrase)) {
      console.log(`OK   ${REL}: ${phrase}`);
    } else {
      console.log(`FAIL ${REL}: missing ${phrase}`);
      failures++;
    }
  }
}

console.log(failures === 0
  ? 'All reviewer-dispatch-line-order checks passed.'
  : `${failures} reviewer-dispatch-line-order check(s) FAILED.`);
process.exit(failures === 0 ? 0 : 1);
