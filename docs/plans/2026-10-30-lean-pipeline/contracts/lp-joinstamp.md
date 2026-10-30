Unit: lp-joinstamp

## Objective
Remove the review-join stamps and the flag tombstones from the route gate, the state library and the prose (plan change 4, decision D7, step "U8b lp-joinstamp"). After lp-stopgate nothing reads a stamp, so the route gate stops writing them. The reviewer-dispatch block for a bad `name:`, the privileged-name forgery block and the one-unit-mid-review block (a gated dispatch while a `.pending-review.*` flag stands exits 2) all stay. The tombstones go too: the new stop gate drops flags only by deleting them, so the resurrection guard has nothing left to protect. A flag that a non-gate writer re-creates now blocks the next gated dispatch, which fails closed. No version bump.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, step "U8b lp-joinstamp", D7, Risk R2. This file is the contract of record and supersedes the plan's U8b file list and criteria where they differ (see Pre-resolved context). Dispatch after lp-stopgate has PASSed. Implementer tier: sonnet.

## Affected files
- `hooks/scripts/lib/reviewer-route-gate-core.sh`: delete the `state_drop_resurrected_flags` call (:33) and the whole `Unit:`-line block (:86-155: first-line parse, advisory stamp, prior-marker probe, stamp write, both `audit_append` lines). Update the header comment.
- `hooks/scripts/lib/state-access.sh`: delete `state_read/write/delete_review_join`, `state_tombstone_pending_review` and `state_drop_resurrected_flags`, plus their `export -f` lines. `state_write_pending_review` becomes create-only-if-absent. `state_clear_all_pending_review` becomes a plain delete loop. Drop `.review-join` from the :11 marker list.
- Adapter lib copies under `adapters/*/hooks/scripts/lib/` (regenerated, never hand-edited)
- `tests/reviewer-route-gate-caller.test.sh` (three new cases), `tests/state-species-enumeration.test.sh` (drop the `state_write_review_join` call and lower the count to the files it now creates), `tests/review-gating-off.test.sh` (cases d' and f/d' now assert no stamp in both modes), `tests/prompt-diet-pins.test.sh:22`, `tests/adapter-protocol-parity.test.js:97` (pins on removed prose), `tests/state-distinctions-manifest.test.sh` (only if it fails: the `D2_review_join` row)
- `git rm tests/pending-review-resurrection.test.sh tests/state-access-concurrency.test.sh` (both only drive stamps and tombstones) and delete their `tests/validate.sh` blocks
- Prose that turns false: `templates/persona-protocol.md` (:288, :301, :310-320 and the review-join stamp paragraph), `agents/orchestrator.md` (:216, :228-237), `agents/reviewer.md:387`, `commands/gate.md:15`, `adapters/codex/agents-md-fragment.md` (:95, :109-114), `adapters/cursor/rules/persona-protocol.mdc` (:101, :115-120)
- `CHANGELOG.md`: one `[Unreleased]` bullet that names each deleted and edited test

## Ordered edits
1. Write the three new caller-test cases first (red). Use the file's own `OK   (<slug>)` / `FAIL (<slug>)` style. (a) `(route-no-join-stamp)`: a reviewer dispatch whose prompt starts `Unit: u1` exits 0, writes no `.claude/.review-join.*`, and writes no `review-join=` line to `review-audit.log`. (b) `(route-exclusivity-block)`: a standing `.pending-review.x` plus a `lead-programmer` dispatch exits 2. (c) `(route-flag-not-dropped)`: the same setup plus `.claude/.pending-review-cleared.x` also exits 2, and the flag still exists afterwards.
2. Make the code edits above. Then make the prose say that the reviewer's SubagentStop clears the flags and that no per-unit stamp exists. Keep the ADR-0016 file name where it is cited.
3. Edit or delete the tests as listed. Change only the cases about stamps or tombstones.
4. `node bin/cli.js --update --force-render`, then `git add -- .claude adapters`.

## Do NOT touch
- `bin/cli.js`: keep the `.review-join.*` and `.pending-review-cleared.*` ignore patterns, so leftover files in upgraded repos stay ignored. `tests/cli-backfill.test.js` pins them.
- `hooks/scripts/stop-gate.sh`, `lib/stop-gate-core.sh`, `dispatch-hygiene.sh` (lp-stopgate's); `hooks/hooks.json`, `.claude/settings.json`, `harness-integrity-gate.sh`, `reviewed-path-gate.sh`, `lib/benign-command.sh` (U9)
- `docs/` (U12 marks review-join retired in the glossary), `tests/abtest-arms.test.sh`, `eval/`
- No escalation prose anywhere

## Acceptance criteria
1. run: `git grep -nE 'review-join|review_join|pending-review-cleared|tombstone|resurrect' -- hooks bin adapters agents templates commands ':!bin/cli.js' | grep -v 'adr/0016-per-unit-review-join' | wc -l` → `0`. mutation: restore the stamp `printf ... > "$stamp"` line in `reviewer-route-gate-core.sh` → ≥ 1.
2. run: `bash tests/reviewer-route-gate-caller.test.sh` → exit 0, and `grep -cE '\((route-no-join-stamp|route-exclusivity-block|route-flag-not-dropped)\)' tests/reviewer-route-gate-caller.test.sh` → ≥ 3. mutation: restore the `state_drop_resurrected_flags` call and helper → `(route-flag-not-dropped)` fails, exit 1. Second mutation: restore the stamp write → `(route-no-join-stamp)` fails.
3. run: `test ! -e tests/pending-review-resurrection.test.sh && test ! -e tests/state-access-concurrency.test.sh && ! grep -qE 'pending-review-resurrection|state-access-concurrency' tests/validate.sh tests/watch-map.json && echo ok` → `ok`.
4. run: `bash tests/review-gating-off.test.sh && bash tests/state-species-enumeration.test.sh && bash tests/state-access-constraints.test.sh && bash tests/state-distinctions-manifest.test.sh && bash tests/prompt-diet-pins.test.sh && node tests/adapter-protocol-parity.test.js && bash tests/agent-identity-namespace.test.sh` → exit 0.
5. run: `bash tests/escalation-retired.test.sh prose && bash tests/escalation-retired.test.sh code-hdg && bash tests/escalation-retired.test.sh code-bin` → exit 0.
6. C-mirror: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` → exit 0. C-full: `bash tests/validate.sh` → exit 0, run once by the reviewer after the final commit.

## Pre-resolved context
- Today (2026-10-30, 7717b64a): criterion 1 counts 186 (most of them in stop-gate files, which lp-stopgate removes first); criterion 2's grep gives 0; criterion 3 fails (both files exist).
- Plan gaps resolved here. The plan's criterion 2 names `tests/reviewer-route-gate.test.sh`, which does not exist; the mid-review block has no route-side test outside the deleted `review-join.test.sh` and `review-gating-off` case d, so case (b) adds one. lp-stopgate already deletes `tests/review-join.test.sh`; do not delete it again. The plan listed no prose; it is added because the flag-clearing sentences would be false.
- `reviewer-route-gate-caller.test.sh` already covers the named-reviewer and forgery blocks (`name-*` cases), so they keep a test after `review-join.test.sh` goes.

## Escalation
If any gate blocks a write, stop and report the path and the refusal text. Never reword, split or route around it. If a test outside the affected files fails because of the removed helpers, stop and report its path and line.
