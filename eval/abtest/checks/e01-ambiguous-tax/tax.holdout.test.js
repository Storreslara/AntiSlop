'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const pricing = require('../src/pricing');

test('[holdout] tax applies to the discounted total with a percentage rate', () => {
  const total = pricing.cartTotalWithTax([{ price: 100, qty: 1 }], 10, 20);
  assert.equal(total, 108);
});

test('[holdout] the input items are not mutated', () => {
  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
  const before = JSON.parse(JSON.stringify(items));
  pricing.cartTotalWithTax(items, 10, 20);
  assert.deepEqual(items, before);
});

test('[holdout] zero discount and zero tax return the plain cart total', () => {
  const items = [{ price: 10, qty: 2 }, { price: 5, qty: 3 }];
  assert.equal(pricing.cartTotalWithTax(items, 0, 0), 35);
});
