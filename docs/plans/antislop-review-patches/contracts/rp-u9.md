Unit: rp-u9

## Objective
Findings S2 and S3 from st-u1's review, in `hooks/scripts/lib/unit-scope.sh` (classifier correctness; st-u2,
st-u3 and st-u4 build on it, so it lands before them). After this unit:
- S2: `## Do NOT touch` is read by a new `us_exclusions <file>`, one bullet at a time. A bullet is a line
  starting `- ` plus its indented continuation lines, joined by one space. Its **subject** is the text
  before the first ` (`, `: `, ` - ` or ` — `, trailing spaces and `.,;:` dropped. The bullet excludes only
  when its subject is nothing but backticked path tokens (each holding a `/` or a `.`, no space) joined by
  `, `, ` and `, `, and `, ` or ` or `, or `; then every one of those tokens is excluded. Any other word in
  the subject (`by hand`, `except ...`, `ESCALATE-TO-HUMAN steps`, `from the paragraph ...`) makes the
  bullet a restriction, not an exclusion. The explicit marker for a partial-file restriction is the word
  `partial:` anywhere in the bullet, written after the path (for example ``- `agents/orchestrator.md`
  partial: from "## Lane routing" to the end``, which keeps contract-score's R6 rule that a Do-NOT-touch
  bullet opens with a backticked path): such a bullet never excludes, whatever else it says. A path inside a reason (after the subject) is never
  excluded. `us_entries <file> "Do NOT touch"` returns the same list, so no caller can take the old reading.
  Today qw-u2 and qw-u4 list `agents/orchestrator.md` as their main edited file while their Do-NOT-touch
  bullets read "`agents/orchestrator.md` ESCALATE-TO-HUMAN steps" and "`agents/orchestrator.md` from the
  paragraph starting ...", so `us_classify` marks that file `excluded`; qw-u3's reason text
  "`tests/protocol-doc-drift.test.js` counts stay valid" excludes that test.
- S3: a contract glob's `*` and `?` match within one path segment (`docs/*.md` no longer lists
  `docs/adr/0042-x.md`); every other glob character is literal. A path that is empty, holds a newline (it
  would split into two `grep` patterns) or has a `.` or `..` segment (`src/../CONTEXT.md` counted as under
  `src`) is never listed and `us_classify` prints `out` for it (`us_safe_path`). git never prints such a
  path unquoted, so this is the minimal safe handling, with no NUL-delimited input.
- `tests/scope-libs.test.sh` case (g) now expects the reason token to be dropped; new case (h) runs bullets
  copied verbatim from the contracts of every unit shipped this session (aof-u1 to aof-u4, aof-u3b, qw-u1 to
  qw-u6, rp-u1 to rp-u3, st-u1) as a fixture, and case (i) covers the glob and unsafe-path rules.
This is spec Step 9.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 9 (rp-u8 to rp-u10)"
and "Context, st-u1 review findings". This file is the contract of record. Dispatch it right after rp-u8 and
before st-u2 (st-u2 and st-u3 call `us_exclusions`; their amended contracts say so).

## Affected files
- `tests/scope-libs.test.sh` (anchor: line matching `# (g) us_entries reads a named section.`)
- `hooks/scripts/lib/unit-scope.sh` (anchors: line matching `# us_entries <file> [<heading>]: every backtick-quoted token with no space that`; line matching `# us_listed <path> <entries-file>: exit 0 when an entry equals the path, is a`; line matching `# us_classify <path> <rev> <listed> <fix-listed> <criteria-text> <fail-text> [<excluded>]:`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/hooks/scripts/lib/unit-scope.sh`,
  `.claude/agents/*.md`, `.claude/persona-protocol*.md` and `.claude/protocol-digest.md` (version stamps
  only), the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/scope-libs.test.sh`
   anchor: line matching `# (g) us_entries reads a named section.`
   indent: 0
   before:
~~~
# (g) us_entries reads a named section.
printf '## Affected files\n- `a/b.js`\n\n## Do NOT touch\n- `c/d.js` (reason `e.f`)\n' > "$T/g.md"
[ "$(us_entries "$T/g.md" "Do NOT touch" | tr '\n' ' ')" = 'c/d.js e.f ' ] && ok "(g) Do NOT touch entries" || bad "(g) section entries"
[ "$(us_entries "$T/g.md" | tr '\n' ' ')" = 'a/b.js ' ] && ok "(g) default section" || bad "(g) default section"
~~~
   after:
~~~
# (g) us_entries reads a named section; a token in a Do NOT touch reason is not an entry (rp-u9).
printf '## Affected files\n- `a/b.js`\n\n## Do NOT touch\n- `c/d.js` (reason `e.f`)\n' > "$T/g.md"
[ "$(us_entries "$T/g.md" "Do NOT touch" | tr '\n' ' ')" = 'c/d.js ' ] && ok "(g) Do NOT touch entries" || bad "(g) section entries"
[ "$(us_entries "$T/g.md" | tr '\n' ' ')" = 'a/b.js ' ] && ok "(g) default section" || bad "(g) default section"

# (h) rp-u9: `## Do NOT touch` excludes a bullet's whole subject only. The bullets are copied verbatim
# from the contracts of aof-u1 to aof-u4, aof-u3b, qw-u1 to qw-u6, rp-u1 to rp-u3 and st-u1 (fixtures, not
# the live files); the last five bullets are grammar cases.
cat > "$T/h.md" << 'MD'
## Do NOT touch
- `bin/ladder-tier.sh`, `bin/contract-guard.js`, `bin/contract-score.js`, `bin/fail-count.sh`,
  `bin/escalation-card.sh`: no script edits. The layout already resolves under `.claude/`.
- `bin/harness-integrity.sh` and `hooks/scripts/session-start.sh` (spec R2; re-arming the drift check is a
  separate operator decision).
- `hooks/hooks.json`, `templates/settings-fragment.json`, `harness-integrity-gate.sh`'s Set A lists.
- Anything under `eval/`.
- `hooks/scripts/lib/reviewer-route-gate-core.sh` and the stamp format it writes.
- `hooks/scripts/stop-gate.sh`, the entry point, unless the new function needs a lib that is already sourced
  there. It should not.
- `agents/scribe.md`, `agents/spec-master.md`, and the Scribe dispatch convention in orchestrator.md: those
  are aof-u4.
- `.claude/` copies by hand: `node bin/cli.js --update` rewrites them, including the version stamp in
  `.claude/protocol-digest.md` and `.claude/persona-protocol*.md`; that stamp change is expected, not a scope breach
- `CONTEXT.md` and `docs/adr/`: the draft ADR in the spec is landed later by scribe, not by this unit.
- `.claude/agents/orchestrator.md` by hand (only `node bin/cli.js --update` writes it)
- `agents/orchestrator.md` ESCALATE-TO-HUMAN steps (qw-u4 moves them; leave them as they are)
- `bin/cli.js` (no matrix change; section headings are unchanged, so `tests/protocol-doc-drift.test.js` counts stay valid)
- `agents/orchestrator.md` from the paragraph starting `If no` (the no-reviewer paragraph) to the end of the file
- `adapters/codex/agents/reviewer.toml`, `adapters/cursor/agents/reviewer.md` and the two adapter protocol ports (their scaffolds install no `.claude/bin/`; criterion 5)
- `agents/reviewer.md`, `agents/lead-programmer.md` and every other `agents/*.md` frontmatter (subagent tiers are unchanged)
- `hooks/hooks.json` and every other `hooks/scripts/*.sh` except reviewer-tier.sh (no gate or registration change; criterion 5)
- `agents/` and `templates/` (no prose in this unit)
- `hooks/scripts/lib/unit-scope.sh`, `hooks/scripts/writer-scope-gate.sh`, `bin/review-precheck.sh` (st-u1 to st-u3 own them; spec Open Question 1)
- `docs/guide.md` partial: lines 10 to 20 only
- `docs/guide2.md` (partial: its first section)
- `docs/x.md` — an em-dash reason naming `docs/r1.md`
- `docs/y.md` - a dash reason naming `docs/r2.md`
- `docs/z.md`, `docs/w.md`, or `docs/v.md`.
MD
us_exclusions "$T/h.md" > "$T/hx.txt"
want='bin/ladder-tier.sh bin/contract-guard.js bin/contract-score.js bin/fail-count.sh bin/escalation-card.sh bin/harness-integrity.sh hooks/scripts/session-start.sh CONTEXT.md docs/adr/ bin/cli.js agents/ templates/ hooks/scripts/lib/unit-scope.sh hooks/scripts/writer-scope-gate.sh bin/review-precheck.sh docs/x.md docs/y.md docs/z.md docs/w.md docs/v.md '
[ "$(tr '\n' ' ' < "$T/hx.txt")" = "$want" ] && ok "(h) whole-subject bullets only" || bad "(h) exclusions: $(tr '\n' ' ' < "$T/hx.txt")"
cmp -s "$T/hx.txt" <(us_entries "$T/h.md" "Do NOT touch") && ok "(h) us_entries reads Do NOT touch through us_exclusions" || bad "(h) us_entries Do NOT touch differs"
for p in agents/orchestrator.md tests/protocol-doc-drift.test.js hooks/hooks.json hooks/scripts/lib/reviewer-route-gate-core.sh .claude/protocol-digest.md \
         hooks/scripts/stop-gate.sh agents/scribe.md .claude/agents/orchestrator.md adapters/codex/agents/reviewer.toml \
         agents/reviewer.md docs/guide.md docs/guide2.md docs/r1.md docs/r2.md; do
  us_excluded "$p" "$T/hx.txt" && bad "(h) wrongly excluded: $p" || ok "(h) not excluded: $p"
done
printf 'agents/orchestrator.md\n' > "$T/ho.txt"
[ "$(us_classify agents/orchestrator.md "$R1" "$T/ho.txt" /dev/null /dev/null /dev/null "$T/hx.txt")" = listed ] && ok "(h) qw-u2/qw-u4: the main edited file stays listed" || bad "(h) main edited file excluded"
[ "$(us_classify bin/cli.js "$R1" "$T/ho.txt" /dev/null /dev/null /dev/null "$T/hx.txt")" = excluded ] && ok "(h) a whole-file bullet still excludes" || bad "(h) whole-file bullet lost"

# (i) rp-u9: a glob's `*` and `?` stay inside one path segment; an unsafe path (empty, a newline, a `.` or
# `..` segment) is never listed and classifies `out`.
printf 'docs/*.md\nsrc\ntests/?.sh\nlib/a.b*\n' > "$T/i.txt"
us_listed docs/guide.md "$T/i.txt" && ok "(i) glob within a segment" || bad "(i) glob within a segment"
us_listed docs/adr/0042-x.md "$T/i.txt" && bad "(i) * crossed a /" || ok "(i) * stops at /"
us_listed tests/a.sh "$T/i.txt" && ok "(i) ? is one character" || bad "(i) ? one character"
us_listed tests/x/a.sh "$T/i.txt" && bad "(i) ? crossed a /" || ok "(i) ? stops at /"
us_listed lib/axb1 "$T/i.txt" && bad "(i) a glob's . matched any character" || ok "(i) a glob's . is literal"
us_listed lib/a.b1 "$T/i.txt" && ok "(i) literal . then *" || bad "(i) literal . then *"
us_listed src/../CONTEXT.md "$T/i.txt" && bad "(i) .. counted under src" || ok "(i) .. segment not listed"
us_listed src/./a.js "$T/i.txt" && bad "(i) . segment listed" || ok "(i) . segment not listed"
us_listed "$(printf 'src/a.js\nCONTEXT.md')" "$T/i.txt" && bad "(i) newline path listed" || ok "(i) newline path not listed"
printf 'CONTEXT.md\n' > "$T/ix.txt"
[ "$(us_classify "$(printf 'src/a.js\nCONTEXT.md')" "$R1" "$T/i.txt" /dev/null /dev/null /dev/null "$T/ix.txt")" = out ] && ok "(i) newline path classifies out" || bad "(i) newline path class"
[ "$(us_classify src/../CONTEXT.md "$R1" "$T/i.txt" /dev/null /dev/null /dev/null)" = out ] && ok "(i) .. path classifies out" || bad "(i) .. path class"
[ "$(us_classify src/a.js "$R1" "$T/i.txt" /dev/null /dev/null /dev/null)" = listed ] && ok "(i) a plain path under a listed directory" || bad "(i) plain path"
~~~
2. command: `bash -c 'bash tests/scope-libs.test.sh 2>/dev/null | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `10` ((g), three (h) rows: the exclusion list, the `us_entries` equality and the
   whole-file bullet; and six (i) rows: `*` crossing `/`, the `..` and `.` segments, and the three newline
   and `..` class rows). `us_exclusions` does not exist yet, so the shell also reports it not found.
3. file: `hooks/scripts/lib/unit-scope.sh`
   anchor: line matching `# us_entries <file> [<heading>]: every backtick-quoted token with no space that`
   indent: 0
   before:
~~~
# us_entries <file> [<heading>]: every backtick-quoted token with no space that
# contains a `/` or a `.` in the file's `## <heading>` section (default
# `Affected files`), one per line.
us_entries() {
  us_section "$1" "${2:-Affected files}" | grep -oE '`[^` ]+`' | tr -d '`' | grep -E '[/.]' || true
}
~~~
   after:
~~~
# us_entries <file> [<heading>]: every backtick-quoted token with no space that
# contains a `/` or a `.` in the file's `## <heading>` section (default
# `Affected files`), one per line. `Do NOT touch` is read by us_exclusions
# instead: a token there may sit in a reason or a partial-file qualifier.
us_entries() {
  if [ "${2:-}" = "Do NOT touch" ]; then us_exclusions "$1"; return 0; fi
  us_section "$1" "${2:-Affected files}" | grep -oE '`[^` ]+`' | tr -d '`' | grep -E '[/.]' || true
}

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
    /^- / { flush(); b = substr($0, 3); on = 1; next }
    on && /^[[:space:]]+[^[:space:]]/ { t = $0; sub(/^[[:space:]]+/, "", t); b = b " " t; next }
    { flush() }
    END { flush() }
  '
}

# us_safe_path <path>: exit 0 for a path the classes can judge: not empty, no
# newline (it would split into two grep patterns) and no `.` or `..` segment
# (`src/../x` must not count as under `src`). git never prints such a path
# unquoted; callers classify anything else `out`.
us_safe_path() {
  case "$1" in
    ''|*$'\n'*|.|..|./*|../*|*/.|*/..|*/./*|*/../*) return 1 ;;
  esac
  return 0
}

# us_glob_re <glob>: an anchored ERE for a contract glob. `*` and `?` match
# within one path segment, never across `/`; every other character is literal.
us_glob_re() {
  printf '^%s$' "$(printf '%s' "$1" | sed -e 's/[].[^$\\+(){}|]/\\&/g' -e 's#\*#[^/]*#g' -e 's#?#[^/]#g')"
}
~~~
4. file: `hooks/scripts/lib/unit-scope.sh`
   anchor: line matching `# us_listed <path> <entries-file>: exit 0 when an entry equals the path, is a`
   indent: 0
   before:
~~~
# us_listed <path> <entries-file>: exit 0 when an entry equals the path, is a
# directory prefix of it, or is a glob that matches it.
us_listed() {
  local p="$1" e
  [ -s "$2" ] || return 1
  while IFS= read -r e || [ -n "$e" ]; do
    e="${e%/}"
    [ -n "$e" ] || continue
    [ "$p" = "$e" ] && return 0
    case "$p" in "$e"/*) return 0 ;; esac
    case "$e" in *[*?]*) [[ "$p" == $e ]] && return 0 ;; esac
  done < "$2"
  return 1
}
~~~
   after:
~~~
# us_listed <path> <entries-file>: exit 0 when an entry equals the path, is a
# directory prefix of it, or is a glob that matches it (`*` and `?` within one
# segment). An unsafe path (us_safe_path) is never listed.
us_listed() {
  local p="$1" e re
  [ -s "$2" ] || return 1
  us_safe_path "$p" || return 1
  while IFS= read -r e || [ -n "$e" ]; do
    e="${e%/}"
    [ -n "$e" ] || continue
    [ "$p" = "$e" ] && return 0
    case "$p" in "$e"/*) return 0 ;; esac
    case "$e" in *[*?]*) re="$(us_glob_re "$e")"; [[ "$p" =~ $re ]] && return 0 ;; esac
  done < "$2"
  return 1
}
~~~
5. file: `hooks/scripts/lib/unit-scope.sh`
   anchor: line matching `# us_classify <path> <rev> <listed> <fix-listed> <criteria-text> <fail-text> [<excluded>]:`
   indent: 0
   before:
~~~
# us_classify <path> <rev> <listed> <fix-listed> <criteria-text> <fail-text> [<excluded>]:
# prints exactly one class word: excluded | listed | criteria | fail-record |
# fix-contract | plugin-version | judge | out. Every file argument may be
# /dev/null; <excluded> (the `## Do NOT touch` entries) defaults to it. A
# criteria path counts only when the criteria read it, never when they run it.
us_classify() {
  local p="$1"
  if us_excluded "$p" "${7:-/dev/null}"; then echo excluded
~~~
   after:
~~~
# us_classify <path> <rev> <listed> <fix-listed> <criteria-text> <fail-text> [<excluded>]:
# prints exactly one class word: excluded | listed | criteria | fail-record |
# fix-contract | plugin-version | judge | out. Every file argument may be
# /dev/null; <excluded> (us_exclusions of the contract) defaults to it. A
# criteria path counts only when the criteria read it, never when they run it.
# An unsafe path (us_safe_path) is `out` before any other class is tried.
us_classify() {
  local p="$1"
  if ! us_safe_path "$p"; then echo out
  elif us_excluded "$p" "${7:-/dev/null}"; then echo excluded
~~~
6. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.199 to 0.31.200).
7. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Unit-scope classifier: whole-subject exclusions, segment globs, unsafe paths (rp-u9, VERSION).** hooks/scripts/lib/unit-scope.sh: new `us_exclusions` reads `## Do NOT touch` by bullet; a bullet excludes only when its subject (the text before the first ` (`, `: `, ` - ` or ` — `) is nothing but backticked path tokens joined by commas, `and` or `or`, and a bullet carrying the marker `partial:` never excludes, so a path in a reason or a partial-file qualifier (qw-u2 and qw-u4 named their main file that way) is no longer `excluded`. `us_entries <file> "Do NOT touch"` returns the same list. A contract glob's `*` and `?` match within one path segment; a path that is empty, holds a newline, or has a `.` or `..` segment is never listed and classifies `out`. tests/scope-libs.test.sh gains bullets copied from the contracts of every unit shipped this session.
~~~
   Replace `VERSION` with the version that edit 6 wrote.
8. command: `node bin/cli.js --update`
   expect: 0
9. command: `bash tests/scope-libs.test.sh`
   expect: 0
10. command: `git add -u -- hooks/scripts/lib/unit-scope.sh tests/scope-libs.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md .claude && git commit -m "fix(rp-u9): unit-scope exclusions take a bullet's whole subject; globs stay in one segment; unsafe paths are out"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/scripts/reviewer-tier.sh`, `tests/reviewer-tier.test.sh` and `hooks/scripts/lib/sensitive-paths.sh` (rp-u8's; criterion 6)
- `docs/plans/antislop-structural/contracts/st-u2.md`, `docs/plans/antislop-structural/contracts/st-u3.md` and `docs/plans/antislop-structural/contracts/st-u4.md` (already amended for this grammar; criterion 6)
- `adapters/`, `agents/`, `templates/` and `bin/` (the library is Claude-only; no prose or helper changes; criterion 6)

## Acceptance criteria
1. run: `bash -c 'bash tests/scope-libs.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in `us_glob_re`, replace `[^/]*` with `.*`; case (i) prints `FAIL (i) * crossed a /` and stdout is `1`. Deleting the `us_safe_path "$p" || return 1` line from `us_listed` fails three (i) rows.
2. run: `bash -c 'cmp hooks/scripts/lib/unit-scope.sh .claude/hooks/scripts/lib/unit-scope.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 8 (`--update`); `cmp` reports a difference and the command exits 1.
3. run: `bash -c '. hooks/scripts/lib/unit-scope.sh; for c in qw-u2 qw-u4; do us_exclusions docs/plans/antislop-quick-wins/contracts/$c.md | tr "\n" " "; echo; done'`
   exit: 0
   stdout: `adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md templates/persona-protocol.md CONTEXT.md docs/harness-glossary.md ` then `bin/cli.js adapters/ agents/reviewer.md ` (two lines)
   mutation: make `us_exclusions` print every backticked path token of the section (the st-u1 reading); `agents/orchestrator.md` joins both lines.
4. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u9)" | tail -1); l=$(git log --format=%H --grep="(rp-u9)" | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md hooks/scripts/lib/unit-scope.sh package.json tests/scope-libs.test.sh `
   mutation: also edit `hooks/scripts/reviewer-tier.sh` in an rp-u9 commit; it joins the list.
5. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u9)" | tail -1); l=$(git log --format=%H --grep="(rp-u9)" | head -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:package.json" | grep "\"version\"")" = "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:CHANGELOG.md" | grep -c "(rp-u9, ")" = 1 && echo moved'`
   exit: 0
   stdout: `moved`
   mutation: skip edit 6; the versions are equal, stdout is empty and the exit is 1.
6. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u9)" | tail -1); l=$(git log --format=%H --grep="(rp-u9)" | head -1); git diff --name-only "$b^..$l" -- hooks/scripts/reviewer-tier.sh tests/reviewer-tier.test.sh hooks/scripts/lib/sensitive-paths.sh docs/plans adapters agents templates bin | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `docs/plans/antislop-structural/contracts/st-u2.md` in an rp-u9 commit; stdout is `1`.
7. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/scope-libs.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edit 1 adds cases (g) to (i) and edit 2 shows them red (`10`) before the library edits 3 to 5.
evidence: verified against 0b45bd46. With the st-u1 reading (`us_entries <contract> "Do NOT touch"`), the files qw-u2's and qw-u4's own commits changed classify `excluded` for `agents/orchestrator.md`; with `us_exclusions`, no file changed by any of the 15 shipped units (aof-u1 to aof-u4, aof-u3b, qw-u1 to qw-u6, rp-u1 to rp-u3, st-u1; `.claude/` and `docs/plans/` left out) classifies `excluded`, while whole-file bullets still exclude (qw-u3 and qw-u4 `bin/cli.js`, rp-u3 `bin/ladder-tier.sh`, rp-u1 `tests/validate.sh`). Two token lists outside Do NOT touch are wider than the files edited (aof-u1 and aof-u4 name `bin/ladder-tier.sh` and `CONTEXT.md` in Affected-files prose); those names were not edited, so the overlap is harmless and out of scope here.
grammar: the separators are literal: ` (`, `: ` (colon then space, so `a:b` inside a token is safe), ` - `, ` — ` (em dash). The joiners are `, and `, `, or `, `, `, ` and `, ` or `. A token must hold `/` or `.` and no space or backtick. A bullet mixing a whole file and a partial qualifier (aof-u1's "`hooks/hooks.json`, `templates/settings-fragment.json`, `harness-integrity-gate.sh`'s Set A lists") excludes nothing: authors split such a bullet. Under-excluding is safe (the file is then `listed` or `out` as before); over-excluding was the defect.
partial-marker: ``- `<path>` partial: <which part> (<reason>)``; `partial:` anywhere in the bullet counts, so `(partial: ...)` in the reason works too. Documented in the library header, in the spec (Step 9) and, through rp-s1, in the glossary proposal. A `partial:` bullet is prose for the writer and reviewer only.
glob: `us_glob_re` escapes `] . [ ^ $ \ + ( ) { } |`, then maps `*` to `[^/]*` and `?` to `[^/]`; `**` is two `*`, still one segment (no contract uses it). Directory entries keep their prefix match.
unsafe-path: `us_safe_path` rejects `''`, a newline, `.`, `..`, `./x`, `../x`, `x/.`, `x/..`, `x/./y`, `x/../y`. `us_listed` returns 1 and `us_classify` prints `out` before trying `excluded`. st-u2 already turns a C-quoted name (git quotes a newline even with `core.quotepath=false`) into `scope: out ... unquotable`.
chained: st-u2 and st-u3 (amended 2026-10-21) call `us_exclusions`; st-u4 calls `us_entries` for `## Affected files` only. No queued contract edits `hooks/scripts/lib/unit-scope.sh` or `tests/scope-libs.test.sh`; rp-u8 edits `tests/scope-libs.test.sh` at case (b), above this unit's case (g) anchor. spec-master applied rp-u8, this contract and then every queued contract in dispatch order to a clone at 0b45bd46 with a script that requires each `before:` payload once: all matched, and the amended st-u2 and st-u3 tests pass on top of this library.
blast-radius: hooks/scripts/lib/unit-scope.sh:17-37 and :85-92; tests/scope-libs.test.sh:102-105. Callers after the queue: bin/review-precheck.sh (st-u2), hooks/scripts/writer-scope-gate.sh (st-u3), bin/unit-size.sh (st-u4). Line numbers are at 0b45bd46.
version: .claude-plugin/plugin.json and package.json read 0.31.199 after rp-u8 if no fix round bumped; edit 6 adds one (expected 0.31.200).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(rp-u9): unit-scope exclusions take a bullet's whole subject; globs stay in one segment; unsafe paths are out
diagnosis: none
review-packet:
~~~
unit: rp-u9
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If a `before:` payload is not found verbatim (rp-u8 must have landed and left case (g) as it was), stop and
report the current text. If a case outside (g) to (i) changes result, quote it and stop. If `node bin/cli.js
--update` reports a mirror as diverged, quote it and stop. If a gate blocks a command, report it and wait.
Anything outside "Affected files" goes to your report as a proposal.
