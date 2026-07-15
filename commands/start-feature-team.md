---
description: Spin up the persona feature team for a task (agent-teams mode - off by default, a deliberate gear).
---

Act as team lead (coordinate, do NOT implement). Create an agent team for
"$ARGUMENTS". Check `.claude/agents/` for which personas this project
actually has (spec-master, task-master, scribe, reviewer, and researcher are
optional — see the project's `persona-config.json` `personaSelection` field)
and spawn named teammates only from what's present: lead-programmer is always
a teammate; spec-master/task-master/scribe/reviewer join if they exist;
researcher only if the task is novel and it exists. Teammates spawn their own foreground
explorer subagent for ad-hoc lookups; add explorer as a named teammate only
when exploration is itself a standalone parallel workstream, not a one-off
lookup. If `reviewer` doesn't exist for this project, say so up front and do
the lightweight sanity-check fallback described in orchestrator.md's "if no
reviewer persona exists" — don't silently skip the done-check.

**GATE**: require spec-master's finalized spec, sliced by task-master into
dispatch-ready units, to name every affected file and give each step a
machine-checkable acceptance criterion before any code is written. If Claude Code's native plan-approval is available as a
prompt-level feature, use it in addition — but the prose rule above is the
one you can always rely on, so treat it as primary, not a fallback.

**Task naming**: name every implementation task `impl:<slug>` — only tasks
with that prefix are gated by the TaskCompleted hook; anything named
otherwise gets no mechanical done-check at all.

If a scribe teammate exists, the lead-programmer SendMessages it
after each change and keeps working — delivery is asynchronous, so this
doesn't pause it the way a synchronous subagent spawn would. If there's no
scribe, skip this.

**Writer/Reviewer split**: the reviewer (a fresh context that did not write
the code) independently runs the checks and returns PASS/FAIL on each
completed unit; on FAIL, the LEAD routes defects back to the lead-programmer
(single review owner, same rule as the always-on orchestrator), following the
shared protocol's "continuing after a FAIL verdict" section, including its
2-FAIL cap: on a second FAIL for the same unit, stop re-delegating and
surface the full defect history to the user instead. "Done" is enforced
mechanically here: when routing a unit to the reviewer, include its exact
task id — the reviewer creates `.claude/reviewed/<task-id>.pass` via Bash on
PASS using that id, and the TaskCompleted hook blocks any task named
`impl:*` from completing without a matching marker.

If there's no reviewer (deselected, or a teammate that crashed mid-run): the
lead's sanity-check fallback above must itself write the marker in v2
format after checking — `mkdir -p .claude/reviewed && printf 'PASS <task-id>
%s criteria: <sanity check(s) run>\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >
.claude/reviewed/<task-id>.pass` (a bare `touch` no longer satisfies
`task-gate.sh`'s content check — a forged-looking empty marker must not work
for the lead either) — or avoid the `impl:` prefix for that task entirely —
the hook fires whenever `persona-config.json` exists, regardless of reviewer
selection, so skipping this step deadlocks the task list permanently.

Use the shared task list, 5–6 tasks at a time. Don't let two teammates edit
the same files (the reviewer never edits, so this is really about the
lead-programmer vs. any other file-touching teammate). If the lead-programmer
says the plan is wrong, send it back to spec-master. To check on or retrieve a
report from an idle teammate, `SendMessage` it by name — this resumes it
from its own transcript. Do NOT re-invoke `Agent` with its name to do this;
that spawns an unrelated sibling instead of resuming it. Wait for teammates
to finish, then synthesize.

**Cleanup**: on Claude Code v2.1.178+ (the version this plugin targets), team
cleanup is automatic — do not call `TeamCreate`/`TeamDelete` (removed in that
version).
