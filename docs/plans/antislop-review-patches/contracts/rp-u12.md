Unit: rp-u12

## Objective
Finding F6 from rp-u8's review (294ded81, 0.31.199), in `hooks/scripts/reviewer-tier.sh`. rp-u8 made the
two library sources one guarded group, `{ . state-access.sh && . sensitive-paths.sh; } 2>/dev/null ||
{ echo opus; exit 0; }`, followed by a `declare -F` check of the three functions the script calls. Two
gaps remain:
- the group hides only stderr. A library that prints a word on stdout when sourced puts that line in
  front of the result: with `echo sonnet` appended to `lib/sensitive-paths.sh`, a hooks/ diff printed
  `sonnet` then `opus`, and `bin/unit-bookkeeping.sh review` keeps the first line, so it would read
  `sonnet`;
- nothing tests an empty or cut-short `lib/state-access.sh`. Today the `declare -F` check catches both,
  but narrowing it to `touches_sensitive_path` makes the empty case exit 127 with no output and the
  cut-short case print `sonnet`, and every reviewer-tier case still passes (only the scope-libs (b) grep
  pin notices).
After this unit:
- the guarded group sends both streams to `/dev/null` (`>/dev/null 2>&1`); the `|| { echo opus; exit 0; }`
  after it is outside the group, so its `opus` still prints;
- `tests/reviewer-tier.test.sh` runs, against copies of BOTH the source script and the installed
  `.claude/hooks/scripts/` copy: a `sensitive-paths.sh` that prints `sonnet` when sourced (a hooks/ diff
  must print exactly `opus`, a small diff exactly `sonnet`, one line each), an empty `state-access.sh` and a
  `state-access.sh` cut before `state_unit_marker_exists` (both must print `opus`, exit 0); and checks that
  the installed `state-access.sh` equals its source (`cmp`);
- `tests/scope-libs.test.sh` case (b) pins the new group line.
This is a hook-code change on a sensitive path: safety review applies (spec Step 10).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 10 (rp-u11, rp-u12)"
and "Context, rp-u9 review findings" (F6). This file is the contract of record. Dispatch it right after
rp-u10, before rp-u7 (spec Dispatch section).

## Affected files
- `tests/reviewer-tier.test.sh` (anchor: line matching `exit "$fail"`, the last line)
- `tests/scope-libs.test.sh` (anchor: line matching `grep -qxF '  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } 2>/dev/null || { echo opus; exit 0; }'`)
- `hooks/scripts/reviewer-tier.sh` (anchor: line matching `  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } 2>/dev/null || { echo opus; exit 0; }`)
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
# rp-u12: the guarded source group hides a library's stdout as well as its stderr, so a library that
# prints when sourced cannot put a line in front of the result (unit-bookkeeping.sh keeps the first
# line). An empty or cut-short state-access.sh prints opus through the declare -F check; narrowing that
# check to touches_sensitive_path makes the empty case exit 127 and the cut-short case print sonnet.
for rt_dir in hooks/scripts .claude/hooks/scripts; do
  LF="$tmproot/libout"; rm -rf "$LF"; mkdir -p "$LF/lib"
  cp "$rt_dir/reviewer-tier.sh" "$LF/rt.sh" && cp "$rt_dir"/lib/*.sh "$LF/lib/"
  SA="$LF/lib/state-access.sh"; cp "$SA" "$tmproot/libout.sa"
  echo 'echo sonnet' >> "$LF/lib/sensitive-paths.sh"
  run_case "(rp12a) $rt_dir: lib prints sonnet when sourced, hooks/ diff" opus unit-1 "$r_hooks" "$LF/rt.sh"
  run_case "(rp12a) $rt_dir: lib prints sonnet when sourced, small diff" sonnet unit-1 "$r_small" "$LF/rt.sh"
  cp "$rt_dir/lib/sensitive-paths.sh" "$LF/lib/sensitive-paths.sh"
  : > "$SA"
  run_case "(rp12b) $rt_dir: state-access.sh empty, small diff" opus unit-1 "$r_small" "$LF/rt.sh"
  sed '/^state_unit_marker_exists() {$/,$d' "$tmproot/libout.sa" > "$SA"
  run_case "(rp12c) $rt_dir: state-access.sh cut before state_unit_marker_exists, small diff" opus unit-1 "$r_small" "$LF/rt.sh"
done
cmp -s hooks/scripts/lib/state-access.sh .claude/hooks/scripts/lib/state-access.sh \
  && echo "OK   (rp12d) installed state-access.sh equals the source" \
  || { echo "FAIL (rp12d) installed state-access.sh differs from its source (run node bin/cli.js --update)"; fail=1; }

exit "$fail"
~~~
2. file: `tests/scope-libs.test.sh`
   anchor: line matching `grep -qxF '  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } 2>/dev/null || { echo opus; exit 0; }'`
   indent: 0
   before:
~~~
grep -qxF '  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } 2>/dev/null || { echo opus; exit 0; }' "$ROOT/hooks/scripts/reviewer-tier.sh" && ok "(b) reviewer-tier.sh sources the lib, opus when it cannot" || bad "(b) source line missing"
~~~
   after:
~~~
grep -qxF '  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } >/dev/null 2>&1 || { echo opus; exit 0; }' "$ROOT/hooks/scripts/reviewer-tier.sh" && ok "(b) reviewer-tier.sh sources the lib with both streams hidden, opus when it cannot" || bad "(b) source line missing"
~~~
3. command: `bash -c 'bash tests/reviewer-tier.test.sh | grep -c "^FAIL"; bash tests/scope-libs.test.sh | grep -c "^FAIL"'`
   expect: 0
   The red step: it prints `4` then `1` (reviewer-tier: the two rp12a cases for each of the two copies,
   while rp12b, rp12c and rp12d pass, since the `declare -F` check already catches them; scope-libs: the
   (b) source-line row).
4. file: `hooks/scripts/reviewer-tier.sh`
   anchor: line matching `  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } 2>/dev/null || { echo opus; exit 0; }`
   indent: 0
   before:
~~~
# only "false" under `set -e`, so a sourced-but-empty lib would print sonnet.
{ . "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh" \
  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } 2>/dev/null || { echo opus; exit 0; }
~~~
   after:
~~~
# only "false" under `set -e`, so a sourced-but-empty lib would print sonnet.
# Both streams of the group are hidden: a library that prints when sourced would
# otherwise put a line in front of the result, and callers read the first line.
{ . "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh" \
  && . "$(dirname "${BASH_SOURCE[0]}")/lib/sensitive-paths.sh"; } >/dev/null 2>&1 || { echo opus; exit 0; }
~~~
5. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.206 to 0.31.207).
6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Reviewer tier hides a library's output when sourcing it (rp-u12, VERSION).** hooks/scripts/reviewer-tier.sh sourced `lib/state-access.sh` and `lib/sensitive-paths.sh` in a group that hid only stderr, so a library that printed a word when sourced put an extra line before the result (a hooks/ diff printed `sonnet` then `opus`, and callers read the first line). The group now sends both streams to /dev/null; its `opus` fallback is outside the group and still prints. tests/reviewer-tier.test.sh covers a library that prints when sourced, and an empty and a cut-short state-access.sh, for the source and the installed copy; tests/scope-libs.test.sh pins the new line.
~~~
   Replace `VERSION` with the version that edit 5 wrote.
7. command: `node bin/cli.js --update`
   expect: 0
8. command: `bash -c 'bash tests/reviewer-tier.test.sh >/dev/null && bash tests/scope-libs.test.sh >/dev/null'`
   expect: 0
9. command: `git add -u -- hooks/scripts/reviewer-tier.sh tests/reviewer-tier.test.sh tests/scope-libs.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md .claude && git commit -m "fix(rp-u12): reviewer tier hides a library's stdout when sourcing it"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/scripts/lib/sensitive-paths.sh` and `hooks/scripts/lib/state-access.sh` (the libraries are correct; the caller hides what they print; criterion 7)
- `hooks/scripts/lib/unit-scope.sh` (rp-u11's; criterion 7)
- `bin/review-precheck.sh` and `.claude/bin/review-precheck.sh` (st-u2's; its own stdout guard is not this unit's, per the operator's ruling on Open Question 7; criterion 7)
- `bin/unit-bookkeeping.sh` (it keeps the first line; this unit makes that line the only one; criterion 7)
- `adapters/`, `agents/` and `templates/` (reviewer-tier.sh is Claude-only and its contract prose is unchanged; criterion 7)
- `.claude/hooks/` by hand (only `node bin/cli.js --update` writes it)

## Acceptance criteria
1. run: `bash -c 'bash tests/reviewer-tier.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: change `} >/dev/null 2>&1 ||` back to `} 2>/dev/null ||` in hooks/scripts/reviewer-tier.sh; the two source-copy rp12a cases print two lines (`sonnet` then `opus`, `sonnet` then `sonnet`), rp8g reports the copies differ, and stdout is `1`.
2. run: `bash -c 'bash tests/reviewer-tier.test.sh 2>/dev/null | grep -c "^OK   (rp12[bc]) "'`
   exit: 0
   stdout: `4`
   mutation: narrow the `declare -F` line of hooks/scripts/reviewer-tier.sh to `declare -F touches_sensitive_path >/dev/null || { echo opus; exit 0; }`; the source-copy rp12b case gets no output (rc=127) and the source-copy rp12c case prints `sonnet`, so stdout is `2` and the exit is 0.
3. run: `bash -c 'bash tests/scope-libs.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: change `} >/dev/null 2>&1 ||` back to `} 2>/dev/null ||`; case (b) prints `FAIL (b) source line missing` and stdout is `1`.
4. run: `bash -c 'cmp hooks/scripts/reviewer-tier.sh .claude/hooks/scripts/reviewer-tier.sh && cmp hooks/scripts/lib/state-access.sh .claude/hooks/scripts/lib/state-access.sh && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 7 (`--update`); the first `cmp` reports a difference and the command exits 1.
5. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u12): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u12): " | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md hooks/scripts/reviewer-tier.sh package.json tests/reviewer-tier.test.sh tests/scope-libs.test.sh `
   mutation: also edit `hooks/scripts/lib/sensitive-paths.sh` in an rp-u12 commit; it joins the list.
6. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u12): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u12): " | head -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:package.json" | grep "\"version\"")" = "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:CHANGELOG.md" | grep -c "(rp-u12, ")" = 1 && echo moved'`
   exit: 0
   stdout: `moved`
   mutation: skip edit 5; the versions are equal, stdout is empty and the exit is 1.
7. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u12): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u12): " | head -1); git diff --name-only "$b^..$l" -- hooks/scripts/lib bin .claude/bin adapters agents templates | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `hooks/scripts/lib/state-access.sh` in an rp-u12 commit; stdout is `1`.
8. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/reviewer-tier.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edits 1 and 2 add the cases and edit 3 shows them red (`4` and `1`) before the fix (edit 4).
evidence: verified 2026-10-21 against 00b2a860 (0.31.201) on a scratch clone: with `echo sonnet` appended to a copy's `lib/sensitive-paths.sh`, the copy printed `sonnet` then `opus` for a hooks/ diff and `sonnet` twice for a small diff; with an empty `state-access.sh` it printed `opus` (the `declare -F` check), and with that check narrowed to `touches_sensitive_path` it printed nothing, rc 127; cut before `state_unit_marker_exists`, it printed `opus`, and with the narrowed check `sonnet`. After edit 4 the printing library gives `opus` and `sonnet`, one line each.
why-outside: `{ ...; } >/dev/null 2>&1 || { echo opus; exit 0; }` applies the redirection to the group only; the right side of `||` is a separate command, so the fallback `opus` reaches stdout. The `declare -F` line already sends its own stdout to /dev/null.
installed-copy: the test copies `reviewer-tier.sh` and every `lib/*.sh` from `hooks/scripts/` and from `.claude/hooks/scripts/` into a temp directory, as rp-u8's loop does; rp8g already compares the installed `reviewer-tier.sh` and `sensitive-paths.sh` with their sources, and rp12d adds `state-access.sh`. rp8g fails until edit 7 (`--update`) refreshes the installed script.
callers: `bin/unit-bookkeeping.sh review` keeps `head -n1` of the output and treats any word but `sonnet` as opus; a stray first line `sonnet` is the one input it cannot correct. agents/orchestrator.md "Per-unit model routing" reads the same output.
precheck: `bin/review-precheck.sh` (st-u2) sources its libraries with stderr hidden only. Per the operator (Open Question 7, ruled 2026-10-21) its stdout guard is not added here; it can ride on a later unit that already edits that script, if cheap. st-u2-fix1 is in flight on that script.
chained: no queued contract (st-u2-fix1, rp-u11, st-u3, st-u4, rp-u10, rp-u7, rp-u4 to rp-u6) edits `hooks/scripts/reviewer-tier.sh` or `tests/reviewer-tier.test.sh`; rp-u11 edits `tests/scope-libs.test.sh` only at its last line (case (j)), not at case (b). spec-master applied the queued contracts in dispatch order with this one after rp-u10 to a clone, with a script that requires each `before:` payload once: see the spec's Dispatch section for the result.
blast-radius: hooks/scripts/reviewer-tier.sh:20-22; tests/scope-libs.test.sh:26; tests/reviewer-tier.test.sh last line. Callers: bin/unit-bookkeeping.sh `review_cmd` (`UB_REVIEWER_TIER` default `$dir/../hooks/scripts/reviewer-tier.sh`), agents/orchestrator.md "Per-unit model routing". Line numbers are at 00b2a860.
version: .claude-plugin/plugin.json and package.json read 0.31.206 after rp-u10 if no fix round bumped; edit 5 adds one (expected 0.31.207). The bump is relative, so a different starting version is fine.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
safety-review: reviewer-tier.sh is on the sensitive-path class; the reviewer reads it in full.
commit-message: fix(rp-u12): reviewer tier hides a library's stdout when sourcing it
diagnosis: none
review-packet:
~~~
unit: rp-u12
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
If a `before:` payload is not found verbatim, stop and report the current text. If a test case other than
the rp12 ones (and rp8g before edit 7) changes result, quote it and stop. If `node bin/cli.js --update`
reports a mirror as diverged, quote it and stop. If a gate blocks a command, report it and wait. Anything
outside "Affected files" goes to your report as a proposal.
