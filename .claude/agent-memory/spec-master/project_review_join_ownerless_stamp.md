---
name: review-join-ownerless-stamp
description: Review-join stamps name no owner, so a reviewer whose own stamp was consumed is blocked on another unit's stamp; lov-5 (2026-10-14) only documented it. Fix design options and the measured primitives.
metadata:
  type: project
---

A `.claude/.review-join.<unit>` stamp holds `<ts> unit= prior= prior_mtime=`, no owner. `review_join_state` (stop-gate-core.sh) classifies EVERY stamp on ANY reviewer's SubagentStop, so reviewer A (own stamp already consumed, resumed/second turn) stops while unit B's fresh stamp is unsatisfied -> exit 2 naming B. Reproduced with the real hooks in a scratch project (route-gate A, PASS A, stop A = 0, route-gate B, stop A = 2).

**Why:** slice `lov` (docs/plans/2026-10-14-skills-audit-leftovers.md) chose the documented-only option: lov-5 rewrites the block text (no "you were dispatched for"; report and wait) and pins the residual as test case `residual-ownerless-stamp` in tests/review-join.test.sh, which a real fix must flip to rc 0.

**How to apply:** when the fix is specced (Open Question 1 of that plan), the measured primitives are: Claude Code 2.1.300 has a `SubagentStart` hook event and an `agent_transcript_path` payload field (strings-probed). Option B binds `owner=<agent_id>` at SubagentStart; option C reads the stopping agent's own `Unit:` line from its transcript. Both touch the gate core, its two GENERATED adapter copies (bin/cli.js SHARED_HOOK_LIB_FILES, refreshed by `--update --force-render`) and ADR-0016, whose "per-agent keying is provably wrong" section is about the old watermark, not stamps; read it before proposing B. Related: [[pending-review-flag-resurrection]], [[review-join-null-only-covered-zero-stamp]].
