Unit: rp-u6

## Objective
Finding I, operator ruling OQ3 (2026-10-20): a contract's anchors and `before:` payloads are checked by a
script before the contract is committed, instead of by hand. After this unit `bin/contract-anchors.js
<contract> [--repo=<dir>] [--chain=<contract>]...` reads the contract's `## Affected files` and `## Ordered
edits`, applies the `--chain` contracts (the queued units, in dispatch order) and then the contract's own
edits in memory, and prints one `<kind> <status> <item> <file>` line per check and a summary line
`contract-anchors: <ok|fail> checks=<n> bad=<n> unchecked=<n>`. A `line matching|ending|starting` anchor
must hold on exactly one line; a `before:` or `delete:` payload must occur exactly once as whole lines;
`anchor: new file` needs the file absent. Exit 0 when nothing is bad, 1 otherwise, 2 on a usage or read
error. The script is not installed to `.claude/bin/` (no `bin/cli.js` change) and no persona prose names it.
New test `tests/contract-anchors.test.sh`, registered in `tests/validate.sh`. This is spec Step 6.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 6 (rp-u6)" and
Clarifications (Open Question 3, ruled 2026-10-20). This file is the contract of record. Dispatch after
rp-u5, the last lead unit (its `tests/validate.sh` section follows st-u4's).

## Affected files
- `tests/contract-anchors.test.sh` (anchor: new file, mode 755)
- `bin/contract-anchors.js` (anchor: new file, mode 755)
- `tests/validate.sh` (anchor: line matching `echo "== unit-size: lane from the planned scope, downgrade-only, fails closed to full (Bash, st-u4) =="`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md`, `.claude/persona-protocol*.md`,
  `.claude/protocol-digest.md` (version stamps), the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/contract-anchors.test.sh`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env bash
# contract-anchors.js (rp-u6): a contract's anchors and before: payloads are checked against the files they
# edit, in order, after the queued --chain contracts. Fixtures are written to a temp dir.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CA="$ROOT/bin/contract-anchors.js"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/r"
printf 'alpha\nbeta\ngamma\n  indented line\nbeta\n' > "$T/r/a.txt"
edit() { printf '%s. file: `%s`\n   anchor: %s\n   indent: %s\n' "$1" "$2" "$3" "$4"; }
head_() { printf 'Unit: x\n\n## Affected files\n%s\n\n## Ordered edits\n' "$1"; }
{ head_ '- `a.txt` (anchor: line matching `alpha`)'
  edit 1 a.txt 'line matching `alpha`' 0; printf '   before: `alpha`\n   after: `ALPHA`\n'
  edit 2 a.txt 'line matching `ALPHA`' 0; printf '   insert-after: `delta`\n'
  edit 3 a.txt 'line matching `indented`' 2; printf '   before:\n~~~\n  indented line\n~~~\n   after:\n~~~\n  indented line two\n~~~\n'
  edit 4 a.txt 'line ending `amma`' 3; printf '   before:\n~~~\n   gamma\n~~~\n   after:\n~~~\n   GAMMA\n~~~\n'
  edit 5 a.txt 'line matching `beta`' 0; printf '   before:\n~~~\nGAMMA\n  indented line two\nbeta\n~~~\n   after:\n~~~\nGAMMA\n~~~\n'
  edit 6 n.txt 'new file' 0; printf '   insert-after: `new`\n'
  printf '7. command: `true`\n   expect: 0\n'; } > "$T/ok.md"
out="$(node "$CA" "$T/ok.md" --repo="$T/r")"; rc=$?
[ "$rc" = 0 ] && ok "(a) every check ok exits 0" || bad "(a) exit $rc: $out"
[ "$(printf '%s\n' "$out" | tail -n1)" = 'contract-anchors: ok checks=11 bad=0 unchecked=0' ] && ok "(a) summary" || bad "(a) summary: $(printf '%s\n' "$out" | tail -n1)"
printf '%s\n' "$out" | grep -qx 'anchor ok 2 a.txt' && ok "(b) a later edit sees an earlier one" || bad "(b) sequential edits"
printf '%s\n' "$out" | grep -qx 'before ok 4 a.txt' && ok "(c) payload matched after stripping indent: N" || bad "(c) indent strip"
printf '%s\n' "$out" | grep -qx 'anchor ok 5 a.txt' && ok "(d) a repeated anchor inside a unique payload is ok" || bad "(d) covered anchor"
{ head_ '- `a.txt` (anchor: line matching `zeta`)'
  edit 1 a.txt 'line matching `beta`' 0; printf '   insert-after: `x`\n'
  edit 2 a.txt 'line matching `alpha`' 0; printf '   before: `omega`\n   after: `x`\n'
  edit 3 a.txt 'new file' 0; printf '   insert-after: `x`\n'
  edit 4 b.txt 'line matching `x`' 0; printf '   insert-after: `x`\n'; } > "$T/bad.md"
out="$(node "$CA" "$T/bad.md" --repo="$T/r")"; rc=$?
[ "$rc" = 1 ] && ok "(e) a bad check exits 1" || bad "(e) exit $rc"
for l in 'anchor ambiguous 1 a.txt' 'before missing 2 a.txt' 'new exists 3 a.txt' 'file missing 4 b.txt' 'anchor missing af a.txt' 'contract-anchors: fail checks=6 bad=5 unchecked=0'; do
  printf '%s\n' "$out" | grep -qxF -- "$l" && ok "(e) $l" || bad "(e) missing line: $l"
done
{ head_ '- `a.txt` (anchor: line matching `gamma`)'; edit 1 a.txt 'line matching `gamma`' 0; printf '   before: `gamma`\n   after: `GAMMA`\n'; } > "$T/q.md"
{ head_ '- `a.txt` (anchor: line matching `alpha`)'; edit 1 a.txt 'line matching `GAMMA`' 0; printf '   before: `GAMMA`\n   after: `G`\n'; } > "$T/needs.md"
node "$CA" "$T/needs.md" --repo="$T/r" >/dev/null; rc=$?
[ "$rc" = 1 ] && ok "(f) a line only a queued unit creates is missing without --chain" || bad "(f) rc=$rc"
out="$(node "$CA" "$T/needs.md" --repo="$T/r" --chain="$T/q.md")"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qxF "chain ok - $T/q.md" && ok "(f) ... and ok after it" || bad "(f) with chain rc=$rc: $out"
out="$(node "$CA" "$T/q.md" --repo="$T/r" --chain="$T/q.md")"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -qx 'before missing 1 a.txt' && ok "(g) a line a queued unit rewrites is missing" || bad "(g) rc=$rc"
printf 'Unit: x\n\n## Objective\nnone\n' > "$T/none.md"
node "$CA" >/dev/null 2>&1; r1=$?
node "$CA" "$T/ok.md" --repo "$T/r" >/dev/null 2>&1; r2=$?
node "$CA" "$T/none.md" >/dev/null 2>&1; r3=$?
node "$CA" "$T/missing.md" >/dev/null 2>&1; r4=$?
node "$CA" "$T/ok.md" --repo="$T/r" --chain="$T/missing.md" >/dev/null 2>&1; r5=$?
[ "$r1$r2$r3$r4$r5" = 22222 ] && ok "(h) usage and read errors exit 2" || bad "(h) exits $r1 $r2 $r3 $r4 $r5"
u="$(node "$CA" 2>&1 >/dev/null)"
case "$u" in *'usage: contract-anchors.js <contract> [--repo=<dir>] [--chain=<contract>]...'*) ok "(h) usage line" ;; *) bad "(h) usage line: $u" ;; esac
[ -x "$CA" ] && ok "(i) executable" || bad "(i) not executable"
exit "$fail"
~~~
2. command: `bash -c 'bash tests/contract-anchors.test.sh | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `16`. With no script, node exits 1, so only row (e)'s exit-code check and row (f)'s check without `--chain` pass; the other 16 rows fail.
3. file: `bin/contract-anchors.js`
   anchor: new file (mode 755)
   indent: 0
   insert-after:
~~~
#!/usr/bin/env node
'use strict';

// contract-anchors.js (rp-u6): before a lead contract is committed or dispatched, checks that every anchor
// and payload it names exists in the files it edits. Not installed to .claude/bin; run it from the repo root.
//
// usage: node bin/contract-anchors.js <contract> [--repo=<dir>] [--chain=<contract>]...
//
// It reads the contract's `## Affected files` and `## Ordered edits`. An `anchor: line matching|ending|
// starting `<literal>`` must hold on exactly one line; an edit's `before:` or `delete:` payload (inline or
// fenced) must occur exactly once as whole lines, verbatim or after stripping the item's `indent: N` spaces
// from each line. An anchor that holds on several lines is still ok when the edit's payload matched once and
// contains it. `anchor: new file` needs the file to be absent. Edits are applied in memory in order, so a
// later edit sees the earlier ones. Each --chain contract, given in dispatch order, is applied first, so a
// line a queued unit creates counts and a line it rewrites is missing. Command items are not run.
// An Affected-files anchor passes when it holds once before the contract's edits or after them.
//
// stdout: one `<kind> <status> <item> <file>` line per check (kind anchor|before|delete|new|file|chain;
// status ok|missing|ambiguous|exists|unchecked; item the edit number, or `af` for Affected files), then
// `contract-anchors: <ok|fail> checks=<n> bad=<n> unchecked=<n>`.
// Exit 0 when nothing is bad, 1 otherwise, 2 on a usage or read error (only the `=` flag forms are read).

const fs = require('fs');
const path = require('path');

const OPEN = /^\s*(`{3,}|~{3,})/;
const PHRASE = /line (matching|ending|starting) (?:``\s?(.+?)\s?``|`([^`]+)`)/g;
const KEYS = new Set(['file', 'anchor', 'indent', 'before', 'after', 'insert-after', 'delete', 'command']);

function usage(msg) {
  process.stderr.write(`${msg}\nusage: contract-anchors.js <contract> [--repo=<dir>] [--chain=<contract>]...\n`);
  process.exit(2);
}
function readOrDie(p) { try { return fs.readFileSync(p, 'utf8'); } catch (e) { return usage(`cannot read ${p}`); } }
~~~
4. file: `bin/contract-anchors.js`
   anchor: line matching `function readOrDie(p)` (the last line edit 3 wrote)
   indent: 0
   insert-after:
~~~

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
~~~
5. file: `bin/contract-anchors.js`
   anchor: line matching `const statusOf = ` (the last line edit 4 wrote)
   indent: 0
   insert-after:
~~~

function makeState(repo) {
  const files = new Map();
  return {
    get(f) {
      if (!files.has(f)) {
        const abs = path.join(repo, f);
        let c = null;
        try { c = fs.statSync(abs).isFile() ? fs.readFileSync(abs, 'utf8') : null; } catch (e) { c = null; }
        if (c !== null && !c.endsWith('\n')) c += '\n';
        files.set(f, c);
      }
      return files.get(f);
    },
    set(f, c) { files.set(f, c); },
    snapshot() { const s = makeState(repo); for (const [k, v] of files) s.set(k, v); return s; },
  };
}

// Applies one contract's edits to state; report(kind, status, item, file) gets every check.
function run(text, state, report) {
  for (const it of items(section(text, 'Ordered edits') || [])) {
    const file = it.file;
    if (!file) continue;
    let c = state.get(file);
    const a = it.anchor || '';
    if (/^new file/.test(a)) { report('new', c === null ? 'ok' : 'exists', it.n, file); state.set(file, it['insert-after'] || it.after || ''); continue; }
    if (c === null) { report('file', 'missing', it.n, file); continue; }
    const n = Number((/\d+/.exec(it.indent || '') || [0])[0]);
    const key = it.before ? 'before' : it.delete ? 'delete' : null;
    const loc = key ? locate(c, it[key], n) : null;
    const m = new RegExp(PHRASE.source).exec(a);
    let hits = [];
    if (m) {
      const lit = m[2] ?? m[3];
      hits = lineIndex(c, m[1], lit);
      const covered = loc && loc.at.length === 1 && loc.p.includes(lit);
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
~~~
6. file: `bin/contract-anchors.js`
   anchor: line matching `// Affected-files anchors:` (the last line edit 5 wrote)
   indent: 0
   insert-after:
~~~
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
    for (const x of tail.matchAll(PHRASE)) paths.forEach((p) => out.push({ p, kind: x[1], lit: x[2] ?? x[3] }));
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
  const state = makeState(repo);
  for (const [c, t] of chainTexts) {
    let failed = 0;
    run(t, state, (kind, status, item) => { if (status !== 'ok' && status !== 'unchecked') { failed++; say('chain', status, item, c); } });
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
  console.log(`contract-anchors: ${bad ? 'fail' : 'ok'} checks=${checks} bad=${bad} unchecked=${unchecked}`);
  process.exit(bad ? 1 : 0);
}

main();
~~~
7. command: `chmod 755 bin/contract-anchors.js tests/contract-anchors.test.sh`
   expect: 0
8. command: `bash tests/contract-anchors.test.sh`
   expect: 0
9. file: `tests/validate.sh`
   anchor: line matching `echo "== unit-size: lane from the planned scope, downgrade-only, fails closed to full (Bash, st-u4) =="`
   indent: 0
   before:
~~~
echo "== unit-size: lane from the planned scope, downgrade-only, fails closed to full (Bash, st-u4) =="
if bash tests/unit-size.test.sh > /dev/null; then
  echo "OK   tests/unit-size.test.sh"
else
  echo "FAIL tests/unit-size.test.sh"
  fail=1
fi
~~~
   after:
~~~
echo "== unit-size: lane from the planned scope, downgrade-only, fails closed to full (Bash, st-u4) =="
if bash tests/unit-size.test.sh > /dev/null; then
  echo "OK   tests/unit-size.test.sh"
else
  echo "FAIL tests/unit-size.test.sh"
  fail=1
fi

echo
echo "== contract-anchors: a contract's anchors and before payloads exist in the files and the queued chain (Node, rp-u6) =="
if bash tests/contract-anchors.test.sh > /dev/null; then
  echo "OK   tests/contract-anchors.test.sh"
else
  echo "FAIL tests/contract-anchors.test.sh"
  fail=1
fi
~~~
10. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected one above what rp-u5 wrote, 0.31.204 to 0.31.205 with no fix rounds).
11. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Contract anchor check (rp-u6, VERSION).** New bin/contract-anchors.js, not installed to .claude/bin: `node bin/contract-anchors.js <contract> [--repo=<dir>] [--chain=<contract>]...` applies the queued `--chain` contracts and then the contract's own edits in memory and reports, per check, whether each `line matching|ending|starting` anchor holds on exactly one line, each `before:`/`delete:` payload occurs exactly once as whole lines, and each new file is absent; exit 0 when nothing is bad, 1 otherwise, 2 on a usage or read error. Replaces the hand check that let two contracts ship broken anchors. New test tests/contract-anchors.test.sh.
~~~
   Replace `VERSION` with the version that edit 10 wrote.
12. command: `node bin/cli.js --update`
   expect: 0
13. command: `git add bin/contract-anchors.js tests/contract-anchors.test.sh && git add -u && git commit -m "feat(rp-u6): contract anchor check script; anchors and before payloads verified against the files and the queued chain"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `bin/cli.js` (the script is not installed to `.claude/bin/`; criterion 4)
- `agents/task-master.md`, `agents/spec-master.md` and `templates/` (installed projects have no `bin/contract-anchors.js`; criterion 6)
- `bin/contract-score.js`, `bin/contract-guard.js` (they score shape and stay unchanged; criterion 5)

## Acceptance criteria
1. run: `bash -c 'bash tests/contract-anchors.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the `if (at.length === 0 && n > 0)` line in `locate`; rows (a), (c) and (d) fail and stdout is `1`.
2. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u6): " | tail -1); d=$(mktemp -d); git archive "$b^" -- tests/validate.sh CHANGELOG.md | tar -x -C "$d" && node bin/contract-anchors.js docs/plans/antislop-review-patches/contracts/rp-u6.md --repo="$d" | tail -n1'`
   exit: 0
   stdout: `contract-anchors: ok checks=11 bad=0 unchecked=0`
   mutation: pass `--repo=.` (the tree after the unit) instead of the archive; both new files print `new exists`, the summary reads `fail` and the command exits 0 with that line (the `tail` sets the status).
3. run: `bash -c 'node bin/contract-anchors.js >/dev/null 2>&1; a=$?; node bin/contract-anchors.js docs/plans/antislop-review-patches/contracts/rp-u6.md --repo . >/dev/null 2>&1; echo "$a $?"'`
   exit: 0
   stdout: `2 2`
   mutation: change `process.exit(2)` in `usage` to `process.exit(1)`; stdout is `1 1`.
4. run: `bash -c 'l=$(git log --format=%H --grep="^[a-z]*(rp-u6): " | head -1); git ls-tree "$l" -- bin/contract-anchors.js tests/contract-anchors.test.sh | grep -c "^100755 "; test -e .claude/bin/contract-anchors.js && echo installed || echo not-installed'`
   exit: 0
   stdout: `2` then `not-installed`
   mutation: skip edit 7 on a clone with `core.fileMode=true` and commit the files as written by a 644 umask; the count is `0`.
5. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u6): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u6): " | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md bin/contract-anchors.js package.json tests/contract-anchors.test.sh tests/validate.sh `
   mutation: also edit `bin/contract-score.js` in an rp-u6 commit; it joins the list.
6. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u6): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u6): " | head -1); bash hooks/scripts/version-stamp-check.sh "$b^..$l" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: no`
   mutation: also edit `agents/task-master.md` in an rp-u6 commit; stdout reads `version-stamp-check: ok touched: yes`.
7. run: `bash -c 'grep -c "^if bash tests/contract-anchors.test.sh > /dev/null; then\$" tests/validate.sh'`
   exit: 0
   stdout: `1`
   mutation: skip edit 9; stdout is `0` and the command exits 1.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/contract-anchors.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edit 1 adds the test; edit 2 shows it red (`16`) before the script edits 3 to 6.
ruling: Open Question 3, 2026-10-20: build the script, not installed to `.claude/bin/`. 2026-10-20 (this spawn): no task-master or spec-master prose names it, because an installed project has no `bin/contract-anchors.js` and a prompt line naming a missing script costs every install tokens and invites a failed command; the usage text in the script header is its documentation.
semantics: `line matching` is substring, as `agents/task-master.md` "Literal anchors" checks with `grep -cF`. A payload matches verbatim or, when it does not, after stripping `indent: N` spaces from each line (scribe contracts indent fenced text by 3). An anchor that holds on several lines is ok when the edit's payload matched once and contains it (rp-u4 edit 4's `kwFlag` line is the case). Commands are not run: a `perl` bump or `--update` changes no anchored line in a contract written to the house rules.
prototype: the scratch applier spec-master used for rp-u1 to rp-u7 (same parse; this script adds the chain, the covered-anchor rule and the Affected-files check).
proof: spec-master applied edits 1 to 13 to a scratch clone (8b931f0f plus rp-u1 to rp-u3, qw-u6, st-u1 to st-u4, rp-u7, rp-u4 and rp-u5, each applied from its contract): edit 2 printed `16`, edit 8 exited 0, criteria 1 to 7 printed the stated stdout. The script also reported `ok` for rp-u7 against the clone at st-u4, for rp-u7 against the clone at rp-u3 with `--chain` qw-u6 and st-u1 to st-u4, for rp-u5 with that chain plus rp-u7 and rp-u4, and `fail` (four payloads missing) for rp-u4 against its own landed commit. validate.sh was not run by spec-master.
chained: no queued contract edits these files after st-u4; rp-u7, rp-u4 and rp-u5 add no `tests/validate.sh` section, so edit 9's `before:` is st-u4's section as st-u4 wrote it.
blast-radius: tests/validate.sh:804-810 (st-u4's section, in the chained tree); no caller of the new script. Line numbers are in the chained tree; work from the anchors.
version: .claude-plugin/plugin.json and package.json read 0.31.194 while rp-u1 is in flight and, with no fix rounds, 0.31.204 after rp-u5; edit 10 adds one to whatever they read when the unit starts.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: feat(rp-u6): contract anchor check script; anchors and before payloads verified against the files and the queued chain
diagnosis: none
review-packet:
~~~
unit: rp-u6
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
~~~

## Escalation
If edit 9's `before:` payload is not found verbatim (a later unit added a section after st-u4's), stop and
report the current text. If the red step prints a different count, report it with the output and continue
only if every `FAIL` line names a missing script. If a gate blocks a command, report it and wait.
Anything outside "Affected files" goes to your report as a proposal.
