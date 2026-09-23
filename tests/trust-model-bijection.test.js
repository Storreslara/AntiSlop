#!/usr/bin/env node
'use strict';

// Bijection guard for docs/trust-model.md (issue gh422, spec F4 map): every
// hook-registered gate under hooks/scripts/ (excluding lib/, which is
// sourced-only and never itself hook-registered) must appear in the trust
// map, every script the map names as a "checked by" value must exist on
// disk, and every "checked by" cell must resolve to an existing path or the
// literal token `self-reported` — except the two rows the spec explicitly
// exempts (a forward reference to not-yet-landed Step 4, and the
// credential-split upgrade path, neither of which claims a check exists
// today). The self-reported count is pinned exactly so that converting one
// row from self-reported to mechanically-checked without updating this
// test silently drifts the map out of date.

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const DOC_PATH = path.join(REPO_ROOT, 'docs/trust-model.md');
const HOOK_SCRIPTS_DIR = path.join(REPO_ROOT, 'hooks/scripts');

// The two rows documenting plan architecture rather than a check that
// exists today (see docs/plans/2026-08-25-harness-trust-gaps.md, Step 8).
const EXEMPT_CHECKED_BY_PREFIX = '**';
const EXPECTED_SELF_REPORTED_COUNT = 10;
const EXPECTED_EXEMPT_COUNT = 2;

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

const docText = fs.readFileSync(DOC_PATH, 'utf8');

function tableDataRows(text) {
  return text
    .split('\n')
    .filter((line) => line.trim().startsWith('|'))
    .map((line) => line.split('|').map((c) => c.trim()).filter((c, i, arr) => !(i === 0 && c === '') && !(i === arr.length - 1 && c === '')))
    .filter((cells) => cells.length >= 4)
    .filter((cells) => cells[0] !== '#' && !/^-+$/.test(cells[0]));
}

const rows = tableDataRows(docText);

check('the doc has table rows to check (non-vacuity)', () => {
  assert.ok(rows.length > 0, 'no markdown table rows parsed out of docs/trust-model.md');
});

const scriptFiles = fs
  .readdirSync(HOOK_SCRIPTS_DIR)
  .filter((f) => f.endsWith('.sh') && fs.statSync(path.join(HOOK_SCRIPTS_DIR, f)).isFile());

check('C8.2 direction 1: every hooks/scripts/*.sh (excluding lib/) appears in the table', () => {
  for (const f of scriptFiles) {
    assert.ok(docText.includes(f), `${f} is not mentioned anywhere in docs/trust-model.md`);
  }
});

const PATH_CELL_RE = /`([\w./-]+\.sh)`/;

check('C8.2 direction 2 + checked-by classification: every "checked by" cell is an existing path or `self-reported`', () => {
  let selfReportedCount = 0;
  let exemptCount = 0;

  for (const cells of rows) {
    const checkedBy = cells[3];
    if (checkedBy === 'self-reported') {
      selfReportedCount++;
      continue;
    }
    if (checkedBy.startsWith(EXEMPT_CHECKED_BY_PREFIX)) {
      exemptCount++;
      continue;
    }
    const m = checkedBy.match(PATH_CELL_RE);
    assert.ok(m, `unclassified "checked by" cell (not a backtick-quoted .sh path, not "self-reported", not an exempt "**..." marker): ${JSON.stringify(checkedBy)}`);
    const scriptPath = path.join(REPO_ROOT, m[1]);
    assert.ok(fs.existsSync(scriptPath), `checked-by path does not exist on disk: ${m[1]}`);
  }

  assert.strictEqual(selfReportedCount, EXPECTED_SELF_REPORTED_COUNT, `expected exactly ${EXPECTED_SELF_REPORTED_COUNT} self-reported rows, found ${selfReportedCount} — if you converted a row to a mechanical check, update EXPECTED_SELF_REPORTED_COUNT here too`);
  assert.strictEqual(exemptCount, EXPECTED_EXEMPT_COUNT, `expected exactly ${EXPECTED_EXEMPT_COUNT} exempt (forward-reference / upgrade-path) rows, found ${exemptCount}`);
});

if (failures) {
  console.log(`\n${failures} trust-model-bijection check(s) FAILED.`);
  process.exit(1);
}
console.log('\nAll trust-model-bijection checks passed.');
