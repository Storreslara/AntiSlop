---
name: feedback-glossary-unit-separate-when-spans-future-steps
description: When a spec's closing "scribe update hint" introduces glossary terms sourced from multiple steps that land in different waves, file it as its own standalone unit blocked on all contributing steps — don't attach it to whichever step's text happens to mention "routed to scribe in the hint below."
metadata:
  type: feedback
---

Observed 2026-08-26 slicing `docs/plans/2026-08-25-harness-trust-gaps.md`
("spec 1" of the 2026-08-25 six-spec rollout) into gh415-gh424. Step 8
(`docs/trust-model.md`) said new glossary terms are "routed to scribe in the
hint below" — reading only that sentence, the natural instinct is to attach
the scribe glossary dispatch to Step 8's own unit (same pattern as
[[feedback_split_unit_across_persona_scopes]]: one unit, two dispatch
prompts under different personas).

That instinct is wrong when the terms actually originate from steps in
*different waves*. Here the five terms were: **audit seal** / **sanctioned
rotation** (Step 3, W5 — lands first), **disarm surface** (Step 4, W7 —
lands LAST by explicit wave-order ruling), **countersign** / **authority**
(Step 9, W5), plus a cross-reference to Step 8's own doc (W6). Attaching the
glossary dispatch to Step 8's unit would have made Step 8 — a W6 unit —
transitively wait on Step 4 landing before it could be marked done, which
directly contradicts the wave graph's whole point of putting Step 4 last so
it isn't blocking anything else.

**How to apply:** before folding a "routed to scribe" glossary/doc hint into
an existing step's unit, check whether every term it documents actually
originates from *that* step alone. If the terms span steps with different
wave placements (especially if one of them is explicitly sequenced last),
file the glossary/documentation work as its own separate unit (a "10th unit"
beyond however many steps the spec has), with its own `Blocked by` line
listing every contributing step by issue number. This keeps each
contributing step's own unit clean of a dependency it doesn't actually need,
and the glossary unit naturally sorts to the very end of the dispatch order
without anyone having to special-case it. Distinct from
[[feedback_split_unit_across_persona_scopes]], which is about one unit's
files crossing persona write-scope boundaries within a single step — this is
about one *piece of documentation* logically belonging to several steps at
once.
