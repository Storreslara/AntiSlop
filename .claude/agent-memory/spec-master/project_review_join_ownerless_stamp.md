---
name: review-join-ownerless-stamp
description: Review-join stamps name no owner; lov-5 documented it, lo2 (2026-10-14) held the fix on an OQ because SubagentStart carries NO unit id (measured). Fix design options and the measured primitives.
metadata:
  type: project
---

A `.claude/.review-join.<unit>` stamp holds `<ts> unit= prior= prior_mtime=`, no owner. `review_join_state` (stop-gate-core.sh) classifies EVERY stamp on ANY reviewer's SubagentStop. Blocked: any reviewer stopping while NO stamp is satisfied and another is unsatisfied (consumed reviewer, un-stamped reviewer, advisory pass). Converse (by code, :396 + :408-433): a reviewer that wrote no verdict is LET THROUGH when another unit's stamp is satisfied, and consumes that stamp. Test case `residual-ownerless-stamp` in tests/review-join.test.sh pins the residual; a real fix must flip it to rc 0.

**Why:** lov-5 chose documented-only; slice lo2 (docs/plans/2026-10-14-skills-audit-leftovers-2.md, Step 6 + Open Question 1) was asked to spec "Design B, bind at SubagentStart" but measured that it cannot.

**How to apply (measured on Claude Code 2.1.300 binary, re-probe on newer):**
- `SubagentStart` payload = base + `agent_id`, `agent_type` ONLY. No prompt, no `tool_use_id`. Binding at start can only guess ("newest unbound stamp"), and a mis-bind makes another unit fail OPEN.
- `SubagentStop` = base + `agent_id`, `agent_transcript_path` (empty in some mode), `agent_type`, `last_assistant_message`. The transcript's first JSONL record is `type:"user"` whose `message.content` starts with the dispatch prompt (`Unit: lov-5\n...`). That is option C: read own `Unit:` at stop, fall back to all-stamps when unattributable.
- PreToolUse(Agent) carries `tool_use_id`; `subagents/agent-<id>.meta.json` carries `toolUseId` (option B'), but whether meta.json exists when SubagentStart fires is NOT measured.
- Until fixed, reviews must be SEQUENTIAL (concurrent reviewers block or let each other through).
Related: [[pending-review-flag-resurrection]], [[review-join-null-only-covered-zero-stamp]], [[parallel-contracts-and-escape-drift]].
