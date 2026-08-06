# ADR 0009: Reviewer-tier eligibility is measured at dispatch time (amends ADR-0006)

Date: 2026-08-01
Status: Accepted (amends ADR-0006, and through it ADR-0004; supersedes neither)

## Context
ADR-0004 fixed the reviewer's authoritative PASS/FAIL gate on `opus` and
excluded `fable` from it permanently. ADR-0006 narrowed that blanket once,
adding a single conjunctive exception: the gate MAY run on `sonnet` iff the
unit carries `Suggested model: haiku`, is not heavy, and has no prior `.fail`.

The Pass-1 efficiency audit (finding F2,
`docs/plans/2026-08-01-efficiency-audit-remediation-pass1.md`) found that
exception unreachable in practice, and identified the structural reason: a
**timing mismatch**. `task-master` emitted the tag *before* implementation,
when no diff exists, so ADR-0006's condition (1) was a **prediction**
(`haiku`-eligibility of the *implementer's* work) standing in for the property
actually wanted (the *change* is mechanical and low-risk). The reviewer, by
contrast, is dispatched *after* implementation, when the diff is measurable.
Live evidence: an entire 2026-07-30 batch recorded "no unit carries a reviewer
`sonnet` tag either", so every unit was opus-gated regardless of size or risk.

A second finding from the same measurement forced the shape of the fix. Over
the last 50 commits, three of the smallest diffs (`1f 28L`, `2f 41L`, `1f 25L`)
were security-critical hook/matcher fixes. **Size alone is unsafe**: a
size-only threshold would have sonnet-gated all three.

## Decision
Amend ADR-0006 (do NOT supersede it). The principle "the gate is
judgment-capable and `opus` **by default**" is preserved, and the exception
stays a single bounded one. What changes is *when* and *on what evidence* it is
decided:

1. **The prediction-time tag is removed.** `task-master` no longer emits any
   reviewer-model tag. ADR-0006's condition (1) — the `Suggested model: haiku`
   coupling — is retired. `Suggested model:` continues to route the
   *implementer* and now implies nothing about the reviewer's tier.
2. **Eligibility is measured at reviewer-dispatch time** by a deterministic
   script, `hooks/scripts/reviewer-tier.sh <task-id> <git-range>`, which prints
   exactly `sonnet` or `opus`. The orchestrator runs it from the repo root and
   passes the result as the reviewer dispatch's `model` parameter. It prints
   `opus` (fail-closed) if a `.fail` record exists for the unit, the range is
   empty/malformed/unmeasurable, any changed path is in the sensitive set
   (`hooks/`, `bin/cli.js`, `tests/validate.sh`, the protocol templates,
   settings fragments, `.claude-plugin/`, …), or the diff exceeds
   `MAX_CHANGED_LINES=40` / `MAX_CHANGED_FILES=3`.
3. **Downgrade-only asymmetry.** The script's verdict is a **necessary**
   condition for a sonnet gate, never a sufficient one. The orchestrator's
   judgment may downgrade `sonnet` → `opus` at any time and for any reason; it
   may **never** upgrade `opus` → `sonnet`. This is what makes the change a
   relocation of the decision rather than a loosening of it.

**Preserved unchanged (the safety invariants):**

- **`fable` remains PERMANENTLY excluded from the gate** — ADR-0004's decision
  is not reopened. The script never prints `fable`, and no judgment may
  substitute it.
- **The `.fail` disqualifier** — a prior `.claude/reviewed/<task-id>.fail`
  forces `opus`. Enforced twice: inside the script, and by the orchestrator's
  own pre-dispatch check.
- **The escalation path** — a sonnet-gated PASS later found to have missed a
  defect re-reviews on `opus`; that re-review's `.fail` record then
  permanently forces `opus` for that unit id via the disqualifier above. No
  new marker type.
- **The heavy-unit trigger's own three criteria**, which continue to govern
  the **fable advisory pass only**.

**"Heavy" and "sonnet-eligible" remain distinct concepts.** Overloading the
first for the second is precisely what produced F2: ADR-0006's condition (2)
borrowed the fable trigger as a reviewer-gate predicate. The two definitions
are not merged, aliased, or cross-referenced as one rule.

## Consequences
- **The exception becomes reachable, and bounded.** Under a size AND
  path-class rule, roughly 6–8 of the last 50 commits (~15%) become
  sonnet-eligible — up from an observed zero, and still far short of a
  majority.
- **Measured evidence strictly dominates a prediction.** The decision now runs
  against the artifact under review, not against a forecast of it made before
  the artifact existed.
- **Deterministic script over persona re-derivation** (constitution P2). The
  eligibility test is greppable, unit-tested (`tests/reviewer-tier.test.sh`,
  including boundary cases at 39/40/41 lines and 2/3/4 files) and changeable in
  one place, rather than prose each persona re-derives per unit.
- **The gate can still only get stricter by judgment.** Because upgrades are
  forbidden, the worst case of a mis-tuned threshold is an over-conservative
  gate, never an under-reviewed unit that the orchestrator wanted reviewed
  harder.
- **`reviewer-tier.sh` is not a hook.** It is deliberately absent from
  `hooks/hooks.json`; it lives under `hooks/scripts/` only so
  `tests/validate.sh`'s bash-syntax sweep covers it.

### 2026-08-03 re-measurement

A follow-up validation (issue #232) on 2026-08-03 re-measured the gate against the last 60 real commits with fresh task-ids and no prior FAIL records. Result: `8 of the last 60` commits (13.3%) eligible for sonnet; opus 52/60. The measurement lands inside the predicted band: this section's prediction ("roughly 6–8 of the last 50 commits, ~15%") maps to 8 of 60 = 13.3% — confirming initial tuning was sound.

Attribution of the 52 opus verdicts:
- 9 blocked by sensitive-path constraints only (all ≤3 files, ≤38 lines)
- 16 blocked by size constraints only
- 27 blocked by both sensitive-path and size constraints

`MAX_CHANGED_LINES=40` and `MAX_CHANGED_FILES=3` were deliberately left unchanged (operator ruling 2026-08-03, decision option (a) per issue #232). The ~0% figure cited in prior efficiency-pass discussions belonged to the predecessor ADR-0006 scheme that this ADR already retired; no Pass 4 re-files it.

## Related
- Amends ADR-0006 (signal-gated sonnet on the reviewer gate) — its conjunctive
  structure survives; only condition (1)'s prediction-time proxy is replaced by
  a dispatch-time measurement, and the tagging/dispatch split it describes
  collapses into a single dispatch-time decision.
- Amends ADR-0004 transitively — the fable exclusion and the heavy-unit trigger
  it defines are untouched.
- Plan: `docs/plans/2026-08-01-efficiency-audit-remediation-pass1.md` (F2,
  Steps 5 and 6).
