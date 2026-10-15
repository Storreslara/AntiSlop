#!/usr/bin/env node
'use strict';
// Unit sfu-5, hardened by lov-3 and lo2-2: every relative markdown link in the maintained docs
// resolves to a tracked file or directory, relative to the linking file's own directory (the way
// GitHub renders it). Fenced code is skipped, and so are URLs and pure #fragment links. A link may
// carry a quoted or parenthesised title, an <angle-bracket> destination, or balanced parentheses
// in its destination; a destination that cannot be parsed, or whose percent escapes are
// malformed, is reported as broken, and so is a scope entry that matches no tracked file. Not
// handled: inline code spans are scanned like prose, and a link split across lines is skipped.
//
// Out of scope on purpose (lo2-2): docs/plans/, dated records whose contract payloads quote other
// files' text (a payload link resolves from the file it targets, not from the plan) and whose
// nested fences defeat the fence skip; adapters/, whose lead-programmer ports inline
// skills/tdd/SKILL.md byte-for-byte (tests/adapter-skill-parity.test.js), so its tests.md and
// mocking.md links name files a port does not ship. The self-test at the end runs this script
// over a fixture repository (DOC_LINKS_ROOT, DOC_LINKS_SCOPE) and over mutated copies of itself.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = process.env.DOC_LINKS_ROOT || path.resolve(__dirname, '..');
const SCOPE = process.env.DOC_LINKS_SCOPE ? process.env.DOC_LINKS_SCOPE.split(',')
  : ['CONTEXT.md', 'docs/harness-glossary.md', 'docs/trust-model.md', 'docs/adr',
    '.claude/wiki', 'docs/maintenance', 'docs/archive/skills/README.md', 'skills', 'templates'];

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
// The text between `](` and its matching `)`: parentheses nest, a backslash escapes the next
// character, and the scan stops at the end of the line (an unclosed link is not a link).
function* linkDests(text) {
  for (let i = text.indexOf(']('); i !== -1; i = text.indexOf('](', i + 2)) {
    let depth = 1;
    let j = i + 2;
    for (; j < text.length && text[j] !== '\n'; j += 1) {
      if (text[j] === '\\') { j += 1; continue; }
      if (text[j] === '(') depth += 1;
      else if (text[j] === ')' && --depth === 0) break;
    }
    if (depth === 0) yield text.slice(i + 2, j);
  }
}
let links = 0;
for (const f of files) {
  const text = fs.readFileSync(path.join(ROOT, f), 'utf8').replace(/^\s*(```|~~~)[\s\S]*?^\s*\1/gm, '');
  for (const dest of linkDests(text)) {
    const d = DEST.exec(dest);
    if (!d) { bad(`${f}: (${dest}) is not a parsable link destination`); continue; }
    const target = (d[1] !== undefined ? d[1] : d[2]).split('#')[0];
    if (target === '' || /^[a-z][a-z0-9+.-]*:/i.test(target)) continue;
    links += 1;
    let decoded;
    try { decoded = decodeURI(target); } catch (e) { bad(`${f}: ${target} has a malformed percent escape`); continue; }
    const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(f), decoded)).replace(/\/$/, '');
    if (!tracked.has(resolved)) bad(`${f}: ${target}`);
  }
}
// lo2-2 self-test: a fixture repository with one planted defect per check, and mutated copies
// of this script that must change the fixture's result. Skipped in the child runs
// (DOC_LINKS_ROOT is set there), so it never recurses.
if (!process.env.DOC_LINKS_ROOT) {
  const os = require('os');
  const { spawnSync } = require('child_process');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'doc-links-'));
  const fx = path.join(tmp, 'repo');
  const put = (rel, body) => {
    fs.mkdirSync(path.dirname(path.join(fx, rel)), { recursive: true });
    fs.writeFileSync(path.join(fx, rel), body);
  };
  put('docs/target.md', '# target\n');
  put('docs/c_(1).md', '# parens\n');
  put('docs/ok.md', '[a](target.md)\n[b](target.md "t")\n[c](target.md (t))\n[d](<target.md>)\n[e](c_(1).md)\n[f](#frag)\n');
  put('docs/bad.md', '[g](missing.md "t")\n[h](<missing h.md>)\n[i](target%E0%A4%A.md)\n[j](a b c)\n');
  execFileSync('git', ['init', '-q'], { cwd: fx });
  execFileSync('git', ['add', '-A'], { cwd: fx });
  const run = (script) => spawnSync('node', [script], { encoding: 'utf8',
    env: { ...process.env, DOC_LINKS_ROOT: fx, DOC_LINKS_SCOPE: 'docs,docs/gone' } }).stdout;
  const want = [
    'FAIL scope entry docs/gone matches no tracked file',
    'FAIL docs/bad.md: missing.md',
    'FAIL docs/bad.md: missing h.md',
    'FAIL docs/bad.md: target%E0%A4%A.md has a malformed percent escape',
    'FAIL docs/bad.md: (a b c) is not a parsable link destination',
    'doc-relative-links: 5 broken of 8 links',
  ].join('\n') + '\n';
  const self = fs.readFileSync(__filename, 'utf8');
  const cut = self.indexOf('// lo2-2 self-test:');
  const code = self.slice(0, cut);
  if (run(__filename) === want) console.log('OK   (fixture) every planted defect is reported, and nothing else');
  else { broken += 1; console.log('FAIL (fixture) the fixture repository did not give the expected report'); }
  const mutants = [
    ['m1 parentheses do not nest', "if (text[j] === '(') depth += 1;", 'if (false) depth += 1;'],
    ['m2 no scope-entry check', "if (git(['ls-files', '-z', '--', entry]).length === 0)", 'if (false)'],
    ['m3 no percent-escape check', 'try { decoded = decodeURI(target); }', 'try { decoded = target; }'],
    ['m4 no title', '(?:\\s+(?:"[^"]*"|\'[^\']*\'|\\([^()]*\\)))?', ''],
    ['m5 no angle destination', '<([^<>]*)>|', ''],
  ];
  for (const [name, from, to] of mutants) {
    if (code.split(from).length !== 2) { broken += 1; console.log(`FAIL (${name}) mutation text not found exactly once`); continue; }
    const copy = path.join(tmp, 'mutant.js');
    fs.writeFileSync(copy, code.replace(from, to) + self.slice(cut));
    if (run(copy) !== want) console.log(`OK   (${name}) the fixture result changes`);
    else { broken += 1; console.log(`FAIL (${name}) the fixture result is unchanged, so the check is not pinned`); }
  }
  fs.rmSync(tmp, { recursive: true, force: true });
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
