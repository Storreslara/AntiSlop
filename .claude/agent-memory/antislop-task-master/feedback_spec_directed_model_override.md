---
name: spec-directed-model-override
description: how to honor a spec's explicit "must not be haiku" directive when no .claude/reviewed/*.fail marker exists for the unit itself
metadata:
  type: feedback
---

When a finalized spec explicitly states a unit must not be tagged `haiku` and
grounds that in a **named defect lineage in this exact subject matter**
(e.g. spec-master's ubiquitous-language plan R5, citing `028bc23`/`8cedabd`/
`22f5bb2` — three prior vacuous drift-check acceptance-criterion fixes in this
codebase), honor it even though no `.claude/reviewed/<task-id>.fail` marker
exists for the unit itself (it may never have been built before).

**Why:** the reactive-tagging rule's intent is "don't predict risk from your
own judgment" — but a spec author citing a real, named commit lineage of
prior FAILs in the identical subject area (not just "this looks hard") *is*
evidence already on record, just not in marker form. Treating a spec's own
R-numbered risk citation as inadmissible would mean re-deriving the same
judgment the spec already made, which is out of scope for task-master (never
a re-plan owner).

**How to apply:** escalate to `sonnet` (not `opus`, absent a stronger stated
reason) only when the spec itself names the defect lineage and commit SHAs,
not merely because a unit "sounds risky." All other units in the same slice
still start at `haiku` by default. Record the reasoning in the ticket's
`Suggested model:` section citing the spec's own risk ID (e.g. "R5") so a
future reader can verify the escalation traces to spec text, not to
task-master's own risk assessment. See also
[[feedback_model_tag_cross_cutting_protocol]] for the sibling rule on
structural/cross-cutting escalation.
