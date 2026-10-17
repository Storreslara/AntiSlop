'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const cli = path.join(__dirname, '..', 'src', 'cli.js');

function run(args) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'notes-cli-'));
  const seed = path.join(dir, 'seed.json');
  fs.writeFileSync(seed, JSON.stringify([
    { owner: 'alice', title: 'foo' },
    { owner: 'bob', title: 'bar' },
  ]));
  return spawnSync(process.execPath, [cli, ...args], { env: { ...process.env, NOTES_SEED: seed }, encoding: 'utf8' });
}

test('list prints every seeded note', () => {
  const out = run(['list']);
  assert.equal(out.status, 0);
  assert.equal(out.stdout.trim().split('\n').length, 2);
});

test('list --title prints only the matching note', () => {
  const out = run(['list', '--title', 'foo']);
  assert.equal(out.status, 0);
  assert.match(out.stdout, /\tfoo\n$/);
  assert.equal(out.stdout.trim().split('\n').length, 1);
});

test('an unknown command exits 2', () => {
  assert.equal(run(['bogus']).status, 2);
});
