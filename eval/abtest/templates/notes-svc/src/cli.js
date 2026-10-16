#!/usr/bin/env node
'use strict';

const { createStore } = require('./store');
const { loadSeed } = require('./seed');
const { date } = require('./format');

// Usage: node src/cli.js list [--title <text>]
// With NOTES_SEED=<file> the store starts from that JSON file.
function main(argv) {
  const store = createStore();
  if (process.env.NOTES_SEED) loadSeed(store, process.env.NOTES_SEED);
  const [command, flag, value] = argv;
  if (command !== 'list') {
    console.error('usage: cli.js list [--title <text>]');
    return 2;
  }
  const rows = flag === '--title'
    ? store.query(`note.title === ${JSON.stringify(value)}`)
    : store.list({}).items;
  for (const n of rows) console.log(`${n.id}\t${n.owner}\t${date(n.createdAt)}\t${n.title}`);
  return 0;
}

if (require.main === module) process.exitCode = main(process.argv.slice(2));
