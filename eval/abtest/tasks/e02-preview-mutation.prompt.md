Add checkout-preview support to this cart pricing library.

Requirements:
- Add a function `previewDiscountedTotal(items, pct)` in `src/pricing.js`
  that returns what the cart total would be if a `pct`% discount were
  applied, WITHOUT modifying the caller's `items` array or any of its
  objects.
- Add a function `checkout(items, pct)` that actually applies the discount
  to the cart and returns the final total (mutating the cart here is fine).
- A caller must be able to call `previewDiscountedTotal` any number of
  times (e.g. showing a live discount preview as a user types a coupon
  code) with no side effects, then call `checkout` once to finalize.
- Write tests for the new functions.
- Keep the existing `applyDiscountPercent` and `cartTotal` functions
  working exactly as they do today - don't change their signatures or
  break their existing callers.

Acceptance criteria (all must pass via `npm test`):
1. Calling `previewDiscountedTotal(items, 10)` three times in a row
   returns the same value each time, and `items` is unchanged (deep-equal
   to its value before any preview calls) after all three calls.
2. `checkout(items, 10)` returns the same numeric total that
   `previewDiscountedTotal(items, 10)` would have returned, and
   afterward `items` reflects the discounted prices.
3. All pre-existing tests in `test/pricing.test.js` continue to pass.
