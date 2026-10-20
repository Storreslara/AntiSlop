Unit: aof-u1

## Objective
Fix round 1 for aof-u1 (fix-of: 2026-10-20T03:15:09Z). `tests/writer-tier-consistency.test.js` check AC-P4 pins the needle `node .claude/bin/contract-guard.js`, so `node tests/writer-tier-consistency.test.js` exits 0 again. Two reviewer notes ride in the same commit: `agents/task-master.md` runs `node .claude/bin/contract-score.js`, and `agents/orchestrator.md` limits the `opus` helper-missing fallback to scripts that choose a tier. Version 0.31.183.

## Retrieval
GitHub issues: `gh issue view 630 --repo Storreslara/AntiSlop`. Original contract: `docs/plans/antislop-overhead-fixes/contracts/aof-u1.md`, which stays unedited. This file is the fix contract of record. Do NOT run `bash tests/validate.sh` (about a 30 minute run); the reviewer runs it to completion.

## Affected files
- `tests/writer-tier-consistency.test.js` (anchor: line matching `'node bin/contract-guard.js', 'contract-guard: haiku',`). Outside the original contract's list; recorded deviation.
- `agents/task-master.md` (anchor: line matching `scores a contract against`; also `bin/contract-score.js --rubric=v2 <contract>` and `bin/contract-score.js --rubric=v2 --shape=scribe <contract>`)
- `agents/orchestrator.md` (anchor: line matching `If one is missing, take that script's own fail-closed result`)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.182",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- `.claude/agents/orchestrator.md`, `.claude/agents/task-master.md` and the persona config's `fileHashes`: generated only by `node bin/cli.js --update`.
- Already in the aof-u1 commit and accepted by the reviewer, listed so no one reverts them: `tests/cli-backfill.test.js` (fixture change) and the `buildBinHelperSpecs` export in `bin/cli.js`. Make no further edit to either.

## Ordered edits
1. file: `tests/writer-tier-consistency.test.js`
   anchor: line matching `'node bin/contract-guard.js', 'contract-guard: haiku',`
   before: `'node bin/contract-guard.js', 'contract-guard: haiku',`
   after: `'node .claude/bin/contract-guard.js', 'contract-guard: haiku',`
2. file: `agents/task-master.md`
   anchor: line matching `scores a contract against`
   before:
   ~~~
     content-typed, and `node bin/contract-score.js` scores a contract against
   ~~~
   after:
   ~~~
     content-typed, and `node .claude/bin/contract-score.js` scores a contract against
   ~~~
   indent: 2
3. file: `agents/task-master.md`
   anchor: line matching `bin/contract-score.js --rubric=v2 <contract>`
   before:
   ~~~
     `node bin/contract-score.js --rubric=v2 <contract>` on each contract and
   ~~~
   after:
   ~~~
     `node .claude/bin/contract-score.js --rubric=v2 <contract>` on each contract and
   ~~~
   indent: 2
4. file: `agents/task-master.md`
   anchor: line matching `bin/contract-score.js --rubric=v2 --shape=scribe <contract>`
   before:
   ~~~
   `node bin/contract-score.js --rubric=v2 --shape=scribe <contract>` and
   ~~~
   after:
   ~~~
   `node .claude/bin/contract-score.js --rubric=v2 --shape=scribe <contract>` and
   ~~~
   indent: 0
5. file: `agents/orchestrator.md`
   anchor: line matching `If one is missing, take that script's own fail-closed result`
   before:
   ~~~
   If one is missing, take that script's own fail-closed result (`opus`), append `RULING <UTC ISO-8601 timestamp> unit=<task-id> decision=helper missing: <path>: opus` to the rulings ledger,
   ~~~
   after:
   ~~~
   If one is missing, the `opus` fallback applies only to `ladder-tier.sh` and `reviewer-tier.sh`, the scripts that choose a tier; for any other helper, substitute no result. In every case append `RULING <UTC ISO-8601 timestamp> unit=<task-id> decision=helper missing: <path>` (add `: opus` only for a script that chooses a tier) to the rulings ledger,
   ~~~
   indent: 0
   note: the before text is a substring of the line; replace only that text.
6. file: `.claude-plugin/plugin.json` (version 0.31.183)
   anchor: line matching `"version": "0.31.182",`
   before: `"version": "0.31.182",`
   after: `"version": "0.31.183",`
7. file: `package.json` (version 0.31.183)
   anchor: line matching `"version": "0.31.182",`
   before: `"version": "0.31.182",`
   after: `"version": "0.31.183",`
8. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   insert-after: `**aof-u1 fix round 1 (#630, 0.31.183).** Re-pins the AC-P4 needle in tests/writer-tier-consistency.test.js to node .claude/bin/contract-guard.js. agents/task-master.md runs node .claude/bin/contract-score.js. agents/orchestrator.md limits the opus helper-missing fallback to ladder-tier.sh and reviewer-tier.sh.`
9. command: `node bin/cli.js --update`
   expect: 0
10. command: `git add tests/writer-tier-consistency.test.js agents/task-master.md agents/orchestrator.md CHANGELOG.md package.json .claude-plugin/plugin.json && git add -u -- .claude && git commit -m "fix(aof-u1): re-pin AC-P4 to .claude/bin and tidy helper prose (0.31.183) (#630)"`
    expect: 0

## Do NOT touch
- `docs/plans/antislop-overhead-fixes/contracts/aof-u1.md`: the original contract is not edited.
- `tests/validate.sh`: do not run it and do not edit it; the reviewer runs it to completion.
- `bin/cli.js` and `tests/cli-backfill.test.js`: already correct in the aof-u1 commit.
- `tests/bin-helpers-scaffold.test.sh`: no edit; the five `bin/` helper scripts are not edited either.
- `.claude/agents/orchestrator.md` and `.claude/agents/task-master.md`: no hand edits, only through `node bin/cli.js --update`.

## Acceptance criteria
1. run: `node tests/writer-tier-consistency.test.js`
   exit: 0
   stdout: `All writer-tier-consistency checks passed.`
   mutation: skip edit 1; the AC-P4 check fails and the exit is 1.
2. run: `grep -c 'node bin/contract-score.js' agents/task-master.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 2, 3 or 4; the count is 1 or more and the exit is 0.
3. run: `grep -cF 'the scripts that choose a tier' agents/orchestrator.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; stdout `0`, exit 1.
4. run: `grep -cF "own fail-closed result" agents/orchestrator.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 5; stdout `1`, exit 0.
5. run: `test "$(grep -cE 'bash bin/(ladder-tier|escalation-card)\.sh|node bin/contract-guard\.js|bash hooks/scripts/reviewer-tier\.sh' agents/orchestrator.md agents/task-master.md | awk -F: '{s+=$2} END{print s}')" = 0`
   exit: 0
   stdout: `empty`
   mutation: write `bash bin/ladder-tier.sh` into agents/orchestrator.md; exit 1.
6. run: `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: skip edit 6; the line no longer reads ok (the script reads only plugin.json).
7. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;process.exit(a===b&&a==='0.31.183'?0:1)" && echo version-sync: ok`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 7; exit 1, nothing prints.
8. run: `git status --porcelain --untracked-files=no`
   exit: 0
   stdout: `empty`
   mutation: skip edit 9; the regenerated mirrors are left modified and stdout lists them.

## Pre-resolved context
tdd: no the test file edit re-pins an existing check; criterion 1 is the red-to-green proof
blast-radius: tests/writer-tier-consistency.test.js:209 agents/orchestrator.md:493 agents/orchestrator.md:588 agents/task-master.md:142 agents/task-master.md:196 agents/task-master.md:374
commit-message: fix(aof-u1): re-pin AC-P4 to .claude/bin and tidy helper prose (0.31.183) (#630)
review-packet:
~~~
unit: aof-u1 fix round 1 (#630)
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
fix-of: 2026-10-20T03:15:09Z
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
