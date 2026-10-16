'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { round2, applyDiscountPercent, cartTotal } = require('../src/pricing');

test('[holdout] applyDiscountPercent still mutates in place and returns the same array', () => {
  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
  const out = applyDiscountPercent(items, 10);
  assert.equal(out, items);
  assert.deepEqual(items.map((i) => i.price), [90, 45]);
});

test('[holdout] cartTotal still sums price times qty', () => {
  assert.equal(cartTotal([{ price: 10, qty: 2 }, { price: 5, qty: 3 }]), 35);
  assert.equal(cartTotal([]), 0);
});

test('[holdout] round2 still rounds to two places', () => {
  assert.equal(round2(10.456), 10.46);
});
