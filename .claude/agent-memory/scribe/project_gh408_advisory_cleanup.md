---
name: gh408_advisory_cleanup
description: Non-blocking stale documentation items flagged by reviewer on unit gh408
metadata:
  type: project
---

Unit #408 (PASSED) removed the FINDINGS.md reader from the microworld dashboard but left stale documentation in two places. Both are non-blocking cleanup items (graceful degradation confirmed):

1. **bin/microworld-dashboard/decisions.js:4-6** — prose still says "three human-decision touchpoints," but the `findings` field it references no longer exists in the payload. Degrades gracefully to an empty array client-side, confirmed non-crashing; this is purely stale comments.

2. **tests/dashboard-decisions-client.test.js (lines ~296, 477, 643, 670, 720)** — live assertions for the now-unreachable findings pane, testing a UI surface that can never populate after M1.1's removal of the reader.

**Why:** M1.1 (unit #408) decided to remove the `milestone-audit/FINDINGS.md` reader rather than write the missing writer, since writing it would add ceremony and M1 is about reduction. The decision was to remove the capability rather than complete it. The advisory items are remnants of the removed capability.

**Recommendation:** Update the dashboard prose to remove/clarify the findings reference, and remove the corresponding test assertions. Not a blocker — the dashboard degrades gracefully and neither is an acceptance criterion for gh408.
