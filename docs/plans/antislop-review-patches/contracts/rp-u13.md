Unit: rp-u13

## Objective
Three review notes from rp-u11's PASS (2bccfd94, 0.31.203) on `hooks/scripts/lib/unit-scope.sh`, the
library st-u3's scope gate and st-u2's precheck read `## Do NOT touch` with. After this unit:
- A bullet's subject ends only at a separator outside backticks. Today the unspaced em and en dash are
  found with `index()` over the whole bullet, so a dash inside a path cuts it: `` `x–y.md` `` and
  `` `a/x—y.md` (frozen) `` were whole-file exclusions before rp-u11 and now yield none, so a forbidden file
  passes (under-exclusion, the dangerous direction). The bullet is now read from its start: the backticked
  path list, then a separator (` (`, `: `, ` - `, ` -- `, an em or en dash, spaced or not) or the end.
- `partial:` (any letter case) is the partial-file marker only in its documented place: right after the
  path list, outside backticks, optionally opened by `(` (`` `x` partial: <part> `` and
  `` `x` (Partial: <part>) ``). Today it matches anywhere, so `` `a/p5.sh` (frozen; see the Partial:
  section) `` and `` `a/Partial:x.sh` `` lose a real exclusion. Code, header comment, test and the spec's
  scribe hint say the same.
- `us_section` drops every trailing CR, not one (`\r\r\n`, a file converted twice, hid its heading).
- `tests/scope-libs.test.sh` gains case (k).
Over all 131 contract files under `docs/plans/*/contracts/`, the old and new `us_exclusions` print the same
1353 lines. This is spec Step 11.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 11 (rp-u13, rp-u14)"
and "Context, rp-u11 and st-u2 review notes". This file is the contract of record. Dispatch it after rp-u6
(spec Dispatch section); it shares no file with any queued unit except `tests/scope-libs.test.sh`, where
rp-u12 edits case (b) and this unit only the last line.

## Affected files
- `tests/scope-libs.test.sh` (anchor: line matching `exit "$fail"`, the last line)
- `hooks/scripts/lib/unit-scope.sh` (anchors: line matching `us_section() {`; line matching `us_exclusions() {`)
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
# (k) rp-u13: the subject ends only at a separator outside backticks, so a dash inside a path is part of
# it; `partial:` is the marker only right after the path list (optionally opened by `(`), never in a
# reason or inside a path; a line ending in two CRs still has its heading found.
cat > "$T/k.md" << 'MD'
## Do NOT touch
- `k/x–y.md`
- `k/a/x—y.md` (frozen)
- `k/p5.sh` (frozen; see the Partial: section of the spec)
- `k/Partial:x.sh`
- `k/p6.sh` (Partial: lines 1-10)
- `k/p7.sh` partial: its header
- `k/a.md` and `k/b–c.md`
- `k/e.sh` — a spaced em dash reason
MD
[ "$(us_exclusions "$T/k.md" | tr '\n' ' ')" = 'k/x–y.md k/a/x—y.md k/p5.sh k/Partial:x.sh k/a.md k/b–c.md k/e.sh ' ] && ok "(k) dash inside backticks, partial: only after the paths" || bad "(k) exclusions: $(us_exclusions "$T/k.md" | tr '\n' ' ')"
printf '## Do NOT touch\r\r\n- `k/r.sh` (a reason)\r\r\n' > "$T/kc.md"
[ "$(us_exclusions "$T/kc.md")" = k/r.sh ] && ok "(k) two trailing CRs: Do NOT touch exclusion" || bad "(k) CRCR exclusions: $(us_exclusions "$T/kc.md" | od -c | head -n1)"

exit "$fail"
~~~
2. command: `bash -c 'bash tests/scope-libs.test.sh 2>/dev/null | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `2` (the (k) exclusions row and the (k) two-CR row).
3. file: `hooks/scripts/lib/unit-scope.sh`
   anchor: line matching `us_section() {`
   indent: 0
   before:
~~~
# us_section <file> <heading>: the lines of `## <heading>` up to the next `## `
# heading, outside ``` and ~~~ fences. A line's trailing CR is dropped first, so a
# file saved with CRLF endings still has its headings found (rp-u11).
us_section() {
  awk -v h="## $2" '
    { sub(/\r$/, "") }
~~~
   after:
~~~
# us_section <file> <heading>: the lines of `## <heading>` up to the next `## `
# heading, outside ``` and ~~~ fences. A line's trailing CRs (one or more) are
# dropped first, so a file saved with CRLF endings, or converted twice, still has
# its headings found (rp-u11, rp-u13).
us_section() {
  awk -v h="## $2" '
    { sub(/\r+$/, "") }
~~~
4. file: `hooks/scripts/lib/unit-scope.sh`
   anchor: line matching `us_exclusions() {`
   indent: 0
   before:
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
      sub(/[[:space:].,;:]+$/, "", s)
      n = 0
      while (1) {
        if (!match(s, /^`[^` ]+`/)) return
        tok[++n] = substr(s, 2, RLENGTH - 2)
        if (tok[n] !~ /[\/.]/) return
        s = substr(s, RLENGTH + 1)
        if (s == "") break
        if (!match(s, /^(, and |, or |, | and | or )/)) return
        s = substr(s, RLENGTH + 1)
      }
      for (k = 1; k <= n; k++) print tok[k]
    }
~~~
   after:
~~~
# us_exclusions <file>: the whole-file exclusions of the file's `## Do NOT touch`
# section, one per line (rp-u9). A bullet is a line starting `- ` plus its
# indented continuation lines, joined by one space. It is read from its start:
# backticked path tokens (each holding a `/` or a `.`, no space) joined by `, `,
# ` and `, `, and `, ` or ` or `, or `. That path list is the subject, and it
# ends only outside backticks (a dash inside `x–y.md` is part of the path, rp-u13):
# at the end of the bullet (trailing spaces and `.,;:` aside), or at ` (`, `: `,
# ` - `, ` -- `, or an em or en dash, spaced or not. Then every token is
# printed. Any other word in the subject (`by hand`, `except ...`,
# `ESCALATE-TO-HUMAN steps`) makes the bullet a partial restriction, never an
# exclusion; so does a reason after `,` or `;` (`x`, except ... is a partial
# restriction too). The marker `partial:` (any letter case) makes the bullet a
# partial-file restriction only in its documented place: right after the path
# list, outside backticks, optionally opened by `(` (`x` partial: <part>, or
# `x` (Partial: <part>)). Elsewhere, in a reason or inside a path, it is plain
# text, so `x` (frozen; see the Partial: section) still excludes `x`.
us_exclusions() {
  us_section "$1" "Do NOT touch" | awk '
    function flush(   s, k, n, ns, tok, seps) {
      s = b; b = ""; on = 0
      if (s == "") return
      ns = split(" (|: | - | -- |—|–| —| –", seps, "|")
      n = 0
      while (1) {
        if (!match(s, /^`[^` ]+`/)) return
        tok[++n] = substr(s, 2, RLENGTH - 2)
        if (tok[n] !~ /[\/.]/) return
        s = substr(s, RLENGTH + 1)
        if (s ~ /^[[:space:].,;:]*$/) break
        if (tolower(s) ~ /^[[:space:]]*\(?partial:/) return
        for (k = 1; k <= ns; k++) if (index(s, seps[k]) == 1) break
        if (k <= ns) break
        if (!match(s, /^(, and |, or |, | and | or )/)) return
        s = substr(s, RLENGTH + 1)
      }
      for (k = 1; k <= n; k++) print tok[k]
    }
~~~
5. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.211 to 0.31.212).
6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Unit-scope classifier: a dash inside a path is part of it; `partial:` only right after the paths; every trailing CR dropped (rp-u13, VERSION).** hooks/scripts/lib/unit-scope.sh: `us_exclusions` reads a `## Do NOT touch` bullet from its start, so the subject ends only at a separator outside backticks (`` `x–y.md` `` and `` `a/x—y.md` (frozen) `` exclude their file again; rp-u11 had matched the unspaced dashes anywhere in the bullet, so a forbidden file with a dash in its name passed); the `partial:` marker (any letter case) counts only right after the path list, optionally opened by `(`, so a reason that mentions it (`` `a/p5.sh` (frozen; see the Partial: section) ``) or a path that holds it keeps its whole-file exclusion; `us_section` drops every trailing CR, so a line ending in `\r\r\n` still has its heading found. The old and new library print the same exclusions for all 131 contract files. tests/scope-libs.test.sh case (k).
~~~
   Replace `VERSION` with the version that edit 5 wrote.
7. command: `node bin/cli.js --update`
   expect: 0
8. command: `bash tests/scope-libs.test.sh`
   expect: 0
9. command: `git add -u -- hooks/scripts/lib/unit-scope.sh tests/scope-libs.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md .claude && git commit -m "fix(rp-u13): unit-scope subject ends outside backticks, partial: only after the paths, every trailing CR dropped"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `bin/review-precheck.sh` and `tests/review-precheck.test.sh` (rp-u14's; criterion 7)
- `hooks/scripts/writer-scope-gate.sh` and `tests/writer-scope-gate.test.sh` (st-u3's; its cases (m) and (o) keep their result under this grammar; criterion 7)
- `hooks/scripts/reviewer-tier.sh` and `tests/reviewer-tier.test.sh` (rp-u12's; criterion 7)
- `bin/contract-score.js` (no warning for a bullet that yields no exclusion, as ruled for rp-u11; criterion 7)
- `adapters/`, `agents/` and `templates/` (the library is Claude-only; no prose changes; criterion 7)

## Acceptance criteria
1. run: `bash -c 'bash tests/scope-libs.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in `us_exclusions`, replace `if (tolower(s) ~ /^[[:space:]]*\(?partial:/) return` with `if (index(tolower(s), "partial:") > 0) return`; case (k) prints `FAIL (k) exclusions: k/x–y.md k/a/x—y.md k/Partial:x.sh ...` (no `k/p5.sh`) and stdout is `1`. Changing `\r+$` back to `\r$` in `us_section` fails the (k) two-CR row (spec-master ran both).
2. run: `bash -c 'cmp hooks/scripts/lib/unit-scope.sh .claude/hooks/scripts/lib/unit-scope.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 7 (`--update`); `cmp` reports a difference and the command exits 1.
3. run: `bash -c '. hooks/scripts/lib/unit-scope.sh; us_exclusions <(printf "## Do NOT touch\n- \x60a/x–y.md\x60 (frozen)\n- \x60a/p5.sh\x60 (frozen; see the Partial: section)\n- \x60a/p6.sh\x60 (Partial: lines 1-10)\n") | tr "\n" " "'`
   exit: 0
   stdout: `a/x–y.md a/p5.sh `
   mutation: restore the rp-u11 `flush` (edit 4's `before:` code lines); stdout is empty (spec-master ran it against 2bccfd94).
4. run: `bash -c 'f=hooks/scripts/lib/unit-scope.sh; t=$(tr -s " \n#" " " < "$f"); for n in "it ends only outside backticks" "only in its documented place" "so x (frozen; see the Partial: section) still excludes x" "trailing CRs (one or more) are dropped first"; do printf "%s" "$t" | tr -d "\140" | grep -oF -- "$n" | wc -l; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 1 1 `
   mutation: skip the comment lines of edit 4 (keep its code lines); the first three counts are `0`.
5. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u13): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u13): " | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md hooks/scripts/lib/unit-scope.sh package.json tests/scope-libs.test.sh `
   mutation: also edit `bin/review-precheck.sh` in an rp-u13 commit; it joins the list.
6. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u13): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u13): " | head -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:package.json" | grep "\"version\"")" = "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:CHANGELOG.md" | grep -c "(rp-u13, ")" = 1 && echo moved'`
   exit: 0
   stdout: `moved`
   mutation: skip edit 5; the versions are equal, stdout is empty and the exit is 1.
7. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u13): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u13): " | head -1); git diff --name-only "$b^..$l" -- bin hooks/scripts/writer-scope-gate.sh hooks/scripts/reviewer-tier.sh tests/review-precheck.test.sh tests/writer-scope-gate.test.sh tests/reviewer-tier.test.sh docs/plans adapters agents templates | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `tests/review-precheck.test.sh` in an rp-u13 commit; stdout is `1`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/scope-libs.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edit 1 adds case (k) and edit 2 shows it red (`2`) before the library edits 3 and 4.
evidence: verified 2026-10-21 against 2bccfd94 (rp-u11 landed, 0.31.203). `us_exclusions` of `` `x–y.md` `` and `` `a/x—y.md` (frozen) `` printed nothing (the rp-u11 code cuts the bullet at the first `—` or `–` found by `index()`, inside the backticks); `` `a/p5.sh` (frozen; see the Partial: section) `` printed nothing (`index(tolower(s), "partial:")` over the whole bullet); a `## Do NOT touch\r\r` heading hid the section (`sub(/\r$/, "")` drops one CR). Source: `.claude/reviewed/rp-u11.pass` notes 1 to 3 (read with the Read tool).
partial-decision: the marker counts only right after the path list, optionally opened by `(`. Under-exclusion is the dangerous direction (a forbidden file passes; st-u3 blocks nothing, the precheck flags nothing), so the marker is recognised narrowly: a bullet that says `partial:` somewhere else is read as a whole-file exclusion, which at worst flags an edit the reviewer then judges. `` `x` — partial: <part> `` (a dash before the marker) is therefore a whole-file exclusion; the header says where the marker goes. rp-u11's case (j) rows `(Partial: lines 1-10)` and `PARTIAL: its header` keep their result, as do st-u2's u2.md fixture and st-u3's cases (m) and (o).
equivalence: spec-master ran the rp-u11 and the new `us_exclusions` over all 131 contract files under `docs/plans/*/contracts/` at 2bccfd94: both print the same 1353 lines (`cmp` equal). The test passes under gawk 5.2, gawk with `LC_ALL=C` and mawk 1.3.4 (the dashes are matched with `index()` on literal strings and the token regex excludes only a backtick and a space, so multibyte dashes inside a token are kept in every locale).
chained: no queued contract edits `hooks/scripts/lib/unit-scope.sh`; rp-u12 edits `tests/scope-libs.test.sh` at case (b), this unit only at its last line. spec-master applied st-u3, st-u4, rp-u10, rp-u12, rp-u7, rp-u4, rp-u5, rp-u6, this contract and rp-u14 in that order to a clone of the current master with a script that requires each `before:` payload once; see the spec's Dispatch section for the result.
blast-radius: hooks/scripts/lib/unit-scope.sh:6-17 (`us_section`), :28-67 (`us_exclusions`); tests/scope-libs.test.sh last line. Callers: bin/review-precheck.sh (st-u2), hooks/scripts/writer-scope-gate.sh (st-u3), `us_entries <f> "Do NOT touch"`. Line numbers are at 2bccfd94.
version: .claude-plugin/plugin.json and package.json read 0.31.211 after rp-u6 if no fix round bumped; edit 5 adds one (expected 0.31.212).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(rp-u13): unit-scope subject ends outside backticks, partial: only after the paths, every trailing CR dropped
diagnosis: none
review-packet:
~~~
unit: rp-u13
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
If a `before:` payload is not found verbatim (a fix round on st-u3 or rp-u12 may have touched the library or
the test), stop and report the current text. If a case outside (k) changes result, quote it and stop. If
`node bin/cli.js --update` reports a mirror as diverged, quote it and stop. If a gate blocks a command,
report it and wait. Anything outside "Affected files" goes to your report as a proposal.
