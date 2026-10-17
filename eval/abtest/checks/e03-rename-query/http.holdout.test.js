'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

test('[holdout] GET /notes?title= still returns only the caller notes with that title', async () => {
  const store = createStore();
  store.add({ owner: 'alice', title: 'foo' });
  store.add({ owner: 'bob', title: 'foo' });
  store.add({ owner: 'alice', title: 'bar' });
  const server = createServer(store);
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    const url = `http://127.0.0.1:${server.address().port}/notes?title=foo`;
    const res = await fetch(url, { headers: { authorization: 'Bearer tok-alice' } });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.deepEqual(body.items.map((n) => `${n.owner}:${n.title}`), ['alice:foo']);
    assert.equal(body.next, null);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
