// Harness-owned quality gate for eval/tasks/feature-task.md.
// Copied into the scratch fixture's test/ dir AFTER a pilot run completes,
// then run via `npm test` - independent of whatever tests the implementer
// wrote, so a run can't pass the defect-catch gate just by omitting its own
// coverage of the trap (src/pricing.js's applyDiscountPercent mutates its
// input in place; a naive previewDiscountedTotal that reuses it silently
// corrupts the cart on repeated preview calls).
const test = require('node:test');
const assert = require('node:assert/strict');
const { previewDiscountedTotal, checkout } = require('../src/pricing');

test('[holdout] previewDiscountedTotal never mutates the input cart', () => {
  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
  const before = JSON.parse(JSON.stringify(items));
  previewDiscountedTotal(items, 10);
  previewDiscountedTotal(items, 10);
  previewDiscountedTotal(items, 10);
  assert.deepEqual(items, before);
});

test('[holdout] checkout applies the same total previewDiscountedTotal reported', () => {
  const items = [{ price: 100, qty: 1 }, { price: 50, qty: 2 }];
  const previewed = previewDiscountedTotal(items, 10);
  const finalTotal = checkout(items, 10);
  assert.equal(finalTotal, previewed);
});
