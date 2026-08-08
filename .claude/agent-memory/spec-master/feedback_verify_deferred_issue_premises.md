---
name: verify-deferred-issue-premises
description: Before specing a deferred/backlog issue, re-verify its premises against the current tree — deferred issues decay, and a stale premise can moot an entire item.
metadata:
  type: feedback
---

When a task starts from an issue that was **deliberately deferred** ("out of
scope for #X, tracked separately"), verify each premise in its body against the
tree before designing anything.

**Why:** #185 deferred three items out of #184 on 2026-07-31. By the time it was
picked up (2026-08-07), #186 had landed and invalidated two of its premises:
the `rg`/`git` "flag scan" it proposed mirroring had been *deleted*, and the
"case 28" it told me to model the fix on *no longer existed*. One of the three
items was thereby entirely moot (correct answer: no change warranted), and
another's proposed fix shape was wrong. Neither is visible from the issue text —
only from reading the current source.

**How to apply:** for each factual claim in the issue body (function X does Y,
test case N uses shape Z, file F contains G), run the grep before building on
it. Report stale premises explicitly in the spec's Context — they are findings,
not pedantry, because they change the work. Related: [[baselines-expire]] (same
decay problem, applied to measurements) and
[[survey-all-fail-records]] (same problem, applied to sampling).
