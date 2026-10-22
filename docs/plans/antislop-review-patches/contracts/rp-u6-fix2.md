Unit: rp-u6

## Objective
Fix round 2 for rp-u6 (fix-of: 2026-10-22T22:18:57Z; implementer tier sonnet). `bin/contract-anchors.js` still reports a false `anchor ok` for an anchor literal with an escaped backtick that ends in a backslash, and when one file is spelled two ways in one contract. After this fix one function parses every literal, one function maps every `file:` spelling to one confined real path that keys all state, the reviewer's unchecked and new-file gaps are closed, and a seeded differential test against an awk oracle hunts the next class.

## Retrieval
Fast path, no tracker issue. Fix contract of record for `Unit: rp-u6`; original `docs/plans/antislop-review-patches/contracts/rp-u6.md` (0ed1bb1e), round 1 `rp-u6-fix1.md` (32e61aae, version 0.31.218). It answers the FAIL block of 2026-10-22T22:18:57Z. Work from the anchors, not line numbers.

## Affected files
- `tests/contract-anchors.test.sh` (anchor: line matching `bad "(r) missing repo"`)
- `bin/contract-anchors.js` (anchors: line matching `const PHRASE = /line (matching|ending|starting) (?:`; line matching `function makeState(root) {`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated only, by `node bin/cli.js --update`: `.claude/` version stamps, the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/contract-anchors.test.sh`
   anchor: line matching `--repo="$T/non`
   indent: 0
   insert-after:
~~~
# rp-u6 fix 2: grammar table, seeded differential against an awk oracle, the reviewer's cases.
gram() { node -e 'const {phrases}=require(process.argv[1]);for(const l of require("fs").readFileSync(0,"utf8").split("\n").slice(0,-1)){const p=phrases(l);console.log(p.length===1&&p[0].lit!==null?p[0].lit:"NONE")}' "$CA"; }
cat > "$T/gen.awk" <<'AWK'
function rnd(n) { s = (s * 16807) % 2147483647; return s % n }
function esc(x,  i, c, r) { for (i = 1; i <= length(x); i++) { c = substr(x, i, 1); r = r (c == "`" ? "\\`" : c) } return r }
function hit(i, kind, lit) {
  if (kind == "matching") return index(L[i], lit) > 0
  if (kind == "ending") return length(L[i]) >= length(lit) && substr(L[i], length(L[i]) - length(lit) + 1) == lit
  return substr(L[i], 1, length(lit)) == lit
}
BEGIN {
  if (mode == "gram") { # literals (lits) and the phrase lines that must parse back to them (raws)
    print "abc\na`b\nabc\\\n`\\\n\\\\\na`b" > (dir "/lits") # hand rows first
    print "line matching `abc`\nline matching `a\\`b`\nline matching `abc\\`\nline matching `\\`\\`\nline matching `\\\\`\nline matching ``a`b``" > (dir "/raws")
    split("a|b| |\t|`|\\|`|\\", A, "|")
    for (c = 1; c <= n; c++) {
      x = ""; r = ""; for (i = 1 + rnd(6); i > 0; i--) { ch = A[1 + rnd(8)]; x = x ch; r = r (ch == "`" ? "\\`" : ch) }
      print x > (dir "/lits"); print "line matching `" r "`" > (dir "/raws")
    }
    exit
  }
  nt = split("foo|bar|foo bar|a`b|`z|w`|c\\d|x\ty|end\\|  ind|foo", T, "|")
  sp[0] = "a.txt"; sp[1] = "./a.txt"; sp[2] = "adir/../a.txt"; sp[3] = root "/a.txt"; sp[4] = "alias.txt"
  for (c = 1; c <= n; c++) { # a file of repeated, prefixed, tabbed lines; 2 to 4 edits on it, spelled differently
    nl = 2 + rnd(5)
    for (i = 1; i <= nl; i++) {
      if (i > 1 && rnd(3) == 0) L[i] = L[i - 1]
      else { L[i] = T[1 + rnd(nt)]; if (rnd(2)) L[i] = L[i] (rnd(2) ? " " : "") T[1 + rnd(nt)] }
      print L[i] > (dir "/" c ".txt")
    }
    cf = dir "/" c ".md"; print "Unit: x\n\n## Ordered edits" > cf
    out = ""; bads = 0; tot = 0; ne = 2 + rnd(3)
    for (e = 1; e <= ne; e++) {
      k = rnd(3); kind = k == 0 ? "matching" : k == 1 ? "ending" : "starting"; f = sp[rnd(5)]
      src = (nl == 0 || rnd(6) == 0) ? "zz" : L[1 + rnd(nl)]; m = length(src); len = 1 + rnd(m)
      lit = kind == "matching" ? substr(src, 1 + rnd(m - len + 1), len) : kind == "ending" ? substr(src, m - len + 1) : substr(src, 1, len)
      h = 0; for (i = 1; i <= nl; i++) { H[i] = hit(i, kind, lit); h += H[i] }
      print e ". file: `" f "`\n   anchor: line " kind " `" esc(lit) "`" > cf
      st = h == 0 ? "missing" : h == 1 ? "ok" : "ambiguous"
      if (rnd(2)) { # insert after the hit line
        print "   insert-after: `new" c "_" e "`" > cf
        if (h == 1) { for (i = 1; i <= nl; i++) if (H[i]) j = i; for (i = nl; i > j; i--) L[i + 1] = L[i]; L[j + 1] = "new" c "_" e; nl++ }
        out = out "anchor " st " " e " " f "\n"; tot++; bads += st != "ok"
      } else { # delete or replace a whole line
        key = rnd(2) ? "delete" : "before"; x = (nl > 0 && rnd(6) > 0) ? L[1 + rnd(nl)] : "nope"; pc = 0; j = 0
        for (i = 1; i <= nl; i++) if (L[i] == x) { pc++; j = i }
        print "   " key ":\n~~~\n" x "\n~~~" > cf
        if (key == "before") print "   after: `R" c "_" e "`" > cf
        if (h >= 2 && pc == 1 && H[j]) st = "ok"
        ps = pc == 0 ? "missing" : pc == 1 ? "ok" : "ambiguous"
        out = out "anchor " st " " e " " f "\n" key " " ps " " e " " f "\n"; tot += 2; bads += (st != "ok") + (ps != "ok")
        if (pc == 1 && key == "before") L[j] = "R" c "_" e
        else if (pc == 1) { for (i = j; i < nl; i++) L[i] = L[i + 1]; nl-- }
      }
    }
    printf "%scontract-anchors: %s checks=%d bad=%d unchecked=0\n", out, bads ? "fail" : "ok", tot, bads > (dir "/" c ".exp")
    print bads ? 1 : 0 > (dir "/" c ".rc")
  }
}
AWK
mkdir -p "$T/rg"; awk -v s=4242 -v n=150 -v mode=gram -v dir="$T/rg" -f "$T/gen.awk"
gram < "$T/rg/raws" | cmp -s - "$T/rg/lits" && ok "(s) the grammar table and 150 random literals parse back to themselves" || bad "(s) grammar: $(gram < "$T/rg/raws" | diff - "$T/rg/lits" | head -n3 | tr '\n' '|')"
mkdir -p "$T/rd/repo" "$T/rd/cases"; ln -sf a.txt "$T/rd/repo/alias.txt"; RD="$(cd "$T/rd/repo" && pwd -P)"
awk -v s=7331 -v n=160 -v dir="$T/rd/cases" -v root="$RD" -f "$T/gen.awk"; nbad=0
for ((k = 1; k <= 160; k++)); do
  cp "$T/rd/cases/$k.txt" "$RD/a.txt"; out="$(node "$CA" "$T/rd/cases/$k.md" --repo="$RD" 2>/dev/null)"; r=$?
  [ "$r" = "$(cat "$T/rd/cases/$k.rc")" ] && [ "$out" = "$(cat "$T/rd/cases/$k.exp")" ] && continue
  nbad=$((nbad + 1)); [ "$nbad" -le 2 ] && bad "(t) case $k rc=$r got [$(printf %s "$out" | tr '\n' '|')] want [$(tr '\n' '|' < "$T/rd/cases/$k.exp")]"
done
[ "$nbad" = 0 ] && ok "(t) 160 seeded random cases match the awk oracle" || bad "(t) $nbad random cases differ"
printf 'foo\nbar\n' > "$T/m/u.txt"; ln -sf u.txt "$T/m/ualias.txt"
for sp in ./u.txt adir/../u.txt "$(cd "$T/m" && pwd -P)/u.txt" ualias.txt; do
  { head_ ''; edit 1 u.txt 'line matching `bar`' 0; printf '   delete: `bar`\n'; edit 2 "$sp" 'line matching `bar`' 0; printf '   insert-after: `x`\n'; } > "$T/c.md"
  expect "(u) state is one per file: $sp" 1 "anchor ok 1 u.txt
delete ok 1 u.txt
anchor missing 2 $sp
~~~
2. file: `tests/contract-anchors.test.sh`
   anchor: line matching `anchor missing 2`
   indent: 0
   insert-after:
~~~
$(sum fail 3 1)"
done
printf 'x\\y\nfoo\n' > "$T/m/e.txt"; one '- `e.txt`' e.txt 'line matching `\`\`' '   insert-after: `x`\n'
expect "(v) a backtick-backslash literal is missing" 1 "anchor missing 1 e.txt
$(sum fail 1 1)"
mkdir -p "$T/m/adir"; mkfifo "$T/m/ff"; ln -sfn ../nowhere "$T/m/dang"; ln -sfn gone.txt "$T/m/dang2"
for f in adir ff u.txt/x; do
  one '- `u.txt`' "$f" 'new file' '   insert-after: `x`\n'
  expect "(w) new file at $f exists" 1 "new exists 1 $f
$(sum fail 1 1)"
done
one '- `u.txt`' dang 'new file' '   insert-after: `x`\n'; rc_is "(w) a dangling link out of the repo, exit 2" 2
{ head_ ''; edit 1 dang2 'new file' 0; printf '   insert-after: `x`\n'; edit 2 gone.txt 'new file' 0; printf '   insert-after: `y`\n'; } > "$T/c.md"
expect "(w) a dangling link and its target are one file" 1 "new ok 1 dang2
new exists 2 gone.txt
$(sum fail 2 1)"
one '- `u.txt` (anchor: not a phrase)' u.txt 'line matching `foo` or line ending `bar`' '   insert-after: `x`\n'
expect "(x) a second phrase, an unrecognised anchor: unchecked" 0 "anchor unchecked 1 u.txt
anchor ok 1 u.txt
anchor unchecked af u.txt
$(sum unchecked 3 0 2)"
one '- `u.txt`' u.txt 'line matching `foo`' 'Before: `foo`\n   - after: `x`\n   insert-after: `y`\n'
expect "(x) a capitalised or bulleted key: unchecked" 0 "before unchecked 1 u.txt
after unchecked 1 u.txt
anchor ok 1 u.txt
$(sum unchecked 3 0 2)"
rc_is "(x) --repo= with no value, exit 2" 2 --repo=
~~~
3. command: `bash -c 'bash tests/contract-anchors.test.sh 2>/dev/null | /usr/bin/grep -c "^FAIL"'`
   expect: 0
4. file: `bin/contract-anchors.js`
   anchor: line matching `//   and exact`
   indent: 0
   before:
~~~
//   and exactly one hit lies in P. New file: absent ok, else exists. P: 0 times missing, once ok, more ambiguous.
//   unchecked (counted, not bad): no backticked `file:`, an anchor that is no such phrase, a payload that is
//   neither backticked nor fenced; a key given twice in one edit is `duplicate` (bad). A literal may hold a
//   backslash-backtick or end in a backslash. File paths are confined to --repo by real path (outside: exit 2).
~~~
   after:
~~~
//   and exactly one hit lies in P. New file: absent ok; a file, directory, fifo or a path under a file: exists.
//   P: 0 times missing, once ok, more ambiguous. An empty --repo= is a usage error.
//   unchecked (counted, not bad): no backticked `file:`; an anchor that is no such phrase or a second phrase; an
//   Affected-files `(anchor...)` with no phrase; a payload neither backticked nor fenced; a key spelled Before: or
//   - before:. A key given twice in one edit is `duplicate` (bad). One real path per file keys all state (canon).
// One literal grammar (phrases), after `line matching|ending|starting `: `abc` is abc. A backtick directly after a
// backslash never closes (`a\`b` is a`b). The literal ends at the first backtick not directly after a backslash, else
// at the last backtick (`abc\` is abc\). ``a`b`` takes no escapes. An empty or unterminated literal is unchecked.
~~~
5. file: `bin/contract-anchors.js`
   anchor: line matching `const KEYS = n`
   indent: 0
   before:
~~~
const OPEN = /^\s*(`{3,}|~{3,})/;
const PHRASE = /line (matching|ending|starting) (?:``\s?(.+?)\s?``|`((?:[^`\\]|\\.)+)`|`([^`]+)`)/g;
const litOf = (m) => m[2] ?? (m[3] === undefined ? m[4] : m[3].replace(/\\`/g, '`'));
const KEYS = new Set(['file', 'anchor', 'indent', 'before', 'after', 'insert-after', 'delete', 'command']);
~~~
   after:
~~~
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
~~~
6. file: `bin/contract-anchors.js`
   anchor: line matching `if (m && KEYS.`
   indent: 0
   insert-after:
~~~
    const o = cur && !(m && KEYS.has(m[1])) && /^\s*(?:[-*] +)?([A-Za-z][A-Za-z-]*): ?/.exec(l);
    if (o && KEYS.has(o[1].toLowerCase())) cur.odd = [...(cur.odd || []), o[1].toLowerCase()];
~~~
7. file: `bin/contract-anchors.js`
   anchor: line matching `// root = real`
   indent: 0
   before:
~~~
// root = real path of --repo; a path whose real path is outside it exits 2.
~~~
   after:
~~~
// canon is the one path function: f against the real --repo, symlinks followed (a dangling one by its target),
// exit 2 outside it. A state value is the text, null (absent) or false (a non-file, or a path under a file).
~~~
8. file: `bin/contract-anchors.js`
   anchor: line matching `const confine =`
   indent: 0
   before:
~~~
  const confine = (f) => {
    const abs = path.resolve(root, f);
    for (let p = abs; inside(abs); p = path.dirname(p)) {
      try { if (inside(fs.realpathSync(p))) return abs; break; } catch (e) { if (path.dirname(p) === p) break; }
~~~
   after:
~~~
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
~~~
9. file: `bin/contract-anchors.js`
   anchor: line matching `rest.unshift(p`
   indent: 0
   before:
~~~
      rest.unshift(path.basename(p)); p = path.dirname(p);
    }
    return usage(`path is outside --repo: ${f}`);
  };
~~~
   after:
~~~
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
~~~
10. file: `bin/contract-anchors.js`
   anchor: line matching `if (!files.has`
   indent: 0
   before:
~~~
      if (!files.has(f)) {
        const abs = confine(f);
        let c = null;
        try { c = fs.statSync(abs).isFile() ? fs.readFileSync(abs, 'utf8') : null; } catch (e) { c = null; }
        if (c !== null && !c.endsWith('\n')) c += '\n';
        files.set(f, c);
      }
      return files.get(f);
~~~
   after:
~~~
      const k = canon(f);
      if (!files.has(k.abs)) files.set(k.abs, load(k));
      return files.get(k.abs);
~~~
11. file: `bin/contract-anchors.js`
   anchor: line matching `set(f, c) { fi`
   indent: 0
   before:
~~~
    set(f, c) { files.set(f, c); },
    snapshot() { const s = makeState(root); for (const [k, v] of files) s.set(k, v); return s; },
~~~
   after:
~~~
    set(f, c) { files.set(canon(f).abs, c); },
    snapshot() { const s = makeState(root); for (const [k, v] of files) s.files.set(k, v); return s; },
    files,
~~~
12. file: `bin/contract-anchors.js`
   anchor: line matching `for (const d o`
   indent: 0
   insert-after:
~~~
    for (const o of it.odd || []) report(o, 'unchecked', it.n, file);
~~~
13. file: `bin/contract-anchors.js`
   anchor: line matching `if (c === null`
   indent: 0
   before:
~~~
    if (c === null) { report('file', 'missing', it.n, file); continue; }
~~~
   after:
~~~
    if (typeof c !== 'string') { report('file', 'missing', it.n, file); continue; }
~~~
14. file: `bin/contract-anchors.js`
   anchor: line matching `m = new RegExp`
   indent: 0
   before:
~~~
    const m = new RegExp(PHRASE.source).exec(a);
~~~
   after:
~~~
    const ph = phrases(a); const m = ph.find((x) => x.lit !== null);
~~~
15. file: `bin/contract-anchors.js`
   anchor: line matching `let hits = [];`
   indent: 0
   insert-after:
~~~
    for (let i = ph.length - (m ? 1 : 0); i > 0; i--) report('anchor', 'unchecked', it.n, file);
~~~
16. file: `bin/contract-anchors.js`
   anchor: line matching `hits = lineInd`
   indent: 0
   before:
~~~
      hits = lineIndex(c, m[1], litOf(m));
~~~
   after:
~~~
      hits = lineIndex(c, m.kind, m.lit);
~~~
17. file: `bin/contract-anchors.js`
   anchor: line matching `(const x of ta`
   indent: 0
   before:
~~~
    for (const x of tail.matchAll(PHRASE)) paths.forEach((p) => out.push({ p, kind: x[1], lit: litOf(x) }));
~~~
   after:
~~~
    const ph = phrases(tail);
    if (/^ \(anchors?:/.test(tail) && !ph.some((x) => x.lit !== null)) { paths.forEach((p) => out.push({ p, kind: 'bad' })); continue; }
    for (const x of ph) paths.forEach((p) => out.push({ p, kind: x.lit === null ? 'bad' : x.kind, lit: x.lit }));
~~~
18. file: `bin/contract-anchors.js`
   anchor: line matching `repo = a.slice`
   indent: 0
   before:
~~~
    if (a.startsWith('--repo=')) repo = a.slice('--repo='.length);
~~~
   after:
~~~
    if (a.startsWith('--repo=')) { repo = a.slice('--repo='.length); if (repo === '') usage('--repo= needs a value'); }
~~~
19. file: `bin/contract-anchors.js`
   anchor: line matching `if (x.kind ===`
   indent: 0
   insert-after:
~~~
    if (x.kind === 'bad') { say('anchor', 'unchecked', 'af', x.p); continue; }
~~~
20. file: `bin/contract-anchors.js`
   anchor: line matching `const k = befo`
   indent: 0
   before:
~~~
    const k = before === null ? 0 : lineIndex(before, x.kind, x.lit).length;
    const k2 = after === null ? 0 : lineIndex(after, x.kind, x.lit).length;
~~~
   after:
~~~
    const k = typeof before === 'string' ? lineIndex(before, x.kind, x.lit).length : 0;
    const k2 = typeof after === 'string' ? lineIndex(after, x.kind, x.lit).length : 0;
~~~
21. file: `bin/contract-anchors.js`
   anchor: line matching `process.exit(b`
   indent: 0
   before:
~~~
  process.exit(bad ? 1 : 0);
}

main();
~~~
   after:
~~~
  process.exit(bad ? 1 : 0);
}

if (require.main === module) main();
module.exports = { phrases };
~~~
22. command: `bash tests/contract-anchors.test.sh`
   expect: 0
23. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
24. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Contract anchor check: one literal grammar, one path function (rp-u6 fix 2, VERSION).** bin/contract-anchors.js parses every anchor literal with one function (`phrases`) and keys all edit state by one confined real path, so `a.txt`, `./a.txt`, `dir/../a.txt`, an absolute path and a symlink are one file. A directory, fifo or path under a file is `new exists`, a dangling link out of the repo exits 2, a second anchor phrase, an unrecognised Affected-files anchor and a `Before:` or `- before:` key are `unchecked`, and an empty `--repo=` exits 2. The test gains a grammar table and a seeded differential test against an awk oracle.
~~~
25. command: `sed -i "s/rp-u6 fix 2, VERSION/rp-u6 fix 2, $(node -p "require('./package.json').version")/" CHANGELOG.md`
   expect: 0
26. command: `node bin/cli.js --update`
   expect: 0
27. command: `git add bin/contract-anchors.js tests/contract-anchors.test.sh CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "fix(rp-u6): contract-anchors one literal grammar, one path function, seeded differential test (rp-u6)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `hooks/hooks.json` (the registration is the operator's step)
- `bin/cli.js` (the script stays out of the install list; criterion 8)
- `bin/contract-score.js`, `bin/contract-guard.js` (they score shape and stay unchanged)
- `tests/validate.sh` (the section is registered by rp-u6; the test file only grows)
- `agents/`, `templates/`, `adapters/` (no persona prose names the script)
- `tests/microworld/microworld-rerun.test.sh` (case (j) `runs=3` is flaky and unrelated)
- `docs/plans/antislop-review-patches/contracts/rp-u6.md` and every other earlier contract

## Acceptance criteria
1. run: `bash -c 'bash tests/contract-anchors.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 5 (the phrases function); the grammar and random rows FAIL, stdout is 1.
2. run: `bash -c 'bash tests/contract-anchors.test.sh | /usr/bin/grep -c "^OK   ([stuvwx]) "'`
   exit: 0
   stdout: `15`
   mutation: skip edit 2 (the last test part); stdout is 2.
3. run: `bash -c 'printf "Unit: x\n\n## Ordered edits\n1. file: \x60CHANGELOG.md\x60\n   anchor: line starting \x60## [Unreleased]\x60\n   delete: \x60## [Unreleased]\x60\n2. file: \x60./CHANGELOG.md\x60\n   anchor: line matching \x60## [Unreleased]\x60\n   insert-after: \x60x\x60\n" | node bin/contract-anchors.js /dev/stdin --repo=. | paste -sd"|"'`
   exit: 0
   stdout: `anchor ok 1 CHANGELOG.md|delete ok 1 CHANGELOG.md|anchor missing 2 ./CHANGELOG.md|contract-anchors: fail checks=3 bad=1 unchecked=0`
   mutation: change `files.set(canon(f).abs, c)` to `files.set(f, c)`; stdout reads `anchor ok 2 ./CHANGELOG.md`.
   proof: the script from `git show 32e61aae:bin/contract-anchors.js` prints `anchor ok 2 ./CHANGELOG.md`.
4. run: `node -e "const b=String.fromCharCode(96),s=String.fromCharCode(92),p=require('./bin/contract-anchors.js').phrases('line matching '+b+s+b+s+b);console.log(p.length,p[0].lit.length,p[0].lit.charCodeAt(0),p[0].lit.charCodeAt(1))"`
   exit: 0
   stdout: `1 2 96 92`
   mutation: delete the line holding `s.lastIndexOf`; stdout is `1 2 96 96`.
   proof: scratch run of the mutant.
5. run: `bash -c 'printf "Unit: x\n\n## Ordered edits\n1. file: \x60CHANGELOG.md\x60\n   anchor: line starting \x60## [Unreleased]\x60 and line ending \x60]\x60\n   insert-after: \x60x\x60\n" | node bin/contract-anchors.js /dev/stdin --repo=. 2>&1 | paste -sd"|"'`
   exit: 0
   stdout: `anchor unchecked 1 CHANGELOG.md|anchor ok 1 CHANGELOG.md|contract-anchors: unchecked checks=2 bad=0 unchecked=1|contract-anchors: WARNING 1 item(s) were not verified (see the unchecked lines)`
   mutation: delete the line holding `for (let i = ph.length`; the summary reads `ok checks=1`.
   proof: scratch run of the mutant.
6. run: `bash -c 'printf "Unit: x\n\n## Ordered edits\n1. file: \x60tests\x60\n   anchor: new file\n   insert-after: \x60x\x60\n" | node bin/contract-anchors.js /dev/stdin --repo=. | paste -sd"|"'`
   exit: 0
   stdout: `new exists 1 tests|contract-anchors: fail checks=1 bad=1 unchecked=0`
   mutation: in `load` change the `return false;` after `isFile()` to `return null;`; stdout reads `new ok 1 tests`.
   proof: scratch run of the mutant.
7. run: `bash -c 'tr "\n" " " < bin/contract-anchors.js | tr -s " " | /usr/bin/grep -cF "The literal ends at the first backtick not directly after a backslash"'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4 (the header table); stdout is 0, exit 1.
8. run: `bash -c 'test -e .claude/bin/contract-anchors.js && echo installed || echo not-installed'`
   exit: 0
   stdout: `not-installed`
   mutation: copy `bin/contract-anchors.js` into `.claude/bin/`; stdout is `installed`.
9. run: `bash -c 'for c in $(git log --format="%H %s" 32e61aae..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u6\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c" -- . ":(exclude).claude"; done | LC_ALL=C sort -u | paste -sd" "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md bin/contract-anchors.js package.json tests/contract-anchors.test.sh`
   mutation: skip edit 24 (the CHANGELOG entry); CHANGELOG.md leaves the list.
10. run: `bash -c 'for c in $(git log --format="%H %s" 32e61aae..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u6\): " | cut -d" " -f1); do for f in package.json .claude-plugin/plugin.json; do p=$(git show "$c~1:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); n=$(git show "$c:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); [ "${p%.*}.$(( ${p##*.} + 1 ))" = "$n" ] && echo "$f ok"; done; done | sort -u | paste -sd"|"'`
   exit: 0
   stdout: `.claude-plugin/plugin.json ok|package.json ok`
   mutation: skip edit 23 (the version bump); nothing prints.
11. run: `node -e "const v=require('./package.json').version,w=require('./.claude-plugin/plugin.json').version,t=require('fs').readFileSync('CHANGELOG.md','utf8').replace(/\s+/g,' ');process.exit(v===w&&t.includes('(rp-u6 fix 2, '+v+')')&&t.includes('one literal grammar, one path function')?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 24 (the CHANGELOG entry), or leave `VERSION` in it; exit 1, empty stdout.
12. run: `bash -c 'for c in $(git log --format="%H %s" 32e61aae..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u6\): " | cut -d" " -f1); do git log -1 --format=%B "$c" | /usr/bin/grep -c "^Co-Authored-By: "; done | sort -u'`
   exit: 0
   stdout: `1`
   mutation: skip edit 27 (the commit); nothing prints.
13. run: `bash -c 'e=$(git log --format="%H %s" 32e61aae..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u6\): " | cut -d" " -f1 | head -1); git log --format=%s "$e"..HEAD -- bin/contract-anchors.js tests/contract-anchors.test.sh | /usr/bin/grep -vcE "^[a-z]+\(rp-u6\): "'`
   exit: 1
   stdout: `0`
   mutation: a later commit with another subject touching `bin/contract-anchors.js`; stdout is `1`, exit 0.
   proof: scratch repo: a later commit `fix: x` printed 1 with exit 0.
14. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   precondition: if only tests/microworld/microworld-rerun.test.sh case (j) (`runs=3`, passes alone) fails, re-run this criterion once and report both results; any other failure is a FAIL.
   mutation: put `exit 1` as line 2 of tests/contract-anchors.test.sh; stdout is `1`.
15. run: `bash -c 'git status --porcelain --untracked-files=no -- bin tests .claude CHANGELOG.md package.json .claude-plugin'`
   exit: 0
   stdout: empty
   mutation: omit `git add -u -- .claude` from edit 27; the `--update` output stays unstaged and a `.claude/` path shows.

## Pre-resolved context
tdd: yes tests/contract-anchors.test.sh; edits 1 and 2 add the new rows, edit 3 shows them red (17 FAIL lines) before the script edits 4 to 21.
blast-radius: bin/contract-anchors.js:13-16, :25-26, :53, :101-121, :123-124, :137-149, :179, :187, :213-224; tests/contract-anchors.test.sh:150
grammar-table: `phrases` is the one literal parser (the same table heads the script and the test). After `line matching|ending|starting `: a backtick directly after a backslash never closes, backslash-backtick is one backtick; the literal ends at the first backtick not directly after a backslash, else at the last backtick (a trailing backslash is read as written); the double-backtick form takes no escapes; an empty or unterminated literal is unchecked. The rows are in table (s) of the test; the reviewer's case, backtick-backslash-backtick-backslash-backtick, is the two characters backtick-backslash.
path-function: `canon` alone maps a `file:` spelling (./a.txt, dir/../a.txt, absolute, symlink) to a real path inside the real --repo (lstat of the nearest existing ancestor, a dangling link by its readlink target; outside: exit 2). Edit state, the Affected-files snapshot and chains are keyed by it. A state value is the text, null (absent) or false (a directory, fifo or unreadable file, or a path under a file: `new exists`).
unchecked-added: a second phrase after the first in an Ordered-edits anchor, an Affected-files `(anchor...)` with no phrase, a key spelled `Before:` or `- before:`. DECISION: `--repo=` with no value exits 2.
supersedes: this contract's range criteria (over 32e61aae..HEAD) replace fix1 criteria 8 to 12 (their range 0ed1bb1e..HEAD now holds two commits; criterion 11 pins fix1's own CHANGELOG version). Fix1 criteria 1 to 7, 13, 14 and original criteria 1 to 8 (the 100755 mode check included) still hold. Each range loop here ends in `sort -u`: no stdout depends on the number of rp-u6 commits.
anchors-checked: every anchor and `before:` payload was applied to the CURRENT files (32e61aae) by tools/replay.py, and `node bin/contract-anchors.js` over this contract printed ok (it has the holes this unit closes, so the replay did not rely on it). Payloads are file text, `indent: 0`, nothing to strip.
order: dispatch next, before rp-u13, rp-u14 and rp-s1; none edits the two files here. They share CHANGELOG.md (inserts after `## [Unreleased]`, which stays unique) and the version files (each adds one to what it reads).
version: both version files read 0.31.218 at 32e61aae; the perl edit adds one (expected 0.31.219); the sed edit puts package.json's version into the CHANGELOG entry in place of `VERSION`.
already-green: criteria 1, 8, 13 (untagged tail), 14 and 15 pass at HEAD by design and turn red only if the unit breaks them; the new test rows are the red-to-green evidence.
commit-note: run git status --short first; a modified tracked file outside Affected files means STOP and report. Add the trailer lines the dispatch gives, verbatim.
fix-of: 2026-10-22T22:18:57Z
commit-message: fix(rp-u6): contract-anchors one literal grammar, one path function, seeded differential test (rp-u6)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: rp-u6 (fix 2)
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
criterion 15: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
