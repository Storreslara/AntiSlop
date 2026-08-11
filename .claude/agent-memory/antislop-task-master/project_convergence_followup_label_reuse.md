---
name: convergence-followup-label-reuse
description: When slicing a spec-master Convergence follow-ups round into tracker issues, reuse the base spec's existing plan/<slug> label instead of minting a new round-specific label
metadata:
  type: project
---

When `spec-master` appends a dated `## Convergence follow-ups` section to an
already-sliced spec (new Step numbers continuing from the base plan), file
the new units under the **same** `plan/<original-slug>` GitHub label the base
plan's units already use — do not create a distinct label for the follow-up
round.

Confirmed precedent, checked via `gh issue list` before filing:
- `docs/plans/2026-08-09-agent-auditor-persona.md`'s F2/F3 convergence round
  (issues #296, #297) reused `plan/2026-08-09-agent-auditor-persona`, the
  same label as the base plan's Step 0–7 units (#280–287) — no new label, no
  extra "follow-up" marker label.
- The F-number (F1/F2/F3 etc., matching the spec's own gap-numbering) goes in
  the issue **title**'s trailing parenthetical instead, e.g. `[plan] Step 10
  — make format-probe states genuinely distinguishable (F3, CRITICAL)`.
- Applied the same way for
  `docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md`'s
  round 1 convergence follow-ups (Steps 9–11, F1/F2/F3): filed as #298–300
  under the pre-existing `plan/2026-07-28-microworlds-human-review` label
  (shared with #122, #129–138), titled `(F1)`/`(F2)`/`(F3)` with no `CRITICAL`
  suffix since the spec didn't mark those gaps critical-severity.

**Why:** keeps `gh issue list --label plan/<slug>` a single source of truth
for "everything derived from this spec, base plan plus every convergence
round" — a fresh label per round would fragment that query and force whoever
dispatches next to know which round's label to search.

**How to apply:** before filing a Convergence follow-ups round, run
`gh label list --search plan/<original-date-slug>` to confirm the base
label's exact name, then reuse it verbatim on every new issue plus
`ready-for-agent`. Only mint a new label if the base plan somehow has none
(shouldn't happen — every sliced spec gets one at initial `to-tickets` time).
