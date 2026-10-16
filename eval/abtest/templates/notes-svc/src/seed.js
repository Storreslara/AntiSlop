'use strict';

const fs = require('node:fs');

// Load notes from a JSON file (an array of { owner, title, body }) into a
// store. Used by the CLI and the export script when NOTES_SEED names a file.
function loadSeed(store, file) {
  const rows = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const row of rows) store.add(row);
  return store;
}

module.exports = { loadSeed };
