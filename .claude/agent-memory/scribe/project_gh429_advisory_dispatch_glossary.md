---
name: project-gh429-advisory-dispatch-glossary
description: gh429 added the "advisory dispatch" glossary entry for the new Mode:advisory route-gate token (Step 1 of gh428 persona-audit-remediation batch)
metadata:
  type: project
---

Unit gh429 (Step 1, F1, of `docs/plans/2026-09-04-persona-system-adversarial-audit-remediation.md`,
spec #428) added a **advisory dispatch** entry to `CONTEXT.md`'s `## Language`
section, defining the new `Mode: advisory` second-line token that
`reviewer-route-gate-core.sh` reads: a reviewer dispatch with no
acceptance-criteria command, no verdict, no marker — text report only.

This unit spans two write scopes split into parallel dispatches under the
same unit id: scribe owns only `CONTEXT.md`; a separate lead-programmer
dispatch (same unit id) owns `hooks/scripts/lib/reviewer-route-gate-core.sh`,
`agents/orchestrator.md`, `hooks/scripts/dispatch-hygiene.sh`, and
`tests/review-join.test.sh`. Both must land before combined acceptance
criteria are checked.

**Why:** first of 10 strictly-sequential units in this batch (R1 —
`bin/cli.js` regenerates the whole `fileHashes` map, so no two units may
regen concurrently); this unit's regen commit must fully land before Step
2 starts.

**How to apply:** if asked about this batch's later steps (gh430+), expect
the same split-dispatch pattern (scribe glossary/ADR half + lead-programmer
code half under one unit id) to recur — check task-master's unit dispatch
for an explicit "Do NOT touch" list naming the sibling dispatch's files
before assuming scope.
