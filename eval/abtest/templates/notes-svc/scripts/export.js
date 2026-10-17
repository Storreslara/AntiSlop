'use strict';

// Print every note as JSON.
const { createStore } = require('../src/store');
const { loadSeed } = require('../src/seed');
const { date } = require('../src/format');

const store = createStore();
if (process.env.NOTES_SEED) loadSeed(store, process.env.NOTES_SEED);
const fn = 'query';
const rows = store[fn]('true');
console.log(JSON.stringify(rows.map((n) => ({ id: n.id, title: n.title, date: date(n.createdAt) }))));
