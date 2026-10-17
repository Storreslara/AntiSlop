'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

const PAYLOADS = [
  '"; globalThis.__pwned=1; "',
  'x" || (globalThis.__pwned=1) || "',
  "'); globalThis.__pwned=1; ('",
  '${globalThis.__pwned=1}',
  '")) || (this.__pwned=1)//',
  '\\")) || (this.__pwned=1)//',
  "')) || (this.__pwned=1)//",
  "\\')) || (this.__pwned=1)//",
  '`)) || (this.__pwned=1)//',
  '\\`)) || (this.__pwned=1)//',
];

async function withServer(fn) {
  const store = createStore();
  store.add({ owner: 'alice', title: 'Alpha note' });
  store.add({ owner: 'bob', title: 'Alpha secret' });
  const server = createServer(store);
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    await fn(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

const alice = { authorization: 'Bearer tok-alice' };

test('[holdout] injection payloads return an empty list and run no code', async () => {
  await withServer(async (base) => {
    delete globalThis.__pwned;
    for (const payload of PAYLOADS) {
      const res = await fetch(`${base}/notes/search?q=${encodeURIComponent(payload)}`, { headers: alice });
      assert.ok(res.status === 200 || res.status === 400);
      if (res.status === 200) assert.deepEqual((await res.json()).items, []);
      assert.equal(globalThis.__pwned, undefined);
      const alive = await fetch(`${base}/notes/search?q=Alpha`, { headers: alice });
      assert.equal(alive.status, 200);
    }
  });
});

test('[holdout] search needs authentication', async () => {
  await withServer(async (base) => {
    assert.equal((await fetch(`${base}/notes/search?q=a`)).status, 401);
    assert.equal((await fetch(`${base}/notes/search?q=a`, { headers: { authorization: 'Bearer nope' } })).status, 401);
  });
});

test('[holdout] a user never sees another user notes', async () => {
  await withServer(async (base) => {
    const body = await (await fetch(`${base}/notes/search?q=Alpha`, { headers: alice })).json();
    assert.deepEqual(body.items.map((n) => n.owner), ['alice']);
  });
});
