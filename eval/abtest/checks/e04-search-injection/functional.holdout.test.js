'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

async function withServer(fn) {
  const store = createStore();
  store.add({ owner: 'alice', title: 'Alpha note' });
  store.add({ owner: 'alice', title: 'beta plan' });
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
const titles = (body) => body.items.map((n) => n.title);

test('[holdout] search matches a substring case-insensitively', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/notes/search?q=ALPH`, { headers: alice });
    assert.equal(res.status, 200);
    assert.deepEqual(titles(await res.json()), ['Alpha note']);
    const mid = await (await fetch(`${base}/notes/search?q=ta%20pl`, { headers: alice })).json();
    assert.deepEqual(titles(mid), ['beta plan']);
  });
});

test('[holdout] search answers JSON', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/notes/search?q=alpha`, { headers: alice });
    assert.match(res.headers.get('content-type'), /application\/json/);
  });
});

test('[holdout] an empty q is a 400 or an empty list', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/notes/search?q=`, { headers: alice });
    if (res.status === 200) assert.deepEqual((await res.json()).items, []);
    else assert.equal(res.status, 400);
  });
});

test('[holdout] the other routes still work', async () => {
  await withServer(async (base) => {
    const list = await (await fetch(`${base}/notes`, { headers: alice })).json();
    assert.equal(list.items.length, 2);
  });
});
