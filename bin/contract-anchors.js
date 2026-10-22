#!/usr/bin/env node
'use strict';

// contract-anchors.js (rp-u6): before a lead contract is committed or dispatched, checks that every anchor
// and payload it names exists in the files it edits. Not installed to .claude/bin; run it from the repo root.
//
// usage: node bin/contract-anchors.js <contract> [--repo=<dir>] [--chain=<contract>]...
//
// It reads the contract's `## Affected files` and `## Ordered edits`; edits are applied in memory in order,
// each --chain contract (dispatch order) first. Command items are not run. Outcomes, asserted by the matrix in
// tests/contract-anchors.test.sh (h = lines the anchor holds on; P = the before:/delete: payload, whole lines):
//   anchor line matching|ending|starting: h=0 missing; h=1 ok; h>=2 ambiguous, ok only when P is located once
//   and exactly one hit lies in P. New file: absent ok, else exists. P: 0 times missing, once ok, more ambiguous.
//   unchecked (counted, not bad): no backticked `file:`, an anchor that is no such phrase, a payload that is
//   neither backticked nor fenced; a key given twice in one edit is `duplicate` (bad). A literal may hold a
//   backslash-backtick or end in a backslash. File paths are confined to --repo by real path (outside: exit 2).
// stdout: `<kind> <status> <item> <file>` per check, then `contract-anchors: <ok|fail|unchecked> checks=<n>
// bad=<n> unchecked=<n>` (unchecked warns on stderr).
// Exit 0 when nothing is bad, 1 otherwise, 2 on a usage or read error (only the `=` flag forms are read).

const fs = require('fs');
const path = require('path');

const OPEN = /^\s*(`{3,}|~{3,})/;
const PHRASE = /line (matching|ending|starting) (?:``\s?(.+?)\s?``|`((?:[^`\\]|\\.)+)`|`([^`]+)`)/g;
const litOf = (m) => m[2] ?? (m[3] === undefined ? m[4] : m[3].replace(/\\`/g, '`'));
const KEYS = new Set(['file', 'anchor', 'indent', 'before', 'after', 'insert-after', 'delete', 'command']);

function usage(msg) {
  process.stderr.write(`${msg}\nusage: contract-anchors.js <contract> [--repo=<dir>] [--chain=<contract>]...\n`);
  process.exit(2);
}
function readOrDie(p) { try { return fs.readFileSync(p, 'utf8'); } catch (e) { return usage(`cannot read ${p}`); } }

function section(text, name) {
  let fence = null; let out = null;
  for (const l of text.split('\n')) {
    if (fence === null && /^## /.test(l)) { if (out) break; if (l.trim() === `## ${name}`) out = []; continue; }
    const m = OPEN.exec(l);
    if (m && fence === null) fence = m[1]; else if (fence !== null && l.trim() === fence) fence = null;
    if (out) out.push(l);
  }
  return out;
}

function items(sec) {
  const out = []; let cur = null;
  for (let i = 0; i < sec.length; i++) {
    let l = sec[i];
    const head = /^(\d+)\. (.*)$/.exec(l);
    if (head) { cur = { n: head[1] }; out.push(cur); l = `   ${head[2]}`; }
    const m = cur && /^\s+([a-z][a-z-]*): ?(.*)$/.exec(l);
    if (m && KEYS.has(m[1]) && m[1] in cur) cur.dupes = [...(cur.dupes || []), m[1]];
    if (!m || !KEYS.has(m[1]) || m[1] in cur) {
      const f = OPEN.exec(l);
      if (f) { i++; while (i < sec.length && sec[i].trim() !== f[1]) i++; }
      continue;
    }
    const f = m[2] === '' && OPEN.exec(sec[i + 1] || '');
    if (f) {
      const body = []; i += 2;
      while (i < sec.length && sec[i].trim() !== f[1]) body.push(sec[i++]);
      cur[m[1]] = `${body.join('\n')}\n`;
    } else {
      const v = /^``\s?(.+?)\s?``|^`([^`]*)`/.exec(m[2]);
      const lit = v ? v[1] ?? v[2] : null;
      if (['anchor', 'indent', 'command'].includes(m[1])) cur[m[1]] = m[2];
      else cur[m[1]] = m[1] === 'file' || lit === null ? lit : `${lit}\n`;
    }
  }
  return out;
}

function lineIndex(content, kind, lit) {
  const at = [];
  content.split('\n').forEach((l, k) => {
    if (kind === 'matching' ? l.includes(lit) : kind === 'ending' ? l.endsWith(lit) : l.startsWith(lit)) at.push(k);
  });
  return at;
}
function wholeLines(content, p) {
  const at = []; let i = content.indexOf(p);
  while (i !== -1) { if (i === 0 || content[i - 1] === '\n') at.push(i); i = content.indexOf(p, i + 1); }
  return at;
}
function strip(p, n) { return p.split('\n').map((l) => (l.startsWith(' '.repeat(n)) ? l.slice(n) : l)).join('\n'); }
function locate(content, p, n) {
  const at = wholeLines(content, p);
  if (at.length === 0 && n > 0) { const q = strip(p, n); const at2 = wholeLines(content, q); if (at2.length) return { at: at2, p: q, n }; }
  return { at, p, n: 0 };
}
const statusOf = (k) => (k === 1 ? 'ok' : k === 0 ? 'missing' : 'ambiguous');

// How many of the hit lines (0-based) lie inside the payload p located at offset at.
function inSpan(content, at, p, hits) {
  const first = content.slice(0, at).split('\n').length - 1;
  const len = p.replace(/\n$/, '').split('\n').length;
  return hits.filter((k) => k >= first && k < first + len).length;
}

// root = real path of --repo; a path whose real path is outside it exits 2.
function makeState(root) {
  const files = new Map();
  const inside = (p) => p === root || p.startsWith(root + path.sep);
  const confine = (f) => {
    const abs = path.resolve(root, f);
    for (let p = abs; inside(abs); p = path.dirname(p)) {
      try { if (inside(fs.realpathSync(p))) return abs; break; } catch (e) { if (path.dirname(p) === p) break; }
    }
    return usage(`path is outside --repo: ${f}`);
  };
  return {
    get(f) {
      if (!files.has(f)) {
        const abs = confine(f);
        let c = null;
        try { c = fs.statSync(abs).isFile() ? fs.readFileSync(abs, 'utf8') : null; } catch (e) { c = null; }
        if (c !== null && !c.endsWith('\n')) c += '\n';
        files.set(f, c);
      }
      return files.get(f);
    },
    set(f, c) { files.set(f, c); },
    snapshot() { const s = makeState(root); for (const [k, v] of files) s.set(k, v); return s; },
  };
}

// Applies one contract's edits to state; report(kind, status, item, file) gets every check.
function run(text, state, report) {
  const sec = section(text, 'Ordered edits');
  if (!sec) return;
  const list = items(sec);
  if (list.length === 0) report('edit', 'unchecked', '-', '-');
  for (const it of list) {
    const file = it.file;
    if (!file) { if (!('command' in it)) report('edit', 'unchecked', it.n, '-'); continue; }
    for (const d of it.dupes || []) report(d, 'duplicate', it.n, file);
    let c = state.get(file);
    const a = it.anchor || '';
    if (/^new file/.test(a)) { report('new', c === null ? 'ok' : 'exists', it.n, file); state.set(file, it['insert-after'] || it.after || ''); continue; }
    if (c === null) { report('file', 'missing', it.n, file); continue; }
    const n = Number((/\d+/.exec(it.indent || '') || [0])[0]);
    for (const k of ['before', 'after', 'insert-after', 'delete']) if (k in it && it[k] === null) report(k, 'unchecked', it.n, file);
    const key = it.before ? 'before' : it.delete ? 'delete' : null;
    const loc = key ? locate(c, it[key], n) : null;
    const m = new RegExp(PHRASE.source).exec(a);
    let hits = [];
    if (m) {
      hits = lineIndex(c, m[1], litOf(m));
      const covered = hits.length >= 2 && loc && loc.at.length === 1 && inSpan(c, loc.at[0], loc.p, hits) === 1;
      report('anchor', covered ? 'ok' : statusOf(hits.length), it.n, file);
    } else report('anchor', 'unchecked', it.n, file);
    if (key) {
      report(key, statusOf(loc.at.length), it.n, file);
      if (loc.at.length !== 1) continue;
      const rep = key === 'delete' ? '' : strip(it.after || '', loc.n);
      c = c.slice(0, loc.at[0]) + rep + c.slice(loc.at[0] + loc.p.length);
    } else if (it['insert-after'] && hits.length === 1) {
      const lines = c.split('\n');
      lines.splice(hits[0] + 1, 0, ...strip(it['insert-after'], n).replace(/\n$/, '').split('\n'));
      c = lines.join('\n');
    }
    state.set(file, c);
  }
}

// Affected-files anchors: one entry per path and anchor phrase of each bullet.
function affected(text) {
  const out = []; let fence = null;
  for (const l of section(text, 'Affected files') || []) {
    const f = OPEN.exec(l);
    if (fence !== null) { if (l.trim() === fence) fence = null; continue; }
    if (f) { fence = f[1]; continue; }
    const cut = l.indexOf(' (');
    if (!/^\s*[-*] /.test(l) || cut < 0) continue;
    const paths = [...l.slice(0, cut).matchAll(/`([^`]+)`/g)].map((x) => x[1]);
    const tail = l.slice(cut);
    if (/^ \(anchor: new file/.test(tail)) { paths.forEach((p) => out.push({ p, kind: 'new' })); continue; }
    for (const x of tail.matchAll(PHRASE)) paths.forEach((p) => out.push({ p, kind: x[1], lit: litOf(x) }));
  }
  return out;
}

function main() {
  let contract = null; let repo = '.'; const chain = [];
  for (const a of process.argv.slice(2)) {
    if (a.startsWith('--repo=')) repo = a.slice('--repo='.length);
    else if (a.startsWith('--chain=')) chain.push(a.slice('--chain='.length));
    else if (a.startsWith('-')) usage(`unknown argument: ${a}`);
    else if (contract === null) contract = a;
    else usage(`more than one contract: ${a}`);
  }
  if (contract === null) usage('no contract given');
  const text = readOrDie(contract);
  if (!section(text, 'Ordered edits')) usage(`no ## Ordered edits section in ${contract}`);
  const chainTexts = chain.map((c) => [c, readOrDie(c)]);
  let checks = 0; let bad = 0; let unchecked = 0;
  const say = (kind, status, item, file) => {
    checks++; if (status === 'unchecked') unchecked++; else if (status !== 'ok') bad++;
    console.log(`${kind} ${status} ${item} ${file}`);
  };
  let root;
  try { root = fs.realpathSync(path.resolve(repo)); } catch (e) { usage(`cannot read --repo ${repo}`); }
  const state = makeState(root);
  for (const [c, t] of chainTexts) {
    let failed = 0;
    run(t, state, (kind, status, item) => { if (status !== 'ok') { failed++; say('chain', status, item, c); } });
    if (!failed) say('chain', 'ok', '-', c);
  }
  const pre = state.snapshot();
  run(text, state, say);
  for (const x of affected(text)) {
    if (x.kind === 'new') { say('new', pre.get(x.p) === null ? 'ok' : 'exists', 'af', x.p); continue; }
    const before = pre.get(x.p); const after = state.get(x.p);
    const k = before === null ? 0 : lineIndex(before, x.kind, x.lit).length;
    const k2 = after === null ? 0 : lineIndex(after, x.kind, x.lit).length;
    say('anchor', k === 1 || k2 === 1 ? 'ok' : statusOf(k), 'af', x.p);
  }
  console.log(`contract-anchors: ${bad ? 'fail' : unchecked ? 'unchecked' : 'ok'} checks=${checks} bad=${bad} unchecked=${unchecked}`);
  if (unchecked) process.stderr.write(`contract-anchors: WARNING ${unchecked} item(s) were not verified (see the unchecked lines)\n`);
  process.exit(bad ? 1 : 0);
}

main();
