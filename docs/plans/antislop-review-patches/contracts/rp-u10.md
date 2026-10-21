Unit: rp-u10

## Objective
Finding S4 (a) to (c) from the reviews of qw-u6, rp-u3 and rp-u2, grouped as one unit (three small fixes in
different files, safest first). After this unit:
- (a) qw-u6: `applyOrchestratorModel` in `bin/cli.js` prints its "not one of" note with
  `JSON.stringify(value)`. Today the template literal converts the raw value, so a config value such as
  `{"toString": "x"}` throws `Cannot convert object to primitive value` and crashes the render. A string
  value prints exactly as before (`"gpt-x"`).
- (b) rp-u3: when the ladder helper exits non-zero, `bin/unit-bookkeeping.sh dispatch` appends
  `RULING ... decision=helper failed rc=<n>: <tier>` and returns, skipping the guard-demotion and
  no-contract branches. Today it prints `model: opus` but still runs the contract guard and appends a
  `contract-guard sonnet` RULING for a demotion that never happened, and writes no ruling for the opus
  force (unlike the helper-missing path, which writes `helper missing: <path>: opus`).
- (c) rp-u2: `hooks/scripts/stop-gate.sh`'s header step 0 and its loop-guard comment, and the rp-u2
  CHANGELOG entry, say a loop-guarded reviewer stop "never blocks". The microworld surfacing block in
  `lib/stop-gate-core.sh` runs before the reviewer branch and can still exit 2 once (until its watermark
  advances), so the wording becomes "never blocks on the review-join or the marker-commit-check"; under the
  guard `markerCommitCheck.mode: block` is one-shot (the unguarded stop blocks, the guarded stop that
  follows logs, consumes and clears). `tests/review-join.test.sh` gains two pins whose teeth are mutations
  that every test passes today: removing the commit-check suppression under the guard, and replacing the
  entry script's reviewer-identity condition with `if true` (a gated agent's guarded stop on a dirty tree
  with a failing `testAndLintCommand`).
The four `stop-gate-core.sh` copies are not edited and stay equal; `.claude/hooks/scripts/stop-gate.sh` and
`.claude/bin/unit-bookkeeping.sh` change only through `node bin/cli.js --update`. This is spec Step 9.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/antislop-review-patches/spec.md`, "Step 9 (rp-u8 to rp-u10)"
and "Context, st-u1 review findings". This file is the contract of record. Dispatch it after st-u4 and before
rp-u7.

## Affected files
- `tests/orchestrator-model.test.js` (anchor: line matching `if (failures > 0) {`)
- `tests/unit-bookkeeping.test.sh` (anchor: line matching `exit "$fail"`, the last line)
- `tests/review-join.test.sh` (anchor: line matching `exit "$fail"`, the last line)
- `bin/cli.js` (anchor: line matching `orchestratorModel "${value}" is not one of`)
- `bin/unit-bookkeeping.sh` (anchor: line matching `  echo "model: $tier"`)
- `hooks/scripts/stop-gate.sh` (anchors: line matching `#  0) stop_hook_active guard - never re-trigger ourselves in a loop.`; line matching `# Loop guard (rp-u2). The stop that follows a block carries stop_hook_active. For this project's`)
- `CHANGELOG.md` (anchors: line matching `(rp-u2, 0.31.195)`; line matching `## [Unreleased]`)
- `.claude-plugin/plugin.json`, `package.json`
- generated only, by `node bin/cli.js --update`: `.claude/hooks/scripts/stop-gate.sh`,
  `.claude/bin/unit-bookkeeping.sh`, `.claude/agents/*.md`, `.claude/persona-protocol*.md` and
  `.claude/protocol-digest.md` (version stamps only), the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/orchestrator-model.test.js`
   anchor: line matching `if (failures > 0) {`
   indent: 0
   before:
~~~
if (failures > 0) {
  console.log(`${failures} orchestrator-model check(s) FAILED.`);
~~~
   after:
~~~
check('(j) a non-string value warns without throwing and keeps the shipped model (rp-u10)', () => {
  const warn = console.warn;
  const seen = [];
  console.warn = (m) => seen.push(String(m));
  try {
    assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: { toString: 'x' } }), SRC);
    assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: 7 }), SRC);
    assert.strictEqual(cli.applyOrchestratorModel(SRC, 'orchestrator', { orchestratorModel: 'gpt-x' }), SRC);
  } finally {
    console.warn = warn;
  }
  assert.deepStrictEqual(seen.map((m) => m.split(' is not one of')[0]), [
    'Note: persona-config.json orchestratorModel {"toString":"x"}',
    'Note: persona-config.json orchestratorModel 7',
    'Note: persona-config.json orchestratorModel "gpt-x"',
  ]);
});

if (failures > 0) {
  console.log(`${failures} orchestrator-model check(s) FAILED.`);
~~~
2. file: `tests/unit-bookkeeping.test.sh`
   anchor: line matching `exit "$fail"` (the last line)
   indent: 0
   before: `exit "$fail"`
   after:
~~~
# rp-u10: a non-zero ladder exit records `helper failed rc=<n>: <tier>` and runs neither the guard
# demotion nor the no-contract ruling.
printf '#!/usr/bin/env bash\necho "ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=guard-demotion"\nexit 4\n' > "$T/stub/ladderdem"
stub guard 'contract-guard: sonnet score=5/7'
out="$(UB_LADDER="$T/stub/ladderdem" UB_GUARD="$T/stub/guard" bash "$UB" dispatch u15 --contract c.md)"
printf '%s\n' "$out" | grep -qx 'model: opus' && ok "(r) failed helper -> opus" || bad "(r) failed helper -> opus: $out"
printf '%s\n' "$out" | grep -q '^guard:' && bad "(r) guard ran for a failed helper" || ok "(r) no guard line"
grep -qF 'unit=u15 decision=contract-guard' "$LOG" && bad "(r) demotion ruling for a failed helper" || ok "(r) no demotion ruling"
tail -n1 "$LOG" | grep -qE "^RULING $TS unit=u15 decision=helper failed rc=4: opus\$" && ok "(r) helper-failed ruling" || bad "(r) helper-failed ruling: $(tail -n1 "$LOG")"
printf '#!/usr/bin/env bash\necho "ladder-tier: sonnet n=0 ladder=haiku,sonnet,opus reason=no-contract"\nexit 5\n' > "$T/stub/laddernc"
UB_LADDER="$T/stub/laddernc" bash "$UB" dispatch u16 >/dev/null
tail -n1 "$LOG" | grep -qE "^RULING $TS unit=u16 decision=helper failed rc=5: opus\$" && ok "(r) no-contract ruling skipped for a failed helper" || bad "(r) no-contract: $(tail -n1 "$LOG")"

exit "$fail"
~~~
3. file: `tests/review-join.test.sh`
   anchor: line matching `exit "$fail"` (the last line)
   indent: 0
   before: `exit "$fail"`
   after:
~~~
# rp-u10: under the loop guard `markerCommitCheck.mode: block` is one-shot: the unguarded reviewer stop
# blocks on the mismatch, the guarded stop that follows logs it again, consumes the stamp and clears the flag.
dir="$(mcc_repo loop-guard)"
mcc_seed_mismatch "$dir" loop-guard block
rc1=0; lg_stop "$dir" reviewer false || rc1=$?
rc2=0; lg_stop "$dir" reviewer true || rc2=$?
if [ "$rc1" = 2 ] && [ "$rc2" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-mcc" ] \
   && [ ! -e "$dir/.claude/.review-join.own-loop-guard" ] \
   && [ "$(grep -c 'marker-commit-check=mismatch unit=own-loop-guard' "$dir/.claude/review-audit.log")" = 2 ]; then
  echo "OK   (loop-guard-mcc-block-once) mode block blocks the first reviewer stop only; the guarded stop consumes"
else
  echo "FAIL (loop-guard-mcc-block-once) expected rc1=2, rc2=0, flag and stamp gone, two mismatch lines (rc1=$rc1 rc2=$rc2)"
  fail=1
fi

# rp-u10: the guard is the reviewer's only. A gated agent's stop_hook_active stop on a dirty tree whose
# testAndLintCommand fails allows at once; the same stop without the guard blocks (the control).
dir="$tmproot/loop-guard-gated-dirty"
mkdir -p "$dir/.claude/reviewed"
git -C "$dir" init -q
printf 'a\n' > "$dir/a.txt"
git -C "$dir" add a.txt
git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m base
printf 'b\n' > "$dir/a.txt"
printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"false"}\n' > "$dir/.claude/persona-config.json"
rc1=0; lg_stop "$dir" lead-programmer false || rc1=$?
rc2=0; lg_stop "$dir" lead-programmer true || rc2=$?
if [ "$rc1" = 2 ] && [ "$rc2" = 0 ]; then
  echo "OK   (loop-guard-gated-dirty) a gated agent's guarded stop allows at once; unguarded, the same stop blocks"
else
  echo "FAIL (loop-guard-gated-dirty) expected rc1=2 (control) and rc2=0 (rc1=$rc1 rc2=$rc2)"
  fail=1
fi

exit "$fail"
~~~
4. command: `bash -c 'node tests/orchestrator-model.test.js | grep -c "^FAIL"; bash tests/unit-bookkeeping.test.sh | grep -c "^FAIL"; bash tests/review-join.test.sh 2>/dev/null | grep -c "^FAIL"; exit 0'`
   expect: 0
   The red step: it prints `1`, `4`, `0` ((j) throws; the (r) guard, demotion-ruling and two helper-failed
   rows; the two review-join pins already pass, their teeth are criterion 3's mutations).
5. file: `bin/cli.js`
   anchor: line matching `orchestratorModel "${value}" is not one of`
   indent: 4
   before:
~~~
    console.warn(`Note: persona-config.json orchestratorModel "${value}" is not one of ${ORCHESTRATOR_MODELS.join(', ')}; keeping the shipped orchestrator model.`);
~~~
   after:
~~~
    console.warn(`Note: persona-config.json orchestratorModel ${JSON.stringify(value)} is not one of ${ORCHESTRATOR_MODELS.join(', ')}; keeping the shipped orchestrator model.`);
~~~
6. file: `bin/unit-bookkeeping.sh`
   anchor: line matching `  echo "model: $tier"`
   indent: 2
   before:
~~~
  if [ -n "$line" ]; then echo "$line"; fi
  echo "model: $tier"
  case " $line " in
~~~
   after:
~~~
  if [ -n "$line" ]; then echo "$line"; fi
  echo "model: $tier"
  # A failed helper's reason word describes a run that did not complete: record the failure, never a
  # guard demotion or a no-contract ruling for a tier that is not used.
  if [ "$rc" -ne 0 ]; then
    ruling "$unit" "helper failed rc=$rc: $tier"
    return 0
  fi
  case " $line " in
~~~
7. file: `hooks/scripts/stop-gate.sh`
   anchor: line matching `#  0) stop_hook_active guard - never re-trigger ourselves in a loop.`
   indent: 0
   before:
~~~
#  0) stop_hook_active guard - never re-trigger ourselves in a loop.
~~~
   after:
~~~
#  0) stop_hook_active guard (rp-u2) - the stop after a block allows at once, except
#     this project's reviewer: its stop still consumes review-join stamps (see
#     "Loop guard (rp-u2)" below).
~~~
8. file: `hooks/scripts/stop-gate.sh`
   anchor: line matching `# Loop guard (rp-u2). The stop that follows a block carries stop_hook_active. For this project's`
   indent: 0
   before:
~~~
# Loop guard (rp-u2). The stop that follows a block carries stop_hook_active. For this project's
# reviewer it still runs the review-join consume and the bounded flag clear, so a verdict written
# after a marker=MISSING block is not lost; the core never blocks such a stop (loop_guard_active).
# Every other stop with stop_hook_active allows at once, as before.
~~~
   after:
~~~
# Loop guard (rp-u2). The stop that follows a block carries stop_hook_active. For this project's
# reviewer it still runs the review-join consume and the bounded flag clear, so a verdict written
# after a marker=MISSING block is not lost. The core never blocks such a stop on the review-join or
# the marker-commit-check (loop_guard_active), so `markerCommitCheck.mode: block` blocks once; the
# microworld surfacing block runs before the reviewer branch and can still block it once, until its
# watermark advances. Every other stop with stop_hook_active allows at once, as before.
~~~
9. file: `CHANGELOG.md`
   anchor: line matching `(rp-u2, 0.31.195)` (the rp-u2 entry, one line)
   indent: 0
   before:
~~~
**Stop gate: strict review-in-flight stamps; a loop-guarded reviewer stop still consumes (rp-u2, 0.31.195).** hooks/scripts/lib/stop-gate-core.sh: a review-join stamp counts as a review in flight only with an exact `YYYY-MM-DDTHH:MM:SSZ` timestamp not later than now (`now` and future stamps no longer let Stop through forever). hooks/scripts/stop-gate.sh: a reviewer's SubagentStop with `stop_hook_active` (the stop after a `marker=MISSING` block) now runs the review-join consume and flag clear instead of exiting at once, so a verdict written after the block no longer leaves the pending-review flag standing; such a stop never blocks (a still-missing verdict logs `loop-guard=allow`). Other stops are unchanged, and only the reviewer clears flags. New cases in tests/stop-gate-review-inflight.test.sh and tests/review-join.test.sh.
~~~
   after:
~~~
**Stop gate: strict review-in-flight stamps; a loop-guarded reviewer stop still consumes (rp-u2, 0.31.195).** hooks/scripts/lib/stop-gate-core.sh: a review-join stamp counts as a review in flight only with an exact `YYYY-MM-DDTHH:MM:SSZ` timestamp not later than now (`now` and future stamps no longer let Stop through forever). hooks/scripts/stop-gate.sh: a reviewer's SubagentStop with `stop_hook_active` (the stop after a `marker=MISSING` block) now runs the review-join consume and flag clear instead of exiting at once, so a verdict written after the block no longer leaves the pending-review flag standing; such a stop never blocks on the review-join or the marker-commit-check (a still-missing verdict logs `loop-guard=allow`; the microworld surfacing block runs first and can still block it once). Other stops are unchanged, and only the reviewer clears flags. New cases in tests/stop-gate-review-inflight.test.sh and tests/review-join.test.sh.
~~~
10. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (expected 0.31.203 to 0.31.204).
11. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Review follow-ups: config note, bookkeeping ruling, loop-guard wording (rp-u10, VERSION).** bin/cli.js: the `orchestratorModel` note prints the value with `JSON.stringify`, so an object value (for example one with a string `toString`) no longer throws during the render. bin/unit-bookkeeping.sh: when the ladder helper exits non-zero, `dispatch` appends `helper failed rc=<n>: <tier>` and skips the guard-demotion and no-contract rulings, which described a demotion that never happened. hooks/scripts/stop-gate.sh: the loop-guard comments say a guarded reviewer stop never blocks on the review-join or the marker-commit-check (`markerCommitCheck.mode: block` is one-shot under the guard), while the microworld surfacing block can still block once; the rp-u2 entry below says the same. tests/review-join.test.sh pins the one-shot commit-check block and the reviewer-only guard (a gated agent with a dirty tree and a failing test command); tests/unit-bookkeeping.test.sh and tests/orchestrator-model.test.js pin the other two.
~~~
   Replace `VERSION` with the version that edit 10 wrote.
12. command: `node bin/cli.js --update`
   expect: 0
13. command: `bash -c 'node tests/orchestrator-model.test.js >/dev/null && bash tests/unit-bookkeeping.test.sh >/dev/null && bash tests/review-join.test.sh >/dev/null 2>&1'`
   expect: 0
14. command: `git add -u -- bin/cli.js bin/unit-bookkeeping.sh hooks/scripts/stop-gate.sh tests/orchestrator-model.test.js tests/unit-bookkeeping.test.sh tests/review-join.test.sh .claude-plugin/plugin.json package.json CHANGELOG.md .claude && git commit -m "fix(rp-u10): safe orchestratorModel note, no demotion ruling for a failed helper, accurate loop-guard wording"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stop and report it.

## Do NOT touch
- `hooks/scripts/lib/stop-gate-core.sh` (behaviour unchanged; only its callers' comments are corrected; criterion 8)
- `adapters/codex/hooks/scripts/stop-gate.sh` and `adapters/cursor/hooks/scripts/stop-gate.sh` (the ports never set `loop_guard_active`; criterion 8)
- `bin/ladder-tier.sh` and `bin/contract-guard.js` (the helpers are correct; the caller's bookkeeping was not; criterion 8)
- `agents/` and `templates/` (no prose or schema change; criterion 8)
- `CHANGELOG.md` partial: every entry but the rp-u2 entry (edit 9) and the new rp-u10 entry (edit 11)

## Acceptance criteria
1. run: `bash -c 'node tests/orchestrator-model.test.js >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: restore `orchestratorModel "${value}"` in the note; case (j) fails with `Cannot convert object to primitive value` and stdout is `1`.
2. run: `bash -c 'bash tests/unit-bookkeeping.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: delete the `return 0` inside the new `if [ "$rc" -ne 0 ]` block; four (r) rows fail (the guard ran, a `contract-guard sonnet` ruling was written) and stdout is `1`.
3. run: `bash -c 'bash tests/review-join.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: in hooks/scripts/lib/stop-gate-core.sh change `if [ "$mcc_mode" = block ] && [ "${loop_guard_active:-false}" != true ]; then` to `if [ "$mcc_mode" = block ]; then`; `(loop-guard-mcc-block-once)` fails (rc2=2) and stdout is `1`. Replacing the entry script's two-line reviewer-identity `if` with `if true; then` fails `(loop-guard-gated-dirty)` (rc2=2). spec-master ran both mutations; every other suite stays green under them.
4. run: `bash -c 'for f in hooks/scripts/stop-gate.sh .claude/hooks/scripts/stop-gate.sh CHANGELOG.md; do t=$(tr -s " \n#" " " < "$f"); for n in "never blocks on the review-join or the marker-commit-check" "never blocks such a stop on the review-join or the marker-commit-check" "never re-trigger ourselves in a loop" "such a stop never blocks (a still-missing"; do printf "%s" "$t" | grep -oF -- "$n" | wc -l; done | tr "\n" " "; echo; done'`
   exit: 0
   stdout: `0 1 0 0 ` then `0 1 0 0 ` then `2 0 0 0 ` (three lines)
   mutation: skip edit 9; the CHANGELOG line reads `1 0 0 1 `.
5. run: `bash -c 'cmp hooks/scripts/stop-gate.sh .claude/hooks/scripts/stop-gate.sh && cmp bin/unit-bookkeeping.sh .claude/bin/unit-bookkeeping.sh && for c in .claude/hooks/scripts/lib adapters/codex/hooks/scripts/lib adapters/cursor/hooks/scripts/lib; do cmp hooks/scripts/lib/stop-gate-core.sh "$c/stop-gate-core.sh" || exit 1; done && echo same'`
   exit: 0
   stdout: `same`
   mutation: skip edit 12 (`--update`); the first `cmp` reports a difference and the command exits 1.
6. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u10): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u10): " | head -1); git diff --name-only "$b^..$l" -- . ":(exclude).claude" | LC_ALL=C sort | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md bin/cli.js bin/unit-bookkeeping.sh hooks/scripts/stop-gate.sh package.json tests/orchestrator-model.test.js tests/review-join.test.sh tests/unit-bookkeeping.test.sh `
   mutation: also edit `hooks/scripts/lib/stop-gate-core.sh` in an rp-u10 commit; it joins the list.
7. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u10): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u10): " | head -1); test "$(git show "$b^:.claude-plugin/plugin.json" | grep "\"version\"")" != "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:package.json" | grep "\"version\"")" = "$(git show "$l:.claude-plugin/plugin.json" | grep "\"version\"")" && test "$(git show "$l:CHANGELOG.md" | grep -c "(rp-u10, ")" = 1 && echo moved'`
   exit: 0
   stdout: `moved`
   mutation: skip edit 10; the versions are equal, stdout is empty and the exit is 1.
8. run: `bash -c 'b=$(git log --format=%H --grep="^[a-z]*(rp-u10): " | tail -1); l=$(git log --format=%H --grep="^[a-z]*(rp-u10): " | head -1); git diff --name-only "$b^..$l" -- hooks/scripts/lib adapters bin/ladder-tier.sh bin/contract-guard.js agents templates | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `adapters/cursor/hooks/scripts/stop-gate.sh` in an rp-u10 commit; stdout is `1`.
9. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: put `exit 1` as line 2 of tests/review-join.test.sh; validate.sh exits 1 and stdout is `1`.

## Pre-resolved context
tdd: yes edits 1 to 3 add the cases and edit 4 shows (j) and (r) red (`1`, `4`); the two review-join cases are pins that pass before and after (the behaviour is right, only untested), and criterion 3's two mutations are what they catch.
evidence (a): at 0b45bd46, `node -e "require('./bin/cli.js').applyOrchestratorModel('---\nmodel: sonnet\n---\n', 'orchestrator', {orchestratorModel: {toString: 'x'}})"` throws `TypeError: Cannot convert object to primitive value`. `JSON.stringify` of a string adds the same double quotes the old message had, so the existing (d) case and the `--update` output are unchanged.
evidence (b): bin/unit-bookkeeping.sh:44-57 at 0b45bd46: `rc` forces `tier=opus`, but the `case " $line "` branches still run `guard_demote` (which calls the guard and appends `contract-guard sonnet: ...`) or the no-contract ruling. The helper-missing path (line 37-40) already writes `helper missing: $ladder: opus`; the new line mirrors it as `helper failed rc=<n>: <tier>` (`<tier>` is `opus`, or `EXHAUSTED` when the helper printed that).
evidence (c): hooks/scripts/lib/stop-gate-core.sh:64-90 (microworld surfacing, both Stop and SubagentStop) runs before the reviewer branch at :400; it blocks when unreported broken bundles exist and advances its watermark first, so it blocks at most once per result. The marker-commit-check block at :490 already skips under `loop_guard_active`; the missing-verdict branch at :528 allows. Line numbers are at 0b45bd46.
one-shot: the spec records that `markerCommitCheck.mode: block` now blocks a reviewer's stop once: the unguarded stop exits 2 on the mismatch; the stop that follows carries `stop_hook_active`, logs the mismatch again, consumes the stamp and clears the flag. Case `(loop-guard-mcc-block-once)` asserts two mismatch audit lines.
dirty-tree-case: `(loop-guard-gated-dirty)` builds a git repo with a modified tracked file and `testAndLintCommand: "false"`; the same lead-programmer stop without `stop_hook_active` exits 2 (the control, so the case cannot pass vacuously), with it exits 0. The existing `(loop-guard-gated-agent)` case has no repo and no dirty tree, which is why `if true` passed it.
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2); the core copies are unchanged and criterion 5 proves the four are still equal.
chained: dispatched after st-u4 (st-u2 and st-u4 edit `bin/cli.js` at `const BIN_HELPER_FILES = [` only, far from edit 5). rp-u7, rp-u4, rp-u5 and rp-u6 come after; none edits these lines (rp-u4 edits `bin/cli.js` argument parsing; its anchors are unchanged). spec-master applied rp-u8, rp-u9, the amended st-u2 to st-u4, this contract and then rp-u7, rp-u4, rp-u5 and rp-u6 to a clone at 0b45bd46 with a script that requires each `before:` payload once: all matched and every contract's own test commands exited as stated.
blast-radius: bin/cli.js:1115; bin/unit-bookkeeping.sh:52-57; hooks/scripts/stop-gate.sh:34 and :144-147; CHANGELOG.md rp-u2 entry; tests/orchestrator-model.test.js:103; tests/unit-bookkeeping.test.sh and tests/review-join.test.sh last lines. Callers: `renderCleanBody` and the fresh-install render (cli.js:1142, :2536); agents/orchestrator.md "Per-unit model routing" runs `.claude/bin/unit-bookkeeping.sh dispatch`. Line numbers are at 0b45bd46.
version: .claude-plugin/plugin.json and package.json read 0.31.203 after st-u4 if no fix round bumped; edit 10 adds one (expected 0.31.204).
commit-message: fix(rp-u10): safe orchestratorModel note, no demotion ruling for a failed helper, accurate loop-guard wording
diagnosis: none
review-packet:
~~~
unit: rp-u10
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
~~~

## Escalation
If a `before:` payload is not found verbatim (st-u2 to st-u4 or a fix round may have moved a line), stop and
report the current text. If a review-join case other than the two new ones changes result, quote it and stop.
If `node bin/cli.js --update` reports a mirror as diverged, quote it and stop. If a gate blocks a command,
report it and wait. Anything outside "Affected files" goes to your report as a proposal.
