---
name: reproduce-advisory-figures-at-defect-scope
description: Re-measure a reviewer's advisory population figure at the defect's OWN scope before writing it into a plan; a correct-looking number can belong to a different mechanism than the one illustrated.
metadata:
  type: feedback
---

When a reviewer routes an advisory note with a population figure ("47 of 300
markers already do X"), reproduce it yourself at the scope the defect actually
operates on — not the scope that was easiest to grep.

**Why:** on gh295-1 (2026-09-01) the reviewer's item titled "indented-note-list
tag loss" illustrated the defect with a BOLD-wrapped example and attached a
figure measured over INDENTED lines. Three things were wrong at once:

1. It was two independent defects (indent-merge at `marker-verify.sh:78`,
   wrapper-strip at `:85`), not one.
2. The 47 was a whole-file count; scoped to the note section the defect parses,
   it is 19.
3. The illustrated defect (wrappers) had the LARGER population — 79 of 233 —
   and had never been measured at all. Ranking by the quoted figure would have
   prioritized the smaller defect.

**How to apply:** before promoting an advisory into a step or an acceptance
criterion, (a) split it into one mechanism per finding, (b) re-run the count
scoped to the code path that mis-handles it, and (c) execute the illustrated
example against a verbatim copy of the shipped logic — do not read the regex
and infer. The advisory is a lead, not a measurement. Related:
[[verify-own-criteria-nonvacuous]], [[review-join-null-only-covered-zero-stamp]].
