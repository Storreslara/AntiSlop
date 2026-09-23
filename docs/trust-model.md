# Trust model — what is checked, and what is self-reported

This document is the durable, bijection-tested home for the trust map first
derived in `docs/plans/2026-08-25-harness-trust-gaps.md` (§ Context, finding
F4: *"Self-report-only enforcement"*). Its purpose is narrow: for every
trust-critical claim a hook script or an agent makes about this repo's
review harness, name either the script that mechanically checks it, or the
literal token `self-reported` when nothing does.

`self-reported` is not a defect by itself — some of these claims (a stated
reason for a pause, whether a `defer:` is honest) are semantically
unverifiable by any mechanism. The point of this document is to make the
self-report surface **enumerated and labelled**, so nobody has to
rediscover by reading six scripts which claims in this system are checked
and which are taken on faith.

`tests/trust-model-bijection.test.js` keeps this table honest: every
`*.sh` under `hooks/scripts/` (excluding the sourced-only `lib/`) must
appear here, every script this table names must exist on disk, and the
count of `self-reported` rows is pinned exactly so a silent conversion
cannot happen without this document (and the pinned count) being updated
in the same commit.

## The trust map

| # | Trust-critical claim | Asserted by | Checked by | Notes |
|---|---|---|---|---|
| 1 | This unit passed review | reviewer | `hooks/scripts/task-gate.sh` | `marker_valid()` checks the marker file exists, is non-empty, and line 1 begins `PASS <task-id> `. It does not parse the marker's `commit:` or `criteria:` fields — see rows 2-4. |
| 2 | The marker's `commit:` field names this unit's own commit | reviewer | `hooks/scripts/marker-commit-check.sh` | Mechanical, advisory (`mode: warn`) — classifies `ok`/`mismatch`/`unverifiable` against git history and always exits `0`; never decides policy for its caller. |
| 3 | The marker's `criteria:` commands actually pass | reviewer | `hooks/scripts/marker-verify.sh` | `--execute` re-runs the cited commands in a throwaway git worktree checked out at the marker's cited commit, so a dirty live tree cannot contaminate the result. `--list` (default) only parses and counts them. Per RD1, this script is **never registered in any hook** — an operator or reviewer must invoke it deliberately. |
| 4 | The marker's `criteria results:` prose is true | reviewer | self-reported | Subsumed by claim 3 whenever `marker-verify.sh --execute` is actually run — a failing re-run would falsify the prose — but nothing separately checks the prose text on its own. |
| 5 | The reviewer, not the unit's own writer, wrote the marker | `agent_type` | `hooks/scripts/reviewed-path-gate.sh` | The grant matcher restricts writes under `.claude/reviewed/*` by identity. |
| 6 | A WIP sentinel names a real pause | gated agent | self-reported | `stop-gate.sh` honors any non-empty reason; whether the stated reason is true is semantically unverifiable by any mechanism. |
| 7 | A `defer:` reason is real | main session | self-reported | Prefix + non-empty is all that is mechanically required. |
| 8 | A `skip:` abandonment is legitimate | main session | self-reported | Prefix + non-empty is all that is mechanically required. The *consequence* of a defer/skip — not its truth — is mechanized; see `hooks/scripts/stop-gate.sh`'s own row below. |
| 9 | A dispatch carries a real nine-element contract | dispatcher | `hooks/scripts/dispatch-hygiene.sh` | H4 checks that the eight `## ` headings are present **and** each carries a minimal substance floor (non-empty body). It does not check that the content is truthful. |
| 10 | A microworld `result=pass` is a check result | implementer's `run.sh` | `hooks/scripts/microworld-rerun.sh` | Records an `authority=reviewer\|self` field, never self-declarable — derived from whether a matching `.countersign` hash equals the bundle's *current* `run.sh` hash. |
| 11 | The harness is armed (its trust gates have not been silently disarmed) | — | `hooks/scripts/harness-integrity-gate.sh` | Configless, hardcoded write-deny over the harness's own control surface. Complemented by six gates' `harness_armed()` adoption, which blocks rather than fails open when an adapted project's config is absent, empty, or unparseable. |
| 12 | The audit trail (the four gitignored `.claude/*.log` files) is complete | — | `bin/harness-integrity.sh` | Verifies each log's sidecar seal. Detects truncation without a matching reseal; does **not** detect a truncate-and-reseal by an adversary willing to do both — that residual is priced, not eliminated, by the Set A `Bash` text scan in `hooks/scripts/harness-integrity-gate.sh`. |
| 13 | `reviewGating.mode` has not been silently flipped to `off` | — | **forward reference — checked by Step 4 (not yet landed)** | Documents this plan's own architecture: `reviewGating.mode` is a disarm-surface field from the moment it is defined, including while absent (absent means `enforce`). This row does not claim the check exists today — it is a forward reference to a sibling unit, filed last, that has not yet landed. |
| 14 | Credential-split upgrade path: a fine-grained PAT scoped to `contents: write` + `pull_requests: write`, explicitly **not** `administration` or `workflows` | — | **upgrade path — not adopted** | Documented as an upgrade path, never as a current property this repo already has. Its real cost: a token-management workflow (minting, rotating, and distributing a fine-grained PAT) the operator does not have today. Advisory framing only — no criterion in any spec treats this repo as having adopted it. |

## Additional hook-script coverage

The 14 rows above come from the source spec's F4 map plus the two rows
requested by sibling spec 6. The bijection test also requires every
`hooks/scripts/*.sh` file to appear somewhere in this document — the
following rows cover the scripts F4 did not already name, so the map
stays a complete inventory rather than a curated subset.

| # | Trust-critical claim | Asserted by | Checked by | Notes |
|---|---|---|---|---|
| 15 | The code-review graph reflects the latest edit | `hooks/scripts/graph-update.sh` | self-reported | `PostToolUse (Edit\|Write)`, advisory, fire-and-forget — a reporter D0 exempts from the gate battery, not a gate. Nothing re-derives whether the graph update actually succeeded. |
| 16 | The reported lint status for an edited file is accurate | `hooks/scripts/lint-on-edit.sh` | self-reported | `PostToolUse (Edit\|Write)`, advisory — the edit has already happened by the time this runs, so it reports rather than blocks. |
| 17 | The reported config/plugin-version drift at session start is accurate | `hooks/scripts/session-start.sh` | self-reported | `SessionStart`, a reporter (not a trust gate) per D0. Reports session baseline and drift context; blocking on drift happens elsewhere (a gated agent's `SubagentStop`), never here. |
| 18 | The heavy/light surface measurement used for reviewer-tier selection is accurate | `hooks/scripts/heavy-trigger.sh` | self-reported | Deliberately **not** hook-registered — an orchestrator-invoked helper, not a hook. Its measurement feeds a tier decision that nothing independently re-derives. |
| 19 | The sonnet/opus tier decision is the correct one for this unit | `hooks/scripts/reviewer-tier.sh` | self-reported | Deliberately **not** hook-registered — a reviewer-invoked helper. Deterministic given its inputs, but whether the *decision itself* was the right call for the unit is not independently checked. |
| 20 | A `.claude/human-review/*/DECISION` write is denied unless from a legitimate identity | `hooks/scripts/human-decision-gate.sh` | `hooks/scripts/human-decision-gate.sh` | Reads no config at all — configless by design, the same precedent Step 2's gate follows. |
| 21 | A `Write`/`Edit` targeting a `protectedPaths`-listed file is denied | `hooks/scripts/protected-paths.sh` | `hooks/scripts/protected-paths.sh` | Matches `Write\|Edit` only; does not reach a `Bash`-invoked rewrite of the same file. |
| 22 | The pending-review flag correctly blocks the next gated dispatch until a reviewer verdict lands | `hooks/scripts/reviewer-route-gate.sh` | `hooks/scripts/reviewer-route-gate.sh` | Two identity blocks run configless; the pending-review branch is config-gated. |
| 23 | Turn-end is blocked while a completed unit awaits review, and defer/skip/WIP-sentinel *usage rate* is logged even though the *truth* of each reason is not | `hooks/scripts/stop-gate.sh` | `hooks/scripts/stop-gate.sh` | This is the mechanized *consequence* half of rows 6-8 above: the reason's truth is never checked, but the flag it produces, and the audit trail of its use, are.
| 24 | The single-call `marker-write.sh` helper produces a format-valid marker | reviewer (invoker) | `hooks/scripts/task-gate.sh` | Deliberately **not** hook-registered — a reviewer-invoked helper collapsing the documented `mkdir -p` + `printf` two-step into one call (spec2-unitC). An ergonomics wrapper only: it grants no capability the reviewer identity does not already have (its own CLI requires the marker path as an argument, so `reviewed-path-gate.sh`'s identity check still fires on the invoking command), and a marker it wrote wrong would simply fail `marker_valid()`/`marker_format_valid()` downstream, exactly as a hand-typed one would. |
| 25 | A unit touching `agents/*.md` or `templates/` bumped `.claude-plugin/plugin.json`'s version in each commit that touched it (constitution P3 / version-stamp discipline) | `hooks/scripts/version-stamp-check.sh` | self-reported | Deliberately **not** hook-registered — a reviewer-invoked helper, matching `heavy-trigger.sh`/`reviewer-tier.sh` (units version-stamp-guard-1, version-stamp-check-roast-1). Implements **per-commit semantics**: every commit in the range that touches a version-stamped path is checked against its own immediate parent. Deterministic given an explicit `<commit-range>` argument, sidestepping CI's shallow clone; nothing independently re-derives whether the reviewer actually ran it against the right range. |
