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

check('mixed-do-not-touch-r6', () => onlyFalse(score('minus-R6-mixed.md'), R, 'R6'));

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

// --- Rubric v2 (rgh-h1): one named check per v2 rule, so reverting a rule to v1 fails a named check. ---
const S7 = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7'];

function scoreAs(rubric, file, scribe) {
  const args = [`${FIX}/${file}`, `--rubric=${rubric}`];
  if (scribe) args.push('--shape=scribe');
  const r = run(args);
  assert.strictEqual(r.status, 0, `exit ${r.status}: ${r.stderr}`);
  return JSON.parse(r.stdout.trim());
}

check('v1 regression: --rubric=v1 equals the default for every v1 fixture', () => {
  for (const f of fs.readdirSync(path.join(REPO_ROOT, FIX)).filter((n) => !n.startsWith('v2-'))) {
    const scribe = f.startsWith('scribe-');
    const plain = run(scribe ? [`${FIX}/${f}`, '--shape=scribe'] : [`${FIX}/${f}`]).stdout;
    const v1 = run(scribe ? [`${FIX}/${f}`, '--shape=scribe', '--rubric=v1'] : [`${FIX}/${f}`, '--rubric=v1']).stdout;
    assert.strictEqual(v1, plain, f);
    assert.strictEqual(JSON.parse(plain).rubric, 'v1', f);
  }
});

check('v2 all-pass scores 7', () => {
  const j = scoreAs('v2', 'v2-all-pass.md');
  assert.strictEqual(j.score, 7);
  assert.strictEqual(j.rubric, 'v2');
});

const v2Minus = { 'v2-minus-R1-indent': 'R1', 'v2-r1-short-indent': 'R1', 'v2-minus-R5-packet': 'R5',
  'v2-minus-R6-col': 'R6', 'v2-minus-R6-path': 'R6' };
for (const [f, k] of Object.entries(v2Minus)) {
  check(f, () => onlyFalse(scoreAs('v2', `${f}.md`), R, k));
}

for (const f of ['v2-r1-blank-line', 'v2-indented-context-keys', 'v2-r5-pass', 'v2-r5-tokens-ok']) {
  check(`${f} scores 7`, () => assert.strictEqual(scoreAs('v2', `${f}.md`).score, 7));
}

for (const f of ['v2-r5-name-token', 'v2-r5-todo', 'v2-r5-empty-fill', 'v2-r5-no-blank']) {
  check(`${f} scores R5 false`, () => onlyFalse(scoreAs('v2', `${f}.md`), R, 'R5'));
}

for (const f of ['v2-tilde']) {
  check(`${f} scores 7 under v2 and lower under v1`, () => {
    assert.strictEqual(scoreAs('v2', `${f}.md`).score, 7);
    assert.ok(scoreAs('v1', `${f}.md`).score < 7);
  });
}

check('v2 scribe all-pass scores 7', () => {
  const j = scoreAs('v2', 'v2-scribe-all-pass.md', true);
  assert.strictEqual(j.score, 7);
  for (const k of S7) assert.strictEqual(j.rows[k], true, k);
});

for (const [f, k] of Object.entries({ 'v2-minus-S3': 'S3', 'v2-minus-S6': 'S6', 'v2-minus-S7': 'S7' })) {
  check(f, () => onlyFalse(scoreAs('v2', `${f}.md`, true), S7, k));
}

check('v2-r1-pointer-in-payload', () => {
  assert.strictEqual(scoreAs('v2', 'v2-r1-pointer-in-payload.md').rows.R1, true);
  assert.strictEqual(scoreAs('v1', 'v2-r1-pointer-in-payload.md').rows.R1, false);
});

check('v2-r1-pointer-in-instruction', () => {
  assert.strictEqual(scoreAs('v2', 'v2-r1-pointer-in-instruction.md').rows.R1, false);
  const text = fs.readFileSync(path.join(REPO_ROOT, FIX, 'v2-r1-pointer-in-instruction.md'), 'utf8')
    .replace(' as specified in the plan', '');
  assert.strictEqual(JSON.parse(run(['-', '--rubric=v2'], text).stdout.trim()).rows.R1, true);
});

check('v2-r1-pointer-after-payload', () => {
  assert.strictEqual(scoreAs('v2', 'v2-r1-pointer-after-payload.md').rows.R1, false);
});

// --- rgh-h1b: lock in every v2 row that differs from v1, and the lookup hardening ---
// [fixture stem, scribe shape?, row, v2 value, v1 value or null when the row is n/a under v1]
const LOCK = [
  ['v2-fenced-heading-R2', false, 'R2', false, true],
  ['v2-fenced-heading-R3', false, 'R3', true, false],
  ['v2-tilde-run-R4', false, 'R4', true, false],
  ['v2-indented-diagnosis', false, 'R7', true, false],
  ['v2-S1-none', true, 'S1', true, false],
  ['v2-minus-S2-bare-title', true, 'S2', false, true],
  ['v2-minus-S2-backticked-none', true, 'S2', false, true],
  ['v2-fenced-heading-S4', true, 'S4', true, false],
  ['v2-fenced-heading-S5', true, 'S5', true, false],
  ['v2-r1-pointer-in-anchor', false, 'R1', true, null],
  ['v2-fence-len', false, 'R1', true, null],
  ['v2-fence-char', false, 'R1', true, null],
  ['v2-minus-S6-prune-not-last', true, 'S6', false, null],
  ['v2-r6-nested', false, 'R6', true, false],
  ['v2-r6-fenced', false, 'R6', true, false],
];
for (const [f, scribe, row, v2, v1] of LOCK) {
  check(f, () => {
    assert.strictEqual(scoreAs('v2', `${f}.md`, scribe).rows[row], v2, `v2 ${row}`);
    if (v1 !== null) assert.strictEqual(scoreAs('v1', `${f}.md`, scribe).rows[row], v1, `v1 ${row}`);
  });
}

check('v2-crlf scores 7 under v2 and lower under v1', () => {
  const text = fs.readFileSync(path.join(REPO_ROOT, FIX, 'v2-all-pass.md'), 'utf8').replace(/\n/g, '\r\n');
  assert.ok(text.includes('\r'), 'generated input carries no CR');
  assert.strictEqual(JSON.parse(run(['-', '--rubric=v2'], text).stdout.trim()).score, 7);
  const v1 = JSON.parse(run(['-', '--rubric=v1'], text).stdout.trim()).score;
  assert.strictEqual(v1, 4, `v1 scored ${v1}`);
});

check('v2-usage-proto-rubric', () => {
  // toString exists on Object.prototype, so only the rubric lookup can reject this call.
  const r = run([`${FIX}/v2-all-pass.md`, '--rubric=__proto__', '--shape=toString']);
  assert.strictEqual(r.status, 2);
  assert.ok(r.stderr.startsWith('usage:'), r.stderr);
});

check('v2-usage-proto-shape', () => {
  const r = run([`${FIX}/v2-all-pass.md`, '--rubric=v2', '--shape=toString']);
  assert.strictEqual(r.status, 2);
  assert.ok(r.stderr.startsWith('usage:'), r.stderr);
});

check('v2-r6-plus', () => {
  assert.strictEqual(scoreAs('v2', 'v2-r6-plus.md').rows.R6, true);
});

check('unknown rubric exits 2', () => {
  assert.strictEqual(run([`${FIX}/all-pass.md`, '--rubric=v3']).status, 2);
});

console.log(failures === 0 ? '\nAll contract-score checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
