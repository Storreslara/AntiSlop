---
name: technique-update-index-one-flag-per-call
description: git update-index with two index-bit flags in one call does not apply both; set/clear skip-worktree and assume-unchanged in separate calls in criteria fixtures
metadata:
  type: reference
---

`git update-index --no-skip-worktree --assume-unchanged a` leaves skip-worktree SET (`git ls-files -v` prints `s a`, both bits), so a fixture that meant "clear one, set the other" silently tests the wrong state.

**Why:** found 2026-11-01 writing l2-ckhard criterion 2; the probe's 5th step read `index-flags` instead of `pass` until the calls were split.

**How to apply:** in any criterion or test fixture toggling index bits, one flag per `git update-index` call, and check the state with `git ls-files -v` while drafting. Related: [[feedback-verify-own-criteria-nonvacuous]].
