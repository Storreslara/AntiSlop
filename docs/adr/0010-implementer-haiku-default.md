# ADR 0010: Implementer tier defaults to `haiku`; judgment moved to dispatch contract

Date: 2026-08-02
Status: Accepted (works alongside ADR-0009)

## Context

Prior to this plan (2026-08-01), implementer tier defaulted to `sonnet`, and
`task-master` attempted pre-emptive escalation: it tagged units with
`Suggested model: haiku` if they appeared mechanically simple. This escalation
reached roughly 0% of units in practice — no unit was tagged haiku.

ADR-0009 (2026-08-01) fixed the *reviewer* tier by moving its eligibility
decision from pre-implementation *prediction* (a tag) to post-implementation
*measurement* (a deterministic script run at dispatch time). The change
succeeded because the script runs on the actual diff, not a forecast. The
implementer tier has no such measurement point — a unit's implementer is
assigned *before* implementation exists.

The efficiency audit (plan 2026-08-01-lead-programmer-haiku-default, issue #207)
proposes to default the implementer to `haiku` instead of `sonnet`, accepting
the tradeoff that some units will require escalation on first FAIL. This moves
the escalation decision from pre-implementation prediction to post-implementation
*failure*, where evidence (a FAIL on the `.fail` record) proves the unit
actually needs a larger model.

## Decision

1. **Implementer tier now defaults to `haiku`.** `agents/lead-programmer.md`
   frontmatter sets `model: haiku` (was `sonnet`).

2. **Task-master's pre-emptive escalation is removed entirely.** Every unit is
   tagged `Suggested model: haiku` by default, and no unit is tagged *above*
   `haiku` pre-emptively: no pre-implementation tagging attempts to predict
   that a unit needs a larger implementer tier, however risky it looks (see
   `agents/task-master.md`, "Per-unit model tag"). `sonnet`/`opus` are
   reachable only reactively, from something already on record — a prior
   `.claude/reviewed/<task-id>.fail`, or the orchestrator's first-FAIL rule.
   Judgment is deferred entirely to post-implementation, reactive escalation
   via FAIL records.

3. **Escalation now happens only after a FAIL.** When a unit fails on `haiku`,
   the orchestrator (per `agents/orchestrator.md:184-189`'s first-FAIL escalation
   rule) re-dispatches to `lead-programmer` with a `.fail` record on disk. This
   record is read by `hooks/scripts/reviewer-tier.sh` (ADR-0009's dispatch-time
   script), forcing the reviewer to `opus`. The `sonnet` tier for that re-run is
   selected by that same `agents/orchestrator.md:184-189` rule — which says to
   re-dispatch on `sonnet`, not haiku again — and by no skill. If the second run
   on `sonnet` also fails, the orchestrator routes to `spec-master` for a debug
   spec, hitting the 2-FAIL cap.

4. **The tradeoff is explicit and not softened.** A wrong-cheap unit (one that
   appears simple but becomes costly on discovery) now costs:
   - One haiku attempt (FAIL)
   - One sonnet re-run (FAIL or PASS)
   - Two reviews (one on the haiku attempt, one on the sonnet re-run)

   This is more expensive than the prior sonnet default for such units. The bet
   is that such units are rare enough that the expected value of defaulting all
   units to haiku justifies the cost of occasional escalation on discovery.

5. **Implementer tier and reviewer tier are two different mechanisms with
   different decision criteria.** This is essential to avoid a repeat of finding
   F2 (from the efficiency audit), where two model-selection axes were
   conflated. The implementer tier is a flat pre-implementation default (no
   pre-emptive escalation), decided by this ADR. The reviewer tier is
   post-implementation measurement (ADR-0009), decided on the actual diff. They
   are not merged, aliased, or cross-referenced as one rule. The reviewer gate
   is unaffected by this change: even a haiku-implemented unit producing a large
   or security-sensitive diff still draws an opus reviewer (per ADR-0009's script
   measurement).

6. **The "heavy" roast-work/fable advisory trigger remains fully disjoint from
   model selection.** ADR-0004 defines heaviness as ~8 files OR ~400-line diff
   OR structural/security-sensitive change. A haiku-implemented unit satisfying
   the heavy criteria still receives the advisory fable roast pass, independent
   of implementer tier selection. This distinction is what prevents conflating
   the two axes again.
   - **Fable roast-work dispatch superseded:** The separate fable advisory roast pass is superseded by ADR-0013, which removes the dispatching of fable for roast-work entirely.

7. **The judgment `task-master` no longer exercises has moved into an enforced
   dispatch contract.** Dropping pre-emptive tier prediction only works if the
   dispatch itself leaves nothing for a haiku-tier executor to infer. So the
   dispatch instructions from `task-master` to `lead-programmer` are now a
   nine-element checkable contract (issue #209): a `Unit: <task-id>` literal
   first line, plus the eight headings `## Objective`, `## Retrieval`,
   `## Affected files`, `## Ordered edits`, `## Do NOT touch`,
   `## Acceptance criteria`, `## Pre-resolved context`, and `## Escalation`,
   enumerated in `agents/task-master.md`. The contract is mechanically
   enforced, not advisory: the `H4` check in
   `hooks/scripts/dispatch-hygiene.sh` (issue #214) blocks a dispatch to a
   gated target — `lead-programmer` by default — that is missing any of the
   nine elements. The judgment did not disappear; it moved from a per-unit
   tier guess into a per-dispatch completeness requirement a hook can check.
   Scope limit, stated deliberately: H4 audits heading *labels*, not their
   substance — it can force a well-labelled dispatch, never a well-formed one
   — and it is disarmable via `dispatchHygiene.requireContract: false`.

## Consequences

- **Expected FAIL rate increase on haiku units.** All units now start on haiku
  by default; those that fail escalate to sonnet via the `.fail` record. The
  efficiency gain of defaulting the entire population to haiku is expected to
  exceed the cost of escalation on units that cannot be completed on haiku.

- **The success criterion is not measurable forward.** The `.claude/reviewed/`
  directory is `.gitignore`d, so there is no recoverable baseline of
  pre-implementation FAIL rates to compare against. Any before/after measurement
  must start forward from this change.

- **Reactive escalation only.** There is no pre-implementation check,
  no prediction, no heuristic for "this unit looks cheap." A unit escalates if
  and only if it actually fails on haiku. This is the difference between
  "cheaper on average" and "predictably cheap on this unit."

## Related

- **ADR-0009** (Reviewer-tier measured eligibility) — this decision works
  alongside, not within, ADR-0009. ADR-0009 makes the review gate
  post-implementation and measurement-driven, guaranteeing that a large or
  risky diff (including one written on haiku) still gets an opus reviewer.
  That gate is the safety property that makes defaulting implementer to haiku
  safe.

- **ADR-0006** (Reviewer gate: sonnet for mechanical units) — this ADR does not
  amend ADR-0006. The reviewer gate and the implementer tier are separate
  decisions.

- **ADR-0004** (Reviewer roast-work: dual model routing) — the "heavy"
  definition stands unchanged. A haiku-written heavy unit still receives the
  advisory fable roast.

- **Plan:** `docs/plans/2026-08-01-lead-programmer-haiku-default.md` (Steps 1, 3,
  and the outcome this ADR records).
