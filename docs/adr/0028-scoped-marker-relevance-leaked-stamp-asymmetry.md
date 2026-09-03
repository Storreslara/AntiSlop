# ADR-0028: Scoped Marker Relevance and the Leaked-Stamp/Leaked-Marker Asymmetry

**Date**: 2026-09-03  
**Status**: Approved  
**Deciders**: lead-programmer (gh425-3), scribe (gh425-4), reviewer (gh425-1, gh425-2, gh425-3)

## Context

A real incident exposed a critical gap in the analysis of [ADR-0016](0016-per-unit-review-join.md) ("No stale-stamp sweeper and no stamp TTL"). ADR-0016 argued that a leaked review-join stamp is inert — it can never deadlock a reviewer that did its job — and therefore no sweeper is needed. That reasoning is **sound for stamps and inverts for markers**: a leaked `.blocked` or `.escalated` marker is not inert; it is absorbing — a single stray marker anywhere in `.claude/reviewed/` silently blocks every reviewer's pending-review flag from clearing, project-wide, indefinitely.

### The Incident Timeline

**First occurrence (2026-08-31T22:12:03Z)**: `tests/marker-write.test.sh` leaked four fixture markers (`.pass`, `.fail`, `.blocked`, `.pass` for spec2-unitC) into the real `.claude/reviewed/` directory. A reviewer dispatched on 2026-09-01 correctly root-caused the freeze to `hooks/scripts/lib/stop-gate-core.sh:327` and stated: "the early-exit is directory-wide, not per-unit, so one stray `.blocked` file anywhere suppresses every unit's flag-clear... a real, still-unfixed defect (worth its own small unit someday)." The recommendation was filed in `tmp/gh413-gh414-handoff.md:92-105` but never actioned.

**Second occurrence (2026-09-02T04:06:46Z)** — 30 hours later: the same defect fired again when `validate.sh` re-planted the same four fixtures during a test run. The stray marker jammed pending-review flag-clearing; seven of the eight review-join stamps consumed in the single recovery `cleared-by=reviewer` event at 2026-09-02T19:46:16Z belonged to two unrelated plans (gh295, gh377), having been silently jammed by a marker from the test suite — a recurrence of a defect that had been correctly diagnosed and abandoned once before.

### The Root Cause

`hooks/scripts/lib/stop-gate-core.sh` lines 326–341 globbed the entire `.claude/reviewed/` directory for any `.blocked`/`.escalated` marker and short-circuited the SubagentStop grant branch **before** ever consulting the review-join stamps that capture which units the stopping reviewer was actually dispatched for. A leaked fixture marker belonging to no real unit violated the one-unit-at-a-time invariant's premise (there is never a second unit's flag to confuse) without violating the invariant itself — which is precisely why the global glob failed here and why the first root-cause analyst flagged it as a defect.

### Why ADR-0016's Analysis Holds for Stamps But Not Markers

[ADR-0016](0016-per-unit-review-join.md) states:

> "No stale-stamp sweeper and no stamp TTL. An unconsumed stamp is inert: a stop is allowed whenever any stamp is satisfied, so a leaked stamp can never deadlock a reviewer that did its job."

This reasoning is **correct and unchanged**. A review-join stamp with no corresponding unit entry in the stop-gate's branch logic cannot prevent a flag-clear: the governing rule (allow iff no stamps or at least one satisfied) remains satisfied by zero stamps, and a malformed stamp safely fails open. A leaked `.review-join.unitC` stamp (where unitC is not real) has zero bearing on a reviewer's ability to clear flags for units actually in flight.

The asymmetry: a leaked **marker** inverts this property. A `.blocked` marker, if it exists anywhere, keeps flags standing *regardless of its source*. The early-exit glob does not consult the scoped unit set; it examines global state and applies a binary rule. ADR-0016 did not anticipate markers because the analysis addressed stamps in isolation. This ADR completes the analysis by documenting what ADR-0016 left implicit: markers behave oppositely to stamps and require scoped relevance.

## Problem

The mechanism for keeping pending-review flags standing during an INSUFFICIENT-CONTEXT or ESCALATE-TO-HUMAN verdict is **correct in intent and necessary for safety**. However, the implementation checked for markers globally rather than scoped to the reviewer's own units, allowing a leaked or orphaned marker to absorb other units' flag-clears indefinitely.

## Decision

Scope the `.blocked`/`.escalated` marker check to the stopping reviewer's own stamped units, falling back to the original global behavior when the scoped unit set is empty (zero stamps, or all stamps malformed).

### Implementation Detail

The `review_join_state "$dot"` call was moved ahead of the marker check (consuming the review-join stamps to build `JOIN_SATISFIED_UNITS` and `JOIN_UNSATISFIED_UNITS`):

- **Scoped unit set is empty** (no stamps exist, or every stamp is malformed): preserve today's directory-wide glob verbatim, including the exact literal for `escalated_markers` that test mutation controls depend on.
- **Scoped unit set is non-empty**: consider only `.blocked` and `.escalated` markers for units in that set; skip out-of-scope markers and log `marker-out-of-scope=<unit>` per skipped marker to the audit trail so this jam class is diagnosable without inspection.

This is a minimal, conservative fix: it narrows the blast radius of a stray marker without removing the intended safety property (genuine `.blocked`/`.escalated` markers for stamped units still keep flags standing).

### Behavioral Narrowing (Documented Here for Audit)

One genuine behavioral change results: a standing `.escalated` marker for an unrelated unit **no longer** keeps flags standing when an unrelated reviewer's stop is evaluated. Prior to the fix, such a marker would prevent flag-clearing for all reviewers; after the fix, it is logged as `marker-out-of-scope=<unit>` and does not block the unrelated reviewer's operation. This is **intentional per the fix's design** (scoped relevance) and is the correct behavior when that marker is orphaned or leaked. However, it is worth documenting here because it is the one place where the fix genuinely narrows prior (accidental) protection: a case where the flag-keeping behavior existed before only as a side effect of unscoped globbing, not as a designed safety property.

## Residual Gaps and Lessons (Recorded for Future Reference)

**F9 — Documented defects not actioned recur.** The first root-cause was correct and precise, was filed in a side artifact that no later dispatch was obliged to read, and was never escalated to a spec or ticket. The same defect fired again 30 hours later. Future remedy: root-cause findings that name a specific code location and defect class should either (1) route to a spec immediately, or (2) be recorded in a persistent bug-list issue that the orchestrator reads before planning. A side artifact (e.g., a handoff memo) is insufficient.

**F10 — Measured blast radius.** The clearing event at 2026-09-02T19:46:16Z consumed eight review-join stamps in a single `cleared-by=reviewer` line: gh295-1, gh295-1b, gh377-4, gh377-5, gh377-6, gh377-6a, gh377-7, gh425-2. Seven of those eight belong to two completely unrelated plans and had been silently jammed by a marker from the test suite. This provides measured evidence of real-world multi-unit, multi-plan impact.

**F12 — Shape lesson for marker-hygiene units.** A marker-cleanup unit whose success criterion is "zero `.blocked`/`.escalated` markers remain" cannot legally write a `.blocked` verdict marker (it would violate its own acceptance criterion). The reviewer correctly reached a PASS with `commit: none` rather than deadlocking. This shape (cleanup unit whose success condition forbids its own verdict class) will recur in future. Recommendation: future marker-hygiene units should either state `commit: none` as expected up front, or scope acceptance criteria to markers *other than its own*.

## Measurement and Validation

Units gh425-1 through gh425-3 verify:

- Test suite isolation is hardened (`gh425-2`): `CLAUDE_PROJECT_DIR` is pinned on every helper invocation, and a standing guard asserts `.claude/reviewed/` entry list is unchanged across a `validate.sh` run.
- Leaked fixtures are removed and the corrupted marker is rewritten (`gh425-1`): three pure-fixture markers deleted, `spec2-unitC.pass` rewritten to document its destruction, deletion recorded in audit log.
- The marker check is scoped to stamped units (`gh425-3`): all existing flag-keeping cases pass unmodified; new cases verify scoping works (stray marker no longer blocks); global fallback works when scoped set is empty; `marker-out-of-scope` token is logged; `bash tests/validate.sh` and `bash tests/hook-latency-budget.test.sh` exit 0.

## Related ADRs

- [ADR-0016](0016-per-unit-review-join.md): Per-Unit Review Join Stamp — establishes that leaked stamps are inert; this ADR documents why leaked markers are not and adds the scoped relevance mechanism.

## Rationale

**Asymmetry closure.** ADR-0016's analysis of stamps is correct and remains in force; this ADR completes the analysis for markers, which behave oppositely. The combined reading is: stamps are inert, markers are absorbing when unscoped — scoping markers to their source reviewers prevents a single stray marker from jamming an entire project's reviewer pipeline.

**Fail-safe scoping.** When the scoped unit set is empty (no stamps or all malformed), the fix preserves today's global behavior entirely. A reviewer dispatched without a `Unit:` line or whose stamps are corrupted gets the same flag-keeping semantics as before. This is conservative: when we lack scoping information, we default to the safer (broader) behavior.

**Auditability.** The new `marker-out-of-scope` token makes this jam class diagnosable from the audit log rather than requiring inspection of `.claude/reviewed/`. Past incidents required manual directory listing; future incidents can be detected via audit-log grep.

## Scope Notes

This ADR records the decision and lessons; implementation is covered in the gh425 plan and its four units. The standing guard added in gh425-2 converts a silent recurrence into a loud failure; the scoped-relevance fix in gh425-3 closes the defect itself. Neither change affects public APIs, dispatch contracts, or marker formats.
