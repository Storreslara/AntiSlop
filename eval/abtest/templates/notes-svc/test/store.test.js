'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createStore } = require('../src/store');

function seeded() {
  const store = createStore();
  store.add({ owner: 'alice', title: 'one' });
  store.add({ owner: 'alice', title: 'two' });
  store.add({ owner: 'bob', title: 'three' });
  return store;
}

test('add assigns sequential ids and get returns the note', () => {
  const store = seeded();
  assert.equal(store.get('n1').title, 'one');
  assert.equal(store.get('missing'), null);
});

test('list returns only the owner notes, paged by cursor', () => {
  const store = seeded();
  const first = store.list({ owner: 'alice', limit: 1 });
  assert.deepEqual(first.items.map((n) => n.title), ['one']);
  assert.equal(first.next, 'n1');
  const second = store.list({ owner: 'alice', limit: 1, cursor: first.next });
  assert.deepEqual(second.items.map((n) => n.title), ['two']);
  assert.equal(second.next, null);
});

test('query filters with an expression over note', () => {
  const store = seeded();
  const rows = store.query(`note.title === ${JSON.stringify('three')}`);
  assert.deepEqual(rows.map((n) => n.owner), ['bob']);
});

test('remove deletes a note', () => {
  const store = seeded();
  assert.equal(store.remove('n1'), true);
  assert.equal(store.get('n1'), null);
});
