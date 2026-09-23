---
name: rollout_preflight_bump_18_completion
description: PASS 2026-09-23; added mutation-proof direction glossary entry to CONTEXT.md
metadata:
  type: project
---

**Unit:** rollout-preflight-bump-18 (no tracker issue; ad hoc chore)
**Status:** PASS 2026-09-23 (reviewer-approved; commit bc40352)

## Work completed

Bumped `scripts/rollout-preflight.sh`'s A24 hook-script-count baseline from 17 to 18, triggered by `version-stamp-guard-1` adding `hooks/scripts/version-stamp-check.sh` as the 18th hooks script. Updated synthetic test fixtures in `tests/rollout-preflight.test.sh` (18→19 scripts) to maintain discrimination.

This is the fourth recurrence of this procedural update:
- gh418: 14→15
- gh420: 15→16
- spec2-unitC: 16→17
- rollout-preflight-bump-18: 17→18

## Institutional knowledge recorded

**New CONTEXT.md glossary entry:** `**mutation-proof direction**` (CONTEXT.md, after line 780).

The reviewer flagged a new load-bearing term: "mutation-proof direction" — a property of a test that evaluates to true if the measurement genuinely *binds to* its baseline value and responds to mutations. Key distinction:
- Test 1 in rollout-preflight: hardcodes baseline `17`; mutating it causes failure → mutation-proof direction holds
- Test 2 in rollout-preflight: derives expected value as `real+1`; never binds to baseline → mutation-proof direction does not hold

This is load-bearing because:
1. Referenced explicitly in this unit's commit message
2. Explicitly required by spec A30 in architecture-d (`docs/plans/2026-08-25-ci-shaped-review-architecture-d.md`), which mandates mutation discipline for criteria validation
3. Related to existing "mutation proof" concept (CONTEXT.md:772-780) and review technique memory
4. Necessary to distinguish vacuous tests from genuinely discriminating ones

Cross-linked to `[[mutation-proof]]` bundles and mutation discipline in spec governance.

## Advisory note (out of scope for this unit)

The reviewer separately noted that A24's underlying mechanization (an absolute hook-script count) is the pre-amendment draft of its own governing spec (architecture-d:862), which explicitly forbids an absolute count and was superseded by a `git diff --diff-filter=D --name-only` emptiness check. This treadmill (14→15→16→17→18) will recur until A24 is mechanized correctly. The orchestrator is routing a fix for this as a separate future unit.
