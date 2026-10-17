'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

test('[holdout] GET /notes?title= never shows another owner notes', async () => {
  const store = createStore();
  store.add({ owner: 'alice', title: 'shared' });
  store.add({ owner: 'bob', title: 'shared' });
  store.add({ owner: 'bob', title: 'other' });
  const server = createServer(store);
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    const url = `http://127.0.0.1:${server.address().port}/notes?title=shared`;
    const mine = await (await fetch(url, { headers: { authorization: 'Bearer tok-alice' } })).json();
    assert.deepEqual(mine.items.map((n) => n.owner), ['alice']);
    const theirs = await (await fetch(url, { headers: { authorization: 'Bearer tok-bob' } })).json();
    assert.deepEqual(theirs.items.map((n) => n.owner), ['bob']);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
