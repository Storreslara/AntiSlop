Unit: lp-joinstamp

## Objective
Remove the review-join stamps and the flag tombstones from the route gate, the state library and the prose (plan change 4, decision D7, step "U8b lp-joinstamp"). After lp-stopgate nothing reads a stamp, so the route gate stops writing them. The reviewer-dispatch block for a bad `name:`, the privileged-name forgery block and the one-unit-mid-review block (a gated dispatch while a `.pending-review.*` flag stands exits 2) all stay. The tombstones go too: the new stop gate drops flags only by deleting them, so the resurrection guard has nothing left to protect. A flag that a non-gate writer re-creates now blocks the next gated dispatch, which fails closed. No version bump.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, step "U8b lp-joinstamp", D7, Risk R2. This file is the contract of record and supersedes the plan's U8b file list and criteria where they differ (see Pre-resolved context). Dispatch after lp-stopgate has PASSed. Implementer tier: sonnet.

## Affected files
- `hooks/scripts/lib/reviewer-route-gate-core.sh`: delete the `state_drop_resurrected_flags` call (:33) and the whole `Unit:`-line block (:86-155: first-line parse, advisory stamp, prior-marker probe, stamp write, both `audit_append` lines). Update the header comment.
- `hooks/scripts/lib/state-access.sh`: delete `state_read/write/delete_review_join`, `state_tombstone_pending_review` and `state_drop_resurrected_flags`, plus their `export -f` lines. `state_write_pending_review` becomes create-only-if-absent. `state_clear_all_pending_review` becomes a plain delete loop. Drop `.review-join` from the :11 marker list.
- Adapter lib copies (regenerated, never hand-edited): `adapters/codex/hooks/scripts/lib/reviewer-route-gate-core.sh`, `adapters/codex/hooks/scripts/lib/state-access.sh`, `adapters/cursor/hooks/scripts/lib/reviewer-route-gate-core.sh`, `adapters/cursor/hooks/scripts/lib/state-access.sh`
- `tests/reviewer-route-gate-caller.test.sh` (three new cases), `tests/state-species-enumeration.test.sh` (drop the `state_write_review_join` call and lower the count to the files it now creates), `tests/review-gating-off.test.sh` (cases d' and f/d' now assert no stamp in both modes), `tests/prompt-diet-pins.test.sh` (the pin "writes the per-unit review-join stamp", ~22) and `tests/adapter-protocol-parity.test.js` (`PENDING_REVIEW_RULE.probe`: "one flag per satisfied review-join" and "leaves a tombstone", ~60-67), both pins on removed prose, `tests/state-distinctions-manifest.test.sh` (only if it fails: the `D2_review_join` row)
- `git rm` these: `tests/pending-review-resurrection.test.sh` and `tests/state-access-concurrency.test.sh` (both only drive stamps and tombstones) and delete their `tests/validate.sh` blocks
- Prose that turns false (text anchors; approximate line numbers at HEAD 4fc80b6a in brackets):
  - `templates/persona-protocol.md`: in "Review markers and gate mechanics", "Inert under `off`: the pending-review flags and review-join verdict check in `stop-gate.sh`" [~296], the parenthetical "(one exception: the drop of a flag re-created after a hook deleted it ...)" and "and `.review-join.*` stamps" [~306-308]; in "## Pending-review flag", the "one flag per satisfied review-join stamp" sentence, the tombstone / `flag-resurrected-dropped` sentence and the **review-join stamp** paragraph [~317-330]. Keep the ADR-0016 file-name citation [~257].
  - `agents/orchestrator.md`: from "`reviewer-route-gate.sh` reads exactly the `Unit:` line to write the per-unit review-join stamp" through "logs `advisory-dispatch=<id>` to the review audit log instead." [~209-224]; in "Reviewer re-tasking discipline", the clause "writes the per-unit review-join stamp — a `SendMessage` carries no unit id and cannot write one" [~229].
  - `agents/reviewer.md`: in the bullet "If a stop-gate block demands a marker you believe you already wrote", drop ", and do not delete or edit a review-join stamp" [~322-323].
  - `commands/gate.md`: step 2, "Stale flags and `.review-join.*` stamps left on disk" becomes "Stale flags left on disk" [~13].
  - `adapters/codex/agents-md-fragment.md` [~94, ~108-113] and `adapters/cursor/rules/persona-protocol.mdc` [~100, ~114-119]: the same passages as the template.
- `templates/persona-config.schema.json`: in the `reviewGating` `description` string [~150], replace "(stop-gate.sh's pending-review flags and marker check, reviewer-route-gate.sh's unit-exclusivity block and .review-join.* stamps)" with "(stop-gate.sh's pending-review flag rules and writer-dispatch marker check, reviewer-route-gate.sh's unit-exclusivity block)". Nothing else in the file. It has no generated copy: `--update --force-render` does not render it (checked in a throwaway clone).
- Generated copies that step 4 refreshes (never hand-edit): `.claude/persona-protocol.md`, `.claude/agents/lead-programmer.md`, `.claude/agents/milestone-auditor.md`, `.claude/agents/orchestrator.md`, `.claude/agents/reviewer.md`, `.claude/agents/spec-master.md`, `.claude/hooks/scripts/lib/reviewer-route-gate-core.sh`, `.claude/hooks/scripts/lib/state-access.sh`, plus the render record in `.claude/persona-config.json`. The `.review-join.*` text in `.claude/agents/milestone-auditor.md` and `.claude/agents/spec-master.md` comes from the inlined `templates/persona-protocol.md` block, not from `agents/`. In a throwaway clone, rewriting only the template and re-rendering left 0 hits in both files (and in lead-programmer.md). The remaining hits in `.claude/agents/orchestrator.md` (2) and `.claude/agents/reviewer.md` (1) come from their `agents/` sources above. So regeneration fixes them; no hand edit.
- `CHANGELOG.md`: one `[Unreleased]` bullet that names each deleted and edited test

## Ordered edits
1. Write the three new caller-test cases first (red). Use the file's own `OK   (<slug>)` / `FAIL (<slug>)` style. (a) `(route-no-join-stamp)`: a reviewer dispatch whose prompt starts `Unit: u1` exits 0, writes no `.claude/.review-join.*`, and writes no `review-join=` line to `review-audit.log`. (b) `(route-exclusivity-block)`: a standing `.pending-review.x` plus a `lead-programmer` dispatch exits 2. (c) `(route-flag-not-dropped)`: the same setup plus `.claude/.pending-review-cleared.x` also exits 2, and the flag still exists afterwards.
2. Make the code edits above. Then make the prose say that the reviewer's SubagentStop clears the flags and that no per-unit stamp exists. Keep the ADR-0016 file name where it is cited.
3. Edit or delete the tests as listed. Change only the cases about stamps or tombstones.
4. `node bin/cli.js --update --force-render`, then `git add -- .claude adapters`.

## Do NOT touch
- `bin/cli.js`: keep the `.review-join.*` and `.pending-review-cleared.*` ignore patterns, so leftover files in upgraded repos stay ignored. `tests/cli-backfill.test.js` pins them.
- `hooks/scripts/stop-gate.sh`, `hooks/scripts/lib/stop-gate-core.sh`, `hooks/scripts/dispatch-hygiene.sh` (lp-stopgate's); `hooks/hooks.json`, `.claude/settings.json`, `hooks/scripts/harness-integrity-gate.sh`, `hooks/scripts/reviewed-path-gate.sh`, `hooks/scripts/lib/benign-command.sh` (U9)
- `docs/` (U12 marks review-join retired in the glossary), `CONTEXT.md` (U12), `.claude/wiki/` (scribe), `tests/abtest-arms.test.sh`, `eval/`, `prototype/`, `tmp/`
- `.gitignore` and `tests/cli-backfill.test.js`: keep the `.claude/.review-join.*` ignore line and its pin, for the same reason as `bin/cli.js`
- No escalation prose anywhere

## Acceptance criteria
1. run: `git grep -nE 'review-join|review_join|pending-review-cleared|tombstone|resurrect' -- hooks bin adapters agents templates commands .claude/agents .claude/hooks .claude/persona-protocol.md ':!bin/cli.js' | grep -v 'adr/0016-per-unit-review-join' | wc -l`
   exit: 0
   stdout: `0`
   mutation: restore the stamp `printf ... > "$stamp"` line in `reviewer-route-gate-core.sh` → ≥ 1. Second mutation: put back " and .review-join.* stamps" in the schema description → 1.
2. run: `bash tests/reviewer-route-gate-caller.test.sh >/dev/null && test "$(grep -cE '\((route-no-join-stamp|route-exclusivity-block|route-flag-not-dropped)\)' tests/reviewer-route-gate-caller.test.sh)" -ge 3 && echo ok`
   exit: 0
   stdout: `ok`
   mutation: restore the `state_drop_resurrected_flags` call and helper → `(route-flag-not-dropped)` fails, no `ok`, exit 1. Second mutation: restore the stamp write → `(route-no-join-stamp)` fails.
3. run: `test ! -e tests/pending-review-resurrection.test.sh && test ! -e tests/state-access-concurrency.test.sh && ! grep -qE 'pending-review-resurrection|state-access-concurrency' tests/validate.sh tests/watch-map.json && echo ok`
   exit: 0
   stdout: `ok`
4. run: `{ bash tests/review-gating-off.test.sh && bash tests/state-species-enumeration.test.sh && bash tests/state-access-constraints.test.sh && bash tests/state-distinctions-manifest.test.sh && bash tests/prompt-diet-pins.test.sh && node tests/adapter-protocol-parity.test.js && bash tests/agent-identity-namespace.test.sh; } >/dev/null`
   exit: 0
   stdout: empty
5. run: `{ bash tests/escalation-retired.test.sh prose && bash tests/escalation-retired.test.sh code-hdg && bash tests/escalation-retired.test.sh code-bin; } >/dev/null`
   exit: 0
   stdout: empty
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` (C-mirror)
   exit: 0
   stdout: empty
7. run: `node -e 'const t=JSON.stringify(require("./templates/persona-config.schema.json"));process.stdout.write(String(t.includes("pending-review flag rules and writer-dispatch marker check, reviewer-route-gate.sh")))'`
   exit: 0
   stdout: `true`
   mutation: leave the description as at HEAD → `false`.
8. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; C-full, run once by the reviewer after the final commit)
   exit: 0
   stdout: empty

## Pre-resolved context
- At 4fc80b6a (after lp-stopgate): criterion 1 counts 185 with the `.claude` paths added; criterion 7 prints `false`; `--update --force-render` leaves the tree clean. Earlier (7717b64a): criterion 1 counted 186 (most of them in stop-gate files, which lp-stopgate removes first); criterion 2's grep gives 0; criterion 3 fails (both files exist).
- Plan gaps resolved here. The plan's criterion 2 names `tests/reviewer-route-gate.test.sh`, which does not exist; the mid-review block has no route-side test outside the deleted `review-join.test.sh` and `review-gating-off` case d, so case (b) adds one. lp-stopgate already deletes `tests/review-join.test.sh`; do not delete it again. The plan listed no prose; it is added because the flag-clearing sentences would be false.
- `reviewer-route-gate-caller.test.sh` already covers the named-reviewer and forgery blocks (`name-*` cases), so they keep a test after `review-join.test.sh` goes.

## Escalation
If any gate blocks a write, stop and report the path and the refusal text. Never reword, split or route around it. If a test outside the affected files fails because of the removed helpers, stop and report its path and line.
