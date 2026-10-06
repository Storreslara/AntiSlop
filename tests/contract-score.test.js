#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const FIX = 'tests/fixtures/contract-score';

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

function run(args, input) {
  return spawnSync('node', ['bin/contract-score.js', ...args], { cwd: REPO_ROOT, encoding: 'utf8', input });
}

function score(file, scribe) {
  const r = run(scribe ? [`${FIX}/${file}`, '--shape=scribe'] : [`${FIX}/${file}`]);
  assert.strictEqual(r.status, 0, `exit ${r.status}: ${r.stderr}`);
  const lines = r.stdout.split('\n').filter(Boolean);
  assert.strictEqual(lines.length, 1, 'expected exactly one output line');
  return JSON.parse(lines[0]);
}

function onlyFalse(j, keys, bad) {
  assert.strictEqual(j.score, keys.length - 1);
  for (const k of keys) assert.strictEqual(j.rows[k], k !== bad, `${k} should be ${k !== bad}`);
}

const R = ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7'];
const S = ['S1', 'S2', 'S3', 'S4', 'S5'];

check('all-pass scores 7', () => {
  const j = score('all-pass.md');
  assert.strictEqual(j.score, 7);
  for (const k of R) assert.strictEqual(j.rows[k], true, k);
});

for (const k of R) {
  check(`minus-${k}`, () => onlyFalse(score(`minus-${k}.md`), R, k));
}

check('minus-R1-command', () => onlyFalse(score('minus-R1-command.md'), R, 'R1'));

check('pointer-body scores R1 false', () => {
  assert.strictEqual(score('pointer-body.md').rows.R1, false);
});

check('oversize sizeOver', () => {
  const j = score('oversize.md');
  assert.strictEqual(j.sizeOver, true);
  assert.strictEqual(j.maxBlockLines, 81);
  assert(j.bytes >= 31000, `bytes ${j.bytes}`);
});

check('scribe-all-pass scores 5', () => {
  const j = score('scribe-all-pass.md', true);
  assert.strictEqual(j.score, 5);
  for (const k of S) assert.strictEqual(j.rows[k], true, k);
});

const scribeRows = { glossary: 'S1', adr: 'S2', close: 'S3', donottouch: 'S4', criteria: 'S5' };
for (const [name, k] of Object.entries(scribeRows)) {
  check(`scribe-minus-${name}`, () => onlyFalse(score(`scribe-minus-${name}.md`, true), S, k));
}

check('stdin dash', () => {
  const text = fs.readFileSync(path.join(REPO_ROOT, FIX, 'all-pass.md'), 'utf8');
  const viaStdin = run(['-'], text);
  const viaFile = run([`${FIX}/all-pass.md`]);
  assert.strictEqual(viaStdin.status, 0);
  assert.strictEqual(viaStdin.stdout, viaFile.stdout);
});

check('unreadable exits 2', () => {
  assert.strictEqual(run([`${FIX}/does-not-exist.md`]).status, 2);
});

console.log(failures === 0 ? '\nAll contract-score checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
