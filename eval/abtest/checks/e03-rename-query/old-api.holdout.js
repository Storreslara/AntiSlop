'use strict';
// Usage: node old-api.holdout.js DIR...
// Prints "file:line: text" for every line of code that still calls query(, indexes ['query'] or builds
// a new Function, and exits 1 when it printed any. Comments are removed first (line comments, block
// comments over several lines, and trailing comments), so a comment may name the old API; strings are
// kept, so a "//" inside a string does not hide a call after it. Files that are not .js, .cjs or .mjs
// are read as plain text. Out of scope: a regular expression literal that holds a quote character.
const fs = require('node:fs');
const path = require('node:path');

const OLD = /\bquery\s*\(|\[.query.\]|new Function/;

function stripComments(src) {
  let out = '';
  let quote = '';
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    const d = src[i + 1];
    if (quote) {
      out += c;
      if (c === '\\') {
        out += d === undefined ? '' : d;
        i += 2;
        continue;
      }
      if (c === quote || (c === '\n' && quote !== '`')) quote = '';
      i += 1;
    } else if (c === '/' && d === '/') {
      while (i < src.length && src[i] !== '\n') i += 1;
    } else if (c === '/' && d === '*') {
      i += 2;
      while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) {
        if (src[i] === '\n') out += '\n';
        i += 1;
      }
      i += 2;
      out += ' ';
    } else {
      if (c === '"' || c === "'" || c === '`') quote = c;
      out += c;
      i += 1;
    }
  }
  return out;
}

const hits = [];
function scan(file) {
  const raw = fs.readFileSync(file, 'utf8');
  const text = /\.(js|cjs|mjs)$/.test(file) ? stripComments(raw) : raw;
  text.split('\n').forEach((line, n) => {
    if (OLD.test(line)) hits.push(`${file}:${n + 1}: ${line.trim()}`);
  });
}
function walk(p) {
  if (!fs.existsSync(p)) return;
  if (fs.statSync(p).isDirectory()) {
    for (const name of fs.readdirSync(p).sort()) if (name !== 'node_modules') walk(path.join(p, name));
  } else {
    scan(p);
  }
}

process.argv.slice(2).forEach(walk);
if (hits.length > 0) {
  console.log(hits.join('\n'));
  process.exit(1);
}
