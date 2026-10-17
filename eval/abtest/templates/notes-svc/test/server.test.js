'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');
const { createStore } = require('../src/store');

async function withServer(fn) {
  const store = createStore();
  const server = createServer(store);
  await new Promise((resolve) => server.listen(0, resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base, store);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

const alice = { authorization: 'Bearer tok-alice', 'content-type': 'application/json' };
const bob = { authorization: 'Bearer tok-bob', 'content-type': 'application/json' };

test('every route requires a bearer token', async () => {
  await withServer(async (base) => {
    assert.equal((await fetch(`${base}/notes`)).status, 401);
    assert.equal((await fetch(`${base}/notes`, { headers: { authorization: 'Bearer nope' } })).status, 401);
  });
});

test('POST then GET returns only the caller notes', async () => {
  await withServer(async (base) => {
    const made = await fetch(`${base}/notes`, { method: 'POST', headers: alice, body: JSON.stringify({ title: 'hello' }) });
    assert.equal(made.status, 201);
    await fetch(`${base}/notes`, { method: 'POST', headers: bob, body: JSON.stringify({ title: 'secret' }) });
    const mine = await (await fetch(`${base}/notes`, { headers: alice })).json();
    assert.deepEqual(mine.items.map((n) => n.title), ['hello']);
  });
});

test('GET /notes?title= filters by exact title', async () => {
  await withServer(async (base) => {
    for (const title of ['a', 'b']) {
      await fetch(`${base}/notes`, { method: 'POST', headers: alice, body: JSON.stringify({ title }) });
    }
    const hit = await (await fetch(`${base}/notes?title=b`, { headers: alice })).json();
    assert.deepEqual(hit.items.map((n) => n.title), ['b']);
  });
});

test('GET /notes?title= never shows another owner\'s notes', async () => {
  await withServer(async (base) => {
    for (const headers of [alice, bob]) {
      await fetch(`${base}/notes`, { method: 'POST', headers, body: JSON.stringify({ title: 'shared' }) });
    }
    const mine = await (await fetch(`${base}/notes?title=shared`, { headers: alice })).json();
    assert.deepEqual(mine.items.map((n) => n.owner), ['alice']);
    const theirs = await (await fetch(`${base}/notes?title=shared`, { headers: bob })).json();
    assert.deepEqual(theirs.items.map((n) => n.owner), ['bob']);
  });
});

test('POST without a title is a 400', async () => {
  await withServer(async (base) => {
    const bad = await fetch(`${base}/notes`, { method: 'POST', headers: alice, body: JSON.stringify({}) });
    assert.equal(bad.status, 400);
  });
});

test('DELETE removes an own note and refuses a foreign one', async () => {
  await withServer(async (base) => {
    const note = await (await fetch(`${base}/notes`, { method: 'POST', headers: alice, body: JSON.stringify({ title: 'x' }) })).json();
    assert.equal((await fetch(`${base}/notes/${note.id}`, { method: 'DELETE', headers: bob })).status, 404);
    assert.equal((await fetch(`${base}/notes/${note.id}`, { method: 'DELETE', headers: alice })).status, 200);
  });
});
