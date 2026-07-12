<!-- Copied into the project as .claude/persona-protocol.md by the setup-personas
     skill, and pulled into every persona's context via a single
     `@.claude/persona-protocol.md` line in root CLAUDE.md. CLAUDE.md is the
     only channel that reaches both subagents AND agent-teams teammates
     automatically, so this is where cross-cutting rules live instead of
     being re-pasted into every persona body. Role-agnostic content only —
     adding a new persona never requires editing this file. -->

# Shared persona protocol

## Structural questions go to the explorer
Any question about where something is defined, what calls it, blast radius of
a change, inheritance chains, or test coverage: spawn `explorer`, don't invoke
the code-review-graph skill directly. Note this is instruction-enforced for
most personas, not mechanically blocked: `Skill` is in their `tools:` list so
a teammate copy can reach its OWN preloaded skills (which don't apply to
teammates otherwise) — that same tool would technically let them invoke
code-review-graph too. Only the orchestrator has no `Skill` tool at all,
making its isolation mechanical; everyone else's is this rule. If the
explorer reports the graph index is missing or stale, treat its answer as
grep-derived, not authoritative.

**Name-collision warning — don't let auto-delegation pick the wrong one.**
Claude Code ships a generic, built-in `Explore` subagent type whose name and
description are close enough to this project's `explorer` persona that
description-based auto-delegation (see the orchestrator's "routing is
primarily description-based" note) can silently route to the built-in
instead. The built-in has no MCP tools, so it has no Code Review Graph
access — its answers are grep-derived, weaker, and it bypasses this project's
`explorer` persona entirely. When you spawn for a structural question, name
the persona explicitly (`explorer`, defined in `.claude/agents/explorer.md`)
rather than only describing the task and trusting auto-delegation to route
correctly. If a returned answer doesn't read as graph-derived (no symbol →
file:line provenance, or it says outright it fell back to grep) and you
didn't expect the fallback branch above, treat that as a signal the built-in
ran instead of the project's `explorer`, and re-spawn explicitly by name.

## Answer shape
When you return findings (to the orchestrator, another persona, or the user):
lead with the direct answer, then compact supporting facts. Never dump raw
tool output, full file contents, or whole diffs verbatim — distill it. This
applies doubly to the explorer, whose entire purpose is keeping noisy
traversal out of the caller's context.

## Scope Bash output before it enters context
Don't let a verbose command dump its full, untruncated output into your own
context — that cost is paid whether or not you go on to distill it for
someone else. Before running a command that can plausibly return more than a
screenful (build logs, full-repo greps, directory listings, verbose test
runs), pipe it through `head`/`tail`/`wc -l`/a targeted `grep` first, or pass
the tool's own quiet/summary flag if it has one. If you need to inspect a
large result in full after a summary looked interesting, fetch the narrower
slice you actually need rather than re-running the same command unfiltered.

## Agent-teams mode (only relevant if you were spawned as a teammate)
- Your `skills:` and `mcpServers:` frontmatter fields are NOT applied when
  you run as a teammate. If you need a preloaded skill (e.g. explorer needs
  code-review-graph), invoke it explicitly via the `Skill` tool if it's in
  your tools list; otherwise ask the explorer teammate via `SendMessage`.
- You CAN still spawn ordinary foreground subagents as a teammate (e.g. the
  explorer) — the restriction is on nested TEAMS, not on subagent spawning in
  general. Don't fall back to Grep/Glob out of a mistaken belief that
  spawning is unavailable; only fall back if no explorer teammate exists and
  spawning genuinely isn't warranted for a one-off lookup.
- Delivery to teammates via SendMessage is asynchronous; a spawned subagent
  call is synchronous and pauses you until it returns. Choose based on
  whether you need the answer before continuing.

## WIP sentinel (mid-task handoff, not a bypass)
To end your turn with work genuinely in progress or a red suite you haven't
finished fixing (TDD red phase, a blocked report, a "the plan is wrong"
escalation): write your reason INTO the sentinel file — e.g.
`echo "TDD red phase, 3 tests intentionally failing" > .claude/wip-handoff.<your-agent-id>`
— and state it in your report too. A bare `touch` no longer works: the
stop-gate hook now requires non-empty content, logs it (with a timestamp) to
`.claude/wip-audit.log`, deletes your sentinel, and allows that one turn to
end. An empty sentinel is deleted but NOT honored — the normal check runs
anyway. This is for legitimate pauses only — never write a reason just to
dodge a red suite you could otherwise fix; the audit log exists precisely so
that use is reviewable after the fact. (Claude Code force-ends a turn after 8
consecutive Stop-hook blocks regardless; the sentinel is the designed exit,
not a workaround for that cap.)

## Retrieval contract
The planner's plan states, verbatim, where issues live and how to fetch them
(matching whatever issue tracker was chosen during setup). Follow that line
exactly — never assume a tracker or fetch method.

## Machine-checkable criteria
An acceptance criterion is only valid if it's something an agent can RUN and
get a pass/fail from: a test command, a build/lint exit code, a specific
assertion. "Works correctly" is not a criterion. If a step in a plan has no
runnable check, that's a defect in the plan — say so rather than inventing a
prose substitute.

## Review ownership — one unit, one review, single owner
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

## Continuing after a FAIL verdict
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

## A note on `memory`
If your persona has a `memory` field set, Claude Code auto-grants you Read,
Write, and Edit so you can manage your memory files — this happens regardless
of your declared `tools:` list. That is not license to edit source code if
your role says you never do (e.g. the planner never writes production code,
pseudo-code aside). The restriction in that case is enforced by instruction,
not by the tool allowlist — treat it as a hard rule anyway.
