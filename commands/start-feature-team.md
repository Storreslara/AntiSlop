---
description: Spin up the persona feature team for a task (agent-teams mode - off by default, a deliberate gear).
---
<!-- Corrected vs. the original spec: teammates CAN spawn ordinary foreground
     subagents (the restriction is on nested TEAMS, not on subagent spawning
     in general) - so the explorer-teammate-or-grep-fallback framing below is
     softer than the original "teammates cannot spawn subagents" claim. -->

Act as team lead (coordinate, do NOT implement). Create an agent team for
"$ARGUMENTS". Check `.claude/agents/` for which personas this project
actually has (planner, repo-historian, reviewer, and researcher are optional
— see the project's `persona-config.json` `personaSelection` field) and spawn
named teammates only from what's present: lead-programmer is always a
teammate; planner/repo-historian/reviewer join if they exist; researcher only
if the task is novel and it exists; explorer as a teammate whenever the task
involves heavy unfamiliar-code exploration. If `reviewer` doesn't exist for
this project, say so up front and do the lightweight sanity-check fallback
described in orchestrator.md's "if no reviewer persona exists" — don't
silently skip the done-check.

**GATE**: prefer Claude Code's native plan-approval (require plan approval
before implementation) if this version exposes it as a prompt-level feature;
otherwise fall back to the prose rule: require the planner's plan to name
every affected file and give each step a machine-checkable acceptance
criterion before any code is written.

If a repo-historian teammate exists, the lead-programmer SendMessages it
after each change and keeps working — delivery is asynchronous, so this
doesn't pause it the way a synchronous subagent spawn would. If there's no
historian, skip this.

**Writer/Reviewer split**: the reviewer (a fresh context that did not write
the code) independently runs the checks and returns PASS/FAIL on each
completed unit; on FAIL, the LEAD routes defects back to the lead-programmer
(single review owner, same rule as the always-on orchestrator). "Done" is
enforced mechanically here: the reviewer creates
`.claude/reviewed/<task-id>.pass` via Bash on PASS, and the TaskCompleted hook
blocks any task named `impl:*` from completing without that marker.

Use the shared task list, 5–6 tasks at a time. Don't let two teammates edit
the same files (the reviewer never edits, so this is really about the
lead-programmer vs. any other file-touching teammate). If the lead-programmer
says the plan is wrong, send it back to the planner. Wait for teammates to
finish, then synthesize.

**Cleanup**: on Claude Code v2.1.178+ (the version this plugin targets), team
cleanup is automatic — do not call `TeamCreate`/`TeamDelete` (removed in that
version).
