---
name: goal-prose-vs-step-table-drift
description: A Goal sentence that is never reconciled with the step table it was decomposed into produces drift no reviewer can catch; re-read the Goal against the steps before finalizing.
metadata:
  type: feedback
---

Before finalizing any plan, re-read the Goal's success criteria clause by
clause against the numbered steps, and confirm each clause maps to at least
one step's acceptance criterion. If a clause has no step, either add one or
strike the clause from the Goal.

**Why:** On the agent-auditor plan (2026-08-09), the Goal promised a report
that "enumerates every agent dispatch ... with its tool and skill inventory",
but Step 1's table listed only six anomaly checks plus two aggregate
inventories, and OQ3 signed that eight-section shape off. All 8 units shipped
and PASSed while half of criterion (a) was never built - no per-dispatch
enumeration, and no tool inventory at any granularity. **This failure mode is
structurally invisible to the reviewer**, which checks code against steps; the
steps were internally consistent, so nothing could fire. Only the
milestone-audit checkpoint caught it, one step before it would have shipped
unnoticed.

**How to apply:** Treat it as a Self-check item on every plan with a
multi-clause Goal - phrase it "Does every clause of the Goal map to a step's
acceptance criterion?" A clause with no step is a `missing` FAIL, not a
stylistic quibble. Relates to [[verify-own-criteria-nonvacuous]], which covers
the inverse defect (a step whose criterion checks nothing).
