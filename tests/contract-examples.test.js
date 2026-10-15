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

// fc-4 D7: catch a revert of H12's E3 (anchor form) and E6 (separate proof: line).
check('lead example anchors all use line matching', () => {
  const anchors = example('lead-contract-example').split('\n').filter((l) => /anchor:/.test(l));
  assert.ok(anchors.length > 0, 'the lead example has no anchors');
  for (const l of anchors) assert.ok(/anchor: line matching /.test(l), `not a line matching anchor: ${l}`);
});

check('scribe example has a separate proof: line', () => {
  assert.ok(example('scribe-contract-example').split('\n').some((l) => l.startsWith('   proof: ')), 'no separate proof: line');
});

// lov-4: the issue-body layout task-master documents is one bin/contract-guard.js accepts.
function guard(text, id) {
  const r = spawnSync('node', ['bin/contract-guard.js', '-', `--unit=${id}`], { cwd: REPO_ROOT, encoding: 'utf8', input: text });
  return r.stdout.trim();
}
function issueBody() {
  const lead = example('lead-contract-example');
  return example('issue-body-layout-example').split('\n')
    .map((l) => (l === '<the lead contract above, `Unit: demo-7` first>' ? lead : l)).join('\n');
}

check('issue-body layout example scores haiku through contract-guard', () => {
  assert.strictEqual(guard(issueBody(), 'demo-7'), 'contract-guard: haiku unit=demo-7 shape=lead score=7/7');
});

check('issue-body layout without its ~~~~ fence lines scores no-contract', () => {
  const unfenced = issueBody().split('\n').filter((l) => l !== '~~~~').join('\n');
  assert.strictEqual(guard(unfenced, 'demo-7'), 'contract-guard: sonnet unit=demo-7 shape=lead reason=no-contract');
});

// lo2-3: an issue body carrying both contracts, the lead one and then the scribe one under
// `## Dispatch contract (scribe)`, each fenced; the guard finds each by its own shape.
function guardShape(text, id, shape) {
  const r = spawnSync('node', ['bin/contract-guard.js', '-', `--unit=${id}`, `--shape=${shape}`], { cwd: REPO_ROOT, encoding: 'utf8', input: text });
  return r.stdout.trim();
}
function bothBody() {
  return `${issueBody()}\n\n## Dispatch contract (scribe)\n~~~~\n${example('scribe-contract-example')}\n~~~~\n`;
}

check('issue-body layout example ends with its fenced contract', () => {
  const lines = example('issue-body-layout-example').split('\n').filter((l) => l.trim() !== '');
  assert.strictEqual(lines[lines.length - 1], '~~~~');
});

check('issue body with both contracts: the scribe one scores haiku through contract-guard --shape=scribe', () => {
  assert.strictEqual(guardShape(bothBody(), 'demo-8', 'scribe'), 'contract-guard: haiku unit=demo-8 shape=scribe score=7/7');
});

check('issue body with both contracts: the lead one still scores haiku', () => {
  assert.strictEqual(guardShape(bothBody(), 'demo-7', 'lead'), 'contract-guard: haiku unit=demo-7 shape=lead score=7/7');
});

check('issue body with both contracts, unfenced: the scribe one scores no-contract', () => {
  const unfenced = bothBody().split('\n').filter((l) => l !== '~~~~').join('\n');
  assert.strictEqual(guardShape(unfenced, 'demo-8', 'scribe'), 'contract-guard: sonnet unit=demo-8 shape=scribe reason=no-contract');
});

console.log(failures === 0 ? '\nAll contract-examples checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
