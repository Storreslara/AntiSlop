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
//   and exactly one hit lies in P. New file: absent ok; a file, directory, fifo or a path under a file: exists.
//   P: 0 times missing, once ok, more ambiguous. An empty --repo= is a usage error.
//   unchecked (counted, not bad): no backticked `file:`; an anchor that is no such phrase or a second phrase; an
//   Affected-files `(anchor...)` with no phrase; a payload neither backticked nor fenced; a key spelled Before: or
//   - before:. A key given twice in one edit is `duplicate` (bad). One real path per file keys all state (canon).
// One literal grammar (phrases), after `line matching|ending|starting `: `abc` is abc. A backtick directly after a
// backslash never closes (`a\`b` is a`b). The literal ends at the first backtick not directly after a backslash, else
// at the last backtick (`abc\` is abc\). ``a`b`` takes no escapes. An empty or unterminated literal is unchecked.
// stdout: `<kind> <status> <item> <file>` per check, then `contract-anchors: <ok|fail|unchecked> checks=<n>
// bad=<n> unchecked=<n>` (unchecked warns on stderr).
// Exit 0 when nothing is bad, 1 otherwise, 2 on a usage or read error (only the `=` flag forms are read).

const fs = require('fs');
const path = require('path');

const OPEN = /^\s*(`{3,}|~{3,})/;

// Every `line matching|ending|starting <literal>` phrase of s; lit is null when no literal follows.
function phrases(s) {
  const out = []; const re = /line (matching|ending|starting) /g; let m;
  while ((m = re.exec(s))) {
    const at = re.lastIndex; let lit = null; let end = at;
    if (s.startsWith('``', at)) {
      const d = /^``\s?(.+?)\s?``/.exec(s.slice(at));
      if (d) { lit = d[1]; end = at + d[0].length; }
    } else if (s[at] === '`') {
      let k = at + 1;
      while (k < s.length && !(s[k] === '`' && s[k - 1] !== '\\')) k++;
      if (k >= s.length) k = s.lastIndexOf('`');
      if (k > at + 1) { lit = s.slice(at + 1, k).replace(/\\`/g, '`'); end = k + 1; }
    }
    out.push({ kind: m[1], lit });
    re.lastIndex = end;
  }
  return out;
}
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
    const o = cur && !(m && KEYS.has(m[1])) && /^\s*(?:[-*] +)?([A-Za-z][A-Za-z-]*): ?/.exec(l);
    if (o && KEYS.has(o[1].toLowerCase())) cur.odd = [...(cur.odd || []), o[1].toLowerCase()];
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

// canon is the one path function: f against the real --repo, symlinks followed (a dangling one by its target),
// exit 2 outside it. A state value is the text, null (absent) or false (a non-file, or a path under a file).
function makeState(root) {
  const files = new Map();
  const inside = (p) => p === root || p.startsWith(root + path.sep);
  const canon = (f, depth = 0) => {
    if (depth > 32) return usage(`too many symbolic links: ${f}`);
    let p = path.resolve(root, f); const rest = []; let blocked = false;
    for (;;) {
      let st = null;
      try { st = fs.lstatSync(p); } catch (e) { blocked = blocked || e.code === 'ENOTDIR'; }
      if (st) {
        let real;
        try { real = fs.realpathSync(p); } catch (e) {
          if (!st.isSymbolicLink()) throw e;
          real = canon(path.resolve(fs.realpathSync(path.dirname(p)), fs.readlinkSync(p)), depth + 1).abs;
        }
        const abs = path.join(real, ...rest);
        return inside(abs) ? { abs, blocked } : usage(`path is outside --repo: ${f}`);
      }
      if (path.dirname(p) === p) return usage(`path is outside --repo: ${f}`);
      rest.unshift(path.basename(p)); p = path.dirname(p);
    }
  };
  const load = ({ abs, blocked }) => {
    if (blocked) return false;
    try {
      if (!fs.lstatSync(abs).isFile()) return false;
      const c = fs.readFileSync(abs, 'utf8');
      return c.endsWith('\n') ? c : `${c}\n`;
    } catch (e) { return e.code === 'ENOENT' ? null : false; }
  };
  return {
    get(f) {
      const k = canon(f);
      if (!files.has(k.abs)) files.set(k.abs, load(k));
      return files.get(k.abs);
    },
    set(f, c) { files.set(canon(f).abs, c); },
    snapshot() { const s = makeState(root); for (const [k, v] of files) s.files.set(k, v); return s; },
    files,
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
    for (const o of it.odd || []) report(o, 'unchecked', it.n, file);
    let c = state.get(file);
    const a = it.anchor || '';
    if (/^new file/.test(a)) { report('new', c === null ? 'ok' : 'exists', it.n, file); state.set(file, it['insert-after'] || it.after || ''); continue; }
    if (typeof c !== 'string') { report('file', 'missing', it.n, file); continue; }
    const n = Number((/\d+/.exec(it.indent || '') || [0])[0]);
    for (const k of ['before', 'after', 'insert-after', 'delete']) if (k in it && it[k] === null) report(k, 'unchecked', it.n, file);
    const key = it.before ? 'before' : it.delete ? 'delete' : null;
    const loc = key ? locate(c, it[key], n) : null;
    const ph = phrases(a); const m = ph.find((x) => x.lit !== null);
    let hits = [];
    for (let i = ph.length - (m ? 1 : 0); i > 0; i--) report('anchor', 'unchecked', it.n, file);
    if (m) {
      hits = lineIndex(c, m.kind, m.lit);
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
    const ph = phrases(tail);
    if (/^ \(anchors?:/.test(tail) && !ph.some((x) => x.lit !== null)) { paths.forEach((p) => out.push({ p, kind: 'bad' })); continue; }
    for (const x of ph) paths.forEach((p) => out.push({ p, kind: x.lit === null ? 'bad' : x.kind, lit: x.lit }));
  }
  return out;
}

function main() {
  let contract = null; let repo = '.'; const chain = [];
  for (const a of process.argv.slice(2)) {
    if (a.startsWith('--repo=')) { repo = a.slice('--repo='.length); if (repo === '') usage('--repo= needs a value'); }
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
    if (x.kind === 'bad') { say('anchor', 'unchecked', 'af', x.p); continue; }
    const before = pre.get(x.p); const after = state.get(x.p);
    const k = typeof before === 'string' ? lineIndex(before, x.kind, x.lit).length : 0;
    const k2 = typeof after === 'string' ? lineIndex(after, x.kind, x.lit).length : 0;
    say('anchor', k === 1 || k2 === 1 ? 'ok' : statusOf(k), 'af', x.p);
  }
  console.log(`contract-anchors: ${bad ? 'fail' : unchecked ? 'unchecked' : 'ok'} checks=${checks} bad=${bad} unchecked=${unchecked}`);
  if (unchecked) process.stderr.write(`contract-anchors: WARNING ${unchecked} item(s) were not verified (see the unchecked lines)\n`);
  process.exit(bad ? 1 : 0);
}

if (require.main === module) main();
module.exports = { phrases };
