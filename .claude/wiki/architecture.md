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
   `.claude/reviewed/*.pass`), `protected-paths.sh` (migrations/lockfiles
   need human approval), `graph-update.sh` + `lint-on-edit.sh` (keep the
   graph and formatting current on every edit), `session-start.sh` (version
   drift check + protocol re-injection), `task-gate.sh` (agent-teams mode
   equivalent of stop-gate). See [modules/hooks.md](modules/hooks.md).

3. **ADAPT** (`bin/cli.js` + `skills/install-antislop`) — the one-time
   per-project setup. `bin/cli.js` does the mechanical half (deterministic
   file copying, version-stamping, `--update` resync) with zero LLM
   involvement in the common case; `install-antislop` does the
   judgment-driven half (persona selection, third-party skill/MCP wiring,
   repo-specific config, CLAUDE.md pruning). See [modules/cli.md](modules/cli.md).

## Cross-cutting: the shared protocol

`templates/persona-protocol.md` is copied into every ADAPTed project as
`.claude/persona-protocol.md` and pulled into every persona's context via
one `@.claude/persona-protocol.md` line in root `CLAUDE.md` — this is the
only channel that reaches both subagents and agent-teams teammates
automatically, so protocol-level rules (Review Ownership, memory
conventions, structural-facts-from-explorer) live there instead of being
duplicated into every persona body.

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
