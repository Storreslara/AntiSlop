---
name: new-hook-script-shifts-out-of-scope-baseline
description: OBSOLETE (2026-09-23, unit rollout-a24-remechanize-1) — A24's conversion to documented skip ended the treadmill; new hooks/scripts/*.sh files no longer break A24's report. Kept for historical reference only.
metadata:
  type: feedback
---

**OBSOLETE as of unit rollout-a24-remechanize-1 (2026-09-23).**

This memory warned of a recurring FAIL scenario when adding new top-level
`hooks/scripts/*.sh` files: `tests/rollout-preflight.test.sh` would fail because
`scripts/rollout-preflight.sh`'s `reverify_spec6()` hardcoded the expected
`hooks/scripts/*.sh` count for spec 6's A24 criterion. The warning instructed
not to fix it yourself but to report it for a separate commit.

**Why it is obsolete:** Commit 3dc371b (rollout-a24-remechanize-1) converted A24
from a hardcoded count assertion to a documented skip. A24 now reports
"skipped: flip unit — nothing-deleted diff (requires the flip unit's own commit)"
instead of measuring a script count. This permanently ends the **treadmill**
maintenance burden: adding new `hooks/scripts/*.sh` files no longer causes A24 to
fail or require a baseline bump. The scenario this memory describes can no longer
occur.

**For historical context:** This scenario recurred identically on gh418 and gh420
(caught and reverted mid-turn by the coordinator both times) before being solved
at the spec level, not the enforcement level — the root cause was in the spec's
criterion design (hardcoded baseline), not in agent behavior. The fix was to
defer A24's measurement to a future flip unit's git-diff range, eliminating the
treadmill entirely. See [[treadmill]] and [[flip unit]] in CONTEXT.md.
