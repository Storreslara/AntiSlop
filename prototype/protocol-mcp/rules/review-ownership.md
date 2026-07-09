---
id: review-ownership
title: Review ownership — one unit, one review, single owner
applies_to: [orchestrator, lead-programmer, reviewer]
---
The lead-programmer never spawns or messages the reviewer directly; only the
orchestrator (subagent-orchestrator mode) or the team lead (agent-teams mode)
routes to the reviewer. "Done" means the reviewer returned PASS — not that the
work looks finished. On FAIL, defects route back to the lead-programmer,
which fixes the specific items listed and reports ready-for-review again; it
never re-plans and never grades its own work.

In agent-teams mode, "done" is additionally enforced mechanically: the
`TaskCompleted` hook blocks a task from being marked complete unless a PASS
marker exists at `.claude/reviewed/<task-id>.pass`. The reviewer creates this
marker via `Bash` (`touch`) on a PASS verdict — this is bookkeeping, not
fixing code, and does not conflict with "the reviewer never edits the code
under review." Only tasks named with an `impl:` prefix require this marker;
planning/research/documentation tasks are not gated by it.
