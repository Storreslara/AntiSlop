'use strict';

// Shared test helper: find notes by exact title through the store's filter.
function findByTitle(store, title) {
  return store.query(`note.title === ${JSON.stringify(title)}`);
}

module.exports = { findByTitle };
