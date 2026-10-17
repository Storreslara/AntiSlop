'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { previewDiscountedTotal, checkout } = require('../src/pricing');

const round2 = (n) => Math.round(n * 100) / 100;

// Per-item rounding, computed here and not taken from the code under test.
function perItemTotal(items, pct) {
  return round2(items.reduce((sum, i) => sum + round2(round2(i.price * (1 - pct / 100)) * i.qty), 0));
}

test('[holdout] preview equals checkout on a rounding-sensitive cart', () => {
  const cart = () => [{ price: 0.05, qty: 3 }, { price: 0.15, qty: 3 }];
  const preview = previewDiscountedTotal(cart(), 10);
  const final = checkout(cart(), 10);
  assert.equal(preview, final);
  assert.equal(final, perItemTotal(cart(), 10));
});

test('[holdout] preview equals the per-item value on a second cart', () => {
  const cart = [{ price: 19.99, qty: 3 }, { price: 0.35, qty: 7 }];
  assert.equal(previewDiscountedTotal(cart, 15), perItemTotal(cart, 15));
});
