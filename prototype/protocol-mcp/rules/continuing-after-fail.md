---
id: continuing-after-fail
title: Continuing after a FAIL verdict
applies_to: [orchestrator, lead-programmer]
---
Subagent invocations are one-shot — a fresh lead-programmer call has no
memory of what it just built. When re-delegating after a FAIL: prefer
resuming the same lead-programmer session if the harness supports session
resume for the persona that reported ready-for-review; otherwise bundle a
self-contained prompt with the original plan step, a one-line diff summary
(from `git log`/`git diff` on the relevant commits), and the defect list
verbatim. Don't rely on `memory: project` alone to bridge this gap — memory
is for durable conventions, not the live state of an in-progress fix.

**Cap at 2 FAILs per unit.** If the same unit FAILs a second time, the
orchestrator (or team lead) stops re-delegating — it surfaces the full defect
history across both attempts to the user and asks how to proceed, rather than
spawning a third fix attempt. A unit that fails twice usually means the plan
itself has a gap, not that one more automated pass will close it.
