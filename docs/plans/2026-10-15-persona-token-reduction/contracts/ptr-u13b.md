Unit: ptr-u13b

## Objective
`agents/orchestrator.md`, `agents/task-master.md`, `agents/spec-master.md` and both orchestrator ports carry the ladder and checkpoint wording of items b, c, d, g and h (the EXHAUSTED exception, the contract of record, no-contract as a guard demotion, the progress rule for checkpoints, the handoff-note commit rule, the fast-path checkpoint, and the renamed protocol-section pointer); `tests/persona-prose-pins.test.sh` pins every phrase in the source, the mirror and the ports and is registered in `tests/validate.sh`; version 0.31.180, CHANGELOG entries, mirrors refreshed by `node bin/cli.js --update`. Two commits: the prose and the version first, the test and its registration second.

## Retrieval
GitHub issues: `gh issue view 565 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/persona-token-reduction`. Spec: `docs/plans/2026-10-15-persona-token-reduction.md`, section "Step U13b".

## Affected files
- `agents/orchestrator.md` (anchor: line matching `, dispatch nothing: run`)
- `agents/task-master.md` (anchor: line matching `  not a gated agent).`)
- `agents/spec-master.md` (anchor: line matching `returned; (2) plan doc written and Self-check passed; (3) after publishing,`)
- `adapters/codex/agents/orchestrator.toml` (anchor: line matching `re-dispatch the same persona fresh, citing the path (not a failure, not counted).`)
- `adapters/cursor/agents/orchestrator.md` (anchor: line matching `spec-master, re-dispatch the same persona fresh, citing the path (not a`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.179",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- `tests/persona-prose-pins.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "FAIL tests/gate-fp-harvest.test.sh"`)
- `.claude/agents/*.md` and the other mirrors `node bin/cli.js --update` rewrites (regenerated, never edited by hand)

## Ordered edits
1. command: `test "$(node -p "require('./.claude-plugin/plugin.json').version")" = 0.31.179 && git log --format=%s | grep -qE '^[a-z]+\(ptr-u13a\): ' && test ! -e tests/persona-prose-pins.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `agents/orchestrator.md`
   anchor: line matching `, dispatch nothing: run`
   indent: 3
   before:
   ~~~~
   lower it. On `EXHAUSTED`, dispatch nothing: run `bash bin/escalation-card.sh
   <task-id>` and go to **At the 2-FAIL cap**. A set `CLAUDE_CODE_SUBAGENT_MODEL`
   ~~~~
   after:
   ~~~~
   lower it. On `EXHAUSTED`, dispatch nothing, except a human-chosen (a)/(b)
   re-dispatch from **At the 2-FAIL cap**: run `bash bin/escalation-card.sh
   <task-id>` and go to **At the 2-FAIL cap**. A set `CLAUDE_CODE_SUBAGENT_MODEL`
   ~~~~
3. file: `agents/orchestrator.md`
   anchor: line matching `--contract <contract file>`
   indent: 3
   before:
   ~~~~
   <task-id> --contract <contract file>` and pass its tier as the dispatch's `model`
   parameter. A `Suggested model: haiku|sonnet|opus` tag can raise that tier, never
   ~~~~
   after:
   ~~~~
   <task-id> --contract <contract file>` (the contract of record, never a fix
   contract: a fix contract can score back onto `haiku`) and pass its tier as the
   dispatch's `model` parameter. A `Suggested model: haiku|sonnet|opus` tag can
   raise that tier, never
   ~~~~
4. file: `agents/orchestrator.md`
   anchor: line matching `the script never writes. Scoring is pure`
   indent: 3
   before: `(**Rulings ledger**); the script never writes. Scoring is pure, so a fresh session`
   after:
   ~~~~
   (**Rulings ledger**); the script never writes. `reason=no-contract` is a guard
   demotion too (CONTEXT.md **guard demotion**): tell the user in one line that the
   unit had no contract, and append `RULING <UTC ISO-8601 timestamp>
   unit=<task-id> decision=contract-guard sonnet: no-contract`. Scoring is pure, so a fresh session
   ~~~~
5. file: `agents/orchestrator.md`
   anchor: line matching `- **Cut off** (no`
   indent: 3
   before:
   ~~~~
   - **Cut off** (no `STATUS:` line, or `STATUS: incomplete` other than a
     checkpoint) — resume; for a
   ~~~~
   after:
   ~~~~
   - **Cut off** (no `STATUS:` line, or `STATUS: incomplete` other than a
     task-master or spec-master checkpoint) — resume; for a
   ~~~~
6. file: `agents/orchestrator.md`
   anchor: line matching `record, no 2-FAIL cap, no ladder step.`
   indent: 3
   before:
   ~~~~
   path. This is not a failure and is not counted toward anything: no FAIL
   record, no 2-FAIL cap, no ladder step.
   ~~~~
   after:
   ~~~~
   path. This is not a failure and is not counted toward anything: no FAIL
   record, no 2-FAIL cap, no ladder step. A checkpoint is progress only if the
   cited path has a newer commit (`git log -1 --format=%h -- <path>`) than at the
   same persona's previous checkpoint on this plan; otherwise it is not progress:
   do not re-dispatch, surface it to the user.
   ~~~~
7. file: `adapters/codex/agents/orchestrator.toml`
   anchor: line matching `re-dispatch the same persona fresh, citing the path (not a failure, not counted).`
   indent: 3
   before: `re-dispatch the same persona fresh, citing the path (not a failure, not counted).`
   after:
   ~~~~
   re-dispatch the same persona fresh, citing the path (not a failure, not counted).
   A checkpoint is progress only if the cited path has a newer commit (`git log
   -1 --format=%h -- <path>`) than at the same persona's previous checkpoint on
   this plan; otherwise it is not progress: do not re-dispatch, surface it to the
   user.
   ~~~~
8. file: `adapters/cursor/agents/orchestrator.md`
   anchor: line matching `spec-master, re-dispatch the same persona fresh, citing the path (not a`
   indent: 3
   before:
   ~~~~
   spec-master, re-dispatch the same persona fresh, citing the path (not a
   failure, not counted).
   ~~~~
   after:
   ~~~~
   spec-master, re-dispatch the same persona fresh, citing the path (not a
   failure, not counted). A checkpoint is progress only if the cited path has a newer commit (`git log
   -1 --format=%h -- <path>`) than at the same persona's previous checkpoint on
   this plan; otherwise it is not progress: do not re-dispatch, surface it to the
   user.
   ~~~~
9. file: `agents/orchestrator.md`
   anchor: line matching `"Review ownership" section lists`
   indent: 3
   before: `"Review ownership" section lists which hooks go inert and which stay armed.`
   after:
   ~~~~
   "Review markers and gate mechanics (owner-facing)" section lists which hooks go
   inert and which stay armed.
   ~~~~
10. file: `agents/task-master.md`
   anchor: line matching `  not a gated agent).`
   indent: 3
   before:
   ~~~~
     spawn. A checkpoint is not a failure, and it is not the WIP sentinel (you are
     not a gated agent).
   ~~~~
   after:
   ~~~~
     spawn. A checkpoint is not a failure, and it is not the WIP sentinel (you are
     not a gated agent). Commit the handoff note with the contract file of the last
     unit it lists as done, in the same commit.
   ~~~~
11. file: `agents/spec-master.md`
   anchor: line matching `returned; (2) plan doc written and Self-check passed; (3) after publishing,`
   indent: 3
   before:
   ~~~~
   returned; (2) plan doc written and Self-check passed; (3) after publishing,
     before the fast-path dispatch contracts. At (2) and (3), if the spec has more
     than 5 steps, end the turn with
     `STATUS: incomplete — checkpoint: <plan path>` and leave the next phase to a
     fresh spawn. Decisions live
   ~~~~
   after:
   ~~~~
   returned; (2) plan doc written and Self-check passed; (3) on the fast path,
     write and commit each contract file as soon as it is finished; after every 3
     contract files in one spawn, with contracts remaining, end with
     `STATUS: incomplete — checkpoint: <plan path>` (the plan's dispatch-section
     links show which are done). At (2), if the spec has more than 5 steps, end
     the turn with `STATUS: incomplete — checkpoint: <plan path>` and leave the
     next phase to a fresh spawn. Decisions live
   ~~~~
12. file: `.claude-plugin/plugin.json` (version 0.31.180)
   anchor: line matching `"version": "0.31.179",`
   before: `"version": "0.31.179",`
   after: `"version": "0.31.180",`
13. file: `package.json` (version 0.31.180)
   anchor: line matching `"version": "0.31.179",`
   before: `"version": "0.31.179",`
   after: `"version": "0.31.180",`
14. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   insert-after:
   ~~~~

   **Ladder and checkpoint wording in the orchestration prose (ptr-u13b, 0.31.180).** `agents/orchestrator.md` now says that `EXHAUSTED` dispatches nothing except a human-chosen (a)/(b) re-dispatch from **At the 2-FAIL cap**, that `bin/ladder-tier.sh` takes the contract of record and never a fix contract, that `reason=no-contract` is a guard demotion told to the user and appended to the rulings ledger, that a checkpoint is progress only if the cited path has a newer commit than at the persona's previous checkpoint (the same sentence in both orchestrator ports), and that "Cut off" excludes only a task-master or spec-master checkpoint; its pointer now names the protocol section "Review markers and gate mechanics (owner-facing)". `agents/task-master.md` commits the handoff note with the last listed contract file, and `agents/spec-master.md` checkpoints the fast path after every 3 contract files.
   ~~~~
15. command: `node bin/cli.js --update`
   expect: 0
16. command: `git add agents/orchestrator.md agents/task-master.md agents/spec-master.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git reset -q -- .claude/agent-memory && git commit -m "docs(ptr-u13b): ladder and checkpoint wording in the orchestration prose (0.31.180) (#565)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
17. file: `tests/persona-prose-pins.test.sh`
   anchor: new file
   indent: 3
   insert-after:
   ~~~~
   #!/usr/bin/env bash
   # Prose pins for the wave-7 cleanup (ptr-u13b, ptr-u13c): phrases that must, or must not, appear
   # in persona sources, their .claude mirrors and the adapter ports. Each file is flattened
   # (tr -s ' \n' ' ') first, so a phrase may wrap across lines. Prints ok|FAIL <file> <phrase>.
   set -u
   cd "$(dirname "$0")/.."
   fail=0

   flat() { tr -s ' \n' ' ' < "$1"; }
   has() { # <file> <phrase>
     if [ -f "$1" ] && flat "$1" | grep -qF -- "$2"; then echo "ok   $1 $2"; else echo "FAIL $1 $2"; fail=1; fi
   }
   hasnot() { # <file> <phrase>
     if [ -f "$1" ] && ! flat "$1" | grep -qF -- "$2"; then echo "ok   $1 (absent) $2"; else echo "FAIL $1 (present or missing) $2"; fail=1; fi
   }

   for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
     has "$f" 'except a human-chosen (a)/(b) re-dispatch'
     has "$f" 'the contract of record, never a fix contract'
     has "$f" 'decision=contract-guard sonnet: no-contract'
     has "$f" 'other than a task-master or spec-master checkpoint'
     has "$f" 'is not progress'
     has "$f" '"Review markers and gate mechanics (owner-facing)" section lists'
     hasnot "$f" '"Review ownership" section lists'
   done
   for f in agents/task-master.md .claude/agents/task-master.md; do
     has "$f" 'Commit the handoff note with'
   done
   for f in agents/spec-master.md .claude/agents/spec-master.md; do
     has "$f" 'after every 3 contract files'
   done
   for f in adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md; do
     has "$f" 'is not progress'
   done
   for p in orchestrator task-master spec-master; do
     for f in "agents/$p.md" ".claude/agents/$p.md"; do
       has "$f" 'STATUS: incomplete — checkpoint:'
     done
   done

   # ptr-u13c appends its rows below this line.
   if [ "$fail" -eq 0 ]; then echo "All persona-prose-pins checks passed."; else echo "persona-prose-pins: FAILED"; fi
   exit "$fail"
   ~~~~
18. file: `tests/validate.sh`
   anchor: line matching `echo "FAIL tests/gate-fp-harvest.test.sh"`
   indent: 3
   before:
   ~~~~
     echo "FAIL tests/gate-fp-harvest.test.sh"
     fail=1
   fi
   ~~~~
   after:
   ~~~~
     echo "FAIL tests/gate-fp-harvest.test.sh"
     fail=1
   fi

   echo
   echo "== tests/persona-prose-pins.test.sh: wave-7 prose pins for persona sources, mirrors and ports (Bash, ptr-u13b) =="
   if bash tests/persona-prose-pins.test.sh > /dev/null; then
     echo "OK   tests/persona-prose-pins.test.sh"
   else
     echo "FAIL tests/persona-prose-pins.test.sh"
     fail=1
   fi
   ~~~~
19. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   insert-after:
   ~~~~

   **Persona prose pins (ptr-u13b).** `tests/persona-prose-pins.test.sh`, registered in `tests/validate.sh`, flattens the orchestrator, task-master and spec-master sources and mirrors and the two orchestrator ports, and fails when a ptr-u13b phrase is missing or the old "Review ownership" pointer is back; ptr-u13c appends its rows to it. No version bump.
   ~~~~
20. command: `git add tests/persona-prose-pins.test.sh tests/validate.sh CHANGELOG.md && git commit -m "test(ptr-u13b): persona prose pins and their registration (#565)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `agents/lead-programmer.md`, `agents/reviewer.md`, `agents/scribe.md` and `templates/` (not in the spec's file list for this unit; ptr-u13c edits the lead-programmer surface)
- `bin/` and `scripts/` (ptr-u13a is the script unit; the orchestrator prose here only points at the scripts)
- `tests/writer-tier-consistency.test.js` (the phrases it pins stay verbatim; it is not edited)
- `CONTEXT.md`, `docs/harness-glossary.md` and `docs/adr/` (the scribe lands any glossary change after PASS)
- `.claude/` except what `node bin/cli.js --update` rewrites; never edit a mirror by hand

## Acceptance criteria
1. run: `bash tests/persona-prose-pins.test.sh > /dev/null; echo "exit=$?"`
   exit: 0
   stdout: `exit=0`
   mutation: skip edit 6 (the progress sentence of the orchestrator); a FAIL line for the source and the mirror, and the line reads exit=1.
2. run: `bash tests/persona-prose-pins.test.sh | tail -1`
   exit: 0
   stdout: `All persona-prose-pins checks passed.`
   mutation: skip edit 10 (the task-master sentence); the last line reads persona-prose-pins: FAILED.
3. run: `bash tests/persona-prose-pins.test.sh | grep -c '^ok'`
   exit: 0
   stdout: `26`
   mutation: skip edit 11 (the spec-master edit); two rows print FAIL and stdout is 24.
4. run: `/usr/bin/grep -c 'tests/persona-prose-pins.test.sh' tests/validate.sh`
   exit: 0
   stdout: `4`
   mutation: skip edit 18 (the registration); stdout 0 and the exit is 1.
5. run: `node tests/writer-tier-consistency.test.js | tail -1`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: delete the words `provided it is unchanged` from the Contract-score guard paragraph of agents/orchestrator.md; the last line reads `1 check(s) failed.`
   proof: green at HEAD (a regression guard: this unit keeps the pinned phrases verbatim); scratch run: with those words deleted the suite printed a FAIL line and the last line read 1 check(s) failed.
6. run: `node tests/adapter-protocol-parity.test.js && node tests/adapter-skill-parity.test.js`
   exit: 0
   stdout: `OK   adapters/cursor/agents/reviewer.md inlines roast-work`
   mutation: edit a protocol port to drop its Fourth-verdict header; the parity test exits 1.
   proof: green at HEAD (a regression guard carried over from ptr-u8 criterion 14); this unit edits no protocol port, only the two orchestrator ports.
7. run: `node tests/cli-backfill.test.js | tail -1`
   exit: 0
   stdout: `All cli-backfill tests passed.`
   mutation: skip edit 15 (`node bin/cli.js --update`); the mirror assertions fail and the last line no longer reads that sentence.
   proof: green at HEAD (a mirror guard); scratch run: with the mirror left stale the suite failed.
8. run: `W=$(mktemp -d)/wt; git worktree add --detach "$W" HEAD >/dev/null 2>&1 && (cd "$W" && node bin/cli.js --update >/dev/null 2>&1; git status --porcelain | wc -l); git worktree remove --force "$W"`
   exit: 0
   stdout: `0`
   mutation: skip edit 15 before the commit; the throwaway worktree then shows a non-zero count.
   proof: green at HEAD (a mirror guard); scratch run: with the mirror left stale the worktree after --update showed a non-zero count.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | tail -1); bash hooks/scripts/version-stamp-check.sh "$c~1..$c" | head -1`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 12 (the plugin.json bump) before the commit; the line reads `violation`.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | head -1); bash hooks/scripts/version-stamp-check.sh "$c~1..$c" | head -1`
   exit: 0
   stdout: `version-stamp-check: ok touched: no`
   mutation: also stage agents/lead-programmer.md in the test commit; the line reads touched: yes or violation.
   proof: scratch run: the test commit touches no agents/ or templates/ file and the script printed ok touched: no.
11. run: `node -p "require('./.claude-plugin/plugin.json').version"`
   exit: 0
   stdout: `0.31.180`
   mutation: skip edit 12; stdout 0.31.179.
12. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 13; nothing prints, exit 1.
   proof: green at HEAD (the two versions agree before and after); the mutation breaks the agreement.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; echo "$L" | wc -l`
   exit: 0
   stdout: `2`
   mutation: skip edit 20 (the test commit); one commit remains, stdout 1.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | tail -1); git diff --name-only "$c~1..$c" | grep -vE "^[.]claude/" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md adapters/codex/agents/orchestrator.toml adapters/cursor/agents/orchestrator.md agents/orchestrator.md agents/spec-master.md agents/task-master.md package.json`
   mutation: skip edit 16 (the first commit); the oldest commit is the test commit and the fragment is absent.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | head -1); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `CHANGELOG.md tests/persona-prose-pins.test.sh tests/validate.sh`
   mutation: skip edit 20 (the test commit); the newest commit is the prose commit and the fragment is absent.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"; done | paste -sd" "`
   exit: 0
   stdout: `1 1`
   mutation: skip edit 20; only one commit exists and stdout reads 1.
17. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | grep -cE "^[.]claude/(agent-memory/|reviewed/)"; done | paste -sd" "`
   exit: 0
   stdout: `0 0`
   mutation: skip edit 20; one commit remains and stdout reads 0.
18. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u13b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- agents/orchestrator.md agents/task-master.md agents/spec-master.md | grep -vcE "^[a-z]+\(ptr-u13b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching agents/orchestrator.md after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit makes grep -v count it, so stdout is 1.
19. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip edit 20; the test edits stay uncommitted and stdout is non-zero.
   proof: green at HEAD (the tree is clean before the unit); the mutation leaves tracked edits uncommitted.
20. run: `bash tests/validate-lanes.sh --lanes 4`
   exit: 0
   stdout: `All checks passed.`
   mutation: skip edit 15 and edit 6; the mirror and the pins disagree with the source and the run exits 1.
   proof: scratch run: the lanes gate over the replayed chain printed All checks passed.

## Pre-resolved context
tdd: yes tests/persona-prose-pins.test.sh (the pin test is edit 17 of the second commit; the prose edits land first and criteria 1-3 are the checks)
blast-radius: agents/orchestrator.md:433 agents/orchestrator.md:466 agents/orchestrator.md:485 agents/orchestrator.md:508 agents/orchestrator.md:657 agents/task-master.md:460 agents/spec-master.md:234 adapters/codex/agents/orchestrator.toml:110 adapters/cursor/agents/orchestrator.md:103 tests/writer-tier-consistency.test.js:210 (grep-derived, no graph run)
gate-run: criterion 20 runs the lanes gate in the foreground (about 2-3 minutes; pass the 600000 ms timeout; never background it; it refuses a linked worktree, so use the normal checkout). If it fails only in tests/rollout-preflight.test.sh (AC14/W9) or tests/microworld/dashboard-decision-run.test.js (Test 5), both timing-flaky and unrelated, rerun that test alone and the lanes once more, and report both runs.
gate-refusal: no command in this contract names the persona config file, and none needs to. If any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround).
staging: the first commit command stages explicit paths, then `git add -u -- .claude` for what `--update` rewrites (10 agent mirrors, the config, persona-protocol.md, persona-protocol-slim.md and protocol-digest.md), and unstages agent-memory; if criterion 17 shows an agent-memory path in a commit, STOP and report.
payload-indent: every fenced payload is written with the contract's own 3-space indent; strip exactly 3 leading spaces from each non-empty payload line (empty lines stay empty); a payload line that is indented further keeps its extra spaces. Use the Edit tool for every before/after and insert-after item (each `before:` is a verbatim run of lines, or a verbatim part of one line, from the file) and the Write tool for the new test file.
order: edits 2-16 are the first commit (the prose, the bump, `--update`), edits 17-20 the second; do not run `--update` after the second commit.
commit-message: docs(ptr-u13b): ladder and checkpoint wording in the orchestration prose (0.31.180) (#565)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
commit-message: test(ptr-u13b): persona prose pins and their registration (#565)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
~~~
unit: ptr-u13b (#565)
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
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
criterion 19: <FILL: exit and stdout>
criterion 20: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
