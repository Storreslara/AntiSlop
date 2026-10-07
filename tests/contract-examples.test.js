#!/usr/bin/env node
'use strict';

// AC-H2.1 (rgh-h2): the worked examples in agents/task-master.md score 7/7 under --rubric=v2.
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

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

// Whole-line markers; the fence lines directly inside the markers are dropped.
function example(name) {
  const lines = fs.readFileSync(path.join(REPO_ROOT, 'agents', 'task-master.md'), 'utf8').split('\n');
  const b = lines.indexOf(`<!-- ${name}:begin -->`);
  const e = lines.indexOf(`<!-- ${name}:end -->`);
  assert.ok(b >= 0 && e > b, `${name} markers not found`);
  const body = lines.slice(b + 1, e);
  if (/^```/.test(body[0])) body.shift();
  if (/^```/.test(body[body.length - 1])) body.pop();
  return body.join('\n');
}

function score(text, scribe) {
  const args = ['bin/contract-score.js', '-', '--rubric=v2'];
  if (scribe) args.push('--shape=scribe');
  const r = spawnSync('node', args, { cwd: REPO_ROOT, encoding: 'utf8', input: text });
  assert.strictEqual(r.status, 0, r.stderr);
  return JSON.parse(r.stdout.trim());
}

check('lead example scores 7 under v2', () => {
  const j = score(example('lead-contract-example'));
  assert.strictEqual(j.score, 7, JSON.stringify(j.rows));
});

check('scribe example scores 7 under v2', () => {
  const j = score(example('scribe-contract-example'), true);
  assert.strictEqual(j.score, 7, JSON.stringify(j.rows));
});

console.log(failures === 0 ? '\nAll contract-examples checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
