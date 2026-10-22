Unit: rp-u6

## Objective
Fix round 1 for rp-u6 (fix-of: 2026-10-22T21:16:30Z; the implementer runs on haiku, the second attempt). `bin/contract-anchors.js` reported `anchor ok` for a `line ending` or `line starting` anchor that holds on no line. After this fix one outcome table (in `## Pre-resolved context` and the script header) decides every check, a generated matrix in `tests/contract-anchors.test.sh` asserts it, unverifiable items are counted `unchecked` loudly, a repeated key is `duplicate`, an escaped backtick in an anchor is parsed, and every file path is confined to `--repo`.

## Retrieval
Fast path, no tracker issue. Fix contract of record for `Unit: rp-u6`; the original is `docs/plans/antislop-review-patches/contracts/rp-u6.md`, implemented at 0ed1bb1e (version 0.31.217). The FAIL block it answers is the one timestamped 2026-10-22T21:16:30Z in the reviewer record. Work from the anchors, not line numbers.

## Affected files
- `tests/contract-anchors.test.sh` (anchor: line matching `[ -x "$CA" ] && ok "(i) executable" || bad "(i) not executable"`)
- `bin/contract-anchors.js` (anchors: line matching `const PHRASE = /line (matching|ending|starting)`; line matching `function makeState(repo) {`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated only, by `node bin/cli.js --update`: `.claude/` version stamps, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/contract-anchors.test.sh`
   anchor: line matching `[ -x "$CA" ] && ok "(i) executable" || bad "(i) not executable"`
   indent: 0
   insert-after:
~~~
# rp-u6 fix 1: the outcome table (script header) as a generated matrix, one node run per case.
mkdir -p "$T/m"
hl() { case "$1" in matching) echo "a$2 foo b$2" ;; ending) echo "a$2 foo" ;; starting) echo "foo b$2" ;; esac; }
mk_file() { # kind hits [dup]: hit lines, decoys for the other kinds, two plain lines
  local i; : > "$T/m/a.txt"
  for ((i = 1; i <= $2; i++)); do hl "$1" "$i" >> "$T/m/a.txt"; done
  [ -n "${3:-}" ] && hl "$1" 1 >> "$T/m/a.txt"
  case "$1" in ending) printf 'foo b9\na9 foo b9\n' ;; starting) printf 'a9 foo\na9 foo b9\n' ;; esac >> "$T/m/a.txt"
  printf 'plain line\ntail line\n' >> "$T/m/a.txt"
}
one() { { head_ "$1"; edit 1 "$2" "$3" 0; printf '%b' "$4"; } > "$T/c.md"; } # bullet file anchor payload
sum() { echo "contract-anchors: $1 checks=$2 bad=$3 unchecked=${4:-0}"; }
expect() { # name rc want-stdout [more node args]
  local out r; out="$(node "$CA" "$T/c.md" --repo="$T/m" "${@:4}" 2>"$T/err")"; r=$?
  [ "$r" = "$2" ] && [ "$out" = "$3" ] && ok "$1" || bad "$1: rc=$r got [$(printf %s "$out" | tr '\n' '|')]"
}
rc_is() { node "$CA" "$T/c.md" --repo="$T/m" "${@:3}" >/dev/null 2>"$T/err"; [ "$?" = "$2" ] && ok "$1" || bad "$1"; }
oracle() { # payload hits -> "<anchor status> <payload status or ->"
  case "$1:$2" in
    P0:0) echo "missing -" ;; P0:1) echo "ok -" ;; P0:2) echo "ambiguous -" ;;
    P1:0|P4:0|P2:0) echo "missing ok" ;; P1:1|P4:1|P2:1|P1:2|P4:2) echo "ok ok" ;; P2:2) echo "ambiguous ok" ;;
    P3:0) echo "missing missing" ;; P3:1) echo "ok missing" ;; P3:2) echo "ambiguous missing" ;;
    P5:2) echo "ambiguous ambiguous" ;; P6:2) echo "ambiguous ok" ;;
  esac
}
run_case() { # kind hits payload
  local k="$1" h="$2" p="$3" t a b exp key=before bads=0 n=1 x pay
  mk_file "$k" "$h" "$([ "$p" = P5 ] && echo dup)"; t="$(head -n1 "$T/m/a.txt")"
  case "$p" in P2) x='tail line' ;; P3) x="${t#?}" ;; P5) x="$(hl "$k" 1)" ;; *) x="$t" ;; esac
  case "$p" in
    P0) pay='   insert-after: `new line`\n' ;;
    P4) key=delete; pay="   delete: \`$x\`\n" ;;
    P6) pay="   before:\n~~~\n$(hl "$k" 1)\n$(hl "$k" 2)\n~~~\n   after: \`REPL\`\n" ;;
    *) pay="   before: \`$x\`\n   after: \`REPL\`\n" ;;
  esac
  one '- `a.txt`' a.txt "line $k \`foo\`" "$pay"
  read -r a b <<< "$(oracle "$p" "$h")"
  exp="anchor $a 1 a.txt"; [ "$a" != ok ] && bads=1
  [ "$b" != "-" ] && { exp="$exp"$'\n'"$key $b 1 a.txt"; n=2; [ "$b" != ok ] && bads=$((bads + 1)); }
  expect "(m) $k hits=$h $p" "$([ $bads = 0 ] && echo 0 || echo 1)" "$exp"$'\n'"$(sum "$([ $bads = 0 ] && echo ok || echo fail)" $n $bads)"
}
for k in matching ending starting; do
  for p in P0 P1 P2 P3 P4; do for h in 0 1 2; do run_case "$k" "$h" "$p"; done; done
  run_case "$k" 2 P5; run_case "$k" 2 P6
done
# (end of the generated matrix, rp-u6 fix 1)
~~~

2. file: `tests/contract-anchors.test.sh`
   anchor: line matching `# (end of the generated matrix, rp-u6 fix 1)` (the last line edit 1 wrote)
   indent: 0
   insert-after:
~~~
for k in matching ending starting; do for h in 0 1 2; do # Affected-files anchors: kind x hits
  mk_file "$k" "$h"; w=ambiguous; [ "$h" = 0 ] && w=missing; [ "$h" = 1 ] && w=ok
  printf 'Unit: x\n\n## Affected files\n- `a.txt` (anchor: line %s `foo`)\n\n## Ordered edits\n1. command: `true`\n   expect: 0\n' "$k" > "$T/c.md"
  expect "(n) affected $k hits=$h" "$([ "$h" = 1 ] && echo 0 || echo 1)" "anchor $w af a.txt"$'\n'"$(sum "$([ "$h" = 1 ] && echo ok || echo fail)" 1 "$([ "$h" = 1 ] && echo 0 || echo 1)")"
done; done
printf 'Unit: x\n\n## Affected files\n- `n.txt` (anchor: new file, mode 755)\n- `a.txt` (anchor: new file)\n\n## Ordered edits\n1. file: `n.txt`\n   anchor: new file\n   insert-after: `x`\n2. file: `n.txt`\n   anchor: new file\n   insert-after: `y`\n' > "$T/c.md"
expect "(n) new file: absent ok; present or made by an earlier edit exists" 1 "new ok 1 n.txt
new exists 2 n.txt
new ok af n.txt
new exists af a.txt
$(sum fail 4 2)"
printf 'Unit: x\n\n## Ordered edits\n1. Rewrite the intro paragraph.\n2. file: a.txt\n   anchor: line matching `plain line`\n3. command: `true`\n   expect: 0\n' > "$T/c.md"
expect "(o) items with no backticked file: are unchecked" 0 "edit unchecked 1 -
edit unchecked 2 -
$(sum unchecked 2 0 2)"
grep -q 'WARNING 2 item' "$T/err" && ok "(o) ... and warn on stderr" || bad "(o) no stderr warning"
printf 'Unit: x\n\n## Ordered edits\n' > "$T/c.md"
expect "(o) an Ordered edits section with no items is unchecked" 0 "edit unchecked - -
$(sum unchecked 1 0 1)"
one '- `a.txt`' a.txt 'line matching `plain line`' '   before: plain line\n   after: `X`\n'
expect "(o) an unbackticked before: is unchecked" 0 "before unchecked 1 a.txt
anchor ok 1 a.txt
$(sum unchecked 2 0 1)"
one '- `a.txt`' a.txt 'line matching `plain line`' '   before: `plain line`\n   before: `tail line`\n   after: `X`\n'
expect "(p) a second before: in one edit is duplicate" 1 "before duplicate 1 a.txt
anchor ok 1 a.txt
before ok 1 a.txt
$(sum fail 3 1)"
printf 'use `x` here\nother\nrun --opt \\\nnext\n' > "$T/m/e.txt"
one '- `e.txt` (anchor: line matching `use \`x\` here`)' e.txt 'line matching `use \`x\` here`' '   insert-after: `x`\n'
expect "(q) an anchor literal with an escaped backtick is parsed" 0 "anchor ok 1 e.txt
anchor ok af e.txt
$(sum ok 2 0)"
one '- `e.txt` (anchor: line ending `--opt \`)' e.txt 'line ending `--opt \`' '   insert-after: `x`\n'
expect "(q) an anchor literal that ends in a backslash is read as written" 0 "anchor ok 1 e.txt
anchor ok af e.txt
$(sum ok 2 0)"
printf 'root:x\n' > "$T/outside.txt"; ln -sf ../outside.txt "$T/m/link.txt"; ln -sfn .. "$T/m/dl"
for f in ../outside.txt "$T/outside.txt" link.txt dl/new.txt; do
  one '- `a.txt`' "$f" 'line starting `root:`' '   insert-after: `x`\n'
  rc_is "(r) file: $f is outside the repo" 2; grep -q 'outside --repo' "$T/err" || bad "(r) message for $f: $(cat "$T/err")"
done
one '- `../outside.txt` (anchor: line starting `root:`)' a.txt 'line matching `tail line`' '   insert-after: `x`\n'
rc_is "(r) an Affected-files path outside the repo, exit 2" 2
one '- `a.txt`' ../outside.txt 'line starting `root:`' '   insert-after: `x`\n'; cp "$T/c.md" "$T/chain.md"
one '- `a.txt`' a.txt 'line matching `tail line`' '   insert-after: `x`\n'
rc_is "(r) a --chain contract's path outside the repo, exit 2" 2 --chain="$T/chain.md"
node "$CA" "$T/c.md" --repo="$T/none" >/dev/null 2>&1; [ "$?" = 2 ] && ok "(r) a --repo that does not exist exits 2" || bad "(r) missing repo"
~~~

3. command: `bash -c 'bash tests/contract-anchors.test.sh | /usr/bin/grep -c "^FAIL"'`
   expect: 0
   stdout: `24`
   The red step: against the unchanged script the new rows fail and `grep -c` prints `24`; rows (a) to (i) pass. Exit 0 because `grep -c` found lines.

4. file: `bin/contract-anchors.js`
   anchor: line matching `// from each line. An anchor that holds on several lines is still ok when the edit's payload matched once and`
   indent: 0
   before:
~~~
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
~~~
   after:
~~~
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
~~~

5. file: `bin/contract-anchors.js`
   anchor: line matching `const PHRASE = /line (matching|ending|starting) (?:`
   indent: 0
   before:
~~~
const PHRASE = /line (matching|ending|starting) (?:``\s?(.+?)\s?``|`([^`]+)`)/g;
~~~
   after:
~~~
const PHRASE = /line (matching|ending|starting) (?:``\s?(.+?)\s?``|`((?:[^`\\]|\\.)+)`|`([^`]+)`)/g;
const litOf = (m) => m[2] ?? (m[3] === undefined ? m[4] : m[3].replace(/\\`/g, '`'));
~~~

6. file: `bin/contract-anchors.js`
   anchor: line matching `const m = cur && /^\s+([a-z][a-z-]*): ?(.*)$/.exec(l);`
   indent: 0
   insert-after:
~~~
    if (m && KEYS.has(m[1]) && m[1] in cur) cur.dupes = [...(cur.dupes || []), m[1]];
~~~

7. file: `bin/contract-anchors.js`
   anchor: line matching `function makeState(repo) {`
   indent: 0
   before:
~~~
function makeState(repo) {
  const files = new Map();
~~~
   after:
~~~
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
~~~

8. file: `bin/contract-anchors.js`
   anchor: line matching `const abs = path.join(repo, f);`
   indent: 0
   before:
~~~
        const abs = path.join(repo, f);
~~~
   after:
~~~
        const abs = confine(f);
~~~

9. file: `bin/contract-anchors.js`
   anchor: line matching `snapshot() { const s = makeState(repo); for (const [k, v] of files) s.set(k, v); return s; },`
   indent: 0
   before:
~~~
    snapshot() { const s = makeState(repo); for (const [k, v] of files) s.set(k, v); return s; },
~~~
   after:
~~~
    snapshot() { const s = makeState(root); for (const [k, v] of files) s.set(k, v); return s; },
~~~

10. file: `bin/contract-anchors.js`
   anchor: line matching `for (const it of items(section(text, 'Ordered edits') || [])) {`
   indent: 0
   before:
~~~
  for (const it of items(section(text, 'Ordered edits') || [])) {
    const file = it.file;
    if (!file) continue;
~~~
   after:
~~~
  const sec = section(text, 'Ordered edits');
  if (!sec) return;
  const list = items(sec);
  if (list.length === 0) report('edit', 'unchecked', '-', '-');
  for (const it of list) {
    const file = it.file;
    if (!file) { if (!('command' in it)) report('edit', 'unchecked', it.n, '-'); continue; }
    for (const d of it.dupes || []) report(d, 'duplicate', it.n, file);
~~~

11. file: `bin/contract-anchors.js`
   anchor: line matching `const n = Number((/\d+/.exec(it.indent || '') || [0])[0]);`
   indent: 0
   insert-after:
~~~
    for (const k of ['before', 'after', 'insert-after', 'delete']) if (k in it && it[k] === null) report(k, 'unchecked', it.n, file);
~~~

12. file: `bin/contract-anchors.js`
   anchor: line matching `const covered = loc && loc.at.length === 1 && loc.p.includes(lit);`
   indent: 0
   before:
~~~
      const lit = m[2] ?? m[3];
      hits = lineIndex(c, m[1], lit);
      const covered = loc && loc.at.length === 1 && loc.p.includes(lit);
~~~
   after:
~~~
      hits = lineIndex(c, m[1], litOf(m));
      const covered = hits.length >= 2 && loc && loc.at.length === 1 && inSpan(c, loc.at[0], loc.p, hits) === 1;
~~~

13. file: `bin/contract-anchors.js`
   anchor: line matching `for (const x of tail.matchAll(PHRASE)) paths.forEach((p) => out.push({ p, kind: x[1], lit: x[2] ?? x[3] }));`
   indent: 0
   before:
~~~
    for (const x of tail.matchAll(PHRASE)) paths.forEach((p) => out.push({ p, kind: x[1], lit: x[2] ?? x[3] }));
~~~
   after:
~~~
    for (const x of tail.matchAll(PHRASE)) paths.forEach((p) => out.push({ p, kind: x[1], lit: litOf(x) }));
~~~

14. file: `bin/contract-anchors.js`
   anchor: line matching `const state = makeState(repo);`
   indent: 0
   before:
~~~
  const state = makeState(repo);
~~~
   after:
~~~
  let root;
  try { root = fs.realpathSync(path.resolve(repo)); } catch (e) { usage(`cannot read --repo ${repo}`); }
  const state = makeState(root);
~~~

15. file: `bin/contract-anchors.js`
   anchor: line matching `run(t, state, (kind, status, item) => { if (status !== 'ok' && status !== 'unchecked') { failed++; s`
   indent: 0
   before:
~~~
    run(t, state, (kind, status, item) => { if (status !== 'ok' && status !== 'unchecked') { failed++; say('chain', status, item, c); } });
~~~
   after:
~~~
    run(t, state, (kind, status, item) => { if (status !== 'ok') { failed++; say('chain', status, item, c); } });
~~~

16. file: `bin/contract-anchors.js`
   anchor: line matching `contract-anchors: ${bad ? 'fail' : 'ok'} checks=${checks} bad=${bad} unchecked=${unchecked}`
   indent: 0
   before:
~~~
  console.log(`contract-anchors: ${bad ? 'fail' : 'ok'} checks=${checks} bad=${bad} unchecked=${unchecked}`);
~~~
   after:
~~~
  console.log(`contract-anchors: ${bad ? 'fail' : unchecked ? 'unchecked' : 'ok'} checks=${checks} bad=${bad} unchecked=${unchecked}`);
  if (unchecked) process.stderr.write(`contract-anchors: WARNING ${unchecked} item(s) were not verified (see the unchecked lines)\n`);
~~~

17. command: `bash tests/contract-anchors.test.sh`
   expect: 0

18. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (0.31.217 to 0.31.218 when this fix is dispatched next).

19. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Contract anchor check closes the false-ok class (rp-u6 fix 1, VERSION).** bin/contract-anchors.js reported `anchor ok` for a `line ending` or `line starting` anchor that holds on no line. One outcome table, asserted by a generated matrix in tests/contract-anchors.test.sh, now decides every anchor kind, hit count and payload shape; items it cannot check are counted `unchecked` with a stderr WARNING (exit 0); a repeated key is `duplicate`; an anchor literal may hold an escaped backtick; every edit path is confined to --repo (outside: exit 2).
~~~

20. command: `node bin/cli.js --update`
   expect: 0

21. command: `git add bin/contract-anchors.js tests/contract-anchors.test.sh CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "fix(rp-u6): contract-anchors outcome table, matrix test, unchecked and duplicate keys, escaped backticks, path confinement (rp-u6)"`
   expect: 0
   Run `git status --short` first: a tracked file outside "Affected files" that is modified means stop and report. Add the trailer lines the dispatch gives, verbatim.

## Do NOT touch
- `hooks/hooks.json` (the registration is the operator's step; no agent identity may write it)
- `bin/cli.js` (the script stays out of the install list; criterion 7)
- `bin/contract-score.js`, `bin/contract-guard.js` (they score shape and stay unchanged)
- `tests/validate.sh` (the section is registered by rp-u6; the test file only grows)
- `agents/`, `templates/` and `adapters/` (no persona prose names the script)
- `tests/microworld/microworld-rerun.test.sh` (case (j) `runs=3` is flaky and unrelated)
- `docs/plans/antislop-review-patches/contracts/rp-u6.md` and every other earlier contract

## Acceptance criteria
1. run: `bash -c 'bash tests/contract-anchors.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 12 (the covered rule); nine rows print FAIL and stdout is `1`.
2. run: `bash -c 'bash tests/contract-anchors.test.sh | /usr/bin/grep -c "^FAIL"'`
   exit: 1
   stdout: `0`
   mutation: skip edit 12; stdout is `9`.
3. run: `bash -c 'bash tests/contract-anchors.test.sh | /usr/bin/grep -c "^OK   (m) "'`
   exit: 0
   stdout: `51`
   mutation: delete the `run_case "$k" 2 P5; run_case "$k" 2 P6` line from edit 1's text; stdout is `45`.
4. run: `bash -c 'x=$(printf "Unit: x\n\n## Ordered edits\n1. file: \x60CHANGELOG.md\x60\n   anchor: line ending \x60Change\x60\n   before: \x60# Changelog\x60\n   after: \x60# Changelog\x60\n" | node bin/contract-anchors.js /dev/stdin --repo=.); echo "$? $(echo "$x" | head -n2 | paste -sd"|")"'`
   exit: 0
   stdout: `1 anchor missing 1 CHANGELOG.md|before ok 1 CHANGELOG.md`
   mutation: skip edit 12; stdout is `0 anchor ok 1 CHANGELOG.md|before ok 1 CHANGELOG.md`.
   proof: the script from `git show 0ed1bb1e:bin/contract-anchors.js` prints `0 anchor ok 1 CHANGELOG.md|before ok 1 CHANGELOG.md` for this input.
5. run: `bash -c 'printf "Unit: x\n\n## Ordered edits\n1. file: \x60../../../../etc/passwd\x60\n   anchor: line starting \x60root:\x60\n   insert-after: \x60x\x60\n" | node bin/contract-anchors.js /dev/stdin --repo=. 2>/dev/null; echo $?'`
   exit: 0
   stdout: `2`
   mutation: replace `confine(f)` by `path.join(root, f)` in edit 8's text.
   proof: the script from `git show 0ed1bb1e:bin/contract-anchors.js` (no confinement) prints `anchor ok 1 ../../../../etc/passwd`, an `ok` summary line and `0` from the repo root.
6. run: `bash -c 'printf "Unit: x\n\n## Ordered edits\n1. Rewrite the intro.\n" | node bin/contract-anchors.js /dev/stdin --repo=. 2>&1 | paste -sd"|"'`
   exit: 0
   stdout: `edit unchecked 1 -|contract-anchors: unchecked checks=1 bad=0 unchecked=1|contract-anchors: WARNING 1 item(s) were not verified (see the unchecked lines)`
   mutation: skip edit 10; stdout is `contract-anchors: ok checks=0 bad=0 unchecked=0`.
7. run: `bash -c 'test -e .claude/bin/contract-anchors.js && echo installed || echo not-installed'`
   exit: 0
   stdout: `not-installed`
   mutation: copy `bin/contract-anchors.js` into `.claude/bin/`; stdout is `installed`.
8. run: `bash -c 'for c in $(git log --format="%H %s" 0ed1bb1e..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u6\): " | cut -d" " -f1); do git ls-tree "$c" -- bin/contract-anchors.js tests/contract-anchors.test.sh | /usr/bin/grep -c "^100755 "; done | paste -sd"|"'`
   exit: 0
   stdout: `2`
   mutation: rewrite either file through a 644 umask in the commit; the count is `1` or `0`.
9. run: `bash -c 'for c in $(git log --format="%H %s" 0ed1bb1e..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u6\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c" -- . ":(exclude).claude"; done | LC_ALL=C sort -u | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md bin/contract-anchors.js package.json tests/contract-anchors.test.sh `
   mutation: also edit `tests/validate.sh` in an rp-u6 commit; it joins the list.
10. run: `bash -c 'for c in $(git log --format="%H %s" 0ed1bb1e..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u6\): " | cut -d" " -f1); do for f in package.json .claude-plugin/plugin.json; do p=$(git show "$c~1:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); n=$(git show "$c:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); [ "${p%.*}.$(( ${p##*.} + 1 ))" = "$n" ] && echo "$f ok"; done; done | paste -sd"|"'`
   exit: 0
   stdout: `package.json ok|.claude-plugin/plugin.json ok`
   mutation: bump `.claude-plugin/plugin.json` only; stdout is `.claude-plugin/plugin.json ok`.
11. run: `node -e "const v=require('./package.json').version,w=require('./.claude-plugin/plugin.json').version,t=require('fs').readFileSync('CHANGELOG.md','utf8').replace(/\s+/g,' ');process.exit(v===w&&t.includes('(rp-u6 fix 1, '+v+')')&&t.includes('closes the false-ok class')?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: bump one version file only, leave `VERSION` in the CHANGELOG line, or skip edit 19; exit 1, empty stdout.
12. run: `bash -c 'e=$(git log --format="%H %s" 0ed1bb1e..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u6\): " | cut -d" " -f1 | head -1); git log --format=%s "$e"..HEAD -- bin/contract-anchors.js tests/contract-anchors.test.sh | /usr/bin/grep -vcE "^[a-z]+\(rp-u6\): "'`
   exit: 1
   stdout: `0`
   mutation: make a later commit with another subject that touches `bin/contract-anchors.js`; stdout is `1` and the exit is 0.
13. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/contract-anchors.test.sh; stdout is `1`.
   precondition: if only tests/microworld/microworld-rerun.test.sh case (j) (`runs=3`, passes alone) fails, re-run this criterion once and report both results; any other failure is a FAIL.
14. run: `bash -c 'git status --porcelain --untracked-files=no -- bin tests .claude CHANGELOG.md package.json .claude-plugin'`
   exit: 0
   stdout: empty
   mutation: leave edit 20 out of the commit; a `.claude/` path shows and stdout is not empty.

## Pre-resolved context
tdd: yes tests/contract-anchors.test.sh; edits 1 and 2 add the generated matrix and the hand-written rows, edit 3 shows them red (`24`) before the script edits 4 to 16.
outcome-table: h = lines the anchor predicate holds on, in the file as earlier edits left it; P = the edit's `before:` or `delete:` payload, whole lines. The same table heads `bin/contract-anchors.js` and is the oracle of the matrix.
  - `line matching` = the line contains the literal; `line ending` = it ends with it; `line starting` = it starts with it.
  - anchor h=0: missing (bad), with or without P, even when P contains the literal (the reported bug). h=1: ok. h>=2: ambiguous (bad), except ok when P is located exactly once and exactly one hit line lies inside P.
  - anchor `new file`: file absent ok; present, or made by an earlier edit or --chain contract: exists (bad).
  - P: located 0 times missing (bad), once ok, twice or more ambiguous (bad); part of a line is not located. A located P is applied in memory; insert-after text is applied only when its anchor has h=1.
  - Affected-files anchor: the same predicates, ok when h=1 before the contract's edits or after; a `new file` bullet is ok when the file is absent before the edits.
  - unchecked (counted, not bad): an edit item with neither a backticked `file:` nor a `command:` (`edit unchecked <n> -`); an Ordered edits section with no items; an anchor that is no `line matching|ending|starting` phrase; a `before:`, `after:`, `insert-after:` or `delete:` neither backticked nor fenced (`<key> unchecked <n> <file>`); the same in a --chain contract (`chain unchecked <n> <path>`).
  - duplicate (bad): a key given twice in one edit item (`<key> duplicate <n> <file>`); the first value is used.
  - escaped backtick: in an anchor literal a backslash and a backtick is one backtick; a literal ending in a backslash with no unescaped closing backtick after it is read as written.
  - confinement: every `file:`, Affected-files and --chain edit path is resolved (path.resolve, then fs.realpathSync of it or its nearest existing parent) against the real path of --repo; outside it (`../`, absolute, symlink) the run exits 2 with a stderr message containing `outside --repo`. The contract and --chain paths are not confined. A missing --repo exits 2.
  - summary: `contract-anchors: fail|unchecked|ok checks=<n> bad=<n> unchecked=<n>`. DECISION: exit 0 when bad=0 even if unchecked>0, 1 when bad>0, 2 on a usage, read or confinement error (the original three codes); the `unchecked` word and a stderr `WARNING <n> item(s) were not verified` line make the gap loud.
matrix: the test asserts this table for kinds matching, ending, starting x hits 0, 1, 2 x payload shapes P0 insert-after only, P1 before = first line, P2 before = a non-hit line, P3 before = part of a line, P4 delete = first line, and at h=2 P5 hit line twice, P6 two adjacent hit lines: 51 cases, one node run each, compared whole with a bash `case` oracle.
anchors-checked: every anchor and `before:` payload was run against the CURRENT files (bin/contract-anchors.js and tests/contract-anchors.test.sh at 0ed1bb1e; `## [Unreleased]` once; `"version": "` once per version file) by a scratch applier and by `node bin/contract-anchors.js` over this contract (ok checks=33 bad=0 unchecked=0; that script has the hole this unit closes, so the applier did not rely on it). Fenced payloads are verbatim (`indent: 0`); edits 4 to 16 are the diff hunk by hunk. Edits 1 to 21 were replayed in a scratch clone at 0ed1bb1e: edit 3 printed `24`, edit 17 exited 0, criteria 1 to 14 printed the stated stdout (13: exit 0, OK=3427 FAIL=0). Criteria 1 to 8 of the original contract still hold with this commit in the rp-u6 range, so none is superseded.
order: dispatch next, before the queued units. None of rp-u13 (`unit-scope.sh`, `tests/scope-libs.test.sh`), rp-u14 (`bin/review-precheck.sh`, its test, `agents/reviewer.md`; it also reworks how the precheck handles fix contracts and superseded criteria) or rp-s1 (CONTEXT.md, glossary, wiki) edits the two files here. They share CHANGELOG.md (each inserts after `## [Unreleased]`, which stays unique) and the version files (each adds one to what it reads). The `stdout:` values are single-line for the precheck.
blast-radius: bin/contract-anchors.js:27-28, :47-72, :94-110, :112-144, :147-161, :163-198; tests/contract-anchors.test.sh:56; no caller outside that test and tests/validate.sh:813-819. Line numbers are at 0ed1bb1e.
version: .claude-plugin/plugin.json and package.json read 0.31.217 at 0ed1bb1e; edit 18 adds one (expected 0.31.218). Replace `VERSION` in edit 19's text with the version edit 18 wrote.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2); here it changes version stamps only.
fix-of: 2026-10-22T21:16:30Z
commit-message: fix(rp-u6): contract-anchors outcome table, matrix test, unchecked and duplicate keys, escaped backticks, path confinement (rp-u6)
diagnosis: none
review-packet:
~~~
unit: rp-u6 (fix 1)
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
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written (a `before:` not found exactly once, an anchor not on exactly one line, a `--update` refusal, a gate block, a red-step count other than the one stated), STOP and report a spec gap; do not improvise.
