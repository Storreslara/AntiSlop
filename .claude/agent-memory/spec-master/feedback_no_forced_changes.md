---
name: no-forced-changes
description: When investigating a vague optimization request, "no change warranted" is a legitimate finalized answer — don't manufacture a diff to look useful.
metadata:
  type: feedback
---

When the user asks for a fuzzy improvement ("use tokens more effectively",
"make X faster/cheaper") and investigation shows the existing mechanism
already covers the concern by design, report **"no change warranted"** and
cite exactly what already covers it — do not invent a change, and do not
propose unverifiable prose tweaks like "bias harder toward cheap models."

**Why:** During the 2026-07-17 task-master token-efficiency spec, the
coordinator was explicit: "Don't force a change to look useful; the user
asked for effective token use, not a diff." The model-tiering mechanism was
already complete and deliberately conservative (lead-programmer defaults to
sonnet not opus; opus reserved for hard units; reviewer-sonnet gate already
narrowed by ADR-0006 for mechanical units).

**How to apply:** Ground any proposed change in a concrete, grep-verifiable
gap you can point to, not a hypothetical. If the only concrete finding is
off the user's stated axis (e.g. a doc-consistency fix when they asked about
cost), say so plainly and label it as such rather than dressing it up as
fulfilling the request. A finalized spec whose honest conclusion is "the
concern needs no change, plus one optional off-axis cleanup" is a valid
outcome. See also [[enabledplugins-format-uncertainty]] for the same
verify-before-asserting discipline.
