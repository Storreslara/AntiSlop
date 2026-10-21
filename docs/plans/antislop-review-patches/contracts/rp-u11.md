Unit: rp-u11

## Objective
Findings F2 (library part), F3, F4 and F5 from rp-u9's review (11719f24, 0.31.200), in
`hooks/scripts/lib/unit-scope.sh`. st-u3's scope gate builds on these semantics, so this unit lands before it.
After this unit:
- F2: `us_safe_path` also rejects a doubled slash (`src//secret.js`), a trailing slash (`src/secret.js/`)
  and a leading slash (`/src/secret.js`). Today, with `src` listed and `src/secret.js` excluded, the first
  two classify `listed`: the exact-match exclusion misses them while the directory prefix still matches.
  They now classify `out`, like a `.` or `..` segment. git never prints these shapes; st-u3 takes paths
  from a writer's tool calls and normalises them itself (its amended contract).
- F3: the `partial:` marker matches in any letter case, so `(Partial: lines 1-10)` no longer excludes
  the whole file.
- F4 (operator asked for a decision; recorded in the spec): a bullet's subject also ends at ` -- ` and at
  an em dash or en dash with or without spaces (today an en dash, ` -- ` or an unspaced em dash silently
  drops the exclusion). A reason after `,` or `;` stays a non-separator, because `` `x`, except its
  header `` is a partial restriction written the same way; the library header now says so. No
  contract-score warning: a bullet that yields no exclusion is the normal shape of every `by hand` and
  partial restriction.
- F5: `us_section` drops a line's trailing CR before matching, so a contract saved with CRLF endings has
  its headings found (today the whole section is hidden and its exclusions vanish).
- `tests/scope-libs.test.sh` gains case (j), with bullet fixtures for each rule.
This is spec Step 10.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 10 (rp-u11, rp-u12)"
and "Context, rp-u9 review findings". This file is the contract of record. Dispatch it after st-u2 has
reached PASS and before st-u3 (st-u3's amended contract relies on these semantics).

## Affected files
- `tests/scope-libs.test.sh` (anchor: line matching `exit "$fail"`, the last line)
- `hooks/scripts/lib/unit-scope.sh` (anchors: line matching `us_section() {`; line matching `us_exclusions() {`; line matching `us_safe_path() {`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/hooks/scripts/lib/unit-scope.sh`,
  `.claude/agents/*.md`, `.claude/persona-protocol*.md` and `.claude/protocol-digest.md` (version stamps
  only), the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/scope-libs.test.sh`
   anchor: line matching `exit "$fail"` (the last line)
   indent: 0
   before: `exit "$fail"`
   after:
~~~
# (j) rp-u11: `partial:` in any letter case never excludes; a spaced `--` and an em or en dash (spaced or
# not) end the subject; a reason after `,` or `;` is not a separator (no exclusion, as documented).
cat > "$T/j.md" << 'MD'
## Do NOT touch
- `j/p1.sh` (Partial: lines 1-10)
- `j/p2.sh` PARTIAL: its header
- `j/d1.sh` – an en-dash reason
- `j/d2.sh` -- a double-dash reason
- `j/d3.sh`—an unspaced em dash reason
- `j/d4.sh`–an unspaced en dash reason
- `j/c1.sh`, a reason after a comma
- `j/c2.sh`; a reason after a semicolon
- `j/w1.sh` and `j/w2.sh`
MD
[ "$(us_exclusions "$T/j.md" | tr '\n' ' ')" = 'j/d1.sh j/d2.sh j/d3.sh j/d4.sh j/w1.sh j/w2.sh ' ] && ok "(j) partial: any case, dash separators" || bad "(j) exclusions: $(us_exclusions "$T/j.md" | tr '\n' ' ')"
# (j) a file saved with CRLF endings: headings are still found and no CR reaches an entry.
printf '## Affected files\r\n- `src/a.js`\r\n\r\n## Do NOT touch\r\n- `src/b.js` (a reason)\r\n' > "$T/jc.md"
[ "$(us_entries "$T/jc.md")" = src/a.js ] && ok "(j) CRLF: Affected files entry" || bad "(j) CRLF entries: $(us_entries "$T/jc.md" | od -c | head -n1)"
[ "$(us_exclusions "$T/jc.md")" = src/b.js ] && ok "(j) CRLF: Do NOT touch exclusion" || bad "(j) CRLF exclusions: $(us_exclusions "$T/jc.md" | od -c | head -n1)"
# (j) a doubled, leading or trailing slash is never listed and classifies out, so it cannot slip past the
# exact-match exclusion of the file it names.
printf 'src\n' > "$T/jl.txt"; printf 'src/secret.js\n' > "$T/jx.txt"
for p in src//secret.js src/secret.js/ /src/secret.js; do
  us_listed "$p" "$T/jl.txt" && bad "(j) listed: $p" || ok "(j) not listed: $p"
  [ "$(us_classify "$p" "$R1" "$T/jl.txt" /dev/null /dev/null /dev/null "$T/jx.txt")" = out ] && ok "(j) out: $p" || bad "(j) class of $p"
done
[ "$(us_classify src/secret.js "$R1" "$T/jl.txt" /dev/null /dev/null /dev/null "$T/jx.txt")" = excluded ] && ok "(j) the plain path is still excluded" || bad "(j) plain path class"

exit "$fail"
~~~
2. command: `bash -c 'bash tests/scope-libs.test.sh 2>/dev/null | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `7` (the (j) partial-case row, two CRLF rows, and the listed and class rows of
   `src//secret.js` and `src/secret.js/`); `/src/secret.js` already classifies `out` and passes.
3. file: `hooks/scripts/lib/unit-scope.sh`
   anchor: line matching `us_section() {`
   indent: 0
   before:
~~~
# us_section <file> <heading>: the lines of `## <heading>` up to the next `## `
# heading, outside ``` and ~~~ fences.
us_section() {
  awk -v h="## $2" '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
~~~
   after:
~~~
# us_section <file> <heading>: the lines of `## <heading>` up to the next `## `
# heading, outside ``` and ~~~ fences. A line's trailing CR is dropped first, so a
# file saved with CRLF endings still has its headings found (rp-u11).
us_section() {
  awk -v h="## $2" '
    { sub(/\r$/, "") }
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
~~~
4. file: `hooks/scripts/lib/unit-scope.sh`
   anchor: line matching `us_exclusions() {`
   indent: 0
   before:
~~~
# us_exclusions <file>: the whole-file exclusions of the file's `## Do NOT touch`
# section, one per line (rp-u9). A bullet is a line starting `- ` plus its
# indented continuation lines, joined by one space. Its subject is the text
# before the first ` (`, `: `, ` - ` or ` — `, with trailing spaces and `.,;:`
# dropped. The subject excludes only when it is nothing but backticked path
# tokens (each holding a `/` or a `.`, no space) joined by `, `, ` and `,
# `, and `, ` or ` or `, or `; then every token is printed. Any other word in
# the subject (`by hand`, `except ...`, `ESCALATE-TO-HUMAN steps`) makes the
# bullet a partial restriction, never an exclusion. A bullet holding the
# marker `partial:` anywhere (written after the path: `x` partial: <part>)
# is a partial-file restriction whatever else it says.
us_exclusions() {
  us_section "$1" "Do NOT touch" | awk '
    function flush(   s, c, i, k, n, tok, seps) {
      s = b; b = ""; on = 0
      if (s == "" || index(s, "partial:") > 0) return
      c = 0; split(" (|: | - | — ", seps, "|")
      for (k = 1; k <= 4; k++) { i = index(s, seps[k]); if (i > 0 && (c == 0 || i < c)) c = i }
      if (c > 0) s = substr(s, 1, c - 1)
~~~
   after:
~~~
# us_exclusions <file>: the whole-file exclusions of the file's `## Do NOT touch`
# section, one per line (rp-u9). A bullet is a line starting `- ` plus its
# indented continuation lines, joined by one space. Its subject is the text
# before the first ` (`, `: `, ` - `, ` -- `, em dash or en dash (spaced or
# not), with trailing spaces and `.,;:` dropped. The subject excludes only when
# it is nothing but backticked path tokens (each holding a `/` or a `.`, no
# space) joined by `, `, ` and `, `, and `, ` or ` or `, or `; then every token
# is printed. Any other word in the subject (`by hand`, `except ...`,
# `ESCALATE-TO-HUMAN steps`) makes the bullet a partial restriction, never an
# exclusion; so does a reason after `,` or `;` (`x`, except ... is a partial
# restriction too). A bullet holding the marker `partial:` in any letter case
# anywhere (written after the path: `x` partial: <part>) is a partial-file
# restriction whatever else it says.
us_exclusions() {
  us_section "$1" "Do NOT touch" | awk '
    function flush(   s, c, i, k, n, tok, seps) {
      s = b; b = ""; on = 0
      if (s == "" || index(tolower(s), "partial:") > 0) return
      c = 0; n = split(" (|: | - | -- |—|–", seps, "|")
      for (k = 1; k <= n; k++) { i = index(s, seps[k]); if (i > 0 && (c == 0 || i < c)) c = i }
      if (c > 0) s = substr(s, 1, c - 1)
~~~
5. file: `hooks/scripts/lib/unit-scope.sh`
   anchor: line matching `us_safe_path() {`
   indent: 0
   before:
~~~
# us_safe_path <path>: exit 0 for a path the classes can judge: not empty, no
# newline (it would split into two grep patterns) and no `.` or `..` segment
# (`src/../x` must not count as under `src`). git never prints such a path
# unquoted; callers classify anything else `out`.
us_safe_path() {
  case "$1" in
    ''|*$'\n'*|.|..|./*|../*|*/.|*/..|*/./*|*/../*) return 1 ;;
  esac
  return 0
~~~
   after:
~~~
# us_safe_path <path>: exit 0 for a path the classes can judge: not empty, no
# newline (it would split into two grep patterns), no `.` or `..` segment
# (`src/../x` must not count as under `src`), no empty segment and no leading
# or trailing `/` (`src//x` and `src/x/` must not miss the exact-match
# exclusion of `src/x` while counting as under `src`; rp-u11). git never prints
# such a path; callers classify anything else `out`.
us_safe_path() {
  case "$1" in
    ''|*$'\n'*|.|..|./*|../*|*/.|*/..|*/./*|*/../*|/*|*/|*//*) return 1 ;;
  esac
  return 0
~~~
6. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.201 to 0.31.202).
7. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Unit-scope classifier: case-blind `partial:`, dash separators, CRLF headings, no stray slashes (rp-u11, VERSION).** hooks/scripts/lib/unit-scope.sh: a `## Do NOT touch` bullet holding `partial:` in any letter case (`(Partial: lines 1-10)`) no longer excludes the whole file; a bullet's subject also ends at ` -- ` and at an em or en dash with or without spaces, while a reason after `,` or `;` still makes the bullet a restriction (the library header says so); `us_section` drops a trailing CR, so a contract saved with CRLF endings has its headings found; `us_safe_path` rejects a doubled, leading or trailing `/`, so `src//x.js` and `src/x.js/` classify `out` instead of `listed` under `src` past an exact exclusion of `src/x.js`. tests/scope-libs.test.sh case (j).
~~~
   Replace `VERSION` with the version that edit 6 wrote.
8. command: `node bin/cli.js --update`
   expect: 0
9. command: `bash tests/scope-libs.test.sh`
   expect: 0
10. command: `git add -u -- hooks/scripts/lib/unit-scope.sh tests/scope-libs.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md .claude && git commit -m "fix(rp-u11): unit-scope partial marker in any case, dash separators, CRLF headings, stray slashes are out"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `bin/review-precheck.sh` and `.claude/bin/review-precheck.sh` (st-u2's; it reads git paths, which never carry these shapes; criterion 7)
- `docs/plans/antislop-structural/contracts/st-u3.md` and `docs/plans/antislop-structural/contracts/st-u4.md` (already amended for these semantics; criterion 7)
- `hooks/scripts/reviewer-tier.sh` and `tests/reviewer-tier.test.sh` (rp-u12's; criterion 7)
- `bin/contract-score.js` (no warning for a bullet that yields no exclusion: spec Step 10, F4; criterion 7)
- `adapters/`, `agents/` and `templates/` (the library is Claude-only; no prose changes; criterion 7)

## Acceptance criteria
1. run: `bash -c 'bash tests/scope-libs.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in `us_exclusions`, change `index(tolower(s), "partial:")` back to `index(s, "partial:")`; case (j) prints `FAIL (j) exclusions: j/p1.sh j/d1.sh ...` and stdout is `1`. Deleting the `{ sub(/\r$/, "") }` line fails both CRLF rows; deleting `|*//*` from `us_safe_path` fails the two `src//secret.js` rows (spec-master ran all three).
2. run: `bash -c 'cmp hooks/scripts/lib/unit-scope.sh .claude/hooks/scripts/lib/unit-scope.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 8 (`--update`); `cmp` reports a difference and the command exits 1.
3. run: `bash -c '. hooks/scripts/lib/unit-scope.sh; for p in src//a.js src/a.js/ /src/a.js src/a.js; do us_safe_path "$p"; printf "%s " "$?"; done'`
   exit: 0
   stdout: `1 1 1 0 `
   mutation: delete `|/*|*/|*//*` from the `case` in `us_safe_path`; stdout is `0 0 0 0 `.
4. run: `bash -c 'f=hooks/scripts/lib/unit-scope.sh; t=$(tr -s " \n#" " " < "$f"); for n in "trailing CR is dropped first" "em dash or en dash (spaced or not)" "so does a reason after" "in any letter case" "no empty segment and no leading or trailing"; do printf "%s" "$t" | grep -oF -- "$n" | wc -l; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 1 1 1 `
   mutation: skip the comment lines of edit 4 (keep its code lines); the second, third and fourth counts are `0`.
5. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u11): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u11): " | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md hooks/scripts/lib/unit-scope.sh package.json tests/scope-libs.test.sh `
   mutation: also edit `bin/review-precheck.sh` in an rp-u11 commit; it joins the list.
6. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u11): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u11): " | head -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:package.json" | grep "\"version\"")" = "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:CHANGELOG.md" | grep -c "(rp-u11, ")" = 1 && echo moved'`
   exit: 0
   stdout: `moved`
   mutation: skip edit 6; the versions are equal, stdout is empty and the exit is 1.
7. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u11): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u11): " | head -1); git diff --name-only "$b^..$l" -- bin hooks/scripts/reviewer-tier.sh tests/reviewer-tier.test.sh docs/plans adapters agents templates | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `docs/plans/antislop-structural/contracts/st-u3.md` in an rp-u11 commit; stdout is `1`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/scope-libs.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edit 1 adds case (j) and edit 2 shows it red (`7`) before the library edits 3 to 5.
evidence: verified 2026-10-21 against 952a8796 (st-u2 landed, 0.31.201). With `src` listed and `src/secret.js` excluded, `us_classify` printed `listed` for `src/secret.js/` and `src//secret.js` (`out` for `/src/secret.js`, which matches no entry, and `excluded` for the plain path). `us_exclusions` of a bullet `` `a/b.sh` (Partial: lines 1-10) `` printed `a/b.sh`; bullets ending their subject at an en dash, ` -- `, an unspaced em dash, `,` or `;` printed nothing; a `## Do NOT touch\r` heading printed nothing. (The finding's line numbers ~169 and ~197 match no layout of the 163-line file; the defects are at the anchors above.)
F2-decision: both layers. The library rejects the three shapes, because it is the one classifier every caller shares and it cannot know whether a caller normalised; st-u3 normalises a tool-call path lexically before judging it (so a legitimate edit through `src//a.js` is judged as `src/a.js`, never blocked as `out`). st-u2 and st-u4 read git paths or contract tokens: st-u2 is unaffected, st-u4 (amended) prints `full` for an unsafe entry.
F4-decision: widen the dashes only. ` - ` already ends a subject, so ` – `, ` -- ` and an unspaced dash read the same way and add no over-exclusion that ` - ` does not already allow. `,` and `;` stay non-separators: treating them as one would turn `` `x`, except its header `` into a whole-file exclusion, the over-exclusion rp-u9 removed. Under-exclusion is not always harmless (a path a criterion reads would classify `criteria`), which is why the header now names the comma and semicolon case. spec-master ran the old and new `us_exclusions` over all 128 contract files under `docs/plans/*/contracts/`: no output changed.
F5-decision: fixed, not recorded: one awk rule, and a CRLF contract (an editor on Windows, a pasted dispatch) would otherwise lose its whole Do-NOT-touch section silently.
awk: the separators are matched with `index()` on literal strings, which is byte-exact in mawk and gawk in any locale; spec-master ran the test under gawk 5.2 (default), gawk with `LC_ALL=C`, and mawk: all pass.
chained: no queued contract edits `hooks/scripts/lib/unit-scope.sh` or `tests/scope-libs.test.sh`. spec-master applied this contract and then the amended st-u3 and st-u4, rp-u10, rp-u7, rp-u4, rp-u5 and rp-u6 to a clone at 952a8796 with a script that requires each `before:` payload once: all matched; st-u2's tests/review-precheck.test.sh still passes on top of this library.
blast-radius: hooks/scripts/lib/unit-scope.sh:6-10 (`us_section`), :26-44 (`us_exclusions`), :65-73 (`us_safe_path`); tests/scope-libs.test.sh last line. Callers: bin/review-precheck.sh (landed, st-u2), hooks/scripts/writer-scope-gate.sh (st-u3), bin/unit-size.sh (st-u4). Line numbers are at 952a8796.
version: .claude-plugin/plugin.json and package.json read 0.31.201 after st-u2 if no fix round bumped; edit 6 adds one (expected 0.31.202).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(rp-u11): unit-scope partial marker in any case, dash separators, CRLF headings, stray slashes are out
diagnosis: none
review-packet:
~~~
unit: rp-u11
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
If a `before:` payload is not found verbatim (a st-u2 fix round may have touched the library), stop and
report the current text. If a case outside (j) changes result, quote it and stop. If `node bin/cli.js
--update` reports a mirror as diverged, quote it and stop. If a gate blocks a command, report it and wait.
Anything outside "Affected files" goes to your report as a proposal.
