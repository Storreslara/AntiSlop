---
name: criterion-authoring-non-vacuity
description: Every acceptance criterion in this repo must name a value that is provably different today; the `! ... | grep -qE ...` form is banned by precedent
metadata:
  type: feedback
---

When authoring acceptance criteria for this repo, each criterion must be
**provably non-vacuous**: name a baseline value measured on the working tree
that the change will demonstrably alter (e.g. "`grep -c '_Avoid_' CONTEXT.md`
is ≥ 1, and the pre-change value is exactly 0"). For script effects, use the
**two-assertion form** — assert the exit code AND assert the resulting
working-tree state (`git status --porcelain -uno`). Never the
`! <cmd> | grep -qE '...'` form.

For behavioural checks, require a **mutation proof**: the implementer runs the
test with the defect injected and with the mechanism stubbed out, and records
both outputs. A test that still passes when the mechanism is removed does not
satisfy the criterion.

**Why:** commit `028bc23` ("correct vacuous drift-check acceptance-criterion
form") found a criterion that discarded its exit code via a pipe and could only
ever match one value, so it passed while detecting nothing. `8cedabd` and
`22f5bb2` are the same lineage — this is a repeated, documented defect class
here, not a one-off. The user's own review-side memory carries matching
entries ("Mutate to prove the criterion", "Vacuous exit codes").

**How to apply:** on every step of every plan, before handoff. Also treat it as
a Self-check item ("Does every step carry a criterion that would fail if the
step were not done?"). Where two plans write the same file, prefer a
**baseline-independent** criterion (compare extracted before/after lists) over
a hard-coded count, so the criterion stays correct under either merge ordering.

**Complements — do not duplicate:**
`.claude/agent-memory/spec-master/feedback_verify_own_criteria_nonvacuous.md`
(a different, older memory namespace for this same persona) already covers:
run every criterion before handoff and confirm it is currently RED; one
criterion per file over one recursive grep; the grep-line-wrap trap; and the
self-reference trap when the artifact under test IS the plan document. Read it
alongside this one. What this memory adds beyond it: the two-assertion form,
the specific `! <cmd> | grep -qE` pipe-discards-exit-code defect from
`028bc23`, the mutation-proof requirement, and baseline-independent criteria
for files two plans both write.

Related: [[spec-master-recommendation-style]]
