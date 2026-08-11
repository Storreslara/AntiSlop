<!-- Inlined directly into the project's AGENTS.md by bin/cli.js --target=codex
     (wrapped in a matching pair of begin/end marker comments at scaffold
     time - see docs/specs/codex-plugin.md §5, §9). This mirrors how Claude
     Code delivers the protocol: physically inlined per persona rather than
     via an @import, since Codex's AGENTS.md has NO @import/include mechanism
     either (confirmed - see docs/codex-port-notes.md), so the protocol
     content must be physically inlined rather than referenced. Role-agnostic
     content only - adding a new persona never requires editing this file. -->

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

**Reuse over re-derivation:** if your dispatch packet already carries a
blast-radius or structural answer (for example under `## Pre-resolved
context`), don't re-derive it from zero - verify the specific claim you
doubt, spawning the `explorer` only to check that claim. This reuse rule
applies to `lead-programmer`, `spec-master`, and `milestone-auditor` only; it
never applies to the reviewer, which always re-derives blast radius and
re-runs the checks itself regardless of what the packet claims.

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
(logged, flag KEPT - sticky, not one-shot: every subsequent `Stop` is allowed
too, until the reviewer's `SubagentStop` clears the flag or a `skip:` deletes
it; the review is still owed) or `skip: <reason>` (logged, flag DELETED, unit
abandoned); a reason-less overwrite is rejected.

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

## Blocked by a gate you do not own (never self-authorize a bypass)
When a hook or gate blocks you and the thing it asks for is not yours to give,
there are exactly two legal responses: do what it actually asks, if that is
genuinely your call, or report it and wait. Metadata-only workarounds are
bypasses, not fixes - bumping a file's mtime, `touch`ing a file to satisfy an
existence check, deleting or editing a gate's own state file, and re-running
with a flag that disarms the check are each a violation, and good intent, a
correct underlying state and full disclosure redeem none of them. If the
block's premise looks false, that is evidence of a defect in the gate and
reporting it is the useful action - routing around it leaves the defect in
place for the next agent. The WIP sentinel above and a pending-review flag's
`defer:`/`skip:` escape are sanctioned exits with their own audit trail; using
either as documented is not a bypass.

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

## Fourth verdict: escalate-to-human
`ESCALATE-TO-HUMAN` is a gate on PASS, never a replacement for FAIL. Precedence:
`FAIL` > `INSUFFICIENT-CONTEXT` > `ESCALATE-TO-HUMAN` > `PASS` - a real defect is
a normal FAIL, an unverifiable criterion is INSUFFICIENT-CONTEXT, and only a unit
the reviewer would have passed escalates. It fires when `humanReviewMode` is
`all`, or is `critical` (an absent key reads as `critical`) and the unit meets the
heavy-unit trigger defined solely in
`docs/adr/0004-reviewer-roast-work-dual-model-routing.md` § "Heavy unit trigger"
(as amended by ADR-0013) - referenced by pointer, never restated here.

**Marker:** `.claude/reviewed/<task-id>.escalated`, first line exactly
`ESCALATE-TO-HUMAN <task-id> <UTC ISO-8601 timestamp> trigger: <which criterion> microworld: <packet path or "none">`,
then the command to run the packet's `run.sh`, the escalation-time SHA as
`commit: <sha>`, a one-line inputs/expected-outputs description, the would-be
verdict and the criteria checked, and non-blocking notes. `microworld:` names the
durable packet, not the gitignored working `microworlds/<unit-slug>/`.

**Packet:** in the same action, snapshot the bundle to
`.claude/human-review/<task-id>/` - whole directory, executable bit on `run.sh`
preserved - plus `PACKET.md`, a byte-identical copy of the marker body; the
marker stays authoritative wherever the two differ. With no bundle, still create
the directory with `PACKET.md` alone and write `microworld: none` - escalation is
never skipped for want of a bundle. The packet is NOT under `.claude/reviewed/`
because `reviewed-path-gate.sh` blocks every Bash command whose text contains
that path for non-reviewer callers, read-only ones included, so a packet sited
there could not be run. It is untracked: `git clean -fdx` destroys it - documented,
not fixed.

Distinct from `.blocked` (reviewer *lacked context*; this one means policy wants
human eyes on critical code) - separate marker files, separate audit-log tokens.
`.escalated` never consumes a 2-FAIL-cap slot. Resolved only by the reviewer, on a
later re-dispatch naming the unit and pointing at its DECISION file, via one of
three terminal transitions, each deleting `.escalated` and its packet.

### Resolving an escalation: the DECISION file and the three routes
**The decision travels as a file, never as a chat message.** The human writes
`.claude/human-review/<task-id>/DECISION` in their own terminal;
`human-decision-gate.sh` blocks every agent identity, reviewer included, from
creating or modifying it, so a decision relayed in a dispatch prompt or any chat
message is never a substitute for the file. The orchestrator surfaces the command
template beside the packet's `run.sh` command and never writes the file itself:
`printf 'DECISION <task-id> %s route: approve escalation: <ts>\nby: <name>\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > .claude/human-review/<task-id>/DECISION`

First line exactly
`DECISION <task-id> <UTC ISO-8601> route: approve|reject|direct escalation: <timestamp>`,
where `escalation:` repeats the standing marker's own first-line timestamp - the
staleness binding, so an older decision cannot resolve a later escalation. Second
line `by: <name>`. Body: the reason verbatim for `reject`, the full prescribed fix
verbatim for `direct`.

The resolution dispatch names only the unit and carries no decision. The reviewer
verifies the file exists, parses its first line, checks the task-id and the
`escalation:` timestamp match the standing marker, then **transcribes** it into
one route - never re-reviews, since re-adjudicating a human decision undoes the
property the escalation exists to create. Missing, malformed, or stale: report and
wait.

| Human decision | Reviewer writes | Cap slot | Next move |
|---|---|---|---|
| **Approve** | `.pass` plus an appended `human: approved by <name> <UTC ISO-8601>` attestation quoting the file | - | unit done |
| **Reject with reason** | `.fail` with the reason verbatim as the defect list | **consumes one** | back to `lead-programmer`, normal FAIL route |
| **Fixable a specific way** | `.directed`, first line exactly `DIRECTED <task-id> <UTC ISO-8601 timestamp> fix: <one-line human directive>`, then the prescribed fix verbatim | **does NOT consume one** | dispatch `lead-programmer` with the directive, then re-review |

All three delete `.escalated` and the packet in the same action, via
`rm -rf .claude/human-review/<task-id>` - the decision gate's sanctioned deletion
path, which is also what removes the decision file, since no identity may `rm` it
by name. Mandatory, not tidiness: nothing globs the packet directory, so a stale
one is silent clutter a human could mistake for a live escalation. Cap asymmetry:
a rejection is a genuine defect, a direction is a human-directed correction rather
than the writer failing its own attempt - the same logic that spares
`INSUFFICIENT-CONTEXT`. The counting rule is unchanged (`.fail` records only), and
`.directed` deliberately has no stop-gate branch so flags clear and the directed
fix can be dispatched.

Unattended: `.escalated` simply stands and turn-end stays blocked - no silent
auto-fallback to the reviewer's own verdict. The only way through is the existing
`defer:`/`skip:` escape hatch on the pending-review flag, which logs to
`.claude/review-audit.log`. `skip:` leaves BOTH the marker and the packet standing
(fail-safe: evidence retained, nothing silently approved), so only a later reviewer
resolution of that unit clears them. "No human present" is a timing condition, not
a terminal one - the packet outlives the session.

## Retrieval contract
The plan states, verbatim, where issues live and how to fetch them (matching
whatever issue tracker was chosen during setup). Follow that line exactly -
never assume a tracker or fetch method.

## Terminal status line (every dispatched turn)
End the message you return to your caller with a status line - the last
non-empty line, nothing after it: `STATUS: complete`, or
`STATUS: incomplete - <one-line, non-empty reason>`. This port has no `maxTurns`
primitive (platform note below), only a soft turn budget, so a turn that stops
early stops for some other reason - an error, a lost thread, a budget you were
told to respect - and looks exactly like a finished one unless the finished one
is signed. The line is that signature: it tells a caller the turn ended cleanly
regardless of why it ended. Not an alternative to the WIP sentinel above - the
sentinel is a file written before a voluntary pause, this is a report line on
every turn-end, so a sentinel turn-end still ends with
`STATUS: incomplete - <the same reason you wrote into the sentinel>`. A missing
line is a prompt to resume, not a defect and not a FAIL.

## Microworld bundles (format and the check contract)
A **microworld bundle** is a gitignored directory under `microworlds/<unit-slug>/` containing a `manifest.json` and a `run.sh` check. Bundles are discovered by `lead-programmer` during implementation and verified by the reviewer as a filesystem check only, never by executing entries. The dashboard is never an acceptance criterion - no gate or hook consults it.

**Manifest structure** includes `unit`, `watch` (globs), `description`, `timeoutSeconds`, and an optional `functions[]` array. Each function entry in `functions[]` declares an invocable executable: `id`, `group`, `label`, `entry` (bundle-relative path), `description` (what it does + one concrete thing to try), optional `location` (object with `file`, `startLine`, `endLine`), and optional `inputs[]` array.

**The `entry` execution contract:** executable, resolved relative to bundle directory (survives packet copies via `$(cd "$(dirname "$0")" && pwd)` idiom). Runs with cwd = project root, receives bundle path in `MICROWORLD_BUNDLE_DIR`. Receives exactly one JSON object on stdin mapping input names to values - nothing shell-interpolated. Prints result to stdout. Exit code carries no verdict; `run.sh` is the sole exit-code contract. Each invocation is a fresh process. `functions` is optional.

**The `location` field** is optional: project-relative `file` and inclusive `startLine`/`endLine`. When absent, records the literal string `location: not declared`.

**Storage and reviewer scope:** bundles are gitignored working-tree scratch, not part of the reviewed diff. The reviewer checks for bundle presence only (filesystem check), never executes entries. The rerun hook never invokes function entries (would convert sync check to hang), and neither does the reviewer for adjudication.

**Authoring policy:** `lead-programmer` SHOULD author `functions[]` with `location` on each for units meeting the heavy-unit trigger (see `docs/adr/0004-reviewer-roast-work-dual-model-routing.md` § "Heavy unit trigger" as amended by ADR-0013); MAY skip otherwise. Microworld bundles (the check contract) are the only persistence surface - the dashboard entry itself (a **microworld**) is ephemeral and human-facing.

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
