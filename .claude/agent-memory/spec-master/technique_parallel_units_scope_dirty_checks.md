---
name: technique-parallel-units-scope-dirty-checks
description: When units are sliced file-disjoint for parallel building, each dirty-tree criterion must name only that unit's files; a directory pathspec or whole-tree check fails on a sibling's work in progress
metadata:
  type: feedback
---

When the operator asks for file-disjoint units to build in parallel (rfp-u7, 2026-10-29), every
`git status --porcelain` criterion must use the unit's own files (plus any read-only ground truth) as its
pathspec. My first draft used `eval/refutation-replay` as the pathspec in three sibling units, and each would
have failed on the others' uncommitted edits in a shared tree.

**Why:** the rfp-u6 contracts used whole-tree `dirty=0` checks, which were safe only because units ran one
at a time. Parallel building breaks that silently: the criterion still looks right.

**How to apply:** for parallel slices, (1) scope every dirty check to the unit's files; (2) a `validate.sh`
criterion runs every suite, so state its precondition (no sibling has uncommitted edits, or its own
worktree); (3) put every version-stamped file, CHANGELOG and `--update` run in one serial unit; (4) a unit
whose criteria read text a sibling adds is ordered after it, even if the two are file-disjoint. Also:
`--update` skips re-rendering when the version already matches, so a mutation measured after the bump does
not change the mirrors (see [[verify-own-criteria-nonvacuous]]).
