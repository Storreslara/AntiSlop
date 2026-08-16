---
name: pass-note-warnings-do-not-propagate
description: A correct diagnosis parked in a non-blocking PASS-marker note does NOT reach the next dispatch — harvest .pass notes for the steps still ahead, not just .fail records
metadata:
  type: feedback
---

Before scoping or re-scoping a step, read the **`.pass` markers of already-
completed sibling steps**, not only the `.fail` records. Reviewers routinely
park accurate, forward-looking warnings in the non-blocking notes of a PASS,
and **nothing in the pipeline carries those forward to the next dispatch**.

**Why:** in the gh403 escalation, the `gh402.pass` marker's note 1 said
verbatim: *"AC2.5 is internally unsatisfiable as written … Steps 3 and 4 edit
the same file and will hit the identical dilemma — task-master should
re-phrase AC before dispatch."* That was exactly right, written ~9 hours
before Step 3 was dispatched, and it was never acted on. Step 3 then burned
two full FAIL cycles and hit the 2-FAIL cap rediscovering it. The PASS marker
is not a dead letter — it is the only place that warning existed.

A related tell: when a sibling step's implementer **silently violated a scope
rule and still passed**, that is evidence the rule itself is defective, not
that the implementer was sloppy. Step 2 regenerated its mirror in-unit
(against its own "Step 5 regenerates those" instruction) and went green;
Step 3 obeyed the instruction and went red. Same rule, opposite outcomes —
the rule was the defect. See [[validate-sh-is-a-mirror-parity-check]].

**How to apply:** in the `.fail`-record screening pass my persona already
requires, widen the sweep to `.pass` markers for units in the *same plan*,
and grep their notes for the names of steps not yet dispatched. Treat any
"Step N will hit this too" note as a blocking input to Step N's criteria.
Per [[survey-all-fail-records]], enumerate rather than sample.
