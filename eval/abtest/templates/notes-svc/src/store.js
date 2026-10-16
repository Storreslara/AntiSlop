'use strict';

// In-memory note store. A note is { id, owner, title, body, createdAt }.
function createStore() {
  const notes = new Map();
  let counter = 0;

  function add({ owner, title, body = '', id, createdAt }) {
    counter += 1;
    const note = {
      id: id || `n${counter}`,
      owner,
      title,
      body,
      createdAt: createdAt || 1700000000000 + counter,
    };
    notes.set(note.id, note);
    return note;
  }

  function all() {
    return Array.from(notes.values());
  }

  function get(id) {
    return notes.get(id) || null;
  }

  function remove(id) {
    return notes.delete(id);
  }

  // Page through one owner's notes in insertion order. The cursor is the id
  // of the last note of the previous page.
  function list({ owner, limit = 50, cursor = null } = {}) {
    let rows = all().filter((n) => !owner || n.owner === owner);
    if (cursor) {
      const at = rows.findIndex((n) => n.id === cursor);
      rows = at === -1 ? rows : rows.slice(at + 1);
    }
    const items = rows.slice(0, limit);
    const next = rows.length > limit ? items[items.length - 1].id : null;
    return { items, next };
  }

  // Filter notes with a JavaScript expression over `note`, for example
  // 'note.title === "x"'. The string is compiled, so callers must build it
  // with JSON.stringify for every value they interpolate.
  function query(filterString) {
    const predicate = new Function('note', `return (${filterString});`);
    return all().filter((n) => predicate(n));
  }

  return { add, get, remove, list, query };
}

module.exports = { createStore };
