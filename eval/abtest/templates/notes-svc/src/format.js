'use strict';

// Small output formatters used by the CLI and the export script.
function money(cents) {
  return `$${(cents / 100).toFixed(2)}`;
}

function date(ms) {
  return new Date(ms).toISOString().slice(0, 10);
}

module.exports = { money, date };
