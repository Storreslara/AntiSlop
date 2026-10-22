Unit: rp-u5

## Objective
Fix round 1 for rp-u5 (fix-of: 2026-10-22T20:07:27Z; the implementer runs on sonnet). The skip clause rp-u5 added to `agents/orchestrator.md` "Scribe dispatch convention" contradicts the sentence it extends: under `knowledgeWrites: apply` a no-issue plan whose digest reports a new convention is a RUN by the first sentence and a SKIP by the clause. After this fix one decision table (mode x has-issue x in-scope change) decides the early-stop and the end-of-plan scribe dispatch alike, the prose says exactly that table, the early-stop dispatch is made before the human is asked at ladder exhaustion or before the plan ends early (a parked unit is not passed; under review gating off ladder exhaustion is not a stop), the end-of-plan dispatch covers only the units an early-stop dispatch did not already send, and `tests/prompt-diet-pins.test.sh` pins every row phrase in the source and its mirror.

## Retrieval
Fast path, no tracker issue. This file is the fix contract of record for `Unit: rp-u5`; the original contract is `docs/plans/antislop-review-patches/contracts/rp-u5.md`, implemented at fe90b048 (version 0.31.215). The FAIL block it answers is the one timestamped 2026-10-22T20:07:27Z in the reviewer record for rp-u5.

## Affected files
- `tests/prompt-diet-pins.test.sh` (anchor: line matching `# rp-u5: the scribe still runs for the passed units when a plan stops early, and knowledgeWrites apply`)
- `agents/orchestrator.md` (anchor: line matching `If the plan stops before its last unit passes (ladder exhaustion, a human stop, an abandoned unit), dispatch`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- generated only, by `node bin/cli.js --update`: `.claude/agents/*.md` (orchestrator.md gets the new prose; every other persona only a version stamp), `.claude/persona-protocol*.md`, `.claude/protocol-digest.md` (version stamps only), the config's `fileHashes` and `pluginVersion`

## Ordered edits
1. file: `tests/prompt-diet-pins.test.sh`
   anchor: line matching `# rp-u5: the scribe still runs for the passed units when a plan stops early, and knowledgeWrites apply`
   indent: 0
   before:
~~~
# rp-u5: the scribe still runs for the passed units when a plan stops early, and knowledgeWrites apply
# leaves only the no-issue condition to skip it.
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'If the plan stops before its last unit passes (ladder exhaustion, a human stop, an abandoned unit), dispatch the scribe once for the units that already reached PASS before you surface the stop'
  has "$f" 'under `knowledgeWrites: apply` the knowledge files are always in scope, so only the first condition can skip it.'
  has "$f" 'Skip the scribe dispatch entirely when no unit has a tracker issue to close'
done
~~~
   after:
~~~
# rp-u5 (fix 1): one decision table decides the scribe dispatch, early-stop and end-of-plan alike: it runs
# when a covered unit has a tracker issue to close, or when none has but a covered digest reports a changed
# API or new convention in scope (under knowledgeWrites apply every knowledge file is in scope); otherwise it
# is skipped. The early-stop dispatch comes before the human is asked at ladder exhaustion or the plan ends
# early, a parked unit is not passed, and the end-of-plan dispatch skips units already sent.
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  has "$f" 'dispatch the scribe once for the units that already reached PASS, before you ask the human at ladder exhaustion or before you end the plan early'
  has "$f" 'A parked unit is not passed, and under review gating off ladder exhaustion is not a stop.'
  has "$f" 'dispatch after the last unit covers only the units not already sent to the scribe by an early-stop dispatch'
  has "$f" 'Skip the scribe dispatch entirely when no unit has a tracker issue to close and no unit'"'"'s digest reports a changed API or new convention whose knowledge file is in unit scope'
  has "$f" 'under `knowledgeWrites: apply` every knowledge file is in scope, so the dispatch is skipped only when no unit has a tracker issue to close and no digest reports a changed API or new convention'
  has "$f" 'it runs when a covered unit has a tracker issue to close, in either mode'
  has "$f" 'it runs when no covered unit has one but a covered digest reports a changed API or new convention whose knowledge file is in unit scope'
  has "$f" 'it is skipped when neither holds'
  hasnot "$f" 'so only the first condition can skip it'
  hasnot "$f" 'an abandoned unit'
done
~~~

2. command: `bash -c 'bash tests/prompt-diet-pins.test.sh | /usr/bin/grep -c "^FAIL"'`
   expect: 0
   The red step: `grep -c` prints `18` (nine of the ten new rows fail for each of the two files; only the `Skip the scribe dispatch entirely when` row already holds) and exits 0.

3. file: `agents/orchestrator.md`
   anchor: line matching `If the plan stops before its last unit passes (ladder exhaustion, a human stop, an abandoned unit), dispatch`
   indent: 0
   before:
~~~
If the plan stops before its last unit passes (ladder exhaustion, a human stop, an abandoned unit), dispatch
the scribe once for the units that already reached PASS before you surface the stop, with the same three
inputs for each. Skip the scribe dispatch entirely when no unit has a tracker issue to close and no unit's
digest reports a changed API or new convention whose knowledge file is in unit scope; under
`knowledgeWrites: apply` the knowledge files are always in scope, so only the first condition can skip it.
~~~
   after:
~~~
If the plan stops before its last unit passes, dispatch the scribe once for the units that already reached PASS,
before you ask the human at ladder exhaustion or before you end the plan early, with the same three inputs for
each. A parked unit is not passed, and under review gating off ladder exhaustion is not a stop. The
dispatch after the last unit covers only the units not already sent to the scribe by an early-stop dispatch.
Skip the scribe dispatch entirely when no unit has a tracker issue to close and no unit's digest reports a
changed API or new convention whose knowledge file is in unit scope; under `knowledgeWrites: apply` every
knowledge file is in scope, so the dispatch is skipped only when no unit has a tracker issue to close and no
digest reports a changed API or new convention. Both dispatches follow one table, over the units each covers:
it runs when a covered unit has a tracker issue to close, in either mode; it runs when no covered unit has one
but a covered digest reports a changed API or new convention whose knowledge file is in unit scope (under
`apply`, any digest that reports one); it is skipped when neither holds.
~~~

4. command: `perl -0pi -e 's/("version": "\d+\.\d+\.)(\d+)"/$1.($2+1)."\""/e' .claude-plugin/plugin.json package.json`
   expect: 0
   This adds one to the patch version in both files (0.31.215 to 0.31.216 if no queued unit has landed first).

5. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
~~~

**Scribe dispatch rule is one decision table (rp-u5 fix 1, VERSION).** agents/orchestrator.md "Scribe dispatch convention": the clause rp-u5 added ("under `knowledgeWrites: apply` ... only the first condition can skip it") contradicted the skip sentence it extended, so a no-issue plan whose digest reported a new convention was a run by one sentence and a skip by the other, and the knowledge write `apply` exists to allow was lost. One table now decides the early-stop and the end-of-plan dispatch alike: it runs when a covered unit has a tracker issue to close, or when none has but a covered digest reports a changed API or new convention whose knowledge file is in scope (under `apply`, any digest that reports one), and is skipped otherwise. The early-stop dispatch is made before the human is asked at ladder exhaustion or before the plan ends early; a parked unit is not passed; under review gating off ladder exhaustion is not a stop; the end-of-plan dispatch covers only the units an early-stop dispatch did not already send. Pinned row by row in tests/prompt-diet-pins.test.sh.
~~~
   Replace `VERSION` with the version that edit 4 wrote.

6. command: `node bin/cli.js --update`
   expect: 0

7. command: `bash tests/prompt-diet-pins.test.sh`
   expect: 0

8. command: `git add tests/prompt-diet-pins.test.sh agents/orchestrator.md CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "fix(rp-u5): scribe dispatch is one decision table; under apply a digest that reports a change keeps the dispatch (rp-u5)"`
   expect: 0
   Run `git status --short` first: if a tracked file outside "Affected files" is modified, stage by the paths above and report it. Add the trailer lines the dispatch gives, verbatim, after the subject.

## Do NOT touch
- `hooks/hooks.json` (the registration is the operator's step; no agent identity may write it)
- `agents/scribe.md` (line 33 `knowledgeWrites: "apply"` restores direct edits; its close rule is unchanged)
- `adapters/codex/agents/orchestrator.toml` and `adapters/cursor/agents/orchestrator.md` (no scribe dispatch convention there)
- `tests/knowledge-writes.test.sh` (its `Skip the scribe dispatch entirely when` row must keep passing unedited)
- `tests/microworld/microworld-rerun.test.sh` (case (j) `expected 1-2 actual runs ... runs=3` is a flaky unrelated test; leave it)
- `docs/plans/antislop-review-patches/contracts/rp-u5.md` and every other earlier contract

## Acceptance criteria
1. run: `bash -c 'bash tests/prompt-diet-pins.test.sh >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: skip edit 6 (`--update`); the mirror rows fail and stdout is `1`.
2. run: `bash -c 'bash tests/prompt-diet-pins.test.sh | /usr/bin/grep -c "^FAIL"'`
   exit: 1
   stdout: `0`
   mutation: skip edit 3; 18 rows print FAIL and the exit is 0.
3. run: `bash -c 'bash tests/prompt-diet-pins.test.sh | /usr/bin/grep -cE "^ok   .*(dispatch the scribe once|A parked unit is not passed|dispatch after the last unit covers|every knowledge file is in scope|it runs when a covered unit|it runs when no covered unit|it is skipped when neither|so only the first condition|an abandoned unit)"'`
   exit: 0
   stdout: `18`
   mutation: delete the line `has "$f" 'it is skipped when neither holds'` from the pins file; stdout is `16`.
4. run: `bash -c 'for f in agents/orchestrator.md .claude/agents/orchestrator.md; do tr -s " \n" " " < "$f" | /usr/bin/grep -cF "it runs when no covered unit has one but a covered digest reports a changed API or new convention whose knowledge file is in unit scope"; done | tr "\n" " "'`
   exit: 0
   stdout: `1 1 `
   mutation: skip edit 3; stdout is `0 0 `.
5. run: `bash -c 'for f in agents/orchestrator.md .claude/agents/orchestrator.md; do tr -s " \n" " " < "$f" | /usr/bin/grep -cE "so only the first condition can skip it|an abandoned unit|surface the stop"; done | tr "\n" " "'`
   exit: 0
   stdout: `0 0 `
   mutation: keep the old five lines of edit 3 (skip edit 3); stdout is `1 1 `.
6. run: `bash -c 'diff agents/orchestrator.md .claude/agents/orchestrator.md | /usr/bin/grep -c "^<"'`
   exit: 1
   stdout: `0`
   mutation: skip edit 6 (`--update`); the mirror lacks the new prose, the diff shows source-only lines and stdout is not `0`.
7. run: `bash -c 'bash tests/knowledge-writes.test.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: `0`
   mutation: reword "Skip the scribe dispatch entirely when" in edit 3's text; its row fails and stdout is `1`.
8. run: `bash -c 'for c in $(git log --format="%H %s" fe90b048..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u5\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c" -- . ":(exclude).claude"; done | LC_ALL=C sort -u | tr "\n" " "'`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md package.json tests/prompt-diet-pins.test.sh `
   mutation: also edit `agents/scribe.md` in an rp-u5 commit; it joins the list.
9. run: `bash -c 'for c in $(git log --format="%H %s" fe90b048..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u5\): " | cut -d" " -f1); do git diff --name-only "$c~1..$c" -- hooks/hooks.json agents/scribe.md adapters tests/knowledge-writes.test.sh tests/microworld docs/plans bin tests/validate.sh; done | wc -l'`
   exit: 0
   stdout: `0`
   mutation: edit `adapters/codex/agents/orchestrator.toml` in an rp-u5 commit; stdout is `1`.
10. run: `bash -c 'c=$(git log --format="%H %s" fe90b048..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u5\): " | cut -d" " -f1 | head -1); for f in package.json .claude-plugin/plugin.json; do p=$(git show "$c~1:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); n=$(git show "$c:$f" | /usr/bin/grep -m1 "\"version\"" | /usr/bin/grep -oE "[0-9]+\.[0-9]+\.[0-9]+"); [ "${p%.*}.$(( ${p##*.} + 1 ))" = "$n" ] && echo "$f ok"; done | paste -sd"|"'`
    exit: 0
    stdout: `package.json ok|.claude-plugin/plugin.json ok`
    mutation: bump `.claude-plugin/plugin.json` only; stdout is `.claude-plugin/plugin.json ok`.
11. run: `bash -c 'c=$(git log --format="%H %s" fe90b048..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u5\): " | cut -d" " -f1 | head -1); bash hooks/scripts/version-stamp-check.sh "$c~1..$c" | cut -d" " -f1-4'`
    exit: 0
    stdout: `version-stamp-check: ok touched: yes`
    mutation: skip edit 4; stdout reads `version-stamp-check: violation touched: yes`.
12. run: `node -e "const v=require('./package.json').version,w=require('./.claude-plugin/plugin.json').version,t=require('fs').readFileSync('CHANGELOG.md','utf8');process.exit(v===w&&t.includes('(rp-u5 fix 1, '+v+')')?0:1)" && echo version-sync: ok`
    exit: 0
    stdout: `version-sync: ok`
    mutation: bump `.claude-plugin/plugin.json` only, or leave `VERSION` in the CHANGELOG line; the exit is 1 with empty stdout.
13. run: `bash -c 'tr "\n" " " < CHANGELOG.md | tr -s " " | /usr/bin/grep -cF "Scribe dispatch rule is one decision table"'`
    exit: 0
    stdout: `1`
    mutation: skip edit 5; stdout is `0` and the exit is 1.
14. run: `bash -c 'e=$(git log --format="%H %s" fe90b048..HEAD | /usr/bin/grep -E "^[0-9a-f]+ [a-z]+\(rp-u5\): " | cut -d" " -f1 | head -1); git log --format=%s "$e"..HEAD -- agents/orchestrator.md tests/prompt-diet-pins.test.sh | /usr/bin/grep -vcE "^[a-z]+\(rp-u5\): "'`
    exit: 1
    stdout: `0`
    mutation: make a later commit with another subject that touches `agents/orchestrator.md`; stdout is `1` and the exit is 0.
15. run: `bash -c 'bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms)
    exit: 0
    stdout: `0`
    mutation: put `exit 1` as line 2 of tests/prompt-diet-pins.test.sh; validate.sh exits 1 and stdout is `1`.
    precondition: if validate.sh exits non-zero and the only failing test is tests/microworld/microworld-rerun.test.sh case (j) (`expected 1-2 actual runs ... runs=3`, passes alone), re-run this criterion once and report both results; any other failure is a FAIL.
16. run: `bash -c 'git status --porcelain --untracked-files=no -- agents tests .claude CHANGELOG.md package.json .claude-plugin'`
    exit: 0
    stdout: empty
    mutation: leave edit 6 (`--update`) out of the commit; a `.claude/` path shows as modified and stdout is not empty.

## Pre-resolved context
tdd: yes tests/prompt-diet-pins.test.sh; edit 1 replaces the rp-u5 rows with the table rows; edit 2 shows them red (`18`) before edit 3.
decision-table: the rule the prose (edit 3) and the pins (edit 1) state, for both the end-of-plan dispatch and the early-stop dispatch. "Covered" units: for the end-of-plan dispatch the units not already sent by an early-stop dispatch; for the early-stop dispatch the units that reached PASS so far and were not sent before. "In-scope change": a covered digest reports a changed API or new convention whose knowledge file is in unit scope; under `apply` every knowledge file is in scope, so any digest that reports a changed API or new convention counts.
  mode=scoped, has-issue=yes, in-scope-change=yes: end-of-plan RUN, early-stop RUN
  mode=scoped, has-issue=yes, in-scope-change=no: end-of-plan RUN, early-stop RUN
  mode=scoped, has-issue=no, in-scope-change=yes: end-of-plan RUN, early-stop RUN
  mode=scoped, has-issue=no, in-scope-change=no: end-of-plan SKIP, early-stop SKIP
  mode=apply, has-issue=yes, in-scope-change=yes: end-of-plan RUN, early-stop RUN
  mode=apply, has-issue=yes, in-scope-change=no: end-of-plan RUN, early-stop RUN
  mode=apply, has-issue=no, in-scope-change=yes: end-of-plan RUN, early-stop RUN (the row the FAIL found: the old clause said SKIP)
  mode=apply, has-issue=no, in-scope-change=no: end-of-plan SKIP, early-stop SKIP
  Pinned as: `it runs when a covered unit has a tracker issue to close, in either mode` (the four has-issue=yes rows), `it runs when no covered unit has one but a covered digest reports a changed API or new convention whose knowledge file is in unit scope` (the two no-issue + change rows, with the `apply` parenthesis in the prose), `it is skipped when neither holds` (the two SKIP rows), the aof-u4 sentence `Skip the scribe dispatch entirely when no unit has a tracker issue to close and no unit's digest reports a changed API or new convention whose knowledge file is in unit scope` (kept verbatim, so tests/knowledge-writes.test.sh still passes), and the apply sentence (skip only when no issue and no digest reports a change).
wording-fixes: the FAIL's two REQUIRED notes. (1) "The dispatch after the last unit covers only the units not already sent to the scribe by an early-stop dispatch" (units are not processed twice). (2) the stops are stated exactly: the scribe is dispatched for passed units "before you ask the human at ladder exhaustion or before you end the plan early"; "A parked unit is not passed" (the glossary's parked unit, the protocol's `skip:` abandoned unit); "under review gating off ladder exhaustion is not a stop" (the orchestrator lists the findings and moves on). The words "a human stop" and "an abandoned unit" are gone; pinned absent (`an abandoned unit`).
anchors-checked: every anchor and every `before:` payload was run against the CURRENT files (agents/orchestrator.md lines 58-62, tests/prompt-diet-pins.test.sh lines 95-101, CHANGELOG.md `## [Unreleased]` once) with a python applier in a scratch worktree at fe90b048 that requires each `before:` to occur exactly once and each anchor line once; edits 1 to 8 were then replayed there (edit 2 printed 18, edit 7 exited 0, criteria 1 to 14 printed the stated stdout).
order: where this fix sits. None of the queued units edits `agents/orchestrator.md` or `tests/prompt-diet-pins.test.sh`: rp-u6 (`bin/contract-anchors.js`, `tests/contract-anchors.test.sh`, `tests/validate.sh` at the unit-size echo line), rp-u13 (`hooks/scripts/lib/unit-scope.sh`, `tests/scope-libs.test.sh`), rp-u14 (`bin/review-precheck.sh`, `tests/review-precheck.test.sh`, `agents/reviewer.md` only; it adds no sentence to the orchestrator) and rp-s1 (CONTEXT.md, `docs/harness-glossary.md`, wiki) touch other files, so this fix has no `Depends on` edge to any of them and any order is safe. Shared stamped files (plugin.json, package.json, CHANGELOG.md) are bumped by relative edits (edit 4 adds one to what it reads, edit 5 inserts after the `## [Unreleased]` line), so they serialise by commit order alone. rp-u14's edit of `agents/reviewer.md` changes `.claude/agents/reviewer.md` by `--update`; this fix's `git add -u -- .claude` stages only what its own `--update` changed, so run it after the previous unit's commit. rp-s1's scribe glossary run reads this convention but edits no file named here. Dispatch after fe90b048 and before or after any of them.
blast-radius: agents/orchestrator.md:58-62 ("Scribe dispatch convention"); tests/prompt-diet-pins.test.sh:95-101; tests/knowledge-writes.test.sh:69 (the `Skip the scribe dispatch entirely when` row, unchanged and kept passing); agents/scribe.md:33 (read only). Line numbers are at fe90b048.
version: .claude-plugin/plugin.json and package.json read 0.31.215 at fe90b048; edit 4 adds one (expected 0.31.216 if no queued unit has landed first).
mirrors: `.claude/` copies change only through `node bin/cli.js --update` (constitution P2).
commit-message: fix(rp-u5): scribe dispatch is one decision table; under apply a digest that reports a change keeps the dispatch (rp-u5)
fix-of: 2026-10-22T20:07:27Z
diagnosis: none
review-packet:
~~~
unit: rp-u5 (fix 1)
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
criterion 16: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written (a `before:` payload not found verbatim once, a `--update` refusal, a gate block), STOP and report a spec gap; do not improvise.
