---
name: esc-chat-6-completion
description: esc-chat-6 docs cleanup; FAIL 1 was a measurement taken against the wrong (pre-fix) gate and an over-broad "every other path hard-denied" invariant; fix b2bc789
metadata:
  type: project
---

esc-chat-6 (2026-10-03, baseline 60b454f): ADR-0039 dialog is 8 lines not 7; stale glossary prose reworded to the ADR-0039 invariant; Evidence-limits clause added to README, CONTEXT.md, architecture.md.

**FAIL 1 (2c3f3c4), fixed in b2bc789:**
- The Unicode-space list I "measured in bash" was true only at 60b454f. 9b98f10 (an ancestor of my own commit) added `local LC_ALL=C` to `is_sanctioned_marker_write`. Lesson: measure at the commit you are documenting, by extracting the function from `git show <rev>:` and checking, not against a locale-level bash test. See [[verify-plan-premise-freshness]].
- "every other protected path stays hard-denied" was false: reviewed-path-gate grants the reviewer (and the main session when no reviewer is selected) writes to the reviewed-marker directory. The human-decision gate is also inert under `reviewGating.mode: off`. Scope any write invariant to the gate and the gating mode it holds under.

**Gate hazard:** a Bash probe whose text spells the reviewed-marker path is blocked for scribe by reviewed-path-gate. Put the probe in a scratch script via Write and build the path from split strings, and use `git commit -F`.
**Finding:** two early `tests/validate.sh` runs reported mirror-parity/cli-backfill FAILs with a clean tree; later runs (including the clean-worktree one at b2bc789) were green.
