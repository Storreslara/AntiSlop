---
name: gh299_known_gaps
description: "Dashboard CHANGES.md rendering gap closure (closed at 0779929)"
metadata:
  type: project
---

## Human-facing dashboard gap (CLOSED)

**Status:** Closed at commit `0779929` ("feat(gh375): dashboard renders CHANGES.md/QUIZ.md, quiz select, reveal").

**What was the gap:** The microworld dashboard was not surfacing `CHANGES.md` to a human reviewing via the dashboard UI.

**How it was fixed:**
- **Data layer:** `bin/microworld-dashboard/decisions.js:59-63` reads `CHANGES.md` into `entry.changesBody`, fail-soft to `null` when absent.
- **Render layer:** `bin/microworld-dashboard/index.html:649-651` renders `CHANGES.md`, labelled, in the reading order CHANGES.md → PACKET.md → EXAMPLES.md, omitting the pane entirely (not an empty pane) when null. (Line numbers shifted from 635-637 after mw-step3 inserted the `verifiedBy` provenance block above at 632-644.)
- **Coverage:** `tests/dashboard-decisions.test.js` Test (i) covers data layer presence + fail-soft absence; `tests/dashboard-decisions-client.test.js` Test (g) covers render layer presence, ordering, and clean absence.

**Why this matters:** Unit #299 added CHANGES.md as a human-readable walkthrough of *the change* in conceptual order — the whole feature exists to help humans read "CHANGES.md before the diff." The dashboard is a primary way humans engage with escalations, so fixing this was essential to the feature's stated goal.
