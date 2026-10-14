#!/usr/bin/env node
'use strict';
// Unit sfu-5: every relative markdown link in the maintained docs resolves to a
// tracked file or directory, relative to the linking file's own directory (the way GitHub
// renders it). Fenced code is skipped. URLs and <angle> targets are skipped.
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
const files = git(['ls-files', '-z', '--', ...SCOPE]).filter((f) => f.endsWith('.md'));
let links = 0;
let broken = 0;
for (const f of files) {
  const text = fs.readFileSync(path.join(ROOT, f), 'utf8').replace(/^\s*(```|~~~)[\s\S]*?^\s*\1/gm, '');
  for (const m of text.matchAll(/\]\(([^)#\s]+)(?:#[^)]*)?\)/g)) {
    const target = m[1];
    if (/^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith('<')) continue;
    links += 1;
    const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(f), decodeURI(target))).replace(/\/$/, '');
    if (!tracked.has(resolved)) {
      broken += 1;
      console.log(`FAIL ${f}: ${target}`);
    }
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
