Unit: rfp-u1b

## Objective
Revise the shipped refutation brief, `bin/refutation-brief.sh`, and its installed copy
`.claude/bin/refutation-brief.sh`, after Gate G run 1 failed its turn rule (plan "Revision 3"). The brief
gains a stated tool-call budget: at most 9 tool calls in all, split evenly per defect (9 for one defect, 4 for
two, 3 for three). It says that every call counts, refused calls and parallel calls included. It tells the
explorer to answer UNCERTAIN, naming the open question, once a defect's share is spent. It says what to read
when a whole file would go over the share, and that an answer must not contain a line break. The old line
"Batch independent reads in parallel: you have at most 10 turns." is replaced, and the 10-turn cap is still
stated. Two rfp-u1 PASS notes are closed: a trailing CR on a defect line is dropped, and every exit-2 case
asserts empty stdout.

Why 9: on a run that finishes normally, Claude Code reports `num_turns` as 1 plus one user message per tool
result (plan "Revision 3", diagnosis 1), and Gate G fails any run whose `num_turns` is above 10.

Unchanged: the defect grammar, the cap of 3 (D4), the three questions, the UNCERTAIN and artifact rules, the
answer grammar line, the exit codes and "writes nothing". No persona text changes. `run.sh` (rfp-u2) calls
this checkout's `bin/refutation-brief.sh`, so the next replay (Gate G run 2) measures this brief.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md`, sections "Revision 3: Gate G
run 1 failed" and "Step 1b". This file is the contract of record. Dispatch it after rfp-u2e's review has
returned (one unit is mid-review at a time; rfp-u1b shares no file with rfp-u2e). Before dispatch, the user
answers plan Open Questions 4 and 5, or accepts their defaults; this contract is written to those defaults.

## Affected files
- `bin/refutation-brief.sh` (anchors: line matching `# Refutation brief (rfp-u1): prints the prompt the reviewer gives the`; line matching `Batch independent reads in parallel: you have at most 10 turns.`)
- `tests/refutation-brief.test.sh` (anchors: line matching `# Fixture suite for bin/refutation-brief.sh (rfp-u1). Every case runs in a scratch git repo, never this tree.`; line matching `if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'usage'; then ok "(i) no baseline"; else bad "(i) no baseline rc=$rc"; fi`)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`
- generated only, by `node bin/cli.js --update`: `.claude/bin/refutation-brief.sh`, the `.claude/agents/*.md` stamp lines, `.claude/persona-protocol*.md`, `.claude/protocol-digest.md`, and the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/refutation-brief.test.sh`
   anchor: line matching `# Fixture suite for bin/refutation-brief.sh (rfp-u1). Every case runs in a scratch git repo, never this tree.`
   before:
~~~
# Fixture suite for bin/refutation-brief.sh (rfp-u1). Every case runs in a scratch git repo, never this tree.
~~~
   after:
~~~
# Fixture suite for bin/refutation-brief.sh (rfp-u1; budget cases rfp-u1b). Every case runs in a scratch
# git repo, never this tree.
~~~
2. file: `tests/refutation-brief.test.sh`
   anchor: line matching `  err="$(cat "$tmp/err")"`
   before:
~~~
  err="$(cat "$tmp/err")"
}
~~~
   after:
~~~
  err="$(cat "$tmp/err")"
}
has()  { printf '%s\n' "$out" | grep -qF -- "$1"; }
hasx() { printf '%s\n' "$out" | grep -qx -- "$1"; }
~~~
3. file: `tests/refutation-brief.test.sh`
   anchor: line matching `# (a) two valid defects: exit 0, both D-lines, the baseline sha, the changed file, the rules and the grammar`
   before:
~~~
# (a) two valid defects: exit 0, both D-lines, the baseline sha, the changed file, the rules and the grammar
run $'D1: src/a.sh:2 b is unquoted\n\nD2: src/a.sh:1-2 no guard on empty input\n' "$base"
if [ "$rc" = 0 ] \
   && printf '%s\n' "$out" | grep -qx 'D1: src/a.sh:2 b is unquoted' \
   && printf '%s\n' "$out" | grep -qx 'D2: src/a.sh:1-2 no guard on empty input' \
   && printf '%s\n' "$out" | grep -qx "Baseline: $base" \
   && printf '%s\n' "$out" | grep -qx -- '- src/a.sh' \
   && printf '%s\n' "$out" | grep -qF 'When unsure, answer UNCERTAIN, never CONFIRMED. A verdict with no artifact is UNCERTAIN.' \
   && printf '%s\n' "$out" | grep -qF 'D<n>: REFUTED|CONFIRMED|UNCERTAIN — q1=<yes|no> q2=<change|baseline> q3=<real|mitigated|n/a> — artifact:' \
   && printf '%s\n' "$out" | grep -qF "on why it stops this defect on" ; then
~~~
   after:
~~~
# (a) two valid defects: exit 0, both D-lines, the baseline sha, the changed file, the rules, the grammar
# and a budget of 4 calls per defect
run $'D1: src/a.sh:2 b is unquoted\n\nD2: src/a.sh:1-2 no guard on empty input\n' "$base"
if [ "$rc" = 0 ] \
   && hasx 'D1: src/a.sh:2 b is unquoted' \
   && hasx 'D2: src/a.sh:1-2 no guard on empty input' \
   && hasx "Baseline: $base" \
   && hasx '- src/a.sh' \
   && has 'When unsure, answer UNCERTAIN, never CONFIRMED. A verdict with no artifact is UNCERTAIN.' \
   && has 'D<n>: REFUTED|CONFIRMED|UNCERTAIN — q1=<yes|no> q2=<change|baseline> q3=<real|mitigated|n/a> — artifact:' \
   && has "on why it stops this defect on" \
   && hasx 'Budget: at most 9 tool calls in all, and at most 4 for each defect.' ; then
~~~
4. file: `tests/refutation-brief.test.sh`
   anchor: line matching `if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'malformed'; then ok "(d) malformed"; else bad "(d) malformed rc=$rc"; fi`
   before:
~~~
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'malformed'; then ok "(d) malformed"; else bad "(d) malformed rc=$rc"; fi
~~~
   after:
~~~
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'malformed'; then ok "(d) malformed"; else bad "(d) malformed rc=$rc"; fi
~~~
5. file: `tests/refutation-brief.test.sh`
   anchor: line matching `if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'not a commit'; then ok "(e) bad baseline"; else bad "(e) bad baseline rc=$rc"; fi`
   before:
~~~
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'not a commit'; then ok "(e) bad baseline"; else bad "(e) bad baseline rc=$rc"; fi
~~~
   after:
~~~
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'not a commit'; then ok "(e) bad baseline"; else bad "(e) bad baseline rc=$rc"; fi
~~~
6. file: `tests/refutation-brief.test.sh`
   anchor: line matching `if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'repeated D1'; then ok "(f) repeated id"; else bad "(f) repeated id rc=$rc"; fi`
   before:
~~~
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'repeated D1'; then ok "(f) repeated id"; else bad "(f) repeated id rc=$rc"; fi
~~~
   after:
~~~
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'repeated D1'; then ok "(f) repeated id"; else bad "(f) repeated id rc=$rc"; fi
~~~
7. file: `tests/refutation-brief.test.sh`
   anchor: line matching `if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'over-cap'; then ok "(g) D-number cap"; else bad "(g) D-number cap rc=$rc"; fi`
   before:
~~~
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'over-cap'; then ok "(g) D-number cap"; else bad "(g) D-number cap rc=$rc"; fi
~~~
   after:
~~~
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'over-cap'; then ok "(g) D-number cap"; else bad "(g) D-number cap rc=$rc"; fi
~~~
8. file: `tests/refutation-brief.test.sh`
   anchor: line matching `if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'usage'; then ok "(i) no baseline"; else bad "(i) no baseline rc=$rc"; fi`
   before:
~~~
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'usage'; then ok "(i) no baseline"; else bad "(i) no baseline rc=$rc"; fi
~~~
   after:
~~~
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'usage'; then ok "(i) no baseline"; else bad "(i) no baseline rc=$rc"; fi

# (j) the per-defect share is 9 calls divided by the number of defects: 9 for one, 3 for three
run $'D1: src/a.sh:2 b\n' "$base"; one="$out"
run $'D1: src/a.sh:1 x\nD2: src/a.sh:1 y\nD3: src/a.sh:2 z\n' "$base"
if printf '%s\n' "$one" | grep -qx 'Budget: at most 9 tool calls in all, and at most 9 for each defect.' \
   && hasx 'Budget: at most 9 tool calls in all, and at most 3 for each defect.' \
   && [ "$(printf '%s\n' "$out" | grep -c '^Budget: ')" = 1 ]; then
  ok "(j) budget share per defect count"
else
  bad "(j) budget share per defect count"
fi

# (k) the budget rules: what counts as a call, the 10-turn cap, UNCERTAIN when a share is spent, the
# large-file rule and one line per answer
run $'D1: src/a.sh:2 b\n' "$base"
if has 'including a refused call and each call in a parallel batch' \
   && hasx '10 turns, so batch independent calls into one turn.' \
   && has 'stop work on it and answer UNCERTAIN, naming' \
   && has 'the open question in the artifact. Do not spend another defect' \
   && has 'and say in the artifact which part you read.' \
   && has 'with no line break inside it, then your STATUS line:'; then
  ok "(k) budget rules"
else
  bad "(k) budget rules"
fi

# (l) the old turn note is gone
run $'D1: src/a.sh:2 b\n' "$base"
if [ "$rc" = 0 ] && ! has 'Batch independent reads in parallel'; then ok "(l) old turn note gone"; else bad "(l) old turn note gone"; fi

# (m) a CRLF defect line is accepted and echoed without its CR
run $'D1: src/a.sh:2 b\r\n' "$base"
if [ "$rc" = 0 ] && hasx 'D1: src/a.sh:2 b' && ! printf '%s' "$out" | grep -q $'\r'; then ok "(m) CRLF dropped"; else bad "(m) CRLF dropped rc=$rc"; fi
~~~
   Then run `bash tests/refutation-brief.test.sh`: it must exit 1, printing `FAIL` for cases (a), (j), (k),
   (l) and (m) only. This is the red step.
9. file: `bin/refutation-brief.sh`
   anchor: line matching `# Refutation brief (rfp-u1): prints the prompt the reviewer gives the`
   before:
~~~
# Refutation brief (rfp-u1): prints the prompt the reviewer gives the `explorer` it spawns for the
# refutation pass (agents/reviewer.md, "Refutation pass"). The eval replay
~~~
   after:
~~~
# Refutation brief (rfp-u1; tool-call budget rfp-u1b): prints the prompt the reviewer gives the `explorer`
# it spawns for the refutation pass (agents/reviewer.md, "Refutation pass"). The eval replay
~~~
10. file: `bin/refutation-brief.sh`
    anchor: line matching `# Reads 1 to 3 defect lines on stdin (blank lines ignored), each`
    before:
~~~
# Reads 1 to 3 defect lines on stdin (blank lines ignored), each `D<1-3>: <path>:<line>[-<line>] <claim>`.
# Prints the brief on stdout and exits 0. Writes nothing. Run from the repo root of the reviewed tree.
~~~
    after:
~~~
# Reads 1 to 3 defect lines on stdin (blank lines ignored, a trailing CR dropped), each
# `D<1-3>: <path>:<line>[-<line>] <claim>`.
# Prints the brief on stdout and exits 0. Writes nothing. Run from the repo root of the reviewed tree.
# The brief states a budget of 9 tool calls in all, split evenly per defect (9, 4 or 3), because a
# headless run's num_turns is 1 plus its tool calls and Gate G fails any run above 10.
~~~
11. file: `bin/refutation-brief.sh`
    anchor: line matching `while IFS= read -r line || [ -n "$line" ]; do`
    before:
~~~
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "${line//[[:space:]]/}" ] || continue
~~~
    after:
~~~
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  [ -n "${line//[[:space:]]/}" ] || continue
~~~
12. file: `bin/refutation-brief.sh`
    anchor: line matching `  [[ $d =~ ^D([1-3]): ]] || die "over-cap: D-numbers run 1 to 3"`
    before:
~~~
  [[ $d =~ ^D([1-3]): ]] || die "over-cap: D-numbers run 1 to 3"
done
~~~
    after:
~~~
  [[ $d =~ ^D([1-3]): ]] || die "over-cap: D-numbers run 1 to 3"
done
share=$(( 9 / ${#defects[@]} ))
~~~
13. file: `bin/refutation-brief.sh`
    anchor: line matching `Batch independent reads in parallel: you have at most 10 turns.`
    before:
~~~
Batch independent reads in parallel: you have at most 10 turns.
Reply with exactly one line per defect, in this form, then your STATUS line:
~~~
    after:
~~~
EOF
printf 'Budget: at most 9 tool calls in all, and at most %d for each defect.\n' "$share"
cat <<'EOF'
Every tool call counts, including a refused call and each call in a parallel batch. You also have at most
10 turns, so batch independent calls into one turn.
When a defect's share is spent and a question is still open, stop work on it and answer UNCERTAIN, naming
the open question in the artifact. Do not spend another defect's share.
If reading the whole file would go over the share, read the part around the cited line and the places
grep finds for the cited code, and say in the artifact which part you read.
Reply with exactly one line per defect, in this form, with no line break inside it, then your STATUS line:
~~~
    Keep the file's mode at 755 and its em dashes (U+2014). The answer grammar line that follows is unchanged
    (criterion 7). Run `bash tests/refutation-brief.test.sh`: it must exit 0 now.
14. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
    expect: 0
    Adds one to the patch version in both files (+1 on whatever is current at dispatch). P3 does not require
    it (no `agents/` or `templates/` path is touched). It keeps the CHANGELOG entry versioned, as rfp-u1 did.
15. file: `CHANGELOG.md`
    anchor: line matching `## [Unreleased]`
    indent: 0
    insert-after:
~~~

**Refutation brief tool-call budget (rfp-u1b, VERSION).** `bin/refutation-brief.sh` (installed to `.claude/bin/`) now states a budget of at most 9 tool calls in all, split evenly per defect (9, 4 or 3). It says that every call counts, refused calls and parallel calls included, and that the explorer answers UNCERTAIN, naming the open question, once a defect's share is spent. It also says what to read when a whole file would go over the share, and that an answer must contain no line break. The 10-turn cap is still stated. Reason: Gate G's first replay failed its turn rule, because a finished headless run reports `num_turns` as 1 plus its tool calls. A trailing CR on a defect line is now dropped. The defect grammar, the cap of 3, the questions and the answer grammar are unchanged. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Revision 3").
~~~
    Replace `VERSION` with the version edit 14 wrote.
16. command: `node bin/cli.js --update`
    expect: 0
17. command: `git add bin/refutation-brief.sh tests/refutation-brief.test.sh .claude/bin/refutation-brief.sh .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude ':(exclude).claude/agent-memory' && git commit -m "fix(rfp-u1b): refutation brief states a 9-call tool budget split per defect, UNCERTAIN once a share is spent"`
    expect: 0
    Run `git status --short` first. If a tracked file outside "Affected files" is modified, stop and report it.
    The untracked `eval/refutation-replay/report.jsonl` (Gate G run 1) is the human's: never add, edit or
    delete it. Keep `(rfp-u1b)` in every fix-round commit subject.

## Do NOT touch
- `eval/` in full: `run.sh`, `score.py`, `corpus.jsonl`, `labels.tsv`, `guard.py` and the untracked
  `report.jsonl` (criterion 6; the thresholds and labels are the user's, plan Open Question 4)
- `agents/`, `templates/`, `hooks/` and `adapters/` (criterion 6; no persona text changes in this unit)
- `bin/refutation-brief.sh`'s defect grammar, its cap of 3, the three questions and the answer grammar line
  (criterion 7)
- `.claude/bin/` and `.claude/agents/` by hand (only `node bin/cli.js --update` writes them)

## Acceptance criteria
1. run: `bash -c 'bash tests/refutation-brief.test.sh >/dev/null; echo $?'`
   exit: 0
   stdout: `0`
   mutation: replace `share=$(( 9 / ${#defects[@]} ))` with `share=3` in `bin/refutation-brief.sh`; cases (a) and (j) print `FAIL` and stdout is `1`. Deleting `  line="${line%$'\r'}"` fails case (m). Replacing `stop work on it and answer UNCERTAIN` with `keep working on it` fails case (k). spec-master ran these three mutations on a scratch copy.
2. run: `bash -c 't=$(mktemp -d); git show 5eb84715:bin/refutation-brief.sh > "$t/old.sh"; r=$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1]))" "$t/old.sh"); BRIEF_UNDER_TEST="$r" bash tests/refutation-brief.test.sh | grep -o "^FAIL ([a-z])" | tr -d "FAIL ()" | tr -d "\n"; echo'`
   exit: 0
   stdout: `ajklm`
   mutation: skip edits 3 and 8 (the new assertions); the rfp-u1 script passes every case and stdout is an empty line. spec-master ran the command on today's tree (empty line) and on a scratch tree carrying edits 1 to 8 (`ajklm`).
3. run: `cmp bin/refutation-brief.sh .claude/bin/refutation-brief.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 16 (`--update`); the installed copy is still rfp-u1's, cmp prints `differ` and exits 1.
4. run: `bash -c 'b=$(git rev-parse HEAD~1); for n in 1 2 3; do seq 1 "$n" | sed "s/.*/D&: bin\/cli.js:656 claim &/" | bash .claude/bin/refutation-brief.sh "$b" | sed -n "s/^Budget: at most 9 tool calls in all, and at most \([0-9]*\) for each defect\.$/\1/p"; done | tr -d "\n"; echo'`
   exit: 0
   stdout: `943`
   mutation: replace `share=$(( 9 / ${#defects[@]} ))` with `share=3` before edit 16; stdout is `333`. On today's tree (the rfp-u1 copy) stdout is an empty line; spec-master ran it there and on the scratch payload (`943`).
5. run: `bash -c 'bash tests/refutation-replay.test.sh >/dev/null 2>&1; a=$?; bash tests/refutation-replay-isolation.test.sh >/dev/null 2>&1; echo "$a $?"'`
   exit: 0
   stdout: `0 0`
   mutation: add `exit 2` as the line after `set -uo pipefail` in `bin/refutation-brief.sh`; `run.sh` writes `NONE brief` rows, isolation cases (h), (i), (j), (k), (m) and (q) fail, and stdout is `0 1`. spec-master ran the payload and this mutation in a scratch copy of `eval/refutation-replay` and both suites.
6. run: `bash -c 'cs=$(git log --format=%H --grep="(rfp-u1b)"); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git diff-tree --no-commit-id --name-only -r "$c"; done | sort -u | grep -v -E "^(bin/refutation-brief\.sh|tests/refutation-brief\.test\.sh|\.claude/.*|\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md)$" | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `eval/refutation-replay/score.py` or `agents/reviewer.md` in an `(rfp-u1b)` commit; stdout is at least `1`. With no `(rfp-u1b)` commit it prints `no-commits` and exits 1 (spec-master ran it on today's tree).
7. run: `bash -c 'k() { grep -E "over-cap|^D<n>: REFUTED|^Try to DISPROVE|^\([123]\) |^When unsure, answer UNCERTAIN" "$@"; }; diff <(git show 5eb84715:bin/refutation-brief.sh | k) <(k bin/refutation-brief.sh) >/dev/null && echo same'`
   exit: 0
   stdout: `same`
   mutation: change `at most 3` to `at most 5` in the over-cap message, or edit the answer grammar line; diff finds a difference, stdout is empty and the exit is 1.
8. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of `tests/refutation-brief.test.sh`; validate.sh's existing rfp-u1 block reports it and stdout is `1`.
9. run: `bash -c 'git status --porcelain -- bin tests .claude/bin .claude-plugin package.json CHANGELOG.md | wc -l'`
   exit: 0
   stdout: `0`
   mutation: leave the edit-8 test change uncommitted; stdout is `1`.

## Pre-resolved context
- **Why the budget is 9 calls, not 10 turns.** Gate G run 1 (2026-10-28) failed only on `max-turns=11`.
  Claude Code 2.1.312 counts two things:
  - The `--max-turns` cap counts loop iterations. After a tool round, it sets `gr=tn+1` and stops with
    `error_max_turns` once `gr` passes the cap. That result has no `result` text, so `run.sh` would write
    `NONE` rows.
  - The success result's `num_turns` starts at 1 and adds one for every `user`-type message, and Claude Code
    writes one user message per tool result. spec-master counted 2,388 tool results in four local session
    transcripts, each in its own user message, including 405 API turns that each issued several calls.

  Both 11-turn rows (esc-left-4) carry answers, so that run ended normally after 10 tool calls; it did not hit
  the cap. Batching calls in parallel saves turns, not `num_turns`. So under the rule as written, a run that
  wants `num_turns` ≤ 10 can make at most 9 tool calls.
- **The share.** `9 / n` in bash integer arithmetic: 9, 4, 3. Run 1 used 3 to 10 calls per run. Per defect,
  that was 4.5 for 1-defect groups, 3.5 for 2-defect groups and 2.2 for 3-defect groups, so the share binds
  mainly on 2-defect groups and on long files.
- **Rejected brief changes** (plan "Revision 3", diagnosis 2):
  - A "q1=no, so REFUTED" short-circuit. Cited lines drift between commits, so it would push answers toward
    REFUTED, which is the costly direction.
  - A lower defect cap (D4). The 11-turn group had 2 defects, so a cap of 2 would not have helped.
- **Replay coupling.** `eval/refutation-replay/run.sh:31` uses this checkout's `bin/refutation-brief.sh`, and
  both replay suites call it through `run.sh` with a fake `claude` (criterion 5). No test except
  `tests/refutation-brief.test.sh` pins brief text.
- **Install.** `bin/cli.js:656` lists the helper in `BIN_HELPER_FILES` as a `raw` spec. Content drift alone
  makes `--update` re-render it (`bin/cli.js:1546-1550`). The version bump keeps the CHANGELOG versioned.
- **Registration.** `tests/validate.sh:823` already runs `tests/refutation-brief.test.sh` (rfp-u1), so no
  registration edit is needed.
- **Scratch proof.** spec-master applied edits 1 to 13 to scratch copies:
  - All 13 cases pass and `bash -n` is clean.
  - Against rfp-u1's script (5eb84715), cases (a), (j), (k), (l) and (m) fail.
  - The criterion-1 mutations each turn their case red.
  - With the payload, both replay suites print `0 0`.
  - A 3-defect brief from the real corpus (group abt-u12) is 2,972 bytes, against 2,424 before.
- **Hook constraints.** No criterion names the reviewed-markers directory or the persona config file. No
  criterion uses `rm -rf`, and each scratch directory comes from its own `mktemp -d`.
- **rfp-u1 PASS notes.** Closed here: the empty-stdout asserts (edits 4 to 8) and the CRLF note (edit 11,
  case m). Kept as designed: D10 to D99 report `malformed`, per the `^D([1-9])` grammar.

## Escalation
If a `before:` or anchor text is not found exactly once, stop and report the current text. If
`node bin/cli.js --update` refuses, quote its message and stop. If a gate blocks a command, report it and
wait. Do not run `eval/refutation-replay/run.sh` without `--dry-run`: a real run spends the human's API
budget (Gate G2). Anything outside "Affected files" goes in your report as a proposal.
