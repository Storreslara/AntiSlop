# ADR 0013: Fable removed from the roast-work advisory pass (amends ADR-0004 and ADR-0009)

Date: 2026-08-03 (operator ruling)
Status: Accepted

## Context

ADR-0004 established that the reviewer's authoritative PASS/FAIL gate runs on `opus`, and that for heavy units (≥8 files, ≥400 lines, structural, or security-sensitive), an **additional** separate advisory `roast-work` pass runs on `fable` to provide bulk-context critique without gating the verdict.

The efficiency audit (2026-08-03) measured the heavy-unit trigger (roast-work criteria 2 and 3) as firing on ~85% of this repo's commits (52 of 60), with no size floor on either criterion — an over-broad trigger, not the genuinely rare exception ADR-0004 intended. spec-master's own recommendation was to **narrow** the trigger (add a conjunctive size floor to criteria 2 and 3) rather than remove the pass, which would have kept ADR-0004 intact. **The operator ruled otherwise on 2026-08-03 (OQ1): remove the separate fable dispatch entirely, against spec-master's recommendation**, accepting the resulting capability reduction against ADR-0004's rationale as a deliberate tradeoff.

## Decision

**Supersedes ADR-0004 § Decision Tension 2** (model routing / the separate fable advisory dispatch). The separate fable advisory pass is removed entirely; `fable` is no longer dispatched for roast-work critique.

**ADR-0004 § Decision Tension 1 survives unchanged:** roast-work remains advisory-only, appended after the verdict line, never gating the PASS/FAIL verdict. The core safety property (PASS/FAIL determined by acceptance criteria + materiality filter, roast-work never flips it) is untouched.

**Capability knowingly given up:** per the operator's 2026-08-03 ruling on OQ1 — against spec-master's own recommendation to narrow the trigger rather than remove the pass — fable's bulk-context critique strength on large surfaces is no longer available as a separate dispatch. The replacement is the reviewer's inline `roast-work` skill (opus or sonnet per the measured tier), which provides detailed critique within a single dispatch.

**Fable is now dispatched by no persona and no pass for roast-work specifically.** The standing exclusion guard in `agents/orchestrator.md` (§ task-master model routing) is retained deliberately to prevent accidental re-introduction into `task-master`. This is a deliberate cost reduction, not an oversight.
  - **Superseded by #348:** the cited heading was renamed to "Dispatch-model routing for spec-master, milestone-auditor, and task-master" (`agents/orchestrator.md:294`); the exclusion guard itself is unmoved and still there.

**Caveat:** `milestone-auditor` **retains a `fable` tier** — but only on a different, size-measured condition: a judgment-signal-free milestone of ≥8 units (measured to fire on ~25% of this repo's milestones). This is per the operator's 2026-08-06 correction (Revision 6 of the efficiency audit plan). Do not overstate this decision as "fable is retired everywhere" — that is false.
  - **Superseded by #348:** OQ-N1(a) removes this `milestone-auditor` `fable` tier entirely — `milestone-auditor` now always dispatches on its `opus` frontmatter default, same as `spec-master`. "Fable is retired everywhere" is now true for `milestone-auditor`.

**Amends ADR-0009** with the 2026-08-03 re-measurement: 8 of the last 60 commits (13.3%) are sonnet-eligible for the reviewer gate. This lands inside ADR-0009's predicted band (roughly 6–8 of 50, ~15%); the thresholds (`MAX_CHANGED_LINES=40`, `MAX_CHANGED_FILES=3`) were deliberately left unchanged per operator ruling.

**Preserves ADR-0006's reviewer-gate invariant:** the `.fail` expiry added in unit #233 applies to **implementer tiers only**. The reviewer gate's `.fail` disqualifier never expires — a prior `.claude/reviewed/<task-id>.fail` record permanently forces `opus` on that unit, independent of subsequent PASS markers.

**F10 was assessed and rejected:** the milestone-audit gate remains unconditional and mandatory; "a clean checkpoint is not a reason to skip the audit" is unchanged. The audit itself was never made optional. F10's saving is partly captured by F1 (unit #230), which drops a clean, FAIL-free, all-mechanical milestone's audit from `fable` to `sonnet` — but only for milestones **under 8 units**. A clean milestone of **8 or more units** still audits on `fable` (3 of this repo's 12 milestones, 25%). That partial saving was the narrower of two supports for the rejection; the load-bearing one is that the principle is deliberate and reasoned. Provenance: `docs/plans/2026-07-13-persona-review-hardening.md:583`.
  - **Superseded by #348:** OQ-N1(a) removes the `milestone-auditor` `fable` tier entirely — a clean milestone of 8 or more units now audits on `opus`, same as every other milestone. The "3 of 12 milestones" fable-eligible figure no longer applies.

## Related findings

**F9 (unit #241) — resume the same reviewer on `INSUFFICIENT-CONTEXT`:** When a reviewer dispatch encounters a missing constraint and signals `INSUFFICIENT-CONTEXT`, the orchestrator now resumes the same reviewer session by name via `SendMessage`, quoting the constraint, instead of spawning a fresh reviewer dispatch. This does not count against the 2-FAIL cap, does not re-dispatch lead-programmer, and the standing pending-review flag stays in place.

**F11 (unit #242) — reuse a forwarded blast-radius answer instead of re-deriving:** When a dispatch packet already contains a `## Pre-resolved context` blast-radius / structural answer, personas now verify the specific doubted claim via `explorer` rather than re-deriving from scratch. Applies to lead-programmer, spec-master, and milestone-auditor only — the reviewer is explicitly exempt and always re-derives blast radius independently.

## Consequences

- **Simpler review flow:** A single reviewer dispatch runs on opus or sonnet (measured at dispatch time); no separate fable advisory pass. Removes the cognitive overhead of tracking two parallel verdict streams.
- **Capability traded for simplicity:** Fable's bulk-context strength on large surfaces is no longer available as a separate dispatch. Roast-work critique is inline only, at the reviewer's measured tier. This is a real reduction in coverage for structurally large changes.
- **Fable's niche narrowed:** Fable is now dispatched only by `milestone-auditor` on a size-measured condition (≥8-unit milestones), never by `spec-master`, never by `reviewer`, and guarded against in `task-master`. This is intentional — the model's cost/benefit ratio is poor for most unit-level work.
  - **Superseded by #348:** OQ-N1(a) removes this `milestone-auditor` `fable` tier entirely — fable is now dispatched by no persona for any purpose. The exclusion guard in `task-master` remains, now redundant-but-harmless rather than load-bearing.
- **Implementer-tier ratchet vs. reviewer-gate ratchet:** Distinguishes two separate `.fail` disqualifier mechanics, per the F4 ratchet table (`docs/plans/2026-08-03-efficiency-audit-remediation-pass3.md` ~line 131-139). The implementer-tier ratchets — R3 (a unit's own prior `.fail`, scoped to that unit) and R4 (haiku→sonnet on first FAIL, "never haiku again") — expire on a subsequent verified PASS newer than the `.fail` record. **R2, the reviewer-gate ratchet, stays permanent**: a `.fail` record permanently forces `opus` on that unit's review, and ADR-0006 § Consequences depends on this never expiring. Both use the same `.claude/reviewed/<task-id>.fail` marker type; the difference is which tier's routing it guards.
- **Cost reduction measured:** Efficiency audit finding F2 measured the separate fable advisory pass's trigger (criteria 2 and 3, which carried no size floor) as firing on roughly 85% of this repo's commits (52 of 60 measured) — the over-broad-trigger problem this removal addresses. Only 8 of 60 measured commits did not trigger it.
- **Dead-state note:** `.claude/agent-memory/antislop-task-master/roast-pass-class-ledger.md` (which would have tracked clean-pass streaks for the now-removed fable trigger) has never existed in this repo's git history. There is nothing to delete or mark retired; recorded here so a future pass does not go looking for it.

## Related
- Supersedes ADR-0004 (reviewer roast-work / dual-model routing) § Decision Tension 2 — the fable advisory pass is removed; the roast-work advisory-only property (Tension 1) survives.
- Preserves ADR-0006 (signal-gated sonnet on the reviewer gate) — the `.fail` expiry added by Step 4 applies to implementer tiers only; the reviewer-gate `.fail` disqualifier (R2) remains permanent and untouched, exactly as ADR-0006 requires.
- Amends ADR-0009 (reviewer-tier measured eligibility) with the 2026-08-03 re-measurement and affirms thresholds unchanged.
- Plan: `docs/plans/2026-08-03-efficiency-audit-remediation-pass3.md` (Step 15, Step 16 Contract B).
