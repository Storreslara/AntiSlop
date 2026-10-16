---
name: ptr-u8-completion
description: ptr-u8 PASS c8cee04 closed #558; dispatch checkpoint + handoff note added to CONTEXT.md; 7 OPEN follow-ups (not fixed)
metadata:
  type: project
---

PASS c8cee04 (2026-10-16) closed #558. CONTEXT.md gained **dispatch checkpoint** and **handoff note** (distinct from the escalation-ladder "handoff" avoid at ~line 403).

OPEN follow-ups (reviewer notes, deliberately not fixed):
- orchestrator.md ~716-717 "Cut off" excludes "a checkpoint" from any persona, but ~84 limits it to task-master/spec-master; reword "other than a task-master/spec-master checkpoint".
- spec-master checkpoint (3) (spec-master.md ~236-238, specs >5 steps) conflicts with the <=5-unit fast path (orchestrator.md ~458); step count vs unit count, mostly unreachable.
- No commit rule for the handoff note (task-master.md ~464-466): an uncommitted overwrite dirties a tracked file and blocks the next reviewer's clean-tree check; commit with the contract file or gitignore it.
- Nothing in tests/ pins the checkpoint wording; suggest a small parity test.
- Checkpoint re-dispatch has no cap; require the handoff note's "next unit" to advance between checkpoints.
- Splitting a wave larger than 5 units is unstated ("consecutive steps").
- Lanes runner deletes its work dir on exit, so a first failed lanes run was unidentifiable; tests/rollout-preflight.test.sh fails alone ~2/11 on the known AC14/W9 flake.

Related: [[ptr-u3b-completion]]
