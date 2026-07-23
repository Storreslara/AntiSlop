<!-- Inlined directly into the project's AGENTS.md by bin/cli.js --target=codex
     (wrapped in a matching pair of begin/end marker comments at scaffold
     time - see docs/specs/codex-plugin.md §5, §9). This is the Codex equivalent of
     Claude's `@.claude/persona-protocol.md` import line: Codex's AGENTS.md
     has NO @import/include mechanism (confirmed - see docs/codex-port-notes.md),
     so the protocol content must be physically inlined rather than
     referenced. Role-agnostic content only - adding a new persona never
     requires editing this file. -->

# AntiSlop persona protocol

## Structural questions go to the explorer
Any question about where something is defined, what calls it, blast radius of
a change, inheritance chains, or test coverage: spawn `explorer`, don't query
the Code Review Graph MCP directly. On Codex the graph MCP IS scoped to the
explorer alone (`mcp_servers` in `explorer.toml` - the one platform where this
isolation is mechanical, not just a convention), so routing through the
explorer keeps noisy traversal out of every other persona's context on
purpose, not just by discipline.

**Name-collision warning:** if a built-in Codex agent shadows this project's
`explorer` under description-based auto-delegation, it has no graph MCP
access. Always spawn by explicit name (`explorer`). If an answer lacks graph
provenance (symbol -> file:line) and you didn't expect the grep fallback,
assume a built-in ran and re-spawn by name.

## Answer shape
When you return findings (to the orchestrator, another persona, or the user):
lead with the direct answer, then compact supporting facts. Never dump raw
tool output, full file contents, or whole diffs verbatim - distill it. This
applies doubly to the explorer, whose entire purpose is keeping noisy
traversal out of the caller's context.

## Scope Bash output before it enters context
Before running a command that can plausibly return more than a screenful
(build logs, full-repo greps, directory listings, verbose test runs), pipe it
through `head`/`tail`/`wc -l`/a targeted `grep` first, or pass the tool's own
quiet/summary flag. If you need a large result in full after a summary looked
interesting, fetch the narrower slice you actually need rather than re-running
the same command unfiltered.

## Machine-checkable criteria
An acceptance criterion is only valid if it's something an agent can RUN and
get a pass/fail from: a test command, a build/lint exit code, a specific
assertion. "Works correctly" is not a criterion. If a step in a plan has no
runnable check, that's a defect in the plan - say so rather than inventing a
prose substitute.

## Review ownership - one unit, one review, single owner
The lead-programmer never spawns or messages the reviewer directly; only the
orchestrator routes to the reviewer. "Done" means the reviewer returned PASS -
not that the work looks finished. On FAIL, defects route back to the
lead-programmer, which fixes the specific items listed and reports
ready-for-review again; it never re-plans and never grades its own work.

The reviewer writes the PASS marker at `.codex/reviewed/<task-id>.pass` on a
PASS verdict: the file must be non-empty and its first line must read exactly
`PASS <task-id> <UTC ISO-8601 timestamp> criteria: <acceptance-criteria
command(s) run>`. It writes this via Bash (`printf`, not a bare `touch`) -
bookkeeping, not fixing code. Planning/research/documentation work is never
gated by this marker.

Mechanical enforcement (default subagent-orchestrator mode): the
pending-review gate (`stop-gate.sh` / `reviewer-route-gate.sh`) blocks turn-end
and the next implementation dispatch while a completed unit awaits review.

## Pending-review flag (review backstop)
Whenever a gated agent (default `lead-programmer`) has a `SubagentStop` that is
NOT honored by a WIP sentinel, `stop-gate.sh` writes
`.codex/.pending-review.<agent-id>` - a completed unit, no reviewer run yet.
The reviewer's own `SubagentStop` clears every such flag (PASS or FAIL) and
logs `cleared-by=reviewer`. While any flag exists: the main-session `Stop`
hook blocks turn-end, and `reviewer-route-gate.sh` blocks dispatching the next
gated-agent unit - the orchestrator's correct next move (spawn the reviewer,
or spawn anything non-gated like `explorer`) is never blocked. Escape hatch,
mirroring the WIP sentinel: overwrite the flag's content with `defer: <reason>`
(logged, flag KEPT, that one Stop allowed) or `skip: <reason>` (logged, flag
DELETED, unit abandoned); a reason-less overwrite is rejected.

## FAIL record (durable warning for future spawns)
On every FAIL verdict the reviewer also writes `.codex/reviewed/<task-id>.fail`
- first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`, followed by the
defect list from the verdict, verbatim. No hook gate depends on it; it exists
so a completely fresh spawn - one with no memory of this session - still sees
that a unit already failed once.

## WIP sentinel (mid-task handoff, not a bypass)
To end your turn with work genuinely in progress or a red suite you haven't
finished fixing (TDD red phase, a blocked report, a "the plan is wrong"
escalation): write your reason INTO the sentinel file - e.g.
`echo "TDD red phase, 3 tests intentionally failing" > .codex/wip-handoff.<your-agent-id>`
- and state it in your report too. A bare `touch` does not work: the
stop-gate hook requires non-empty content, logs it to `.codex/wip-audit.log`,
deletes the sentinel, and allows that one turn to end. An empty sentinel is
deleted but NOT honored - the normal check runs anyway. This is for
legitimate pauses only.

## Continuing after a FAIL verdict
Subagent invocations are one-shot - a fresh lead-programmer call has no memory
of what it just built. When re-delegating after a FAIL: bundle a self-contained
prompt with the original plan step, a one-line diff summary (from
`git log`/`git diff` on the relevant commits), and the defect list verbatim.
The `.fail` record above is what bridges this for a session with no memory.

**Cap at 2 FAILs per unit.** If the same unit FAILs a second time, the
orchestrator stops re-delegating - it surfaces the full defect history across
both attempts to the user and asks how to proceed, rather than spawning a third
fix attempt. A unit that fails twice usually means the plan itself has a gap.

## Reviewer roast-work advisory pass trigger (fable heavy-lifting)
A unit is "heavy" - eligible for an additional, non-authoritative fable
`roast-work` pass alongside the authoritative PASS/FAIL review - when it meets
ANY of: (1) **large surface** (blast radius ~8+ impacted files OR a ~400+ line
diff); (2) **structural / cross-cutting change** (a persona split, an
orchestrator routing rewrite, a `bin/cli.js` migration, or any other change to
shared/cross-persona surface a reasonable reviewer would call cross-cutting);
(3) **security-sensitive surface** (auth, input parsing/validation, secret
handling, or migrations touched). Fable is the single most expensive model tier
here - fire the pass only on a real trigger, never as a default-to-yes hedge.

**Downgrade/expiry path.** A recurring unit *class* (same trigger reason, same
recurring surface) that clears 3 consecutive fable passes with zero
Major/Critical findings stops qualifying: task-master records the class and its
clean-streak count and omits the roast tag for matching units, noting the
omission in the dispatch prompt. Any Major/Critical finding - from either pass -
resets that class's streak to zero and restores the trigger. The downgrade is
always per-class, never global, so total cost does not only ratchet up.

## Retrieval contract
The plan states, verbatim, where issues live and how to fetch them (matching
whatever issue tracker was chosen during setup). Follow that line exactly -
never assume a tracker or fetch method.

## Codex platform notes (loud degradations - see docs/codex-port-notes.md)
- **AGENTS.md reaching subagents is doc-stated but NOT empirically confirmed
  by this project.** Codex's own docs state custom agents "automatically
  inherit applicable AGENTS.md and project instructions" - stronger than what
  Cursor's docs gave that port - but this project has not verified it against
  a real session. Every persona's `developer_instructions` also inlines the
  load-bearing subset of this file as a backstop for exactly this reason; if
  you're reading this as a subagent, both channels reached you and the
  digest is redundant but harmless.
- No per-tool allowlist: only `sandbox_mode` (`read-only`/`workspace-write`)
  exists. The reviewer's and explorer's "cannot edit" is mechanical where
  `sandbox_mode = "read-only"` is set; every finer restriction (the
  orchestrator's no-Skill isolation, the lead-programmer's precise tool set)
  is INSTRUCTION-ONLY - honor it as if it were mechanical.
- No per-agent turn cap (`maxTurns` equivalent): treat any turn budget as a
  soft target; lean on the 2-FAIL cap and "scale effort to the task." Global
  `agents.max_threads`/`agents.max_depth` bound fan-out, not per-agent depth
  of work.
- Per-agent MCP scoping IS preserved (unlike Cursor) - see the explorer
  section above. This is the one primitive Codex keeps that no other ported
  platform does.
- No per-agent memory primitive: durable notes are a file convention under
  `.codex/memory/<agent>.md`.
- "lead-programmer must not spawn the reviewer directly" (the other half of
  review ownership) is UNVERIFIED whether `SubagentStart` exposes the calling
  agent's identity distinct from the spawned agent's own `agent_id`/
  `agent_type` - defaults to instruction-only until confirmed. The dispatch-
  block half (blocking the next gated unit while one awaits review) stays
  mechanical regardless.
- Dropped for v1 (no Codex equivalent shipped yet): agent-teams mode
  (`SendMessage`, shared task list, the `TaskCompleted`/task-gate mechanism -
  Codex has no `TaskCompleted` event), structured user-question prompts. Open
  Questions are relayed as plain text.
