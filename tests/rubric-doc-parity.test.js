#!/usr/bin/env node
'use strict';

// Rubric row-range parity (blf-5): a doc that states a rubric row range (R1-R7, S1-S5, S1-S7) must
// agree with the rows bin/contract-score.js reports. The row keys come from the scorer's own JSON
// output (black box: the scorer exports nothing).

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const FIX = 'tests/fixtures/contract-score';

let failures = 0;
function fail(msg) {
  console.log(`FAIL ${msg}`);
  failures++;
}
function ok(msg) {
  console.log(`OK   ${msg}`);
}

// The contiguous range of row keys the scorer reports for one fixture, shape and rubric.
function scorerRange(fixture, shape, rubric) {
  const r = spawnSync('node', ['bin/contract-score.js', `${FIX}/${fixture}`, `--shape=${shape}`, `--rubric=${rubric}`], { cwd: REPO_ROOT, encoding: 'utf8' });
  let keys = [];
  try {
    keys = Object.keys(JSON.parse(r.stdout).rows);
  } catch (e) {
    fail(`scorer ${shape} ${rubric}: no JSON rows (exit ${r.status})`);
    return null;
  }
  const letter = keys[0][0];
  if (!keys.every((k, i) => k === `${letter}${i + 1}`)) {
    fail(`scorer ${shape} ${rubric}: rows are not contiguous: ${keys.join(',')}`);
    return null;
  }
  return `${letter}1-${letter}${keys.length}`;
}

const lead = { v1: scorerRange('v2-all-pass.md', 'lead', 'v1'), v2: scorerRange('v2-all-pass.md', 'lead', 'v2') };
const scribe = { v1: scorerRange('v2-scribe-all-pass.md', 'scribe', 'v1'), v2: scorerRange('v2-scribe-all-pass.md', 'scribe', 'v2') };
if (lead.v1 !== lead.v2) fail('lead rows differ between rubrics: v1 ' + lead.v1 + ', v2 ' + lead.v2);

const flat = (text) => text.replace(/\s+/g, ' ');
const read = (rel) => fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');

// A glossary entry: its heading line down to the next blank line, whitespace flattened.
function entry(rel, heading) {
  const lines = read(rel).split('\n');
  const start = lines.findIndex((l) => l.startsWith(heading));
  if (start < 0) {
    fail(`${rel}: no entry ${heading}`);
    return '';
  }
  let end = start;
  while (end < lines.length && lines[end].trim() !== '') end++;
  return flat(lines.slice(start, end).join(' '));
}

const rangesIn = (text) => [...text.matchAll(/\b([RS])\d+-\1\d+\b/g)].map((m) => m[0]);

// sMode 'each': every S-range equals the v2 scribe range; 'set': the S-ranges are exactly {v1, v2}; null: S-ranges are not checked.
const docs = [
  { name: 'CONTEXT.md rubric v2 entry', text: entry('CONTEXT.md', '**rubric v2**:'), sMode: 'each' },
  { name: 'docs/harness-glossary.md contract score entry', text: entry('docs/harness-glossary.md', '**contract score**:'), sMode: 'set' },
  { name: 'agents/task-master.md', text: flat(read('agents/task-master.md')), sMode: null },
];

for (const doc of docs) {
  const found = rangesIn(doc.text);
  if (found.length === 0) {
    fail(`${doc.name}: states no row range`);
    continue;
  }
  const bad = [];
  for (const r of found.filter((x) => x[0] === 'R')) {
    if (r !== lead.v2) bad.push(`${r} (the scorer's lead rows are ${lead.v2})`);
  }
  const s = found.filter((x) => x[0] === 'S');
  if (doc.sMode === 'each') {
    for (const r of s) if (r !== scribe.v2) bad.push(`${r} (the scorer's v2 scribe rows are ${scribe.v2})`);
  } else if (doc.sMode === 'set') {
    const got = [...new Set(s)].sort().join(' ');
    const want = [...new Set([scribe.v1, scribe.v2])].sort().join(' ');
    if (got !== want) bad.push(`S-ranges {${got}} differ from the scorer's {${want}}`);
  }
  if (bad.length) fail(`${doc.name}: ${bad.join('; ')}`);
  else ok(`${doc.name}: ${[...new Set(found)].join(', ')}`);
}

if (failures) {
  console.log(`\n${failures} rubric-doc-parity check(s) FAILED.`);
  process.exit(1);
}
console.log('\nAll rubric-doc-parity checks passed.');
