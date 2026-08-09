---
name: feedback-fable-roast-pass-removed
description: Never tag a sliced unit "Roast pass: fable" — ADR-0013 (2026-08-03) removed the separate fable advisory roast-work dispatch entirely, superseding ADR-0004's Decision Tension 2. The reviewer's own inline roast-work skill (at its measured tier) now covers what the fable pass used to.
metadata:
  type: feedback
---

Observed 2026-08-09 (agent-auditor-persona slicing, issues #281 and #284):
tagged both units `Roast pass: fable` citing ADR-0004's heavy-unit trigger
list (large surface / structural-cross-cutting / security-sensitive). The
team lead caught this before dispatch — ADR-0004's separate fable advisory
pass was removed entirely by ADR-0013 (2026-08-03, operator ruling,
"Fable is now dispatched by no persona and no pass for roast-work
specifically"). Both issue bodies had to be corrected post-filing.

**Why:** ADR-0004 (which I read/relied on to justify the tag) was still
present in `docs/adr/` and reads as current at a glance — nothing about
reading it in isolation signals it has been superseded. ADR-0013 is a
later, amending ADR that narrows/removes the mechanism ADR-0004 introduced.
Citing an ADR by number without checking whether a later ADR supersedes it
produced a stale instruction baked into a dispatch-ready ticket.

**What actually replaced it:** the reviewer's own inline `roast-work` skill,
run at whatever tier `reviewer-tier.sh` measures for that unit (opus or
sonnet) within the single authoritative review dispatch — no second fable
dispatch. `fable` survives in exactly one place: `milestone-auditor`, and
only on a judgment-signal-free milestone of >=8 units (a different,
size-measured condition, unrelated to per-unit heavy-work triggers).

**How to apply:**
1. Never write a `Roast pass: fable` field on any sliced unit, regardless of
   how well it matches ADR-0004's old trigger list (large surface /
   structural-cross-cutting / security-sensitive) — that mechanism no longer
   exists for task-master-sliced units.
2. Instead, when a unit meets what would have been ADR-0004's heavy-unit
   trigger, note it explicitly for the reviewer in the dispatch prompt (e.g.
   under Routing note or Rationale) — "flag this surface/prior-FAIL-history
   to the reviewer so its inline roast-work skill weighs it" — since the
   reviewer's inline skill still benefits from knowing why a unit is heavy,
   even though no separate dispatch happens.
3. Before citing ANY numbered ADR in a dispatch prompt as justification for
   a mechanism, grep `docs/adr/` for later ADRs whose title or body says
   "supersedes ADR-000N" or "amends ADR-000N" — this repo actively revises
   its own review-routing mechanics (see also ADR-0006, ADR-0009, both
   amended/superseded-adjacent to this same area) and an ADR number alone is
   not evidence the mechanism it describes is still live.
