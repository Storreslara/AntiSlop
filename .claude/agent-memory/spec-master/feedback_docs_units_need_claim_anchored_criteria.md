---
name: docs-units-need-claim-anchored-criteria
description: Existence greps are structurally vacuous for docs units, whose deliverable is the truth value of prose — three units have now FAILed this way. Spec claim-anchored criteria (negative wrong-phrase + positive canonical-phrase) instead.
metadata:
  type: feedback
---

For any unit whose product is **prose about a shipped mechanism** (wiki, ADR,
`CONTEXT.md`, README), never gate on existence checks alone. `grep -q '<term>'
<file>` passes identically whether the surrounding sentence is true or inverts
the mechanism it describes. Gate on **claim-anchored criteria**: a pair per
defect — a negative asserting the exact wrong phrase is absent, and a positive
asserting the canonical phrase is present.

**Why:** three separate documentation units in this repo have now FAILed on the
same thing, each behind existence-only criteria that stayed GREEN throughout:
- `260` — `docs/adr/0015-*.md` states the H3 fail-direction rule **inverted**
  relative to `hooks/scripts/dispatch-hygiene.sh`.
- `gh-286-docs` — docs advertise two capabilities `scripts/agent-audit.sh` does
  not have. Reviewer's words: *"this is a documentation unit, so the accuracy of
  these strings IS the deliverable."*
- `gh138` — wiki prose contradicting `templates/persona-protocol.md`, and in one
  case contradicting an ADR the same unit wrote correctly. Hit the 2-FAIL cap;
  all six gated criteria were GREEN at both FAIL verdicts, i.e. zero
  discriminating power across nine defects.

An aggravating factor in gh138: the wiki portion was labelled "hint-level scope,
not separately gated". That de-gates whether the refresh was **done**; both the
writer and the reviewer read it as **held to a lower standard**, and the fix
pass never reopened the two files at all.

**How to apply:**
1. Identify the canonical source (`templates/persona-protocol.md` for protocol
   rules) and state in the spec that the derived doc loses on any disagreement.
2. Write the negative/positive grep pair per claim; verify every one RED first
   ([[verify-own-criteria-nonvacuous]]).
3. Add a **canonical-source cross-check ledger** for the residue: one row per
   new/edited sentence asserting mechanism behaviour — claim `file:line`,
   canonical `file:line`, verbatim quote, "does the claim follow?". Citation
   resolution is mechanical; the last column is reviewer judgment. Say plainly
   that full semantic checking is not mechanizable rather than inventing a gate
   that looks like it is.
4. Never let "not separately gated" appear without the clause that it de-gates
   *doneness*, never accuracy.

See [[baselines-expire]] for the sibling failure in the same unit (stale packet
assertions) and [[feedback-no-forced-changes]].
