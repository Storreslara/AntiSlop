# ADR-0023: Marker Commit Attribution — Semantic Redefinition

**Status:** Decided (unit #386, 2026-08-15)

**Decision:** The `commit:` field on a v3 `.pass` marker records the unit's own **final commit**, never the state of `HEAD` at marker-write time. This semantic clarity ensures dispatch-hygiene validation (H3) correctly interprets markers across history changes.

## Problem

The v3 marker format (ADR-0015, unit #260) introduced a `commit:` field to detect work lost to history. However, without explicit semantic alignment, the field could be misread as:
- The state of HEAD when the marker was written
- An arbitrary recent commit
- Something other than "the exact commit at which this unit's work concluded"

This ambiguity risks incorrect H3 gate behaviour when markers are consulted after history rewrites. A marker written at time T with HEAD at commit ABC should reliably mean "this unit completed at ABC", not "HEAD was at ABC when the marker was written (but may have since moved)".

Measurement (2026-08-15, every `.pass` marker in `.claude/reviewed/`, not a sample): of 224 markers total, 109 are pre-v3 and carry no `commit:` field at all, leaving 115 that carry a resolvable `commit:` SHA. Of those 115, 14 (12.2%) are proven `mismatch` cases — the marker's `commit:` field equals what `HEAD` was at marker-write time, but that value is a *different* unit's commit (e.g. a sibling unit dispatched into the same shared working tree), not this unit's own final commit. Concrete examples: `263.pass` cites `feat(unit #264)`'s commit; `gh341.pass` cites `fix(gh288-2)`'s commit. In 13 of the 14, the correct commit for that unit exists elsewhere in history — the marker recorded the wrong one, not an unconventional one.

## Decision

Clarify the semantic meaning:
- `commit:` means the unit's **own final commit** — the commit at which the unit's work, as reviewed and accepted, concluded.
- Never the state of `HEAD` at the moment the marker was written.
- Not tied to any other commit in the repo's history; not a "closest reachable" approximation.

This clarity applies **retroactively** to all markers already carrying a `commit:` field, and **prospectively** to all new markers written going forward (unit #260 onwards).

## Validation: H3's Ancestor Test Is Necessary But Not Sufficient

The dispatch-hygiene gate (H3, `dispatch-hygiene.sh`) checks whether a marker's commit is an ancestor of `HEAD`. This is a **necessary** gate for detecting lost work (if the commit is not reachable, the unit was definitely lost). However, it is **not sufficient** to determine semantic meaning:

- **Necessary:** A commit that is not an ancestor of HEAD (unreachable) proves the work was lost, allowing re-dispatch.
- **Not sufficient:** A commit that IS an ancestor of HEAD (reachable) does not tell us *which* commit the marker refers to — only that the marker's claim is still live in the repo. The gate cannot distinguish "marker meant this commit, and it's still here" from "marker meant a different commit, and it's also still here because both are ancestors of HEAD".

The semantic meaning (unit's own final commit) is therefore not validated by H3 alone. H3 prevents dispatch of units whose work is provably lost; it does not validate that the marker's commit claim is *semantically* correct — a commit that belongs to a different unit but is still reachable from `HEAD` passes H3's test just as cleanly as the unit's own commit would. Validating that the field names the *right* commit, not merely a *reachable* one, is what the rest of this milestone's steps (G1/G2/G3 below) exist to do; H3 alone cannot do it. In particular, the field must never be derived by prescribing `git rev-parse HEAD` at marker-write time as if that were sufficient — `HEAD` is acceptable only when the writer has verified it equals the unit's own final commit (the tip of the range actually reviewed); deriving the field this way is the subject of a later step in this milestone (Step 2), not yet shipped, and is not restated as done here.

## Three-Layer Design: G1, G2, G3

Three separable outcomes were adopted together, in descending order of certainty:

**G1 (deterministic).** The escalation-resolution `approve` route stops re-deriving the commit at all. It copies the `commit:` value verbatim from the standing `.escalated` marker, which already records the commit the review was actually performed against.

**G2 (deterministic).** The protocol stops *prescribing* the defect. Every surface that today tells a marker writer to use `git rev-parse HEAD` is corrected to prescribe the unit's own final commit — the tip of the range the reviewer actually reviewed — with `HEAD` accepted only when the writer has verified the two are equal.

**G3 (heuristic safety net).** A new shared script (`marker-commit-check.sh`, a later unit in this milestone) classifies any marker's `commit:` field as `ok` / `mismatch` / `unverifiable` and is consulted at reviewer turn-end, where the unit id is already known. Its output is logged to `.claude/review-audit.log`; by default (see below) a `mismatch` classification is logged, never blocked. `commit: none` — the ADR-0015 fail-open bootstrap for markers written before a repo's first commit — classifies `unverifiable`, consistent with H3's own treatment of that value.

**Adopted:** all three, layered — G1 and G2 close the defect at its source; G3 is a heuristic safety net over whatever G1/G2 do not (or cannot yet) prevent. G3 is explicitly **not** a substitute for G1/G2: a heuristic that catches a fraction of a defect it did not prevent is a worse outcome than a protocol that does not create the defect.

## G3's Gate Defaults to Warn, Not Block

G3's classifier is consulted through a dedicated config key, `markerCommitCheck` (introduced by a later step in this milestone, not yet shipped as of this ADR), independent of the pre-existing `dispatchHygiene` config (whose own `mode` defaults to `"block"`, per `dispatch-hygiene.sh` and unchanged by this ADR). `markerCommitCheck`'s `mode` is designed to default to `"warn"` when the config key is absent, with `"block"` available as an opt-in. This is a deliberately different default from `dispatchHygiene`, because:

1. **Humans are the ultimate arbiter of history changes.** A rebase, force push, or other history rewrite is a deliberate human act. If work was lost, the human already knows and is handling it; forcing the gate to block adds no new information.

2. **False positives are costly.** A `mismatch` classification can arise from legitimate commit-message conventions the classifier doesn't yet recognize. Defaulting to "block" would halt legitimate re-dispatch attempts unnecessarily.

3. **Transparency over enforcement.** Logging the classification makes the marker's state visible so humans can reason about it. Enforcement (blocking) is an opt-in choice via config, not a default.

## Related Decisions

- [ADR-0015: Commit-Anchored PASS Markers (v3 Format)](0015-commit-anchored-pass-markers.md) — the technical mechanism; this ADR clarifies the semantic meaning.
- [[Dispatch hygiene]] (CONTEXT.md) — the gate that enforces the H3 check.
- [[Attested commit]] (CONTEXT.md) — glossary entry defining the semantic term.
- [[Commit attribution]] (CONTEXT.md) — glossary entry on the marker field's meaning.
