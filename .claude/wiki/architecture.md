# Architecture

AntiSlop is a Claude Code plugin: a set of persona system-prompts
(`agents/*.md`), enforcement hooks (`hooks/`), first-party skills (including
`skills/coding-discipline`, `skills/install-antislop`, and the 12 vendored
mattpocock-derived skills), and project configuration, packaged so a project
costs one setup run (`install-antislop`) instead of hand-authoring ~500 lines
of persona/hook prose per project. The mattpocock skills (12 total, pinned at
upstream SHA e9fcdf95b402d360f90f1db8d776d5dd450f9234) are now shipped
first-party in `skills/`; the `<MATTPOCOCK:slot>` substitution machinery and
external install step are deleted. See `dependencies.md` for the full history
and `docs/maintenance/resync-vendored-skills.md` for the re-sync runbook.

## The three layers

1. **Personas** (`agents/*.md`) — system prompts for subagents. Core:
   `orchestrator` (router, becomes the main agent via `settings.json`'s
   `"agent": "orchestrator"`), `explorer` (fast structural lookups, optional
   Code Review Graph MCP), `lead-programmer` (writes code, TDD-first).
   Optional, selected per-project: `spec-master` (spec-writing),
   `task-master` (issue-slicing + dispatch prompts), `scribe`
   (this wiki + CONTEXT.md + ADRs), `reviewer` (independent PASS/FAIL —
   the system's core safety property, the Writer/Reviewer split),
   `milestone-auditor` (audits the plan's premises, not the code),
   `researcher` (arXiv-backed literature bridge, template-only — see below).

2. **Hooks** (`hooks/hooks.json` + `hooks/scripts/*.sh`) — mechanical
   enforcement that doesn't rely on a persona choosing to comply:
   `stop-gate.sh` (done = reviewer PASS, not "I think I'm done"),
   `reviewer-route-gate.sh` (lead-programmer can't route around the
   reviewer), `reviewed-path-gate.sh` (only the reviewer writes
   `.claude/reviewed/*.pass`), `human-decision-gate.sh` (no agent identity,
   reviewer included, may ever write a human's `DECISION` file — see
   "Agent-unwritable path as consent proof" below), `protected-paths.sh`
   (migrations/lockfiles need human approval), `graph-update.sh` +
   `lint-on-edit.sh` (keep the graph and formatting current on every edit),
   `session-start.sh` (version drift check + protocol re-injection),
   `task-gate.sh` (agent-teams mode equivalent of stop-gate). See
   [modules/hooks.md](modules/hooks.md).

3. **ADAPT** (`bin/cli.js` + `skills/install-antislop`) — the one-time
   per-project setup. `bin/cli.js` does the mechanical half (deterministic
   file copying, version-stamping, `--update` resync) with zero LLM
   involvement in the common case; `install-antislop` does the
   judgment-driven half (persona selection, third-party skill/MCP wiring,
   repo-specific config, CLAUDE.md pruning). See [modules/cli.md](modules/cli.md).

## Cross-cutting: the shared protocol

`templates/persona-protocol.md` is **physically inlined** into each
full-tier persona's `.claude/agents/*.md` body at generation time by
`bin/cli.js` — not pulled via a root-`CLAUDE.md` `@import` of the protocol
file. That include was migrated away from deliberately (issue #121 Step
2 proved `@import` does not resolve inside a subagent body); this repo's
own `CLAUDE.md` has carried no such line since. Since the 2026-08-01
efficiency-remediation pass (issue #190), inlining is a **tier plus a
per-persona section selection**: every full-tier persona carries only the
protocol sections that mechanically apply to its role (a config-driven
matrix in `bin/cli.js`, fail-closed on any gap), so protocol-level rules
(Review Ownership, memory conventions, structural-facts-from-explorer)
still live in one shared source without every persona body paying for
every section regardless of role. A full, untrimmed reference copy is
also restored on disk at `.claude/persona-protocol.md` — nothing
auto-loads it (zero tokens per dispatch), but a persona whose excerpt
dropped a rule can read it on demand. See
[protocol-delivery-tiers.md](protocol-delivery-tiers.md) for the full
mechanism, its three fail-closed guarantees, and why this trimming is
Claude-Code-only by construction.

## Marker state machine (`.escalated`, `.directed`)

When a unit escalates under `humanReviewMode` (unit #138: defaults to `critical`, on-by-default), the
reviewer writes `.escalated` marker at `.claude/reviewed/<task-id>.escalated` and
snapshots the microworld bundle to `.claude/human-review/<task-id>/` (the escalation packet).
The `.escalated` marker carries: the trigger criterion (heavy-unit trigger), commit
SHA, the packet's `run.sh` invocation, inputs/expected-outputs description, and
the reviewer's would-be verdict. The packet contains the bundle's `run.sh`,
manifest, fixtures, and `PACKET.md` (byte-identical copy of marker body, marker
authoritative on divergence).

On a later re-dispatch, the reviewer reads and **transcribes** (never re-reviews)
a human's `.claude/human-review/<task-id>/DECISION` file via three terminal routes:
- **Approve:** write `.pass` with an appended human-attestation line, delete
  `.escalated` and packet.
- **Reject with reason:** write `.fail` with the human's reason verbatim as the
  defect list (consumes a 2-FAIL-cap slot), delete `.escalated` and packet.
- **Direct a specific fix:** write `.directed` marker carrying the prescribed fix
  verbatim (does NOT consume a cap slot; same logic as `INSUFFICIENT-CONTEXT`),
  dispatch `lead-programmer` for re-review, delete `.escalated` and packet on
  subsequent re-review completion.

The `.directed` marker is **deliberately absent from `stop-gate.sh`'s marker glob**
— that omission is load-bearing, since clearing the flags is what lets the
directed fix be dispatched. Once re-review completes, the reviewer deletes
`.directed` in the same action as the next resolution.

## Agent-unwritable path as consent proof

Every gate before `human-decision-gate.sh` (issue #325, 2026-08-11) followed
the same shape: block most callers, **grant** one privileged identity through
(`reviewed-path-gate.sh` grants the reviewer; `stop-gate.sh`'s SubagentStop
branch grants a reviewer-with-verdict). `human-decision-gate.sh` breaks that
shape on purpose — it blocks every agent identity, including the reviewer,
from writing `.claude/human-review/<task-id>/DECISION`, and has no grant
branch at all. The point isn't access control between agents; it's that a
file no agent can write is a file whose eventual contents can only be the
human's own word, never an agent's paraphrase of it. This is Step 1 of a
3-unit fix (#324): the DECISION file isn't read by anything yet (that lands
in Step 3, amended #136) — this unit only makes the consent boundary real
before anything downstream can rely on it.

## MCP scoping (a recurring gotcha)

Both optional MCP integrations — Code Review Graph and arXiv — are scoped
to a SINGLE persona's frontmatter (`explorer.md`'s `mcpServers:`,
`researcher.md`'s `mcpServers:`), never left as a project-wide `.mcp.json`
entry. `bin/cli.js --wire-graph-mcp` / `--wire-arxiv-mcp` do this
mechanically. The `mcpServers` frontmatter field must be a LIST of
single-key dicts each with an explicit `type:` — a flattened bare map
connects to nothing with **no error at all**, which is why this is
scripted rather than hand-edited. Plugin-shipped agents ignore
`mcpServers` entirely (a Claude Code plugin security restriction), which is
why `researcher.md` is shipped only as a template (`templates/researcher.md.tmpl`)
copied in per-project, never as a plugin agent.

## Adapters

`adapters/cursor/` and `adapters/codex/` are self-contained ports of the
same three-layer shape to other coding agents (Cursor's own plugin/rules
format; Codex's TOML agent format + `AGENTS.md` fragment instead of a
separate protocol file). See [modules/adapters.md](modules/adapters.md).

## Evaluation

`eval/` is a pilot harness that empirically measures whether a given
persona/hook-file variant produces a correct, spec-compliant
implementation on a fixed task, at what cost/turn count — not just "does it
run." See [modules/eval-harness.md](modules/eval-harness.md).
