Unit: lp-hdg

## Objective
Retire `human-decision-gate.sh` in code (plan change 3, decision D4, step "U7a lp-hdg"). The script becomes a no-op stub that reads stdin and exits 0. Its two `hooks/hooks.json` registrations stay, by the same reasoning as D5: `tests/abtest-arms.test.sh:141-142` pins the Bash matcher to exactly `harness-integrity-gate.sh human-decision-gate.sh reviewed-path-gate.sh` and the pruned copy to `human-decision-gate.sh`, and the plan forbids editing that file. The gate's test suite, its sweep tool and every test case that asserts its deny behaviour go. A new `code-hdg` mode in `tests/escalation-retired.test.sh` enforces it. No version bump.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, step "U7a lp-hdg", decisions D4 and D5, Context bullet "Escalation shared code to KEEP", Risk R4. This file is the contract of record and supersedes the plan's U7a file list and criterion 1 where they differ (see Pre-resolved context). Dispatch after lp-escprose has PASSed. Implementer tier: sonnet.

## Affected files
- `hooks/scripts/human-decision-gate.sh` (rewrite as stub, mode 755 kept); `.claude/hooks/scripts/human-decision-gate.sh` (regenerated, never hand-edited)
- `tests/human-decision-gate.test.sh`, `tests/hdg-differential-sweep.sh` (`git rm` both)
- `tests/validate.sh` (delete the `human-decision-gate.test.sh` block near :706; reword the :535 header to name `reviewed-path-gate.sh` only)
- `tests/watch-map.json` (drop `bash tests/human-decision-gate.test.sh` from every `run[]`, drop it and the gate path from every `watch[]`; drop an entry left with an empty `run[]`)
- Tests that assert the gate's deny behaviour or its source text: `tests/refusal-disclosure.test.sh` (hdg half), `tests/review-gating-off.test.sh` (case k), `tests/state-access-capability-regression.test.sh` (check 2), `tests/state-access-constraints.test.sh` (check 2c near :429), `tests/state-distinctions-manifest.test.sh` (the two rows whose file is the gate), `tests/harness-integrity-gate.test.sh` (the `tests/human-decision-gate.test.sh|1` row of the C4.1 table), `tests/hook-latency-budget.test.sh:37` (path to a deleted file)
- `scripts/rollout-preflight.sh` (:81 and :98 entries)
- `tests/escalation-retired.test.sh` (add mode `code-hdg`)

## Ordered edits
1. Stub: shebang, a 2-4 line comment ("retired in 0.32.0 by lean-pipeline D4; registration kept for A/B harness parity, see D5"), `cat >/dev/null`, `exit 0`. At most 15 lines. Keep every phrase of `c41_pattern` (`tests/harness-integrity-gate.test.sh`, C4.1) out of the comment: that sweep greps the whole repo live, and any new hit-bearing file fails C4.1a.
2. Delete the two test files and their validate.sh and watch-map.json references. Edit each listed test only to remove the cases about the deny behaviour or the source text of the gate. Name each one in the CHANGELOG bullet.
3. `tests/escalation-retired.test.sh code-hdg` fails and prints each failing check unless all of these hold: (a) the gate is at most 15 lines and exits 0 with empty stdout, both for a Bash payload from `lead-programmer` that writes the human-review decision file and for a Write payload to that path (assemble the path from split literals); (b) its `.claude` mirror is byte-identical; (c) both deleted test files are absent; (d) neither `tests/validate.sh` nor `tests/watch-map.json` names the deleted suite; (e) `hooks/hooks.json` names the gate exactly twice (D5 parity). Register `bash tests/escalation-retired.test.sh code-hdg` in `tests/validate.sh`.
4. `node bin/cli.js --update --force-render`. Stage the mirrors as `git add -- .claude adapters`, never by naming the persona config file, which `harness-integrity-gate` scans for. Add one `[Unreleased]` CHANGELOG bullet.

## Do NOT touch
- `hooks/hooks.json`, `.claude/settings.json`, `hooks/scripts/harness-integrity-gate.sh` (Set B), `tests/abtest-arms.test.sh`, `eval/`
- `agents/`, `templates/`, `commands/`, `skills/`, `adapters/*/agents*`, `adapters/*/rules/`: no prose about this gate may come back (lp-escprose removed it; the `prose` mode fails on `human-decision-gate`)
- `hooks/scripts/lib/benign-command.sh`, `reviewed-path-gate.sh` and its tests (U9); `hooks/scripts/stop-gate.sh`, `lib/stop-gate-core.sh` (U8a); `bin/microworld-dashboard/`, `bin/escalation-card.sh`, `heavy-trigger.sh` (U7b); `tests/marker-write.test.sh`, `tests/cli-backfill.test.js`, `tests/cli-hook-propagation.test.js` (they use the file as a sample and still pass on the stub)
- `CONTEXT.md`, `docs/`, `.claude-plugin/plugin.json`

## Acceptance criteria
1. run: `bash tests/escalation-retired.test.sh code-hdg` → exit 0. mutation: `git show 94b55ee3:hooks/scripts/human-decision-gate.sh > hooks/scripts/human-decision-gate.sh` (the old gate) → exit 1.
2. run: `grep -c 'human-decision-gate' tests/refusal-disclosure.test.sh` → `0`; and `bash tests/refusal-disclosure.test.sh && bash tests/review-gating-off.test.sh && bash tests/state-access-capability-regression.test.sh && bash tests/state-access-constraints.test.sh && bash tests/state-distinctions-manifest.test.sh && bash tests/watch-map-registration.test.sh` → exit 0. mutation: restore `tests/review-gating-off.test.sh` from 94b55ee3 → exit 1 (case k expects 2 from the stub).
3. run (after the final commit): `bash tests/abtest-arms.test.sh` → exit 0. mutation: in a scratch `git worktree` of HEAD, delete the Bash-matcher `human-decision-gate.sh` line of `hooks/hooks.json`, commit there, run that worktree's copy → exit 1.
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` → exit 0 (C-mirror).
5. run: `bash tests/validate.sh` → exit 0 (C-full, run once by the reviewer after the final commit).

## Pre-resolved context
- Today (2026-10-30, 94b55ee3): criterion 1 exits 127 (no test file); criterion 2's grep gives 5; the gate is 758 lines; the tests in criteria 2 and 3 pass (baseline measured).
- Plan gap resolved here: the plan's U7a removed the hooks.json lines and asserted their absence, yet kept `abtest-arms.test.sh` passing and untouched. Both cannot hold. The stub honours the plan's explicit constraints (D5, U4 criterion 3). Dropping the registrations is the D5 follow-up. Also missing from the plan list: watch-map.json and five behaviour tests. `bin/cli.js` needs no edit, because hook copies are globbed.
- `abtest-arms.test.sh` asserts `git diff --quiet HEAD -- hooks`, so run it only after committing.
- A subagent's Write/Edit to a Set B path is denied outright, with no ask. Nothing in this unit writes one.

## Escalation
If `harness-integrity-gate.sh` (or any gate) blocks a write, stop and report the path and the refusal text. Never reword, split or route around the command. If a test outside the affected files fails because of the stub, stop and report its path and line.
