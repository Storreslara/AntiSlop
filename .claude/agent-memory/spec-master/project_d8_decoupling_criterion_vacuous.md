---
name: d8-decoupling-criterion-vacuous
description: The shipped D8 dashboard decoupling criterion greps bin/dashboard/ which does not exist (real dir is bin/microworld-dashboard/) — it reports 0 unconditionally and never constrained anything
metadata:
  type: project
---

Step D8's "executable proof that the dashboard is decoupled from the
escalation machinery" in `docs/plans/2026-08-10-microworld-dashboard.md`
(~line 1478) is **vacuous as shipped**:

```
grep -rc 'humanReviewMode' bin/dashboard/ | grep -v ':0$' | wc -l   # always 0
```

`bin/dashboard/` does not exist — the real module directory is
`bin/microworld-dashboard/` (7 modules). `ugrep` warns "No such file or
directory", exits 0, and the pipeline reports 0 for any code whatsoever.
The unit (#321) passed on it. Same defect in D8's "Affected files" list,
which names `bin/dashboard/discover.js` and `bin/dashboard/index.html`.

**Why:** measured directly 2026-08-13 while scoping the dashboard decision
surface. The draft spec had proposed "amend the criterion we're breaking";
the truth is stronger and changes the remediation — there was never a
constraint to break, only a document asserting one.

**How to apply:**
- Any new criterion greping the dashboard must name
  `bin/microworld-dashboard/`. Do not copy D8's path.
- When a plan says a shipped criterion constrains your work, **run it first**.
  This is the second instance of a shipped-but-vacuous criterion in this repo
  — see [[feedback_verify_own_criteria_nonvacuous]] and
  [[project_drift_check_idiom_broken]].
- The constraints that DO have force in this area are D8's *prose* ("never
  reads a `.escalated` marker, never writes anything under `.claude/`") and
  the shared protocol's "the dashboard ... is never an acceptance criterion —
  no hook registers it, no gate consults it". That protocol sentence bars the
  dashboard's *rendered output* from adjudicating a unit; it does not bar
  acceptance criteria that test dashboard *code* (D8 itself has such criteria,
  which settles the reading by precedent).
- Recording the vacuity is the fix, not silently repairing the path as though
  the unit had passed a real check. See
  [[project_dashboard_decision_surface_spec]] Step 5.
