function round2(n) {
  return Math.round(n * 100) / 100;
}

function applyDiscountPercent(items, pct) {
  for (const item of items) {
    item.price = round2(item.price * (1 - pct / 100));
  }
  return items;
}

function cartTotal(items) {
  return round2(items.reduce((sum, item) => sum + item.price * item.qty, 0));
}

module.exports = { round2, applyDiscountPercent, cartTotal };
