---
name: feedback-recheck-baseline-counts-live
description: A finalized spec's stated grep/count baselines (e.g. "14 referrer hits") can be stale by the time task-master slices it, even hours later — re-run the exact baseline command live before finalizing a dispatch, and fold any real discrepancy into Affected files/Ordered edits rather than just noting it.
metadata:
  type: feedback
---

Observed 2026-08-11 (microworld-silo plan slicing, Step 1 -> issue #327). The
plan's Context section stated a referrer-grep baseline of 14 hits for
`bin/dashboard`, with a table enumerating every referrer. Re-running the
identical grep live (`grep -rn "bin/dashboard\|'./dashboard/\|\"./dashboard/"
bin/ tests/ hooks/ | wc -l`) before dispatch returned 15, not 14. The extra
hit was `bin/dashboard/index.html:728`, a self-referential comment naming
`bin/dashboard/feedback-block.js` that the plan's own referrer table omitted
entirely -- not a timing/drift issue (nothing changed the tree between spec
authoring and slicing), just a miss in the original grep's manual table.

**Why this matters:** the step's acceptance criterion is `grep ... | wc -l ->
0`, an absolute target, not a relative "minus 14" check -- so a persona that
trusted the plan's affected-files list without re-running the baseline grep
would land a diff that still fails this criterion (1, not 0), burning a
review cycle for something catchable at slicing time.

**How to apply:** for any acceptance criterion in the finalized spec that is
a `grep`/`ls`/count-based baseline-to-zero check, re-run the exact command
live during slicing (not the plan's likely-similar variant -- the literal
command string) before writing the dispatch. If the live count disagrees
with the spec's stated baseline, don't just silently correct the number in
the dispatch's criteria text -- (1) identify the specific extra/missing hit,
(2) add it to the unit's Affected files and Ordered edits so the executing
persona actually fixes it, and (3) state the discrepancy explicitly in the
dispatch ("live baseline is N, not the plan's stated M -- trust this
dispatch's number") so the persona doesn't get confused by a criterion
comment that disagrees with what they observe when they run it themselves.
This is a routine verification step for any step whose criteria are
`baseline -> 0` shaped, not a special case.
