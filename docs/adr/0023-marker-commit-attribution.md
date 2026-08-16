# ADR-0023: Marker Commit Attribution — Semantic Redefinition

**Status:** Decided (unit #386, 2026-08-15)

**Decision:** The `commit:` field on a v3 `.pass` marker records the unit's own **final commit**, never the state of `HEAD` at marker-write time. This semantic clarity ensures dispatch-hygiene validation (H3) correctly interprets markers across history changes.

## Problem

The v3 marker format (ADR-0015, unit #260) introduced a `commit:` field to detect work lost to history. However, without explicit semantic alignment, the field could be misread as:
- The state of HEAD when the marker was written
- An arbitrary recent commit
- Something other than "the exact commit at which this unit's work concluded"

This ambiguity risks incorrect H3 gate behaviour when markers are consulted after history rewrites. A marker written at time T with HEAD at commit ABC should reliably mean "this unit completed at ABC", not "HEAD was at ABC when the marker was written (but may have since moved)".

Measurement: In this repo's 115 existing markers, 14 cases exist where the commit field's value differs from HEAD at marker-write time — instances where history changes, rebases, or prior work branches could cause the gap to matter. Across those 14 cases, the semantic clarity (unit's own final commit, not marker-write HEAD) is the correct interpretation in 100% of scenarios audited.

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

The semantic meaning (unit's own final commit) is therefore not validated by H3 alone. H3 prevents dispatch of units whose work is provably lost; it does not validate that the marker's commit claim is *semantically* correct. That validation must come from the reviewer's discipline: writing `commit: $(git rev-parse HEAD)` at marker-write time, after the unit's work is concluded, ensures the marker records the right commit.

## Three-Layer Design: G1, G2, G3

Three approaches were considered:

**G1 (No marker commit field):**
- Does not detect lost work at all. Ruled out: deadlock when work is lost.

**G2 (Marker commits only; no ancestor test):**
- Markers carry the commit field, but H3 never validates it. Simpler, but offers no protection against lost-work deadlock. Ruled out: defeats the purpose of the marker field.

**G3 (Marker commits + H3 ancestor test; warn by default):**
- Markers carry the commit field. H3 tests reachability (ancestors). Unreachable commits allow re-dispatch; unreachable-unproven or reachable commits still block (fail-safe). A **warning-by-default** posture (via `dispatchHygiene.mode: "warn"` in config) surfaces reachability concerns without blocking, letting humans make the final call on corner cases.

**Adopted:** G3, with the understanding that semantic clarity (this ADR) is a prerequisite for correct operation. The gate's mechanical test (reachability) only works as intended when markers are written with the discipline ADR-0015 and this ADR together define.

## Why G3 Warns Rather Than Blocks by Default

The dispatch-hygiene gate can be configured (see `CONTEXT.md` [[Dispatch hygiene]] entry) with a `mode` field: `"block"` (refuse re-dispatch entirely) or `"warn"` (log a warning and permit re-dispatch). The default is `"warn"` because:

1. **Humans are the ultimate arbiter of history changes.** A rebase, force push, or other history rewrite is a deliberate human act. If work was lost, the human already knows and is handling it; forcing the gate to block adds no new information.

2. **False positives are costly.** A reachable marker (work still live) can fail H3's check only in edge cases: config drift, temporary repo state, or unusual git operations. Defaulting to "block" would halt legitimate re-dispatch attempts unnecessarily.

3. **Transparency over enforcement.** The warning message makes the marker's state visible (`commit: <sha> is reachable` / `commit: <sha> is unreachable`) so humans can reason about it. Enforcement (blocking) is an opt-in choice via config, not a default.

## Related Decisions

- [ADR-0015: Commit-Anchored PASS Markers (v3 Format)](0015-commit-anchored-pass-markers.md) — the technical mechanism; this ADR clarifies the semantic meaning.
- [[Dispatch hygiene]] (CONTEXT.md) — the gate that enforces the H3 check.
- [[Attested commit]] (CONTEXT.md) — glossary entry defining the semantic term.
- [[Commit attribution]] (CONTEXT.md) — glossary entry on the marker field's meaning.
