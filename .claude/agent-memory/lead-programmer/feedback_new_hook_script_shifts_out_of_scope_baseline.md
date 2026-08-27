---
name: new-hook-script-shifts-out-of-scope-baseline
description: Adding a new top-level hooks/scripts/*.sh legitimately breaks scripts/rollout-preflight.sh's hardcoded A24 script-count baseline — never fix that file yourself, even though your own diff caused it and your reasoning is right
metadata:
  type: feedback
---

Landing a new top-level `hooks/scripts/*.sh` file (e.g. gh418's
harness-integrity-gate.sh, gh420's marker-verify.sh) makes
`tests/rollout-preflight.test.sh` FAIL with "A24 did not show passing on
unmodified worktree" via `bash tests/validate.sh`. The cause is legitimate:
`scripts/rollout-preflight.sh`'s `reverify_spec6()` hardcodes the expected
`hooks/scripts/*.sh` count for spec 6's A24 criterion, and your new file
correctly bumps the real count past it — this is the exact staleness
`docs/plans/2026-08-25-ci-shaped-review-architecture-d.md`'s own A24 note
predicts at W9 (16, then 17 after a further addition).

**Why:** even though your diagnosis and fix are correct, `scripts/
rollout-preflight.sh` and `tests/rollout-preflight.test.sh` are NOT this
unit's files — they belong to a different, already-shipped spec (5, the
rollout-sequencing doc) and are edited as a **separate, scoped commit**, not
folded into the unit whose file addition caused the drift. This recurred
identically on gh418 and again on gh420 (caught and reverted mid-turn by the
coordinator both times) — the project's discipline is "one unit does not
silently patch another unit's criteria," even when your own change is what
broke it and the fix is a one-line count bump.

**How to apply:**
- If `bash tests/validate.sh` fails on `A24` after you add a new top-level
  `hooks/scripts/*.sh` file, do NOT edit `scripts/rollout-preflight.sh` or
  `tests/rollout-preflight.test.sh` yourself, however obviously correct the
  fix looks.
- Report the FAIL and its cause in your ready-for-review packet as a known,
  expected side effect of landing the new script, and name the exact
  baseline bump needed (old count -> new count) so the coordinator/orchestrator
  can apply it as its own commit.
- This is a sibling gotcha to [[g1-bump-invalidates-mirrors]] (mirrors must be
  regenerated in the SAME unit) — the two look similar (both are "your new
  file broke a hardcoded count elsewhere") but the ownership rule is opposite:
  mirrors get fixed IN your unit, this rollout-preflight baseline gets fixed
  OUT of it.
