#!/usr/bin/env node
'use strict';
// Unit sfu-5, hardened by lov-3: every relative markdown link in the maintained docs resolves
// to a tracked file or directory, relative to the linking file's own directory (the way GitHub
// renders it). Fenced code is skipped, and so are URLs and pure #fragment links. A link may
// carry a title or an <angle-bracket> destination; a destination that cannot be parsed, or
// whose percent escapes are malformed, is reported as broken, and so is a scope entry that
// matches no tracked file.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const SCOPE = ['CONTEXT.md', 'docs/harness-glossary.md', 'docs/trust-model.md', 'docs/adr',
  '.claude/wiki', 'docs/maintenance', 'docs/archive/skills/README.md', 'skills'];

const git = (args) => execFileSync('git', args, { cwd: ROOT, encoding: 'utf8' }).split('\0').filter(Boolean);
const tracked = new Set(git(['ls-files', '-z']));
for (const t of [...tracked]) {
  for (let d = path.posix.dirname(t); d !== '.'; d = path.posix.dirname(d)) tracked.add(d);
}
let broken = 0;
const bad = (msg) => { broken += 1; console.log(`FAIL ${msg}`); };
for (const entry of SCOPE) {
  if (git(['ls-files', '-z', '--', entry]).length === 0) bad(`scope entry ${entry} matches no tracked file`);
}
const files = git(['ls-files', '-z', '--', ...SCOPE]).filter((f) => f.endsWith('.md'));
const DEST = /^\s*(?:<([^<>]*)>|(\S+))(?:\s+(?:"[^"]*"|'[^']*'|\([^()]*\)))?\s*$/;
let links = 0;
for (const f of files) {
  const text = fs.readFileSync(path.join(ROOT, f), 'utf8').replace(/^\s*(```|~~~)[\s\S]*?^\s*\1/gm, '');
  for (const m of text.matchAll(/\]\(([^)\n]*)\)/g)) {
    const d = DEST.exec(m[1]);
    if (!d) { bad(`${f}: (${m[1]}) is not a parsable link destination`); continue; }
    const target = (d[1] !== undefined ? d[1] : d[2]).split('#')[0];
    if (target === '' || /^[a-z][a-z0-9+.-]*:/i.test(target)) continue;
    links += 1;
    let decoded;
    try { decoded = decodeURI(target); } catch (e) { bad(`${f}: ${target} has a malformed percent escape`); continue; }
    const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(f), decoded)).replace(/\/$/, '');
    if (!tracked.has(resolved)) bad(`${f}: ${target}`);
  }
}
if (links === 0) {
  console.log('FAIL no links found: the scope list matches nothing');
  process.exit(1);
}
if (broken > 0) {
  console.log(`doc-relative-links: ${broken} broken of ${links} links`);
  process.exit(1);
}
console.log(`doc-relative-links: ok (${links} links in ${files.length} files)`);
