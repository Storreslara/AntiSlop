<!-- Physically inlined into each full-tier persona's .claude/agents/*.md body
     by bin/cli.js (inlineProtocolBlock) at scaffold/update time — @import
     does not resolve inside a subagent body, so this is delivered per
     persona rather than via a CLAUDE.md include. Role-agnostic content
     only — adding a new persona never requires editing this file. -->

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

**Name-collision warning:** Claude Code's built-in `Explore` subagent shadows
this project's `explorer` under description-based auto-delegation, and it has
no graph MCP access. Always spawn by explicit name (`explorer`,
`.claude/agents/explorer.md`). If an answer lacks graph provenance (symbol →
file:line) and you didn't expect the grep fallback, assume the built-in ran
and re-spawn by name.

**Reuse over re-derivation:** if your dispatch packet already carries a
blast-radius or structural answer (for example under `## Pre-resolved
context`), don't re-derive it from zero — verify the specific claim you
doubt, spawning the `explorer` only to check that claim. This reuse rule
applies to `lead-programmer`, `spec-master`, and `milestone-auditor` only; it
never applies to the reviewer, which always re-derives blast radius and
re-runs the checks itself regardless of what the packet claims.

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
- `skills:`/`mcpServers:` frontmatter is NOT applied to a teammate; a skill
  marked `disable-model-invocation` is unreachable in any mode — read its
  `SKILL.md` directly, or ask the explorer via `SendMessage`.
- You CAN spawn foreground subagents; only nested TEAMS are barred.
- `SendMessage` is async, a spawned subagent blocks; report finished work by
  `SendMessage` to the name the lead spawned you under, never turn-text.
- `Write` and `Edit` may be listed in your `tools:` frontmatter and still be
  rejected at call time in a teammate dispatch, with the runtime error
  `<tool> exists but is not enabled in this context`. Re-measured 2026-08-09.
- Do not retry, do not request permission, do not treat it as a defect to
  diagnose mid-task: fall back immediately to `Bash` — a quoted heredoc
  (`cat > file << 'EOF'`) for whole-file authoring, or a `python3` heredoc that
  asserts `old` occurs exactly once before replacing, for surgical edits.
- The fallback inherits the marker-directory gate's constraint: that gate
  matches on **command text**, so a heredoc whose body merely spells the
  reviewer-owned marker directory is refused regardless of where it writes.
  Author such a document with a placeholder token and substitute the real value
  from its canonical definition, so the invoking command text never spells the
  path. (This is the same move the gate's own refusal text recommends for
  `git commit -F <file>`.)
- This applies **regardless of how the tools were granted**. A persona that
  lists `Write, Edit` in its own `tools:` frontmatter loses them exactly as a
  persona that receives them through the `memory:` auto-grant does — measured
  on both paths, 2026-08-09. Do not read a persona's frontmatter as evidence
  that the call will succeed.

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

## Blocked by a gate you do not own (never self-authorize a bypass)
A hook or gate that blocks you is asking for a specific thing — a verdict, a
marker, a passing check. When that thing is **not yours to give**, you have
exactly two legal responses:

1. **Do what it is actually asking**, if that is genuinely your call to make.
2. **Report and wait** — a message to the orchestrator or team lead naming the
   block and what you believe it is waiting on, or the WIP sentinel where that
   is the fitting mechanism for the blocking hook.

There is no third response. In particular, **metadata-only workarounds are
bypasses**, not clever fixes. Bumping a file's mtime so a freshness check
passes, `touch`ing a file to satisfy an existence check, deleting or editing a
gate's own state file, and re-running with a flag that disarms the check are
each a violation on their own. None is redeemed by good intent, by the
underlying state genuinely being fine, or by disclosing it afterwards: a
disclosed bypass is still a bypass, and the gate's record is now wrong for
everyone who reads it later.

If you believe the block's premise is false — it is waiting on something that
already happened, or it cannot be satisfied at all — that is **evidence of a
defect in the gate**, and reporting it is the useful action. Routing around it
leaves the defect in place for the next agent; surfacing it is the only thing
that ever gets it fixed.

This rule does **not** cover the sanctioned exits. The **WIP sentinel** above
and the `defer:` / `skip:` escape in a **pending-review flag** are designed
exits with their own audit trail, and using either as documented is not a
bypass. The difference is not how much friction it saves you — it is whether
the mechanism recorded that you took it.

## Terminal status line (every dispatched turn)
End the message you return to your caller with a status line — the last
non-empty line of that message, with nothing after it, exactly one of:

- `STATUS: complete`
- `STATUS: incomplete — <one-line, non-empty reason>`

An ASCII hyphen is an accepted substitute for the em dash, so anything checking
this line is encoding-robust. Reference regex:
`^STATUS: (complete|incomplete [—-] .+)$`

**When it applies:** every turn-end where control returns to a caller — a
dispatched subagent's returned result, and a teammate's `SendMessage` report to
the lead in agent-teams mode. The main session answering its user directly has
no caller, so there is nothing to sign. That is a trigger condition, **not an
exemption** — the rule lives in the one shared section every persona carries,
so a persona that gains a turn cap later is covered automatically.

**Why it exists** (stated as fact, so nobody later "fixes" it with a hook): you
cannot see your own turn count, you cannot see your own cap being hit, and the
harness renders the `max_turns_reached` attachment as **zero content blocks**.
A turn truncated mid-work is therefore indistinguishable from a finished one —
unless a finished one carries a signature. This line is that signature, and its
absence is the only available evidence of a cutoff.

**Not an alternative to the WIP sentinel above** — the two are different
mechanisms and they co-occur. The sentinel is a *file* written before a
voluntary pause; the status line is a *report line* emitted at every turn-end.
A sentinel turn-end therefore ends with `STATUS: incomplete — <the same reason
you wrote into the sentinel>`.

A missing line is a **prompt to resume**, not a defect and not a FAIL. Nothing
is gated on it; it costs one cheap resume, which is the whole point.

**Keep that resume cheap.** If the message resuming you asks ONLY whether you
finished — not to continue unfinished work, not to check something new — reply
with a brief one-or-two-sentence confirmation and the status line; do not
re-run tests, tools, or verification you already reported in your prior turn.
Re-verify only if the resume message explicitly asks you to continue work or
check something new, or you genuinely doubt your prior turn's report was
accurate. A confirmation resume that turns into a full re-run defeats the
whole point of it being cheap.

## Running acceptance-criteria commands (there is no self-wake)
Run acceptance-criteria commands — test suites, build/lint checks, anything
gating a verdict or a ready-for-review — synchronously in the foreground via
the `Bash` tool's `timeout` parameter, set as high as needed up to its
600000 ms (10 min) ceiling. Never hand one to `run_in_background: true` and
end your turn assuming you'll be notified when it finishes; this ban is
scoped specifically to acceptance-criteria commands, not backgrounding in
general. Only a *dispatching* session's own `Agent`-tool calls get an
autonomous wake-up when a subagent's turn ends. A subagent's own nested
background `Bash` job has no such mechanism — it goes dormant at
`SubagentStop` until the dispatcher explicitly resumes it, no matter how the
job itself turns out.

If a command genuinely cannot finish within the 600000 ms ceiling, the only
legitimate way to end your turn is the WIP sentinel described above, with a
reason string that plainly states there is "no autonomous wake-up available —
requires the dispatcher to resume me later." Never phrase it as "I'll get
notified" or "I'll poll again shortly" — that implies a self-wake mechanism
that does not exist.

## Retrieval contract
`task-master`'s dispatch instructions state, verbatim, where issues live and
how to fetch them (matching whatever issue tracker was chosen during setup).
Follow that line exactly — never assume a tracker or fetch method.

## Machine-checkable criteria
An acceptance criterion is only valid if it's something an agent can RUN and
get a pass/fail from: a test command, a build/lint exit code, a specific
assertion. "Works correctly" is not a criterion. If a step in a plan has no
runnable check, that's a defect in the plan — say so rather than inventing a
prose substitute.

## Review ownership — one unit, one review, single owner
The lead-programmer never spawns or messages the reviewer directly; only the
orchestrator (subagent-orchestrator mode) or the team lead (agent-teams mode)
routes to the reviewer. The reviewer returns one of three verdicts — PASS,
FAIL, or INSUFFICIENT-CONTEXT (see "Third verdict" below) — and "done" means
it returned PASS, not that the work looks finished. On FAIL, defects route
back to the lead-programmer, which fixes the specific items listed and
reports ready-for-review again; it never re-plans and never grades its own
work. This ownership model relies on a one-unit-at-a-time invariant — only
one unit is ever mid-review — which is also what the `.blocked` marker's
flag-keeping heuristic (below) depends on: the route-gate already blocks the
next gated dispatch while any pending-review flag stands, so there is never a
second unit's flag to confuse with the blocked one.

The reviewer writes the v3 PASS marker at `.claude/reviewed/<task-id>.pass`
in BOTH modes, not only where a `TaskCompleted` hook exists to check it — a
marker that exists only in one mode would be an audit gap. Marker format v3:
the file must be non-empty and its first line must read exactly `PASS
<task-id> <UTC ISO-8601 timestamp> commit: <sha|none> criteria: <acceptance-criteria
command(s) run>`. The reviewer writes this via `Bash` (`printf`, not a bare
`touch`) on a PASS verdict — this is bookkeeping, not fixing code, and does
not conflict with "the reviewer never edits the code under review."
Planning/research/documentation work is never gated by this marker. On PASS,
the marker MAY carry the reviewer's non-blocking notes appended after this
required first line, so Minor findings persist instead of being discarded;
`task-gate.sh`'s `marker_valid()` checks only line 1's `PASS <task-id> ` prefix and non-emptiness, so v2 markers remain valid and are never retroactively rejected, and `dispatch-hygiene.sh`'s H3 reads the `commit:` field and declines to fire when the named commit is unreachable from `HEAD`, so a marker whose work was lost no longer blocks its own correction.

In agent-teams mode, "done" is additionally enforced mechanically: the
`TaskCompleted` hook blocks a task from being marked complete unless this
*valid* marker exists at that task's `.pass` path — existence alone is not
enough; an empty or malformed marker is rejected by `task-gate.sh`, and an
accepted marker is additionally logged to `.claude/review-audit.log`
(sibling of `wip-audit.log`). Only tasks named with an `impl:` prefix are
gated by it. In default (subagent-orchestrator) mode, where no
`TaskCompleted` event exists, the equivalent mechanical enforcement is the
pending-review gate (`stop-gate.sh` / `reviewer-route-gate.sh`): turn-end and
the next implementation dispatch are blocked while a completed unit awaits
review.

**Until 2026-07-27** (legacy-marker grace period), `task-gate.sh` warns-and-
allows a legacy/empty/malformed marker instead of blocking, logging
`legacy-marker-grace-period-warning`; after that, unconditional rejection.

## Pending-review flag (default-mode review backstop)
In default (subagent-orchestrator) mode there is no `TaskCompleted` event, so
`stop-gate.sh` carries its own mechanical backstop: whenever a gated agent
(default `lead-programmer`) has a `SubagentStop` that is NOT honored by a WIP
sentinel, it writes `.claude/.pending-review.<agent-id>` — a completed unit,
no reviewer run yet. The reviewer's own `SubagentStop` clears every such flag
(PASS or FAIL — a reviewer having run is what the flag tracks, not the
verdict) and logs `cleared-by=reviewer` to `.claude/review-audit.log`, but only
once the unit it was dispatched for actually holds a verdict. That coupling is
the **review-join stamp**: `reviewer-route-gate.sh` writes
`.claude/.review-join.<unit-id>` when it sees a reviewer dispatch whose first
non-blank line is `Unit: <id>`, and the stop consumes that stamp only when a
format-valid `<id>.pass` or `<id>.fail` exists and is newer than any prior
verdict the stamp recorded. No stamp at all fails OPEN (`marker-check=bootstrap`);
a stamp with no verdict blocks the stop with `marker=MISSING unit=<id>` and
leaves the flags standing. Keying the join per UNIT is what lets two reviewers
running concurrently each clear only their own, and lets a second stop by the
same reviewer — with nothing left owed — be allowed instead of stranded.
While any flag exists: the main-session `Stop` hook blocks turn-end (exit 2,
"a completed unit is awaiting review"), and `reviewer-route-gate.sh` blocks
dispatching the next gated-agent unit — the orchestrator's correct next move
(spawn the reviewer, or spawn anything non-gated like `explorer`) is never
blocked. Escape hatch, mirroring the WIP sentinel: overwrite the flag's
content with `defer: <reason>` (logged, flag KEPT — this is **sticky**, not
one-shot: it permits turn-end on every subsequent `Stop` until the reviewer's
`SubagentStop` clears the flag or a `skip:` deletes it; the review is still
owed the whole time) or `skip: <reason>` (logged, flag DELETED, unit
explicitly abandoned); a reason-less overwrite is rejected the same way an
empty WIP sentinel is. Sticky or not, `reviewer-route-gate.sh` continues to
block the next gated-agent dispatch regardless of the defer — it blocks on
the flag's existence, never its content.

## FAIL record (durable warning for future spawns)
On every FAIL verdict, the reviewer also writes `.claude/reviewed/<task-id>.fail`
(both modes) — first line exactly `FAIL <task-id> <UTC ISO-8601 timestamp>`,
followed by the defect list from the verdict, verbatim. This is a bookkeeping
exception, same as the PASS marker — not a change to the code under review.
No hook gate depends on it (the pending-review flag already clears on any
reviewer `SubagentStop`, PASS or FAIL alike); it exists purely so a
completely fresh `spec-master` or orchestrator spawn — one with no memory of
this session at all — still sees that a unit already failed once.

## Third verdict: insufficient-context
Beyond PASS and FAIL, the reviewer may return a third verdict,
`INSUFFICIENT-CONTEXT`, when it cannot verify an acceptance criterion because
a required constraint is neither in the review packet nor discoverable via
its own exploration (Read/Grep/Glob, or the explorer, if present). This is a
last resort after exhausting that exploration, never a substitute for it.

On this verdict the reviewer writes a new marker,
`.claude/reviewed/<task-id>.blocked` — NOT the `.pass`/`.fail` markers above —
whose first line reads exactly `BLOCKED <task-id> <UTC ISO-8601 timestamp>
missing: <one-line description>`, followed by specifics: which criterion
could not be verified, what constraint or doc is missing, and where the
reviewer looked for it. This marker **never consumes a 2-FAIL-cap slot** —
the cap below counts `.fail` records only, unchanged. When the reviewer
later resolves the same unit to PASS or FAIL, it deletes the `.blocked`
marker as part of writing the new one.

Mechanical consequence: on an insufficient-context verdict the pending-review
flag (above) is kept standing rather than cleared, so turn-end and the next
gated-unit dispatch stay blocked, while dispatching anything non-gated
(explorer, scribe, or the reviewer itself, if present) is still allowed; the
existing `defer:`/`skip:` escape hatch on the flag still applies unchanged.

## Continuing after a FAIL verdict
Subagent invocations are one-shot — a fresh lead-programmer call has no
memory of what it just built. When re-delegating after a FAIL: prefer
resuming the same lead-programmer session if the harness supports session
resume for the persona that reported ready-for-review; otherwise bundle a
self-contained prompt with the original plan step, a one-line diff summary
(from `git log`/`git diff` on the relevant commits), and the defect list
verbatim. Don't rely on `memory: project` alone to bridge this gap — memory
is for durable conventions, not the live state of an in-progress fix; the
`.fail` record above is what bridges it for a session with no memory at all.

**Cap at 2 FAILs per unit.** If the same unit FAILs a second time, the
orchestrator (or team lead) stops re-dispatching `lead-programmer` — it
surfaces the full defect history across both attempts to the user, then
spawns `spec-master` to produce a debug spec (a focused root-cause diagnosis
plus revised acceptance criteria for the failed step(s), never a
from-scratch replan), which flows back through `task-master` for
re-dispatch. A unit that fails twice usually means the plan itself has a
gap, not that one more automated pass will close it.

## A note on `memory`
If your persona has a `memory` field set, Claude Code auto-grants you Read,
Write, and Edit so you can manage your memory files — this happens regardless
of your declared `tools:` list. That is not license to edit source code if
your role says you never do (e.g. spec-master and task-master never write
production code, pseudo-code aside). The restriction in that case is enforced
by instruction, not by the tool allowlist — treat it as a hard rule anyway.
