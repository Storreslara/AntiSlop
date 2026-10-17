'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createStore } = require('../src/store');
const { findByTitle } = require('./helpers');

test('findByTitle returns nothing for an unknown title', () => {
  const store = createStore();
  store.add({ owner: 'alice', title: 'only' });
  assert.deepEqual(findByTitle(store, 'missing'), []);
});
