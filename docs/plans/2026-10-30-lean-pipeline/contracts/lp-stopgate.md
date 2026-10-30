Unit: lp-stopgate

## Objective
Reduce the stop gate to one pending-review flag check plus the marker-forgery check (plan change 4, decisions D6 and D7, step "U8a lp-stopgate"). The rules, exactly:
- Under `reviewGating.mode: off` the gate exits 0.
- On a gated writer's SubagentStop, it honours the WIP sentinel. Otherwise it blocks, naming the file, if any `*.pass`, `*.fail` or `*.blocked` in `<dot>/reviewed/` is newer than `<dot>/reviewed/.writer-dispatch-stamp`. Otherwise it writes the flag.
- On a reviewer SubagentStop, it clears all flags.
- On the main Stop, it blocks while a flag exists whose first line starts with neither `skip:` nor `defer:`.
- `dispatch-hygiene.sh` touches the stamp on every gated writer dispatch.
No version bump.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, step "U8a lp-stopgate", D6, D7, Risks R2 and R4, Self-check CHK9. This file is the contract of record and supersedes the plan's U8a file list where they differ. Dispatch after lp-escbin has PASSed and the user has answered plan gap G1 (below). Implementer tier: opus.

## Affected files
- `hooks/scripts/stop-gate.sh`, `hooks/scripts/lib/stop-gate-core.sh` (shared; the adapter copies regenerate), `adapters/codex/hooks/scripts/stop-gate.sh`, `adapters/cursor/hooks/scripts/stop-gate.sh` (hand-kept entries)
- `hooks/scripts/dispatch-hygiene.sh` (item 0a block, near :133-155)
- `tests/stop-gate.test.sh` (new, mode 755). `git rm` these: `tests/stop-gate-blocked.test.sh`, `stop-gate-config-drift.test.sh`, `stop-gate-microworld-skip.test.sh`, `stop-gate-deferred-microworld.test.sh`, `stop-gate-escalated.test.sh`, `stop-gate-review-inflight.test.sh` and `tests/review-join.test.sh` (it drives the stamp consumption this unit removes; the plan had it in U8b)
- `tests/adapter-stop-gate-parity.test.sh` (rewrite cases f1-f4, g, h and i for the new behaviour on all three ports, keeping one core-mutation control on codex), `tests/dispatch-hygiene.test.sh` (stamp case), `tests/validate.sh`
- Tests that drive removed branches. Edit only those cases: `tests/pending-review-resurrection.test.sh`, `tests/state-access-capability-regression.test.sh` (check 1), `tests/state-access-constraints.test.sh` (C5 and any other stop-gate case), `tests/state-distinctions-manifest.test.sh` (rows on `stop-gate-core.sh` and the codex loop guard), `tests/review-gating-off.test.sh`, `tests/state-access-concurrency.test.sh`, `tests/writer-scope-gate.test.sh`
- Prose that would turn false: `templates/persona-protocol.md` (the `.blocked` flag-keeping sentence; the off-mode lists naming config-drift detection and the test+lint check), `agents/orchestrator.md` (the `stop-allowed=review-in-flight` paragraph; "stop-gate.sh keeps it"), `adapters/codex/agents-md-fragment.md:97`, `adapters/cursor/rules/persona-protocol.mdc:103`, `templates/persona-config.schema.json` (`gatedAgents` :46, `reviewGating` :150, `markerCommitCheck` :138: "no longer run by stop-gate")
- `CHANGELOG.md` (one `[Unreleased]` bullet naming each test edited or deleted)

## Ordered edits
1. Write `tests/stop-gate.test.sh` first (red). Run the Claude entry against tmp projects. The cases are (a)-(h) of the plan's U8a criterion 1, plus: (i) a missing stamp does not block, (j) `stop_hook_active: true` exits 0, (k) a non-gated agent's SubagentStop writes no flag. Set mtimes with `touch -d` at explicit times, never by sleeping. Build the marker directory name from parts (`r=revi; r="${r}ewed"`), so a heredoc fallback does not trip `reviewed-path-gate`.
2. Rewrite the core to D7. Remove: tombstones, the resurrection-guard call, stamp consumption, bootstrap, grant-denied logging, microworld surfacing and skip, config drift, test+lint, the `.escalated` block, marker-commit-check, the `.blocked` keep-flag branch and review-in-flight. Keep `harness_arm_or_deny` and the `stop_hook_active` short-circuit.
3. Stamp: in the item 0a block, when the target matches `gatedAgents` (default `lead-programmer`), `touch "${project_dir}/.claude/reviewed/.writer-dispatch-stamp"`, guarded so a failure never changes the verdict.
4. Adapter entries keep passing what the new core reads, nothing more. Edit the prose and the schema. Delete the tests and their validate.sh blocks, then register `bash tests/stop-gate.test.sh`.
5. `node bin/cli.js --update --force-render`; stage with `git add -- .claude adapters`.

## Do NOT touch
- `hooks/hooks.json`, `.claude/settings.json`, `hooks/scripts/harness-integrity-gate.sh` (Set B)
- `hooks/scripts/lib/state-access.sh` and `lib/reviewer-route-gate-core.sh` (U8b removes the helpers and stamp writes), `hooks/scripts/marker-commit-check.sh` (stays callable by hand)
- `hooks/scripts/reviewed-path-gate.sh`, `lib/benign-command.sh` (U9); `tests/abtest-arms.test.sh`, `eval/`
- No escalation prose anywhere: `tests/escalation-retired.test.sh prose` must stay green

## Acceptance criteria
1. run: `bash tests/stop-gate.test.sh` → exit 0, with cases (a)-(k) present. mutation: delete the D6 branch → case (f) fails, exit 1.
2. run: `test $(cat hooks/scripts/stop-gate.sh hooks/scripts/lib/stop-gate-core.sh | wc -l) -le 250 && echo ok` → `ok`.
3. run: `bash tests/adapter-stop-gate-parity.test.sh && bash tests/dispatch-hygiene.test.sh` → exit 0. mutation: drop the stamp `touch` from `dispatch-hygiene.sh` → its new stamp case fails.
4. run: `git grep -nE 'review-in-flight|flag standing|stop-gate.sh keeps it|config-drift detection|test\+lint check' -- agents templates adapters ':!adapters/*/hooks' | wc -l` → `0`. mutation: restore `agents/orchestrator.md` :231 → ≥ 1.
5. run: `bash tests/escalation-retired.test.sh prose && bash tests/escalation-retired.test.sh code-hdg && bash tests/escalation-retired.test.sh code-bin` → exit 0.
6. C-mirror: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` → exit 0. C-full: `bash tests/validate.sh` → exit 0, run once by the reviewer after the final commit.

## Pre-resolved context
- Today (2026-10-30, 94b55ee3): criterion 1 exits 127; criterion 2 counts 947 lines; criterion 4 finds 9 hits. The parity and dispatch-hygiene tests pass (baseline).
- Entailed by D7 (no stamps): marker-commit-check and the no-new-verdict watermark go, because both run per stamped unit.
- Self-resolved: a missing stamp fails open (case i). Codex and Cursor have no dispatch-hygiene, so D6 is inert there.
- G1 (open, user): D7 clears flags on every reviewer stop, so an INSUFFICIENT-CONTEXT verdict no longer keeps the unit pending. R2 does not list this loss. If the user keeps the behaviour, add case (l) and keep the `.blocked` branch.
- A subagent's Set B write is denied with no ask. This unit needs none.

## Escalation
If `harness-integrity-gate.sh` or another gate blocks a write, stop and report the path and the refusal text. Never reword, split or route around it. If the core cannot meet 250 lines with D7 intact, stop and report the measured count.
