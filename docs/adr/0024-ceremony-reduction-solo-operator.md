# ADR 0024: Ceremony reduction for the solo-operator posture (Steps 2-4)

Date: 2026-08-16

Status: Accepted (plan `docs/plans/2026-08-15-ceremony-reduction-solo-operator.md`, Steps 2-4)

## Context

An independent read-only `fable` review of this repo's own agent-team
workflow (review frequency, gate self-interference, ceremony/progress token
ratio) found the per-unit ceremony cost high relative to a single,
unsupervised developer's actual risk tolerance, without finding any rule
that was safe to delete outright. `docs/plans/2026-08-15-ceremony-reduction-solo-operator.md`
resolved this as five coordinated changes; Step 1 (the local config flip,
`humanReviewMode: "off"` and `dispatchHygiene.mode: "warn"`) and Step 5
(release hygiene, this ADR included) are recorded separately. **This ADR
covers Steps 2-4 as one decision** because all three share the same
rationale — stop *automatic* triggering of a mechanism, while keeping the
mechanism itself fully reachable by explicit request — and were designed,
reviewed, and landed together.

Every change below is a reduction in automatic friction, not a capability
deletion: each mechanism this ADR touches survives and remains reachable,
either by explicit request or by an operator's choice at a decision point.

## Decision

### Step 2 — Milestone audit becomes on-demand

The `## Milestone audit gate` section of `agents/orchestrator.md` no longer
fires automatically once a milestone's units all reach reviewer PASS. It now
runs **only when the operator explicitly asks** — that exact literal is the
required, greppable trigger string (Open Question 2, resolved 2026-08-15). A
non-gating reminder that a release boundary is a good moment to *ask for* an
audit is retained; reaching one no longer triggers the gate by itself.
Everything else about the gate — never per-task, never a replacement for the
reviewer, the human-flagged-premises pass-through, the findings-relay
protocol, the challenged-premise re-plan route, and the
`unconverged-requirement` → `## Convergence follow-ups` route — is preserved
verbatim. This changes *when* the gate fires, not what it does.
`agent-auditor` was already on-demand and needed no change.

### Step 3 — Fast path raised from ≤2 to ≤5, publish threshold coupled at ≥6

The `spec-master` fast-path threshold (below which a finalized spec's
dispatch contract is emitted directly, skipping `task-master` slicing) rises
from ≤2 to ≤5 dispatchable units, mirrored consistently across
`agents/orchestrator.md`, `agents/spec-master.md`, `agents/task-master.md`,
`templates/persona-protocol.md`, and `CONTEXT.md`.

**Amends ADR-0003** (fast-path dispatch for ≤2 units, its "Related decisions"
bullet): the threshold that bullet fixed at ≤2/≥3 moves to ≤5/≥6. Per Open
Question 3 (resolved 2026-08-15), the two thresholds are coupled rather than
independent: `agents/spec-master.md`'s `to-spec` tracker-publish threshold
(previously "specs resolving to ≥3 units") moves to **≥6** in the same step,
so the fast path handles ≤5 units and tracker publication triggers at ≥6.
The decoupled alternative was rejected because a 4-unit spec would then skip
`task-master` yet still file a tracker issue nobody slices from, leaving
`scribe`'s issue-closing duty holding an issue number with no matching
dispatch. ADR-0003's own text is annotated in place (`**Superseded by**`
convention), not rewritten, per this repo's no-status-header-supersession
convention (ADR-0005:82).

### Step 4 — The 2-FAIL cap stops and asks the human

At the 2-FAIL cap, the orchestrator no longer automatically spawns a
`spec-master` debug spec. It surfaces the full two-attempt defect history
(both `.fail` records and the fix-attempt commits) and asks the human via
`AskUserQuestion` — the mechanism fixed by Open Question 4 (resolved
2026-08-15) — and **waits** for the answer before proceeding. Three discrete
options are offered, all previously-existing routes now gated behind an
explicit human choice rather than picked automatically:

- **(a) Debug spec** — dispatch `spec-master` for the diagnostic artifact,
  exactly as the prior automatic path did, now routed through Step 3's ≤5
  fast path.
- **(b) Re-dispatch with a human directive** — re-dispatch `lead-programmer`
  with an operator-supplied correction; unchanged, does not count against
  the cap.
- **(c) Park the unit** — stop work, leave the defect history standing, move
  on. No marker is written and none is deleted; a parked unit is
  distinguishable from any other only by the absence of further dispatch.

This interacts directly with [ADR-0018](0018-human-in-the-loop-review-on-by-default.md)'s
human-in-the-loop framing: ADR-0018 puts a human in the loop for
*heavy-unit PASS verdicts*; this step puts a human in the loop for
*repeated-FAIL escalation decisions*. The two are independent gates on
independent triggers — this repo's own local opt-out of ADR-0018's default
(`humanReviewMode: "off"`, see CONTEXT.md's "solo-operator posture" entry)
does not affect this step's human-ask, which is unconditional prose in the
orchestrator, not a `humanReviewMode`-gated check.

## Consequences

- **Nothing was deleted.** The milestone audit, the ≤2-unit-era fast path's
  successor, and the automatic debug-spec route are each still reachable —
  by explicit request, a wider default, or an explicit human choice,
  respectively.
- **New standing human touchpoint at the 2-FAIL cap.** Where the cap
  previously resolved itself (auto-spawn debug spec), it now blocks on an
  `AskUserQuestion` answer. For the solo-operator posture this is a single
  developer answering their own question, not new organizational overhead.
- **Threshold coupling is now load-bearing.** Any future change to the
  fast-path threshold must move the `to-spec` publish threshold with it, per
  Open Question 3's rationale — decoupling them re-opens the orphaned-issue
  gap this decision closed.
- **`CONTEXT.md`'s "FAIL routing (post-reviewer)" entry now states the
  human-decision gate, not an unconditional route to `spec-master`** — see
  that entry and the "parked unit" glossary entry this ADR's Step 4 half
  motivated.

## Related

- **Amends** [ADR-0003](0003-hivemind-split-spec-master-task-master.md)
  (fast-path/publish-threshold values, ≤2/≥3 → ≤5/≥6).
- **References** [ADR-0018](0018-human-in-the-loop-review-on-by-default.md)
  (human-in-the-loop review on by default) — Step 4's human-ask is a
  separate gate from ADR-0018's escalation trigger, not a re-implementation
  of it; see the Step 4 decision text above for how they interact.
- Plan: `docs/plans/2026-08-15-ceremony-reduction-solo-operator.md`, Steps
  2-4. Step 1 (local config posture) and Step 5 (this release, including
  this ADR) are recorded in `CONTEXT.md`'s "solo-operator posture" glossary
  entry and `.claude/wiki/changelog.md` respectively.
