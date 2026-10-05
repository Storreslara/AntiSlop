---
name: flatten-wrapped-prose-for-phrase-greps
description: A per-line grep for a persona-prose phrase silently misses it when the hard wrap splits it; flatten with tr first.
metadata:
  type: feedback
---

When a criterion asserts a phrase is present or absent in hard-wrapped
persona prose (agents/*.md wrap near 78 cols), use
`tr -s '\n' ' ' < f | grep -o '<phrase>' | wc -l`, never a plain `grep -c`.

**Why:** in the 2026-10-05 ocigf-2 spec, the phrase to remove ("checks
against the journal file itself") was split across orchestrator.md:176-177.
A per-line `grep -c` for it already returns 0, so an "absent" criterion
would have passed vacuously before any edit.

**How to apply:** for any phrase criterion on wrapped prose, flatten first,
then run the criterion against the unedited tree and confirm it is red. See
[[verify-own-criteria-nonvacuous]].
