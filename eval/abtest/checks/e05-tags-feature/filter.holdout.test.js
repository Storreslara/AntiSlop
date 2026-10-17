'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { withServer, H, post } = require('./lib.holdout');

test('[holdout] GET /notes?tag= returns only the caller notes with that tag', async () => {
  await withServer(async (base) => {
    await post(base, 'alice', { title: 'one', tags: ['red', 'blue'] });
    await post(base, 'alice', { title: 'two', tags: ['blue'] });
    await post(base, 'alice', { title: 'three' });
    await post(base, 'bob', { title: 'four', tags: ['blue'] });
    const body = await (await fetch(`${base}/notes?tag=blue`, { headers: H('alice') })).json();
    assert.deepEqual(body.items.map((n) => n.title), ['one', 'two']);
    const none = await (await fetch(`${base}/notes?tag=green`, { headers: H('alice') })).json();
    assert.deepEqual(none.items, []);
  });
});

test('[holdout] the CLI list --tag prints only matching notes', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'notes-tag-'));
  const seed = path.join(dir, 'seed.json');
  fs.writeFileSync(seed, JSON.stringify([
    { owner: 'alice', title: 'red one', tags: ['red'] },
    { owner: 'bob', title: 'blue one', tags: ['blue'] },
    { owner: 'alice', title: 'plain' },
  ]));
  const cli = path.join(__dirname, '..', 'src', 'cli.js');
  const run = (args) => spawnSync(process.execPath, [cli, ...args], { env: { ...process.env, NOTES_SEED: seed }, encoding: 'utf8' });
  const red = run(['list', '--tag', 'red']);
  assert.equal(red.status, 0);
  assert.equal(red.stdout.trim().split('\n').length, 1);
  assert.match(red.stdout, /red one/);
  assert.equal(run(['list', '--tag', 'green']).stdout.trim(), '');
  assert.equal(run(['list']).stdout.trim().split('\n').length, 3);
});
