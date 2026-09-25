---
name: hcb-prose-history-completion
description: PASS 2026-09-24; four new glossary entries added to CONTEXT.md for sweep closure and related terms
metadata:
  type: project
---

## Unit hcb-prose-history Completion

**Status:** PASS 2026-09-24; commit `8f7c1d6`

**What shipped:** Dated, append-only amendment notes on five finalized historical plan documents (rows 7, 8, 9, 13, 14) whose prose about `harness-integrity-gate.sh` was made false by the human-confirmation branch shipping; an in-place correction (row 15) to a `spec-master` agent-memory file; and a new sweep-closure test in `tests/harness-integrity-gate.test.sh`.

**Glossary entries added to CONTEXT.md:**

1. **sweep closure / Cat 1 / Cat 2 / Cat 3 / Cat 4** — repo-wide grep-based classification via a literal file→category table, ensuring every file matching a stale claim's pattern is accounted for, in both directions. Citation: `docs/plans/2026-09-23-harness-integrity-gate-human-confirmation.md` subsection "Sweep closure" (lines 1339–1557). Four-category taxonomy: Cat 1 (not about this gate), Cat 2 (claim made false, needs dated note), Cat 3 (still literally true, NO note), Cat 4 (whole file excluded).

2. **hit-bearing file** — a file matching a sweep-closure pattern at least once; the unit of classification in a sweep-closure table (never keyed on line or hit count).

3. **lens-2** (finding) — existing glossary term used correctly, but surrounding prose's OTHER claims about the same subject are stale. Distinct from lens-1 (wrong meaning) and lens-3 (missing entry). Used in sweep-closure rows to preserve still-true clauses that must not be deleted.

**Non-blocking gaps noted by reviewer:** (none from this unit)

**Why these terms earned entries:** Each is now asserted on by a merge-gated test (`tests/harness-integrity-gate.test.sh` sweep-closure check), which the reviewer identified as the threshold at which a term warrants a glossary entry.

**Important note:** Two of the four terms (`sweep closure`, `hit-bearing file`) and the Cat 1-4 names originate in the origin document and should be reused as a convention for prose-reconciliation sweeps in future units, rather than reinventing a new classification scheme.
