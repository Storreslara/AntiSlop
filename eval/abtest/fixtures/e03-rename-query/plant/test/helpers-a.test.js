'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createStore } = require('../src/store');
const { findByTitle } = require('./helpers');

test('findByTitle returns every note with that title', () => {
  const store = createStore();
  store.add({ owner: 'alice', title: 'dup' });
  store.add({ owner: 'bob', title: 'dup' });
  store.add({ owner: 'bob', title: 'other' });
  assert.equal(findByTitle(store, 'dup').length, 2);
});
