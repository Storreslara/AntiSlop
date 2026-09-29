# ADR 0038: Review gating is a runtime switch (`reviewGating.mode`), not a fork

Date: 2026-09-29

Status: Accepted

## Context

Operators want a fast mode without the reviewer-marker ceremony. Three
alternatives were on the table:

- A permanent `gateless` branch. Rejected: two products to maintain.
- Spec 6's CI-shaped replacement
  (`docs/plans/2026-08-25-ci-shaped-review-architecture-d.md`). Never
  executed; its D0 also disarmed `protected-paths.sh`, which this change
  must not do.
- A runtime key in `.claude/persona-config.json`.

Spec 6 had already reserved the key name `reviewGating.mode` (values
`enforce | warn | off`) and listed it in the disarm surface.

## Decision

Reuse the reserved key with values `enforce | off`. Absent, unreadable or
junk values resolve to `enforce`; only the exact string `off` disables.

Under `off`:

- The reviewer is still dispatched once per unit and returns a verdict, but
  the verdict is an **advisory verdict**: no `.pass`/`.fail`/`.blocked`/
  `.escalated` marker is written and nothing blocks on it.
- Inert: the pending-review flags and review-join verdict check in `stop-gate.sh`,
  unit stamping and unit-exclusivity in `reviewer-route-gate.sh`,
  `task-gate.sh`, the marker-based H3 check in `dispatch-hygiene.sh`, and
  `human-decision-gate.sh`.
- Human escalation is dropped (the human's 2026-09-29 answer, option B): no
  escalation verdict, packet or marker. The fix loop stays; at a unit's
  second advisory FAIL the orchestrator lists `Unresolved advisory findings`
  in its report and carries on.
- Still armed: `protected-paths.sh`, `harness-integrity-gate.sh` and
  config-drift detection, `reviewed-path-gate.sh`, the reviewer-dispatch
  identity and privileged-name guards, and the stop-gate test+lint check
  (the human's answer to the mixed-hook question: all three stay on).
- Scribe closes an issue when the dispatch quotes the reviewer's PASS verdict
  line verbatim; the closing comment is labelled
  `advisory PASS (review gating off)`.
- The key is flipped only through the human-confirmed Edit path
  (`/antislop:gate on|off`); the human commits the change and starts a new
  session so config-drift clears.

This supersedes spec 6's D0 exemption list and its `warn` value, which was
not adopted. Consequence: CONTEXT.md's "enforced mechanically" statement in
The Writer/Reviewer split is now conditional on `enforce`.

## Consequences

- Each consumer inlines the same canonical read, following the
  `dispatchHygiene.mode` precedent; agreement is proven by
  `tests/review-gating-off.test.sh`.
- Not every dispatch gets an audit line: `dispatch-hygiene.sh` logs only when
  a check fires, so the plan's assumption to the contrary was wrong.
- Flipping back to `enforce` leaves stale `.pending-review.*` and
  `.review-join.*` state, which applies again; the slash command warns about
  it. Flags and markers are ignored under `off`, never deleted.
- Running under `off` drops `.fail` history: findings survive only in the
  orchestrator's report (plan risk R5).
- `humanReviewMode` remains the setting for `enforce` projects; `off` here
  overrides it. ADR-0036's keep-as-is disposition of
  `human-decision-gate.sh` is unaffected.
