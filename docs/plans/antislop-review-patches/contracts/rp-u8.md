Unit: rp-u8

## Objective
Finding S1 from st-u1's review (safety: the reviewer tier fails open). After st-u1,
`hooks/scripts/reviewer-tier.sh` sources `lib/sensitive-paths.sh`. When that library exists but is empty, or
is cut short before `touches_sensitive_path` is defined, the script prints `sonnet` with exit 0 for a diff
that touches `hooks/` (its parent commit printed `opus`): inside an `if`, a command that is not found only
counts as false under `set -e`. When a library is missing or unreadable the script prints nothing and exits
1, although its header promises `sonnet` or `opus` with exit 0. After this unit:
- sourcing `lib/state-access.sh` and `lib/sensitive-paths.sh` is one guarded step: if either fails, the
  script prints `opus` and exits 0;
- a `declare -F touches_sensitive_path unit_id_sanitize state_unit_marker_exists` check right after it
  prints `opus` and exits 0 when any of the three functions is undefined (empty or cut-short library);
- `tests/reviewer-tier.test.sh` runs a missing, empty, cut-short (before the function, and inside the
  array) and unreadable `sensitive-paths.sh`, and a missing `state-access.sh`, against copies of BOTH the
  source script and the installed `.claude/hooks/scripts/` copy, and checks that the installed script and
  library equal their sources (`cmp`);
- `tests/scope-libs.test.sh` case (b) pins the guarded source line and the `declare -F` line.
This is a hook-code change on a sensitive path: safety review applies (spec Step 9).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 9 (rp-u8 to rp-u10)"
and "Context, st-u1 review findings". This file is the contract of record. Dispatch it first, right after
st-u1 (0b45bd46), before st-u2; no queued contract edits these files.

## Affected files
- `tests/reviewer-tier.test.sh` (anchor: line matching `exit "$fail"`, the last line)
- `tests/scope-libs.test.sh` (anchor: line matching `grep -qxF '. "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"'`)
- `hooks/scripts/reviewer-tier.sh` (anchor: line matching `. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/hooks/scripts/reviewer-tier.sh`,
  `.claude/agents/*.md`, `.claude/persona-protocol*.md` and `.claude/protocol-digest.md` (version stamps
  only), the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/reviewer-tier.test.sh`
   anchor: line matching `exit "$fail"` (the last line)
   indent: 0
   before: `exit "$fail"`
   after:
~~~
# rp-u8: a library that is missing, unreadable, empty or truncated prints opus, exit 0, for both the
# source script and its installed copy. Before rp-u8 an empty or truncated lib printed sonnet for a
# hooks/ diff (an undefined function is only false inside `if`) and a missing one exited 1.
for rt_dir in hooks/scripts .claude/hooks/scripts; do
  LF="$tmproot/libfail"; rm -rf "$LF"; mkdir -p "$LF/lib"
  cp "$rt_dir/reviewer-tier.sh" "$LF/rt.sh" && cp "$rt_dir"/lib/*.sh "$LF/lib/"
  LIB="$LF/lib/sensitive-paths.sh"; cp "$LIB" "$tmproot/libfail.orig"
  run_case "(rp8a) $rt_dir: intact lib, small diff" sonnet unit-1 "$r_small" "$LF/rt.sh"
  rm -f "$LIB"
  run_case "(rp8b) $rt_dir: lib missing, hooks/ diff" opus unit-1 "$r_hooks" "$LF/rt.sh"
  run_case "(rp8b) $rt_dir: lib missing, small diff" opus unit-1 "$r_small" "$LF/rt.sh"
  : > "$LIB"
  run_case "(rp8c) $rt_dir: lib empty, hooks/ diff" opus unit-1 "$r_hooks" "$LF/rt.sh"
  run_case "(rp8c) $rt_dir: lib empty, small diff" opus unit-1 "$r_small" "$LF/rt.sh"
  sed '/^touches_sensitive_path() {$/,$d' "$tmproot/libfail.orig" > "$LIB"
  run_case "(rp8d) $rt_dir: lib cut before the function, hooks/ diff" opus unit-1 "$r_hooks" "$LF/rt.sh"
  head -n 12 "$tmproot/libfail.orig" > "$LIB"
  run_case "(rp8d) $rt_dir: lib cut inside the array, small diff" opus unit-1 "$r_small" "$LF/rt.sh"
  cp "$tmproot/libfail.orig" "$LIB" && chmod 000 "$LIB"
  if [ -r "$LIB" ]; then
    echo "OK   (rp8e) $rt_dir: skipped, chmod 000 does not hide a file from this user (root)"
  else
    run_case "(rp8e) $rt_dir: lib unreadable, small diff" opus unit-1 "$r_small" "$LF/rt.sh"
  fi
  chmod 644 "$LIB" && rm -f "$LF/lib/state-access.sh"
  run_case "(rp8f) $rt_dir: state-access.sh missing, small diff" opus unit-1 "$r_small" "$LF/rt.sh"
done
cmp -s hooks/scripts/reviewer-tier.sh .claude/hooks/scripts/reviewer-tier.sh \
  && cmp -s hooks/scripts/lib/sensitive-paths.sh .claude/hooks/scripts/lib/sensitive-paths.sh \
  && echo "OK   (rp8g) installed reviewer-tier.sh and sensitive-paths.sh equal the source" \
  || { echo "FAIL (rp8g) an installed copy differs from its source (run node bin/cli.js --update)"; fail=1; }

exit "$fail"
~~~
2. file: `tests/scope-libs.test.sh`
   anchor: line matching `grep -qxF '. "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"'`
   indent: 0
   before:
~~~
grep -qxF '. "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"' "$ROOT/hooks/scripts/reviewer-tier.sh" && ok "(b) reviewer-tier.sh sources the lib" || bad "(b) source line missing"
~~~
   after:
~~~
grep -qxF '  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } 2>/dev/null || { echo opus; exit 0; }' "$ROOT/hooks/scripts/reviewer-tier.sh" && ok "(b) reviewer-tier.sh sources the lib, opus when it cannot" || bad "(b) source line missing"
grep -qxF 'declare -F touches_sensitive_path unit_id_sanitize state_unit_marker_exists >/dev/null || { echo opus; exit 0; }' "$ROOT/hooks/scripts/reviewer-tier.sh" && ok "(b) reviewer-tier.sh checks the functions are defined" || bad "(b) declare -F guard missing"
~~~
3. command: `bash -c 'bash tests/reviewer-tier.test.sh | grep -c "^FAIL"; bash tests/scope-libs.test.sh | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `16` then `2` (reviewer-tier: the eight rp8b to rp8f cases for each of the two
   copies, while rp8a and rp8g pass; scope-libs: the two (b) rows).
4. file: `hooks/scripts/reviewer-tier.sh`
   anchor: line matching `. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"`
   indent: 0
   before:
~~~
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"
~~~
   after:
~~~
set -euo pipefail
# A library that is missing, unreadable, empty or truncated leaves the FAIL-record
# check or the sensitive-path class unmeasurable, so it fails closed like every
# other unmeasurable input: opus, exit 0. Inside `if`, an undefined function is
# only "false" under `set -e`, so a sourced-but-empty lib would print sonnet.
{ . "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh" \
  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } 2>/dev/null || { echo opus; exit 0; }
declare -F touches_sensitive_path unit_id_sanitize state_unit_marker_exists >/dev/null || { echo opus; exit 0; }
~~~
5. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.198 to 0.31.199).
6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Reviewer tier fails closed on a broken library (rp-u8, VERSION).** hooks/scripts/reviewer-tier.sh printed `sonnet` for a hooks/ diff when `lib/sensitive-paths.sh` was empty or cut before `touches_sensitive_path` (an undefined function is only false inside `if` under `set -e`), and exited 1 with no output when a library was missing or unreadable. It now prints `opus`, exit 0, when sourcing `lib/state-access.sh` or `lib/sensitive-paths.sh` fails or leaves `touches_sensitive_path`, `unit_id_sanitize` or `state_unit_marker_exists` undefined. tests/reviewer-tier.test.sh covers a missing, empty, truncated and unreadable library for the source and the installed copy; tests/scope-libs.test.sh pins the guard.
~~~
   Replace `VERSION` with the version that edit 5 wrote.
7. command: `node bin/cli.js --update`
   expect: 0
8. command: `bash -c 'bash tests/reviewer-tier.test.sh >/dev/null && bash tests/scope-libs.test.sh >/dev/null'`
   expect: 0
9. command: `git add -u -- hooks/scripts/reviewer-tier.sh tests/reviewer-tier.test.sh tests/scope-libs.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md .claude && git commit -m "fix(rp-u8): reviewer tier prints opus when a library is missing, empty, truncated or unreadable"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/scripts/lib/sensitive-paths.sh` and `hooks/scripts/lib/state-access.sh` (the libraries are correct; the caller fails closed; criterion 6)
- `hooks/scripts/lib/unit-scope.sh` (rp-u9's; criterion 6)
- `adapters/`, `agents/` and `templates/` (reviewer-tier.sh is Claude-only and its contract prose is unchanged; criterion 6)
- `bin/unit-bookkeeping.sh` (it already treats any word but `sonnet` as opus; criterion 6)

## Acceptance criteria
1. run: `bash -c 'bash tests/reviewer-tier.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the `declare -F touches_sensitive_path ...` line from hooks/scripts/reviewer-tier.sh; the two source-copy rp8c cases and the first rp8d case print `sonnet`, rp8g reports the copies differ, and stdout is `1`.
2. run: `bash -c 'bash tests/scope-libs.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the same `declare -F` line; case (b) prints `FAIL (b) declare -F guard missing` and stdout is `1`.
3. run: `bash -c 'cmp hooks/scripts/reviewer-tier.sh .claude/hooks/scripts/reviewer-tier.sh && cmp hooks/scripts/lib/sensitive-paths.sh .claude/hooks/scripts/lib/sensitive-paths.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 7 (`--update`); the first `cmp` reports a difference and the command exits 1.
4. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u8)" | tail -1); l=$(git log --format=%H --grep="(rp-u8)" | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md hooks/scripts/reviewer-tier.sh package.json tests/reviewer-tier.test.sh tests/scope-libs.test.sh `
   mutation: also edit `hooks/scripts/lib/sensitive-paths.sh` in an rp-u8 commit; it joins the list.
5. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u8)" | tail -1); l=$(git log --format=%H --grep="(rp-u8)" | head -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:package.json" | grep "\"version\"")" = "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:CHANGELOG.md" | grep -c "(rp-u8, ")" = 1 && echo moved'`
   exit: 0
   stdout: `moved`
   mutation: skip edit 5; the versions are equal, stdout is empty and the exit is 1.
6. run: `bash -c 'b=$(git log --format=%H --grep="(rp-u8)" | tail -1); l=$(git log --format=%H --grep="(rp-u8)" | head -1); git diff --name-only "$b^..$l" -- hooks/scripts/lib adapters agents templates bin | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `hooks/scripts/lib/state-access.sh` in an rp-u8 commit; stdout is `1`.
7. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/reviewer-tier.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edits 1 and 2 add the cases and edit 3 shows them red (`16` and `2`) before the fix (edit 4).
evidence: verified against 0b45bd46 on a scratch copy: with `lib/sensitive-paths.sh` emptied, `reviewer-tier.sh unit-1 <a range touching only hooks/scripts/probe.sh>` printed `sonnet`, exit 0; with the library removed it printed nothing, exit 1; with it cut inside the array (a syntax error) it exited 2. After edit 4 every case prints `opus`, exit 0.
why-group: `{ . a && . b; } 2>/dev/null || { echo opus; exit 0; }` keeps errexit from killing the script on a failed source (commands left of `||` are exempt) and hides the shell's own error text; the `declare -F` line then catches a library that sourced cleanly but defines nothing. `opus()` is defined later in the file, so the guard prints inline.
unreadable: `chmod 000` does not hide a file from root; the rp8e case then prints an OK skip line instead of a result (CI and this machine run as a normal user).
installed-copy: the test copies `reviewer-tier.sh` and every `lib/*.sh` from `hooks/scripts/` and from `.claude/hooks/scripts/` into a temp directory, so each copy is exercised with a broken library beside it; rp8g fails until edit 7 (`--update`) refreshes the installed copy.
callers: `bin/unit-bookkeeping.sh review` already forces opus on a non-zero exit or any word but `sonnet` (rp-u3), so the old exit 1 was not unsafe for it; the header's promise is what this unit restores.
chained: no queued contract (st-u2 to st-u4, rp-u9, rp-u10, rp-u7, rp-u4 to rp-u6) edits `hooks/scripts/reviewer-tier.sh` or `tests/reviewer-tier.test.sh`; rp-u9 edits `tests/scope-libs.test.sh` at case (g) and after it, not at case (b). spec-master applied this contract to a clone at 0b45bd46 and then every queued contract in dispatch order with a script that requires each `before:` payload once: all matched.
blast-radius: hooks/scripts/reviewer-tier.sh:16-18; tests/scope-libs.test.sh:26; tests/reviewer-tier.test.sh:351 (last line). Callers: bin/unit-bookkeeping.sh `review_cmd` (`UB_REVIEWER_TIER` default `$dir/../hooks/scripts/reviewer-tier.sh`), agents/orchestrator.md "Per-unit model routing". Line numbers are at 0b45bd46.
version: .claude-plugin/plugin.json and package.json read 0.31.198 at 0b45bd46; edit 5 adds one (expected 0.31.199).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
safety-review: reviewer-tier.sh is on the sensitive-path class; the reviewer reads it in full.
commit-message: fix(rp-u8): reviewer tier prints opus when a library is missing, empty, truncated or unreadable
diagnosis: none
review-packet:
~~~
unit: rp-u8
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
If a `before:` payload is not found verbatim, stop and report the current text. If a test case other than
the rp8 ones changes result, quote it and stop. If `node bin/cli.js --update` reports a mirror as diverged,
quote it and stop. If a gate blocks a command, report it and wait. Anything outside "Affected files" goes to
your report as a proposal.
