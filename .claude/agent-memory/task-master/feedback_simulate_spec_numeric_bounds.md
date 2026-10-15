---
name: simulate-spec-numeric-bounds
description: A spec's numeric output/size bounds and keep-rules can be unreachable by its own mechanism; simulate the rule on the real data before slicing, hold the unit as SPEC-GAP.
metadata:
  type: feedback
---

Observed 2026-10-15 slicing wave 1 of `docs/plans/2026-10-15-persona-token-reduction.md`.
Two units had criteria the step's own rule could not satisfy: U1's quiet filter left
694 lines / 47 KB against AC1.2's <= 400 lines / 25 KB (measured by running the
stated regexes with awk over a saved real `validate.sh` run), and U4a's keep rule
kept 56 lead-programmer index lines against a 40-line cap.

**Why:** a contract with an unreachable criterion makes the implementer STOP, and a
FAIL/escalation burns the ladder for a spec defect.
**How to apply:** for every numeric bound or keep/drop rule, run the rule on the real
artifact (saved log, `grep -c` over the index) before writing the contract; if it misses,
file the unit HELD with the measured numbers and a `SPEC-GAP:` report, drop
`ready-for-agent`, and hold its shared-file dependents too.
Related: [[feedback_recheck_baseline_counts_live]], [[feedback_gate_unit_on_open_question]].
