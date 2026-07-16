# ADR 0006: Signal-gated sonnet on the reviewer's authoritative PASS/FAIL gate (amends ADR-0004)

Date: 2026-07-16
Status: Accepted (amends ADR-0004; does not supersede it)

## Context
ADR-0004 fixed the reviewer's authoritative PASS/FAIL gate on `opus` and
excluded `fable` from it entirely, confining fable to a separate,
non-authoritative advisory `roast-work` pass on heavy units. That protected
the system's core safety property (the Writer/Reviewer split) by keeping the
judgment-critical gate on the strongest model.

Follow-up request: allow flexible reviewer-gate model selection so a
genuinely mechanical unit is not always reviewed on opus. The tension is that
ADR-0004 blanket-states the gate is always opus. The resolution must not
weaken the gate for anything but demonstrably-mechanical work, and must keep
fable off the gate permanently.

## Decision
Amend ADR-0004 (do NOT supersede it). The principle "the gate is judgment-
capable and opus **by default**" is preserved. A single bounded, signal-gated
exception is added:

- The authoritative PASS/FAIL gate MAY run on `sonnet` for a unit iff ALL of:
  1. the unit carries `Suggested model: haiku` (task-master's mechanical,
     low-judgment lead-programmer signal), AND
  2. the unit does NOT meet the existing heavy-unit trigger (`≥~8 impacted
     files OR ≥~400 changed lines`; structural/cross-cutting; security-
     sensitive surface), AND
  3. no prior `.claude/reviewed/<task-id>.fail` record exists for the unit.
- Otherwise the gate runs on `opus` (the default): any sonnet/untagged
  lead-programmer unit, any heavy-unit-trigger hit, or any prior `.fail`.
- `fable` remains PERMANENTLY excluded from the gate. Fable stays confined to
  the separate advisory `Roast pass: fable` dispatch defined in ADR-0004,
  unchanged.

**Who tags / who dispatches:** `task-master` pre-tags the plan step with
`Suggested reviewer model: sonnet` when conditions (1)+(2) hold (and not (3)
for a re-scoped unit it can see). The orchestrator honors the tag at dispatch
and re-applies the `.fail` disqualifier (condition 3) as a dispatch-time
backstop — mirroring the existing `Suggested model` / `Roast pass: fable`
tagging pattern.

**Escalation (mirrors "haiku FAILs escalate to sonnet, never haiku again"):**
if a unit that received a sonnet-gated PASS is later found to have missed a
defect — a human catch, a milestone-auditor finding, or a downstream FAIL on
that unit — it re-reviews on `opus` and is never sonnet-gated again. The opus
re-review, on confirming the miss, returns FAIL and writes the standard
`.claude/reviewed/<task-id>.fail` record; the `.fail` disqualifier then
permanently forces opus for that unit id. OQ4 (escalation) and OQ5
(disqualifier) therefore share one durable mechanism — no new marker type is
introduced, and reviewed-dir ownership (only the reviewer writes there) is
respected.

## Consequences
- **Core safety property preserved for real judgment work:** the gate is opus
  for everything except a conjunctively-gated mechanical slice; fable is never
  on the gate. The Writer/Reviewer split is intact.
- **Bounded cost saving:** mechanical, low-risk units are gated on sonnet
  instead of opus.
- **Conservative by construction:** the conjunction (haiku AND not-heavy AND
  no-prior-fail) plus permanent-opus-on-any-miss means the exception cannot
  quietly erode the gate; a single confirmed miss removes sonnet eligibility
  for that unit forever.
- **No new durable state:** escalation reuses the existing `.fail` record.
- **PASS marker unchanged:** a sonnet-gated review writes the same v2 PASS
  marker (`criteria: <command(s) run>`); no marker-format change.

## Related
- Amends ADR-0004 (reviewer roast-work / dual-model routing) — the fable
  advisory pass and its heavy-unit trigger are unchanged; only the "gate is
  always opus" blanket is narrowed to "opus by default, sonnet for
  demonstrably-mechanical units, never fable."
- Plan: docs/plans/2026-07-16-reviewer-gate-model-selection.md
