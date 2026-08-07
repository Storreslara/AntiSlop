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

**Half B (Dispatch Hygiene):** The `dispatch-hygiene.sh:H3` gate checks whether a marker's commit is reachable from `HEAD`. If the commit is reachable, the unit is marked done and re-dispatch is blocked (existing behaviour). If the commit is unreachable, the marker is treated as void and re-dispatch is allowed (new behaviour).

**Critical caveat:** Half B alone would **not** have caught issue #165 (false PASS verdict on a CONTEXT.md edit). That incident was a reviewer error: the reviewer checked criteria that should not have passed, not a lost-work scenario. The commit-anchor approach prevents a *different* failure mode (work loss), not reviewer errors. Both halves are required for the design to make sense.

## Decision

Adopt v3 marker format with a required `commit:` field:

```
PASS <task-id> <UTC ISO-8601 timestamp> commit: <sha|none> criteria: <acceptance-criteria command(s) run>
```

- `<sha|none>`: The commit SHA (full or abbreviated, as returned by `git rev-parse HEAD`), or the literal string `none` if the marker was written before the first commit (fail-open bootstrap for empty repos).
- `criteria:` field (existing, v2 onward) is unchanged.

## Fail-Direction Rule

**Unverifiable commits are treated as void, allowing re-dispatch.** This is a fail-open principle: if the marker's commit cannot be determined (missing, malformed SHA, or unreachable), the gate allows re-dispatch rather than deadlocking.

The `dispatch-hygiene.sh:H3` gate has six branches:
1. No marker file exists → allow
2. Marker is empty/malformed → allow (fail-open)
3. Marker lacks a `commit:` field (v2 format) → allow (backward-compatible)
4. Marker has `commit: none` → allow (unit marked before any commit)
5. Marker's commit sha is reachable from `HEAD` → block (unit work is live)
6. Marker's commit is unreachable from `HEAD` → allow (unit may be re-dispatched)

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

4. **No adapter port.** The adapter ports (`adapters/codex/hooks/scripts/dispatch-hygiene.sh`, `adapters/cursor/hooks/scripts/dispatch-hygiene.sh`) are not updated in this unit. The commit-anchor logic in H3 is scoped to the main Claude Code hook. See Open Question 2 below.

5. **No general marker-expiry/TTL mechanism.** The marker's `commit:` field enables history-loss detection, not time-based expiry. A marker remains valid indefinitely as long as its commit is reachable.

## Implementation

### Hook Changes

- `task-gate.sh`: Header comment and help line updated to describe v3 format. `marker_valid()` function (lines 57–64) unchanged, byte-identical to baseline `e2bcc6a`.
- `stop-gate.sh`: Help line (line 156) updated to show v3 printf format.
- `dispatch-hygiene.sh`: H3 gate logic updated to check commit reachability. Not in scope for this ADR; see issue #260 acceptance criteria.

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

The adapter ports (Cursor, Codex) ship their own `dispatch-hygiene.sh` copies but do not yet implement the commit-anchor logic in H3. Porting the logic requires:
- Mirroring the six-branch logic from the main hook's H3
- Ensuring `git merge-base --is-ancestor` works in the adapter's execution environment
- Re-measuring behavioural parity between main and adapter ports

This is deferred to a later unit (post 2026-08-07). The main Claude Code hook is updated; adapter users will receive a warning or error if they re-dispatch a unit whose work was lost, directing them to the plugin update or a workaround.

## Rationale

**Undetectable work loss is a silent failure mode.** A marker exists; the gate sees it; the gate blocks. The developer sees "unit awaiting review" but the work is gone. Without the commit anchor, this deadlock has no obvious fix. With the anchor, the gate can detect the condition and allow re-dispatch.

**Fail-open principle.** Any marker we cannot verify (missing, malformed, v2 without commit anchor) is treated as void, allowing re-dispatch. This errs on the side of unblocking rather than deadlocking.

**Backward compatibility without grace period.** v2 markers are accepted and allow re-dispatch (branch 3). There is no new grace period; v2 markers coexist with v3 indefinitely, limited only by the existing legacy-marker grace period (through 2026-07-27).

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
