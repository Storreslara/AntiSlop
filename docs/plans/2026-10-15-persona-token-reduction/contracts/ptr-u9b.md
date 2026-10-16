Unit: ptr-u9b

## Objective
`agents/orchestrator.md`'s "Per-unit model routing" section is at most 2,500 bytes (awk range check, baseline 6,226) and tells the orchestrator to run `bin/ladder-tier.sh` before every per-unit dispatch and pass its tier, to run `bin/escalation-card.sh` on `EXHAUSTED` and go to "At the 2-FAIL cap", and that a `Suggested model` tag can only raise the tier; "At the 2-FAIL cap" names the card script; every phrase the existing tests pin stays. Version 0.31.179, CHANGELOG entry, mirrors refreshed by `node bin/cli.js --update`.

## Retrieval
GitHub issues: `gh issue view 560 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/persona-token-reduction`. Spec: `docs/plans/2026-10-15-persona-token-reduction.md`, section "Step U9".

## Affected files
- `agents/orchestrator.md` (anchor: line matching `## Per-unit model routing`)
- `.claude-plugin/plugin.json` (anchor: line matching `"version": "0.31.178",`)
- `package.json` (anchor: line matching `"version": "0.31.178",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- `.claude/agents/*.md` and the other mirrors `node bin/cli.js --update` rewrites (regenerated, never edited by hand)

## Ordered edits
1. command: `test "$(node -p "require('./.claude-plugin/plugin.json').version")" = 0.31.178 && test -f bin/ladder-tier.sh && test -f bin/escalation-card.sh && git log --format=%s | grep -qE '^[a-z]+\(ptr-u9a\): '`
   expect: 0
2. file: `agents/orchestrator.md`
   anchor: line matching `## Per-unit model routing`
   indent: 3
   before:
   ```
   ## Per-unit model routing
   When dispatching a unit to `lead-programmer`, pass the tier the **Escalation
   ladder** below gives as the dispatch's `model` parameter. A `Suggested model: haiku|sonnet|opus`
   tag can raise that tier, never lower it. You may omit the parameter only when
   that tier equals lead-programmer's frontmatter `model:`, which is the default,
   not an absolute (its value and history: CONTEXT.md's **Writer tier** entry). An
   `opus` dispatch after ladder exhaustion is expected when the human chose option
   (a) or (b) at **At the 2-FAIL cap**. Per Claude Code's per-invocation model override (env
   var > per-call param > frontmatter), if `CLAUDE_CODE_SUBAGENT_MODEL` is set
   it silently wins over any model routing in this section — check for it if
   routing ever appears to have no effect.

   **`defaultImplementerModel` config precedence.** Before falling back to that
   frontmatter default, check this project's `.claude/persona-config.json` for a
   `defaultImplementerModel` field — the full precedence is per-dispatch
   `Suggested model` tag > `defaultImplementerModel` config field > frontmatter
   default (CONTEXT.md's **Writer tier** entry), except that the tag can only
   raise the tier the **Escalation ladder** below gives, never lower it. Read the
   raw value yourself.
   Only an **absent** key resolves to that frontmatter default; a value present
   but outside the recognised set (`templates/persona-config.schema.json`'s
   `defaultImplementerModel` enum) resolves to the **more** capable tier,
   `opus`, never to the cheaper one — the same direction `humanReviewMode`'s
   own unrecognised-value fallback fails toward escalation. Nothing backfills
   this key into an already-adapted project on its own; until a dedicated
   backfill step lands, this absent-key fallback is how such a project gets
   the default.

   **Escalation ladder.** Each implementer tier gets two attempts at a unit. The
   **default tier** is the `defaultImplementerModel` value resolved above, or
   lead-programmer's frontmatter `model:` when the key is absent. The ladder is
   the tiers from the default tier upward, in the order `haiku`, `sonnet`, `opus`,
   two entries each: from `haiku` it is `haiku`, `haiku`, `sonnet`, `sonnet`,
   `opus`, `opus`; from `sonnet`, `sonnet`, `sonnet`, `opus`, `opus`; from `opus`,
   `opus`, `opus`.

   **Check for a prior `.fail` record before ANY per-unit dispatch**, not only
   right after an in-session FAIL — a fresh session has no memory of a prior
   one's FAIL. Count the unit's FAIL blocks, n: n is 0 when
   `test -f .claude/reviewed/<task-id>.fail` fails, and otherwise
   `grep -c '^FAIL <task-id> ' .claude/reviewed/<task-id>.fail`. Dispatch
   attempt n+1 on the ladder's entry n+1. When n reaches or exceeds the ladder's
   length, that is **ladder exhaustion**: dispatch nothing and go to **At the 2-FAIL
   cap**. The ladder depends only on n, the default tier and whether any block
   predates the **Haiku-default cutover** below, so a fresh session
   computes the same tier the session that saw the FAIL would have; which tier
   wrote a block is never needed (a block's `tier:` line is for the human reader;
   the ladder never reads it). Fail closed: if n cannot be read (the grep
   errors, or the file exists and no line matches), dispatch on `opus`. Every
   re-dispatch carries the prior defect history; with a fix contract
   (**Fix-contract re-dispatch**), it carries the fix contract instead of the
   bare defect list. The **Implementer-tier ratchet** (CONTEXT.md's **Writer
   tier** and **Implementer-tier ratchet** entries) is this rule: never a tier
   cheaper than the ladder's entry.
   ```
   after:
   ```
   ## Per-unit model routing
   Before every per-unit `lead-programmer` dispatch, run `bash bin/ladder-tier.sh
   <task-id> --contract <contract file>` and pass its tier as the dispatch's `model`
   parameter. A `Suggested model: haiku|sonnet|opus` tag can raise that tier, never
   lower it. On `EXHAUSTED`, dispatch nothing: run `bash bin/escalation-card.sh
   <task-id>` and go to **At the 2-FAIL cap**. A set `CLAUDE_CODE_SUBAGENT_MODEL`
   silently wins over this routing.

   **`defaultImplementerModel` precedence.** The `Suggested model` tag > `defaultImplementerModel` config field > frontmatter default (CONTEXT.md's **Writer tier** entry). Only an **absent** key resolves to that frontmatter default; a value present but
   outside the recognised set (`templates/persona-config.schema.json`'s `defaultImplementerModel` enum) resolves to the **more** capable tier, `opus`.

   **Escalation ladder.** Each implementer tier gets two attempts at a unit, from
   the default tier upward. `bin/ladder-tier.sh` holds the arithmetic (its header
   comment) and prints `ladder-tier: <tier> n=<n> ladder=<...> reason=<word>`: n is
   the FAIL-block count, a newer PASS marker expires the record, and a read error is
   `opus`. Every re-dispatch carries the prior defect history or the fix contract
   (**Fix-contract re-dispatch**).

   **Haiku-default cutover: 2026-10-08T17:28:48Z.** The script reads this line; a
   unit with an earlier FAIL block starts at the more capable of `sonnet` and the
   default.

   **Contract-score guard.** When the ladder starts at `haiku`, the script runs
   `node bin/contract-guard.js <contract> --unit=<task-id>`; unless its first line
   starts `contract-guard: haiku `, it is a **guard demotion** to `sonnet`. For a unit
   sliced before contract files, save its issue body to a file and pass that. On
   `reason=guard-demotion`, rerun the guard for its line, tell the user in one line
   quoting it, and append `RULING <UTC ISO-8601 timestamp> unit=<task-id>
   decision=contract-guard sonnet: <guard line>` to `.claude/orchestrator-rulings.log`
   (**Rulings ledger**); the script never writes. Scoring is pure, so a fresh session
   computes the same ladder, provided it is unchanged (the contract of record). A
   scribe dispatch with a scribe contract that would go on `haiku` runs the guard with
   `--shape=scribe` and goes on `sonnet` when it fails.
   ```
3. file: `agents/orchestrator.md`
   anchor: line matching `**Haiku-default cutover: 2026-10-08T17:28:48Z.** FAIL blocks whose header timestamp is`
   indent: 3
   before:
   ```
   **Haiku-default cutover: 2026-10-08T17:28:48Z.** FAIL blocks whose header timestamp is
   earlier than this were written under ADR-0026's `sonnet` default, and the
   count alone cannot say which tier wrote them. Fail closed: a unit with any
   such block uses the ladder that starts at the more capable of `sonnet` and the
   default tier: `sonnet`, `sonnet`, `opus`, `opus` when the default tier is
   `haiku` or `sonnet`, and `opus`, `opus` when it is `opus`.

   **Contract-score guard.** When the ladder above starts at `haiku`, run the
   guard before every dispatch of the unit: `node bin/contract-guard.js
   docs/plans/<plan-slug>/contracts/<unit-id>.md --unit=<task-id>` on both paths
   (the contract file the dispatch cites). A unit sliced before contract files is
   scored from its plan file (`node bin/contract-guard.js <plan-file>
   --unit=<task-id>`, the fast path) or from the retrieval contract's
   `gh issue view <N>` command with `--json body -q .body` piped into
   `node bin/contract-guard.js - --unit=<task-id>` (the standard path). Unless it exits 0 and its first stdout line starts with
   `contract-guard: haiku `, the unit uses the ladder that starts at `sonnet`
   (`sonnet`, `sonnet`, `opus`, `opus`, so ladder exhaustion comes at n = 4): a
   **guard demotion**. A contract held in no file or issue body, a missing script
   and a scorer error all count the same. On a guard demotion, tell the user in
   one line that quotes the guard's line, and append `RULING <UTC ISO-8601
   timestamp> unit=<task-id> decision=contract-guard sonnet: <guard line>` to
   `.claude/orchestrator-rulings.log` (**Rulings ledger** above). Scoring is pure,
   so the guard re-runs on every dispatch and a fresh session computes the same
   ladder from n and the contract of record, provided it is unchanged (a plan
   file revised between dispatches can demote a unit that passed earlier, even
   mid-ladder); it can only move a unit onto a more capable
   ladder, and a `Suggested model` tag can still raise the tier. It scores the
   unit's contract of record, never a fix contract. A scribe dispatch that
   carries a scribe dispatch contract and would go on `haiku` runs the same check
   with `--shape=scribe`, and goes on `sonnet` when it fails. `dispatchHygiene.mode`
   stays `warn` and scribe stays out of `gatedAgents`.

   **Implementer-tier fail ratchet expiry.** A fail record for unit `X` stops
   disqualifying `X` from a cheaper implementer tier once a pass marker for `X`
   exists and is newer than the fail record. Until then it disqualifies
   unchanged; while a unit is mid-retry with no PASS yet, nothing expires. An
   expired record counts as n = 0.

   ### Dispatch-model routing for spec-master, milestone-auditor, and task-master
   ```
   after: `### Dispatch-model routing for spec-master, milestone-auditor, and task-master`
4. file: `agents/orchestrator.md`
   anchor: line matching `defect history to the user (every FAIL block in the`
   indent: 3
   before:
   ```
   defect history to the user (every FAIL block in the `.fail` record and every fix-attempt commit), then ask the human how to proceed via `AskUserQuestion`.
   ```
   after:
   ```
   defect history to the user (`bash bin/escalation-card.sh <task-id>` prints each FAIL block's header, tier line and first defect line, then every fix-attempt commit subject), then ask the human how to proceed via `AskUserQuestion`.
   ```
5. file: `.claude-plugin/plugin.json` (version 0.31.179)
   anchor: line matching `"version": "0.31.178",`
   before: `"version": "0.31.178",`
   after: `"version": "0.31.179",`
6. file: `package.json` (version 0.31.179)
   anchor: line matching `"version": "0.31.178",`
   before: `"version": "0.31.178",`
   after: `"version": "0.31.179",`
7. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 3
   insert-after:
   ```

   **Orchestrator routing section points at the ladder scripts (ptr-u9b, 0.31.179).** `agents/orchestrator.md`'s "Per-unit model routing" section shrinks from 6,226 to 2,392 bytes: it tells the orchestrator to run `bin/ladder-tier.sh` before every per-unit `lead-programmer` dispatch and pass its tier, to run `bin/escalation-card.sh` on `EXHAUSTED` and go to "At the 2-FAIL cap", and that a `Suggested model` tag can only raise the tier. The ladder arithmetic, the cutover comparison and the expiry rule now live in the header comment of `bin/ladder-tier.sh`; the precedence and absent-key text, the Haiku-default cutover line (the script and `scripts/unit-outcomes.js` read it) and the Contract-score guard paragraph stay, because tests and scripts pin them. "At the 2-FAIL cap" names the card script for its defect history. Mirrors refreshed by `node bin/cli.js --update`.
   ```
8. command: `node bin/cli.js --update`
   expect: 0
9. command: `git add agents/orchestrator.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git reset -q -- .claude/agent-memory && git commit -m "docs(ptr-u9b): orchestrator routing section points at the ladder scripts (0.31.179) (#560)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `bin/` and `tests/` (the scripts and the test are ptr-u9a; this unit edits none of them)
- `templates/persona-protocol.md`, `bin/cli.js` and the orchestrator ports under `adapters/` (the ports carry no ladder text)
- `agents/lead-programmer.md`, `agents/reviewer.md`, `agents/scribe.md`, `agents/task-master.md` and `agents/spec-master.md` (not in the spec's file list)
- `CONTEXT.md`, `docs/harness-glossary.md` and `docs/adr/` (the scribe lands any glossary change after PASS)
- `.claude/` except what `node bin/cli.js --update` rewrites; never edit a mirror by hand

## Acceptance criteria
1. run: `test "$(awk '/^## Per-unit model routing/,/^### Dispatch-model routing/' agents/orchestrator.md | wc -c)" -le 2500 && echo section-within-2500`
   exit: 0
   stdout: `section-within-2500`
   mutation: skip edit 3 (the second half stays); the section is over 2500 bytes, nothing prints and the exit is 1.
2. run: `awk '/^## Per-unit model routing/,/^### Dispatch-model routing/' agents/orchestrator.md | wc -c`
   exit: 0
   stdout: `2392`
   mutation: skip edit 2; the first half of the old section stays and the count is larger.
3. run: `test "$(awk '/^## Per-unit model routing/,/^### Dispatch-model routing/' .claude/agents/orchestrator.md | wc -c)" -le 2500 && echo mirror-within-2500`
   exit: 0
   stdout: `mirror-within-2500`
   mutation: skip command 8 (`node bin/cli.js --update`) before the commit; the mirror keeps the old section, nothing prints and the exit is 1.
4. run: `tr -s ' \n' ' ' < agents/orchestrator.md | /usr/bin/grep -o 'bin/ladder-tier.sh' | wc -l`
   exit: 0
   stdout: `2`
   mutation: skip edit 2; the count is 0 (the old prose never names the script).
5. run: `bash bin/ladder-tier.sh no-such-unit-xyz | /usr/bin/grep -c 'fail-closed'`
   exit: 1
   stdout: `0`
   mutation: delete the **Haiku-default cutover: ...** line of agents/orchestrator.md; the script cannot read the cutover and prints reason=fail-closed, stdout `1`.
   proof: scratch run: with the cutover line deleted the script printed reason=fail-closed; with the finished change it printed none.
6. run: `node tests/writer-tier-consistency.test.js | tail -1`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: delete the words `provided it is unchanged` from the Contract-score guard paragraph of agents/orchestrator.md; the last line reads `1 check(s) failed.`
   proof: the same mutation is the proof recorded by ptr-u8 criterion 13.
7. run: `node tests/default-implementer-model.test.js | tail -1`
   exit: 0
   stdout: `All default-implementer-model checks passed.`
   mutation: delete the sentence `Only an **absent** key resolves to that frontmatter default` from agents/orchestrator.md; the last line no longer reads that sentence.
   proof: scratch run: with the sentence deleted the suite printed a FAIL line and exited 1.
8. run: `bash tests/ladder-tier.test.sh | tail -1`
   exit: 0
   stdout: `All ladder-tier checks passed.`
   mutation: delete the Haiku-default cutover line from agents/orchestrator.md; the pre-cutover cases fail and the last line is not that sentence.
   proof: scratch run: with the cutover line deleted the suite exited 1.
9. run: `awk '/^\*\*At the 2-FAIL cap\*\*/,/^- \*\*\(a\)/' agents/orchestrator.md | /usr/bin/grep -c 'bin/escalation-card.sh'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; stdout `0` and exit 1.
10. run: `tr -s ' \n' ' ' < agents/orchestrator.md | /usr/bin/grep -c 'Implementer-tier fail ratchet expiry'`
   exit: 1
   stdout: `0`
   mutation: skip edit 3; the old expiry paragraph stays and stdout is `1`.
11. run: `/usr/bin/grep -c '^\*\*Escalation ladder\.\*\* Each implementer tier gets two attempts' agents/orchestrator.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the old paragraph carries the same words, so the count stays `1` (a regression guard, not a red check).
   proof: scratch run: the finished orchestrator.md printed 1; the old one also printed 1 (guard).
12. run: `node tests/adapter-protocol-parity.test.js && node tests/adapter-skill-parity.test.js`
   exit: 0
   stdout: `OK   adapters/cursor/agents/reviewer.md inlines roast-work`
   mutation: edit a protocol port to drop its Fourth-verdict header; the parity test exits 1.
   proof: regression guard carried over from ptr-u8 criterion 14.
13. run: `node tests/cli-backfill.test.js | tail -1`
   exit: 0
   stdout: `All cli-backfill tests passed.`
   mutation: skip command 8; the mirror assertions fail and the last line no longer reads that sentence.
14. run: `W=$(mktemp -d)/wt; git worktree add --detach "$W" HEAD >/dev/null 2>&1 && (cd "$W" && node bin/cli.js --update >/dev/null 2>&1; git status --porcelain | wc -l); git worktree remove --force "$W"`
   exit: 0
   stdout: `0`
   mutation: skip command 8 before the commit; the throwaway worktree then shows a non-zero count.
   proof: scratch run: with the mirror left stale the worktree after --update showed a non-zero count.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u9b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do bash hooks/scripts/version-stamp-check.sh "$c~1..$c" | head -1; done`
   exit: 0
   stdout: `version-stamp-check: ok touched: yes`
   mutation: skip edit 5 (the plugin.json bump) before the commit; the line reads `violation`.
   proof: scratch commit without the bump; version-stamp-check printed violation (as recorded for ptr-u8).
16. run: `node -p "require('./.claude-plugin/plugin.json').version"`
   exit: 0
   stdout: `0.31.179`
   mutation: skip edit 5; stdout `0.31.178`.
17. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 6; nothing prints, exit 1.
18. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u9b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git log -1 --format=%B "$c" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"; done`
   exit: 0
   stdout: `1`
   mutation: omit the second -m argument of command 9; stdout `0` and exit 1.
   proof: scratch run: the replayed commit message carried the trailer line once.
19. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u9b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- agents/orchestrator.md | grep -vcE '^[a-z]+\(ptr-u9b\): '`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching agents/orchestrator.md after the unit commit; stdout `1`.
   proof: scratch run: with no later commit the count printed 0 (exit 1).
20. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u9b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | grep -vE '^[.]claude/' | LC_ALL=C sort | paste -sd' '; done`
   exit: 0
   stdout: `.claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md package.json`
   mutation: also stage `bin/ladder-tier.sh`; the list gains that path.
   proof: scratch run: the committed replay printed exactly that list.
21. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(ptr-u9b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; for c in $L; do git diff --name-only "$c~1..$c" | grep -cE '^[.]claude/(agent-memory/|reviewed/)'; done`
   exit: 1
   stdout: `0`
   mutation: drop the `git reset -q -- .claude/agent-memory` step of command 9 while a memory file is dirty; stdout `1`.
   proof: scratch run: the replayed commit touched no agent-memory path.
22. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave the edits of command 8 unstaged; stdout is non-zero.
   proof: scratch run: after the replayed commit the tracked tree was clean.
23. run: `bash tests/validate-lanes.sh --lanes 4`
   exit: 0
   stdout: `All checks passed.`
   mutation: skip edit 3 and edit 6; the version-sync and section checks print FAIL and the run exits 1.
   proof: scratch run: the lanes gate over the replayed chain printed All checks passed.

## Pre-resolved context
tdd: no prose edit; the existing writer-tier and default-implementer-model suites pin the retained text, and criteria 1-10 are the checks
blast-radius: agents/orchestrator.md:465 agents/orchestrator.md:394 agents/orchestrator.md:520 tests/writer-tier-consistency.test.js:75 tests/writer-tier-consistency.test.js:194 tests/writer-tier-consistency.test.js:209 tests/default-implementer-model.test.js:110 scripts/unit-outcomes.js:106 commands/start-feature-team.md:49 (grep-derived, no graph run)
gate-run: criterion 23 runs the lanes gate in the foreground (about 2-3 minutes; pass the 600000 ms timeout; never background it; it refuses a linked worktree, so use the normal checkout). If it fails only in tests/rollout-preflight.test.sh (AC14/W9) or tests/microworld/dashboard-decision-run.test.js (Test 5), both timing-flaky and unrelated, rerun that test alone and the lanes once more, and report both runs.
gate-refusal: no command in this contract names the persona config file, and none needs to. If any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround).
staging: the commit command stages explicit paths and unstages agent-memory; if criterion 20 shows an agent-memory path in the commit, STOP and report.
payload-indent: every fenced payload is written with the contract's own 3-space indent; strip exactly 3 leading spaces from each non-empty payload line (empty lines stay empty). The Edit tool is the way to apply the two section edits; each `before:` is a verbatim run of lines from agents/orchestrator.md.
commit-message: docs(ptr-u9b): orchestrator routing section points at the ladder scripts (0.31.179) (#560)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
review-packet:
~~~
unit: ptr-u9b (#560)
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
criterion 21: <FILL: exit and stdout>
criterion 22: <FILL: exit and stdout>
criterion 23: <FILL: exit and stdout>
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
