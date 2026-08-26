# ADR 0026: Writer tier defaults to `sonnet`, reversing ADR-0010

Date: 2026-08-25
Status: Accepted (amends ADR-0010)
Ratified by: user (repo owner), 2026-08-25

## Context

ADR-0010 (2026-08-02) set implementer tier to `haiku` by default, accepting
the tradeoff that some units would require escalation on first FAIL. That
decision deferred measurement: *"the success criterion is not measurable
forward… Any before/after measurement must start forward from this change."*

23 days forward (as of 2026-08-25), the corpus exists and has been measured
against ADR-0010 §B4 of the performance-dampeners spec. The measured data
over 269 units in `.claude/reviewed/`:

**Pre-ADR-0010 (haiku era did not exist; `sonnet` default):**
- 66 units, 11 with FAIL records, **16.7% FAIL rate**

**Post-ADR-0010 (current `haiku` default):**
- 203 units, 66 with FAIL records, **32.5% FAIL rate**

The FAIL rate roughly doubled. Pre/post populations differ in composition
(later units concentrate in gate-hardening work) and sample sizes are
unequal (66 vs 203), introducing confounds disclosed to and acknowledged by
the ratifier before this decision.

**Measured spend per model** across 1,073 transcript sessions:
- Haiku: **4.6% of total ($207.29 of $4,520.80)**
- Sonnet: 32.0% ($1,444.59)
- Opus: **58.6% ($2,647.41)** — reviewer re-verifications

The cheap tier is not where the money goes — re-verification is. Each avoidable
FAIL cycle costs an extra opus review plus a full redispatch, drawing on the 58.6%
line item rather than the 4.6% one.

## Decision

1. **Implementer tier now defaults to `sonnet`.** `agents/lead-programmer.md`
   frontmatter sets `model: sonnet` (was `haiku`, reversing ADR-0010).

2. **The escalation ladder starts one rung higher.** A FAIL on a `sonnet`
   unit re-dispatches to `opus` (was `haiku` → `sonnet` → `opus` per
   ADR-0010). The first-FAIL escalation rule in `agents/orchestrator.md`
   is updated to reflect this; subsequent FAIL handling is unchanged.

3. **No pre-emptive tier prediction is reintroduced.** ADR-0010 §2 documented
   that `task-master`'s pre-implementation tagging reached ~0% of units in
   practice; defaulting to `sonnet` does not resurrect that mechanism.
   `task-master` continues to tag reactively only, and the tag's default
   value changes from `haiku` to `sonnet`.

4. **The reactive escalation ladder is retained.** A `.fail` record still
   ratchets a unit's implementer tier — the ladder simply starts higher
   (`sonnet` → `opus` on FAIL, rather than `haiku` → `sonnet` → `opus`).
   The reviewer-gate ratchet in `reviewer-tier.sh` is untouched.

5. **A cost-accounting script records the measurement and decision rule
   pre-registered for forward verification.** Scripts/spend-accounting.sh
   exits 0, accepts an explicit `--until` cutoff, and emits per-model spend
   and per-period FAIL rate in stable JSON. It is a standing tool, not a
   one-off justification: the pre-registered forward rule (stated below) must
   be verified against post-reversal data to confirm the reversal delivered its
   predicted benefit.

## Consequences

- **Expected FAIL rate decrease on default-tier units.** All units now start on
  `sonnet` by default; those that fail escalate to `opus` via the `.fail`
  record. The bet is that avoiding wrong-cheap units on haiku is worth the
  3× per-attempt cost increase (haiku → sonnet), because the opus re-review
  cycle it avoids is more expensive than the raw writer-tier difference.

- **Forward verification is mandatory, not optional.** The reversal is
  ratified (decision taken), but its effectiveness is a testable claim, not
  a given. The pre-registered forward rule is:

  > **After ≥60 units dispatched under the `sonnet` default, the FAIL rate
  > must have fallen below the 32.5% haiku-era rate.** If not, the reversal
  > has not delivered its predicted benefit and ADR-0010's amendment (this
  > ADR) must be revisited rather than defended. Additionally, total spend
  > must not materially worsen — a `sonnet` writer costs ~3× a `haiku` one
  > per attempt, and the bet is that fewer opus re-reviews more than pay for
  > that.

  This commitment is recorded in the decision record itself (above), not as
  an intention to be honored if convenient. `scripts/spend-accounting.sh`
  with an `--until` cutoff is the mechanism for verifying it.

- **Implementer tier and reviewer tier remain separate decisions.** As
  ADR-0010 §5 stated, they must never be conflated: implementer is a
  flat pre-implementation default (changed here); reviewer is post-implementation
  measurement (ADR-0009). Both remain in force, unchanged except for the
  writer default value.

## Related

- **ADR-0010** (Implementer tier: haiku default) — this ADR reverses that
  decision's tier assignment, not its philosophy or mechanisms. The reactive
  escalation, the dispatch contract, the decision to defer to post-implementation
  measurement — all retain.

- **ADR-0009** (Reviewer-tier measured eligibility) — untouched. A sonnet-
  written unit that produces a large or sensitive diff still draws an opus
  reviewer per ADR-0009's measurement.

- **Plan:** `docs/plans/2026-08-25-agent-throughput-performance-dampeners.md`
  (Unit D — the decision and its ratification).
