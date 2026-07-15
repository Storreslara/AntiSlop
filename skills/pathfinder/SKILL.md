---
name: pathfinder
description: >
  Apply when slicing a finalized spec into dispatch-ready units (task-master's
  `to-issues` job). Sizing, naming, and ordering guardrails adapted from
  mattpocock/skills `wayfinder` for reliable, unambiguous lead-programmer/scribe
  dispatch — not a planning or grilling skill.
---
Derived from mattpocock/skills `wayfinder`, adapted for task dispatch:
wayfinder charts foggy work as a map of decision tickets; pathfinder narrows
that idea to task-master's actual job — turning an already-finalized spec
into dispatch-ready units, never deciding what to build.

Four rules:

1. ONE UNIT, ONE DECISION — size each sliced issue to a single vertical
   slice a lead-programmer session can execute end-to-end: one file set, one
   acceptance check, one commit. If a unit bundles two independent decisions
   or touches unrelated surfaces, split it before filing — don't let "small
   enough to review" become "small enough to argue about."
2. REFER BY NAME, NOT BY BARE ID — in dispatch prompts, retrieval-contract
   lines, and ordering notes, name units by their title (e.g. "Step 2.3 —
   author pathfinder skill"), not a bare issue number. The id still travels
   alongside for fetching, but the name is what a reader keys off; a wall of
   #27, #28, #29 is illegible.
3. EXPLICIT BLOCKING, NEVER IMPLICIT ORDER — when unit B needs unit A done
   first, say so directly (a `Depends on / blocked by:` line pointing at A by
   name, on the tracker's native dependency field if it has one). Don't rely
   on file order in a plan doc or reading order in a dispatch prompt to imply
   sequencing — a unit is only independently grabbable if its blockers are
   stated, not inferred.
4. STATE IT PRECISELY OR IT'S NOT READY TO TICKET — the same bar as this
   project's machine-checkable-criteria rule: an acceptance criterion is only
   valid if it's something an agent can RUN and get a pass/fail from, not
   "works correctly." If you can't state a unit's criterion that precisely,
   that's a spec gap, not a slicing problem — report it back to spec-master
   rather than papering over it with a vaguer ticket. A unit whose question
   isn't sharp yet doesn't get a placeholder ticket; it stays unsliced until
   the spec resolves it.

Scope: slicing and dispatch-prompt authoring only. This skill carries none of
wayfinder's user-facing ticket types (research, prototype, grilling) —
task-master never grills, spec-master already did — and none of its
transitive skill dependencies (grilling, domain-modeling, prototype).
