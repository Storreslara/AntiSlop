const test = require('node:test');
const assert = require('node:assert/strict');
const { round2, applyDiscountPercent, cartTotal } = require('../src/pricing');

test('applyDiscountPercent reduces each item price by the given percent', () => {
  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
  applyDiscountPercent(items, 10);
  assert.equal(items[0].price, 90);
  assert.equal(items[1].price, 45);
});

test('cartTotal sums price * qty across items', () => {
  const items = [{ price: 10, qty: 2 }, { price: 5, qty: 3 }];
  assert.equal(cartTotal(items), 35);
});

test('round2 rounds to two decimal places', () => {
  assert.equal(round2(10.456), 10.46);
  assert.equal(round2(3), 3);
});
