---
name: technique-existing-test-encodes-old-bug
description: Before trusting a plan's "every existing test keeps its verdict", grep old suites for the exact scenario the fix changes; an old fixture may BE the bug (esf-flag-fix, stop-gate-blocked (h))
metadata:
  type: feedback
---

A plan can ask for a behaviour change AND "every pre-existing test keeps its verdict" when an old fixture is the very scenario being changed. esf-flag-fix: `tests/stop-gate-blocked.test.sh` case (h) writes `defer:` into a flag path the reviewer had just cleared, which is a flag resurrection. The approved fix drops that flag, so (h) flips, and the plan's Do-NOT-touch list forbids editing it.

**Why:** spec-master's measured reproduction only checked the suite the plan named in its Escalation (`review-join.test.sh`). It did not check every suite that drives the same hook.

**How to apply:** when you get a behaviour-change unit, grep `tests/` early for the trigger sequence (here, a reviewer stop followed by a write into the same flag path), and run full `tests/validate.sh` before any commit. If an old case encodes the changed behaviour, stop and report it as a plan conflict. Never edit the old test yourself.
