---
name: survey-all-fail-records
description: Enumerate the ENTIRE reviewed-records directory before concluding "no prior FAIL on this surface" — a partial sample once inverted a plan's whole risk section and its model-tagging directive.
metadata:
  type: feedback
---

When my persona says to check `.claude/reviewed/` for `.fail` records before
scoping, that means listing **all** of them and filtering by the surfaces the
plan touches — not sampling.

**Why:** on 2026-08-07, a plan's R5 risk item asserted "the only `.fail`
records present are 124, 128, 150, 177, 182 and 191 ... no prior-defect
escalation applies; units may take the normal `haiku` default." The directory
actually held **22**. Filtering by surface: 8 named `dispatch-hygiene.sh` and
9 named `bin/cli.js`/`.claude/agents/` — which were precisely the two steps
the plan modified. The conclusion wasn't incomplete, it was inverted: the two
riskiest surfaces in the repo were tagged as the safest. One of those records
(`224.fail`) was itself a prior instance of the exact defect class the plan
existed to fix — criteria that passed only in a dirty working tree.

**How to apply:** `ls <reviewed-dir>` piped to `grep -F ".fail"` for the full
list (use `grep -F`, not a backslash regex — the path gate refuses to lex
backslash escapes; see [[reviewed-path-gate-blocks-bash]]). Then
`grep -rl -e <surface1> -e <surface2> <reviewed-dir>` to filter by the files
the plan actually touches, and read the two or three most relevant records —
their defect *shape* is what belongs in Risks, not just their existence. A
matching record means that step must not be tagged `haiku`, and the reason
belongs in the plan's Risks section explicitly so `task-master` can act on it.
Related: [[baselines-expire]] and
[[verify-own-criteria-nonvacuous]] — all three are the same lesson, that a
claim in my own plan is unverified until I run it.
