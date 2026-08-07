# ADR-0015: Commit-Anchored PASS Markers (v3 Format)

**Date**: 2026-08-07  
**Status**: Approved  
**Deciders**: lead-programmer, orchestrator (unit #260)

## Context

PASS markers (`.claude/reviewed/<task-id>.pass`) record reviewer verdicts and gate task completion in both default and agent-teams modes. The v2 format (2026-07-13 onwards) added content validation to close a bare-`touch` forgery gap, requiring a non-empty first line matching `PASS <task-id> <UTC ISO-8601 timestamp> criteria: <acceptance-criteria command(s) run>`.

The v3 format adds a `commit:` field to anchor the marker to a specific commit in the repository, enabling detection of units whose work was lost to history (e.g. via git reset, force push, or rebase).

## Problem

### Failure Mode: Work Lost to History

A marker can exist for a unit that was completed at commit `abc1234`, but a later force push or reset removes that commit from `HEAD`'s ancestry. Without a commit anchor, the dispatch-hygiene gate (`dispatch-hygiene.sh:H3`) cannot distinguish between:
- A unit legitimately marked done whose work is still live in `HEAD`
- A unit marked done whose work has been discarded, allowing re-dispatch

The marker exists; the gate sees it; the gate blocks re-dispatch. But the work is gone from the repository. The unit is deadlocked.

### Half A / Half B Analysis

The v3 commit anchor solves this via two halves:

**Half A (Marker Writers):** The reviewer and lead-programmer (in the no-reviewer-fallback case) write the `commit: <sha|none>` field when creating or updating a marker. This is mechanical bookkeeping, requires no new policy, and is orthogonal to the verdict itself (PASS or FAIL).

**Half B (Dispatch Hygiene):** The `dispatch-hygiene.sh:H3` gate checks whether a marker's commit is positively verifiable as unreachable from `HEAD`. If the commit is reachable, the unit is marked done and re-dispatch is blocked (existing behaviour). Only when the commit resolves and is confirmed NOT an ancestor of `HEAD` is re-dispatch allowed (new behaviour) — every unverifiable case (no `commit:` field, `commit: none`, a malformed SHA, or no git repo) still blocks, preserving H3's pre-v3 behaviour.

**Critical caveat:** Half B alone would **not** have caught issue #165 (false PASS verdict on a CONTEXT.md edit). That incident was a reviewer error: the reviewer checked criteria that should not have passed, not a lost-work scenario. The commit-anchor approach prevents a *different* failure mode (work loss), not reviewer errors. Both halves are required for the design to make sense.

## Decision

Adopt v3 marker format with a required `commit:` field:

```
PASS <task-id> <UTC ISO-8601 timestamp> commit: <sha|none> criteria: <acceptance-criteria command(s) run>
```

- `<sha|none>`: The commit SHA (full or abbreviated, as returned by `git rev-parse HEAD`), or the literal string `none` if the marker was written before the first commit (fail-open bootstrap for empty repos).
- `criteria:` field (existing, v2 onward) is unchanged.

## Fail-Direction Rule

**An unverifiable commit preserves today's behaviour and fires.** Only a positively-proven-unreachable commit (branch 6 below) allows re-dispatch. Everything else — no `commit:` field, `commit: none`, a malformed SHA token, no git repo, or a positively-verified-still-reachable commit — fires, exactly as H3 behaved before this plan. This is a fail-safe (not fail-open) principle: an unverifiable marker keeps protecting the unit rather than silently allowing a possibly-still-live unit to be re-dispatched.

The `dispatch-hygiene.sh:H3` gate has six branches, all conditioned on a marker file existing in the first place (if no marker file exists at all there is nothing to check, and H3 never fires on that unit — a separate, prior condition, not one of the six):
1. Marker lacks a `commit:` field (legacy v2 format) → fires (preserves pre-v3 behaviour)
2. Marker has `commit: none` → fires
3. Marker's `commit:` token is not a well-formed SHA → fires
4. Marker's commit is well-formed but the project directory is not a git work tree (unverifiable) → fires
5. Marker's commit sha resolves and is reachable from `HEAD` → fires (unit's work is confirmed still live)
6. Marker's commit sha resolves and is confirmed NOT reachable from `HEAD` → does not fire (unit may be re-dispatched; its attested work is confirmed gone)

## Backward Compatibility

The marker-validity check (`task-gate.sh:marker_valid()`) uses prefix-only matching (`"PASS ${task_id} "*`), unchanged from v2. This means:
- Existing v2 markers are accepted by `marker_valid()` without modification.
- New markers written in v3 format are accepted.
- Markers lacking the `commit:` field are accepted (branch 3 above).

The v0.6.0 legacy-marker grace period (through 2026-07-27) already handles v1 formats (bare `touch`), which are rejected after the grace period ends. v3 adoption does not introduce a new grace period; v2 markers remain valid indefinitely.

## Deliberate Non-Changes (Out of Scope)

1. **No task-master authoring-convention change.** Task-master dispatch prompts continue to list acceptance criteria; the marker writer's inclusion of those criteria in the first line is still a manual, human-readable step, not machine-generated.

2. **No `.fail`/2-FAIL-cap accounting change.** The 2-FAIL cap and fail-routing logic (unit #233, #239) remain unchanged. A `.fail` record is still written alongside `.pass` markers on FAIL verdicts, and the 2-FAIL cap still forces escalation to spec-master.

3. **No bulk audit/backfill of existing markers.** The 128+ existing v2 markers in this repo remain untouched. v3 adoption applies only to newly written markers.

4. **No adapter port — there is nothing to port.** Neither adapter ships a `dispatch-hygiene.sh` at all (confirmed via `ls adapters/*/hooks/scripts/`: Codex and Cursor each ship only `graph-update.sh`, `lint-on-edit.sh`, `protected-paths.sh`, `reviewer-route-gate.sh`, `stop-gate.sh`, and `lib/`). Half B (H3 re-validation) is a main-hook-only feature and simply does not exist for Codex/Cursor projects. See Open Question 2 below.

5. **No general marker-expiry/TTL mechanism.** The marker's `commit:` field enables history-loss detection, not time-based expiry. A marker remains valid indefinitely as long as its commit is reachable.

## Implementation

### Hook Changes

- `task-gate.sh`: Header comment and help line updated to describe v3 format. `marker_valid()` function (lines 57–64) unchanged, byte-identical to baseline `e2bcc6a`.
- `stop-gate.sh`: Help line (line 156) updated to show v3 printf format.
- `dispatch-hygiene.sh`: H3 gate logic updated to check commit reachability — landed in unit #256 (commit `1b884fa`, spec Step 1), not unit #260. This ADR documents that shipped behaviour; unit #260 itself only updated marker-writer templates and documentation (`git diff --stat 9959b19..HEAD` touches 9 files, none of them `dispatch-hygiene.sh`).

### Marker Writers

- `reviewer.md`: printf template updated to include `commit: $(git rev-parse HEAD)`.
- `start-feature-team.md`: No-reviewer fallback printf updated similarly.
- `hook-verification.md`: Smoke-test printf updated to demonstrate v3 format.

### Documentation

- `CONTEXT.md`: "Dispatch hygiene" glossary entry amended to describe commit-anchor clause and six-branch H3 behaviour.
- `.claude/wiki/modules/hooks.md`: H3 description updated to list all six branches, including the "unreachable" case.
- `agents/scribe.md`, `docs/design.md`: Marker format references updated to v3.

## Known Questions and Deferred Items

### Open Question 1: Commit Abbreviation Policy

Git's `rev-parse HEAD` can return a short or full SHA depending on configuration. This ADR specifies `<sha|none>` without prescribing length. Implementations should use the default `git rev-parse HEAD` output (typically full SHA in modern git). If abbreviation is preferred, document it in the marker writer's comments.

### Open Question 2: Adapter Port (Deferred)

Neither adapter ships a `dispatch-hygiene.sh` at all — Codex and Cursor each ship only `graph-update.sh`, `lint-on-edit.sh`, `protected-paths.sh`, `reviewer-route-gate.sh`, `stop-gate.sh`, and `lib/` (confirmed via `ls adapters/*/hooks/scripts/` and `find adapters -name '*dispatch*'`, both turning up no dispatch-hygiene match). Half B (H3 re-validation) is therefore entirely absent for Codex/Cursor projects today, independent of this ADR — there is no warning, no error, no degraded behaviour; the feature simply is not present there. Porting it (a future unit, post 2026-08-07) would require:
- Writing a `dispatch-hygiene.sh` for each adapter from scratch, or folding the main hook's H3 logic into whatever re-dispatch gating each adapter already has
- Ensuring `git merge-base --is-ancestor` works in the adapter's execution environment
- Measuring behavioural parity against the main hook's H3

Adapter users are unaffected by this ADR; nothing regresses and nothing new is exposed to them.

## Rationale

**Undetectable work loss is a silent failure mode.** A marker exists; the gate sees it; the gate blocks. The developer sees "unit awaiting review" but the work is gone. Without the commit anchor, this deadlock has no obvious fix. With the anchor, the gate can detect the condition and allow re-dispatch.

**Fail-safe principle.** Any marker we cannot positively verify as pointing to a now-unreachable commit (missing, malformed, v2 without commit anchor, no git repo) still fires and blocks, exactly as before this plan. This errs on the side of protecting a marker over silently allowing a possibly-still-live unit to be re-dispatched; only a confirmed-unreachable commit stands the gate down.

**Backward compatibility without grace period.** v2 markers are accepted by `marker_valid()` (branch 1: no `commit:` field still fires/blocks re-dispatch, same as before v3 existed). There is no new grace period governing v2 markers themselves; they coexist with v3 indefinitely. (The existing v0.6.0 legacy-marker grace period, through 2026-07-27, is a separate mechanism governing v1 bare-`touch` markers, not v2.)

**Simplicity.** The commit anchor is a single field; the check is a single `git merge-base --is-ancestor` call. No expiry TTLs, no automatic pruning, no versioning machinery.

## Related Issues and ADRs

- Issue #153: Marker coupling and clear-watermark (ADR-0011, partially related)
- Issue #165: False PASS verdict on CONTEXT.md edit (motivating context; not directly caused by missing commit anchor)
- ADR-0002: Reviewed directory ownership (marker storage)
- ADR-0006: Reviewer tier and model eligibility
- ADR-0009: Measured reviewer tier eligibility
- ADR-0011: Dispatch-hygiene escape-hatch idempotency (related to H3 but distinct mechanism)

## Measurement and Validation

The acceptance criteria for unit #260 verify:
- v3 format is documented in affected help text and comments
- `marker_valid()` is byte-identical to baseline (no behavioral change)
- The ADR exists with required content
- The 0007 hole is preserved (no backfill)
- `bash tests/validate.sh` passes (regression suite)

See unit #260's acceptance criteria and dispatch for the full measurement command.
