'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createStore } = require('../src/store');

function seeded() {
  const store = createStore();
  store.add({ owner: 'alice', title: 'x' });
  store.add({ owner: 'bob', title: 'x' });
  store.add({ owner: 'alice', title: 'y' });
  return store;
}

test('[holdout] where keeps the notes the predicate accepts', () => {
  const rows = seeded().where((n) => n.title === 'x');
  assert.deepEqual(rows.map((n) => n.id), ['n1', 'n2']);
});

test('[holdout] where accepts a closure over outside values', () => {
  const owner = 'alice';
  const rows = seeded().where((n) => n.owner === owner);
  assert.deepEqual(rows.map((n) => n.title), ['x', 'y']);
});

test('[holdout] where with an always-false predicate returns an empty list', () => {
  assert.deepEqual(seeded().where(() => false), []);
});

test('[holdout] the string-based query is gone', () => {
  assert.equal(typeof seeded().query, 'undefined');
});
