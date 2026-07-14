# Porting AntiSlop to Codex and Cursor

Status: design/planning only. No Codex/Cursor code exists yet. This scopes the
work; it does not do it.

Scope: make the AntiSlop persona system installable and functional as a
plugin/extension for **OpenAI Codex CLI** and **Cursor** (IDE + CLI), alongside
the existing Claude Code plugin. What ports as-is, what needs per-platform
adapters, what has to degrade, and in what order to build it.

Research cutoff: this reflects Codex and Cursor as documented in mid-2026. Both
platforms move fast; re-verify every cited primitive before implementing
against it (same discipline `install-antislop/SKILL.md` already applies to the
code-review-graph install shape). Sources are linked inline and collected at the
bottom.

## 0. Headline finding

Both target platforms converged on Claude Code's extensibility model far more
than expected. As of this research **all three** support: named subagents with
`name`/`description`/`model`, a lifecycle hook system with block-on-`exit 2`
semantics, per-project MCP servers, an `AGENTS.md`/`CLAUDE.md`-style
project-instructions file, on-demand skills/slash-commands, and a
`plugin.json` + `marketplace.json` packaging format installed from git. Codex's
hook event names (`PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`,
`SubagentStop`) are almost byte-identical to Claude Code's, and **Cursor natively
reads `.claude/agents/` and `.codex/agents/` directories**, so a subset of
AntiSlop's current agent files already partially load there.

So "porting" is *not* mostly "write a scaffolder for a platform that has no
primitives" (the pessimistic framing in the task). The primitives mostly exist.
The real work is (a) translating file formats (Claude markdown-frontmatter →
Codex TOML; hook payload field names), and (b) absorbing a small number of
genuine capability gaps — chiefly **per-agent tool restriction**, **per-agent
turn caps**, and **per-agent persistent memory** — where AntiSlop currently
leans on a Claude-Code primitive that has no per-agent equivalent on the other
two. Those gaps hit exactly the mechanisms AntiSlop's "Why this shape" section
in `README.md` calls load-bearing (the mechanically-enforced Writer/Reviewer
split, the cost bounds), so they degrade to instruction-only enforcement rather
than disappearing — following the existing "if no reviewer persona exists, say
so and do a lightweight check" precedent (`agents/orchestrator.md:63`).

## 1. Feature mapping table

One row per AntiSlop mechanism. Cells are the concrete equivalent, or "no
equivalent" with the nearest workaround, or "n/a".

| # | AntiSlop mechanism (Claude Code, current) | Codex CLI | Cursor |
|---|---|---|---|
| 1 | **Subagent definition** — markdown + YAML frontmatter in `.claude/agents/*.md`, body = system prompt (`agents/explorer.md` etc.) | TOML in `.codex/agents/*.toml` (project) / `~/.codex/agents/` (user); fields `name`, `description`, `developer_instructions` (= body). Filename need not match `name`. [codex-subagents] | Markdown + YAML frontmatter in `.cursor/agents/*.md`; **also reads `.claude/agents/` and `.codex/agents/`**. Fields `name`, `description`, `model`, `readonly`, `is_background`. [cursor-subagents] |
| 2 | **Subagent discovery / auto-delegation** by `description` | Same: description drives when Codex delegates; invoked by name. [codex-subagents] | Same: auto-delegation by description, explicit `/name`, or natural mention. [cursor-subagents] |
| 3 | **Namespacing** — plugin agents load as `antislop:explorer`; bare name hard-errors, forcing the ADAPT copy into `.claude/agents/` (`skills/install-antislop/SKILL.md:33-38`) | Custom agents in `.codex/agents/` override built-ins of the same `name`; project overrides user. Plugin-provided-agent namespacing **not documented** — verify. Likely *no* hard-error-on-bare-name, so the mandatory-copy trick may be unnecessary here. | Precedence `.cursor/` > `.claude/` > `.codex/`, project > user. No documented bare-name hard-error. [cursor-subagents] Copy-into-project still the safe default but probably not *required*. |
| 4 | **Orchestrator-as-main-agent** — `"agent": "orchestrator"` in settings.json replaces the default system prompt (`templates/settings-fragment.json:3`, `agents/orchestrator.md:3`) | **No clean equivalent.** No documented key that swaps the root session's system prompt for a named agent. Nearest: put routing prose in `AGENTS.md` + `config.toml` global `model`/`sandbox_mode`, and/or switch into an orchestrator agent via `/agent`. Gap — see §2C. | **Custom Modes** (model + tuned system prompt + tool set) are the nearest equivalent; a "Router/Orchestrator" mode. Not identical (a mode is user-selected, not a hard default), and mode packaging inside plugins is unverified. Gap — see §2C. |
| 5 | **Per-agent tool allowlist** — `tools:` (orchestrator has no Write/Edit/Skill; reviewer/milestone-auditor have no Write/Edit — `agents/reviewer.md:6`, `agents/orchestrator.md:5`) | **No per-tool allowlist.** Only `sandbox_mode` (`read-only` / `workspace-write`). Can express "reviewer can't write" (read-only) but **cannot** express "Bash yes, Edit no" or "no Skill/Agent tool." [codex-subagents] Biggest gap — §2A. | **No per-tool allowlist.** Only `readonly: true`. Same limitation as Codex. [cursor-subagents] §2A. |
| 6 | **Per-agent MCP scoping** — `mcpServers:` frontmatter, e.g. explorer's Code Review Graph scoped to explorer alone (`agents/explorer.md:7-10`) | **Supported**: `mcp_servers` in the agent TOML. Direct equivalent — explorer-only graph connection ports cleanly. [codex-subagents] | **No per-agent MCP.** Subagents "inherit all tools from the parent, including MCP tools." [cursor-subagents] Can't scope the graph to explorer alone; it's project-wide or nothing. Gap — §2D. |
| 7 | **`maxTurns` per-agent cap** (explorer 10, planner/reviewer/lead-programmer 30, milestone-auditor 20) | **No per-agent cap.** Only global `agents.max_threads` and `agents.max_depth` (default 1). [codex-subagents] Cost bound becomes instruction-only/global. §2B. | **No per-agent cap** documented. §2B. |
| 8 | **`model` per-agent selection** (haiku/sonnet/opus/inherit) | `model` + `model_reasoning_effort` per agent. Direct equivalent (map model tiers to Codex model ids). [codex-subagents] | `model` per agent, `inherit` or e.g. `claude-opus-4-8[effort=high]`. Direct equivalent. [cursor-subagents] |
| 9 | **`memory: project` persistent notes** (planner, lead-programmer, repo-historian) with auto-granted Read/Write/Edit (`templates/persona-protocol.md:128-134`) | **No per-agent memory primitive.** Emulate with a convention'd file (e.g. `.codex/memory/<agent>.md`) the agent is told to read/append. Loses the auto-grant + isolation. §2E. | **No per-agent memory primitive.** Same file-convention workaround. §2E. |
| 10 | **Hook system** — 7 scripts on PreToolUse/PostToolUse/Stop/SubagentStop/SessionStart/TaskCompleted (`hooks/hooks.json`) | **Near-identical.** Events `SessionStart`, `PreToolUse`, `PostToolUse`, `SubagentStart`, `SubagentStop`, `Stop`, `PermissionRequest`, `PreCompact`/`PostCompact`, `UserPromptSubmit`. `hooks.json` or `[hooks]` in `config.toml`; project `.codex/` (trusted). Block via `exit 2` + stderr or `{"hookSpecificOutput":{"permissionDecision":"deny"}}`. [codex-hooks] Logic ports; **payload field names differ** — §3. | **Present, richer, camelCase.** `sessionStart`, `sessionEnd`, `preToolUse`, `postToolUse`, `subagentStart`, `subagentStop`, `beforeShellExecution`, `afterShellExecution`, `beforeMCPExecution`, `afterMCPExecution`, `beforeReadFile`, `afterFileEdit`, `beforeSubmitPrompt`, `stop`, etc. `.cursor/hooks.json` (`version: 1`). Block via `exit 2` or `{"permission":"deny"}`; `failClosed` flag. [cursor-hooks] Different payload shape — §3. |
| 10a | ↳ `protected-paths.sh` (PreToolUse Write\|Edit block) | PreToolUse, deny decision. Ports (payload adapter). | preToolUse or `beforeReadFile`/`afterFileEdit`; deny. Ports. Cursor's granular `beforeShellExecution` could even *close* the `sed -i` bypass documented in `README.md:328-334`. |
| 10b | ↳ `graph-update.sh` + `lint-on-edit.sh` (PostToolUse Edit\|Write) | PostToolUse on `apply_patch`/edits. Ports. | `afterFileEdit` (gives `old_string`/new content). Ports, arguably cleaner. |
| 10c | ↳ `stop-gate.sh` (Stop + SubagentStop test/lint gate) | Stop + SubagentStop, `exit 2` to block. Ports; needs `agent_type` filtering — verify Codex payload carries a caller-agent field (Claude's does; `hooks/scripts/stop-gate.sh:36`). | stop + subagentStop. `stop` can return `followup_message`. Verify caller-agent identity in payload. |
| 10d | ↳ `reviewer-route-gate.sh` (PreToolUse Agent-spawn block: lead-programmer→reviewer) | PreToolUse on the spawn/Task tool; needs both caller identity + spawn target in payload (Claude's `agent_type` + `tool_input.subagent_type` — `hooks/scripts/reviewer-route-gate.sh:17-18`). Verify Codex exposes both. | `subagentStart` "can allow or deny subagent creation" and filters by subagent type. [cursor-hooks] Maps well — verify caller identity is exposed. |
| 10e | ↳ `session-start.sh` (baseline sha + version drift + digest re-inject on resume/compact) | SessionStart + PreCompact/PostCompact. `additionalContext` output supported. Ports. | sessionStart (`additional_context` + `env` output) + preCompact. Ports. [cursor-hooks] |
| 10f | ↳ `task-gate.sh` (TaskCompleted; `impl:*` tasks need `.claude/reviewed/<id>.pass`) | **No `TaskCompleted` event.** Nearest: SubagentStop keyed on the subagent that did the impl work. But this whole gate is tied to agent-teams mode (row 14) which Codex lacks in the same shape. Degrade — §2F. | **No `TaskCompleted`.** `subagentStop` (status + summary, `followup_message`, `loop_limit`) is the nearest. Same teams-mode caveat. §2F. |
| 11 | **Skills / slash-commands** (`skills/coding-discipline`, `skills/install-antislop`, invoked via `Skill` tool / `/antislop:install-antislop`) | **Skills**: `SKILL.md` + YAML frontmatter, `.agents/skills/` etc., on-demand by `description`. Plus **custom prompts** (`~/.codex/prompts/`) as user slash-commands. [codex-stack] `coding-discipline` and `install-antislop` port as skills. | **Skills** (since Cursor 2.4), `SKILL.md`, `/name` invocation. [cursor-subagents/changelog] Port as skills. |
| 12 | **`AGENTS.md`/`CLAUDE.md` — "the only channel that reaches both subagents AND teammates automatically"**; carries `@.claude/persona-protocol.md` (`templates/persona-protocol.md:1-7`) | `AGENTS.md` is the native equivalent, concatenated root→leaf at session start. [codex-agentsmd] **But: whether it auto-cascades into subagents is not documented** — the customization-stack writeup implies subagents inherit sandbox policy, not necessarily `AGENTS.md`. **Load-bearing open question — §5.** `@import` of an arbitrary file also unconfirmed; may need protocol inlined into `AGENTS.md`. | `AGENTS.md` + `.cursor/rules/*.mdc` (frontmatter, `alwaysApply`/`globs`). Rules are referenced by name+description into the prompt. Subagent inheritance of rules/`AGENTS.md` **not documented** — same open question. §5. |
| 13 | **Plugin packaging + marketplace** — `.claude-plugin/plugin.json` + `marketplace.json`, `/plugin marketplace add` (`. claude-plugin/`) | `plugin.json` manifest; `codex marketplace add` (git/GitHub/local); bundles skills, MCP, agent defs; install policies `INSTALLED_BY_DEFAULT`/`AVAILABLE`/`NOT_AVAILABLE`. [codex-stack] Direct analogue. | `.cursor-plugin/plugin.json` + `.cursor-plugin/marketplace.json` (**nearly identical to Claude's layout**); Cursor Marketplace since 2.5 (Feb 2026); bundles rules, skills, agents, commands, MCP, hooks. [cursor-plugins] Direct analogue. |
| 14 | **Agent-teams mode** — `start-feature-team`, named concurrent teammates, `SendMessage` async delivery, shared task list, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (`commands/start-feature-team.md`) | Parallel subagent spawning + `[features] multi_agent = true`, but **no named-teammate `SendMessage` async messaging, no shared task list**. `agents.max_depth` default 1. Degrade to parallel-subagent fan-out — §2F. | Parallel subagents + `is_background: true` for non-blocking teammates, one-level nesting. **No `SendMessage`/shared task list.** Degrade — §2F. |
| 15 | **CLI scaffolder** `bin/cli.js` (mechanical copy/stamp/merge half of ADAPT) | Reusable pattern; retarget paths (`.codex/`, TOML emit, `config.toml`/`hooks.json` merge). §3. | Reusable pattern; retarget (`.cursor/`, `hooks.json` v1 schema, `mcp.json`). §3. |
| 16 | **`persona-config.json` runtime config** read by every hook script | Same file works — it's plain JSON the scripts read; only the hook scripts' *payload parsing* is platform-specific, not the config they consult. Keep shared. | Same. Keep shared. |
| 17 | **`AskUserQuestion`** (orchestrator relays planner Open Questions; unavailable to subagents — `README.md:322-327`) | No confirmed structured-question primitive for a main agent to interrogate the user mid-run. Fallback: plain-text Open Questions relay (already the subagent behavior). Minor. | Interactive IDE context; a mode can prompt the user conversationally. Plain-text relay is the safe port. |
| 18 | **Version-stamp comment after frontmatter** (`bin/cli.js:51-56`) — needed because a leading comment breaks Claude discovery | Codex agents are TOML; stamp as a `# comment` line — verify TOML parse tolerance, no frontmatter-first-byte constraint. | Cursor agents are markdown-frontmatter like Claude; **the same "stamp must follow the closing `---`" rule likely applies** — verify against Cursor's parser. |

## 2. The genuine gaps (and their graceful degradation)

Each of these is a Claude-Code primitive with no per-agent equivalent on one or
both targets. AntiSlop's rule is that safety degradations must be *loud*, not
silent (`agents/orchestrator.md:63-66`). Every degraded mode below must announce
itself the way the "no reviewer persona" branch does.

### 2A. Per-agent tool allowlist → coarse `sandbox_mode`/`readonly` (biggest gap)

AntiSlop's Writer/Reviewer split is partly *mechanical*: the reviewer and
milestone-auditor ship with **no Write/Edit tool at all**, so "the reviewer can
never edit the code it grades" is enforced by the tool list, not just prose
(`agents/reviewer.md:10-11`). The orchestrator similarly has no `Skill` tool,
making its "never loads persona skills" isolation mechanical
(`templates/persona-protocol.md:16-18`).

- Codex `sandbox_mode: read-only` and Cursor `readonly: true` **do** preserve
  "reviewer/auditor cannot write" — that half ports.
- Neither can express finer restrictions: "Bash + Read but no Edit" (they're
  read-only or full-write, nothing between), or "no `Skill`/`Agent` tool." So
  the orchestrator's no-Skill isolation and the lead-programmer's precise tool
  set become **instruction-only** on both platforms.
- **Degraded behavior**: the orchestrator/reviewer bodies must state, in-band,
  "on this platform my tool restriction is instruction-enforced, not
  mechanically enforced" — mirroring the memory-grant caveat AntiSlop already
  documents once in the shared protocol (`templates/persona-protocol.md:128-134`).
  The `reviewer-route-gate.sh` hook (row 10d) partly backstops this: it can
  still mechanically block a lead-programmer→reviewer spawn even where tool
  lists can't.

### 2B. `maxTurns` per-agent cap → global caps / instruction-only

Cost bounding of the Opus-tier planner/reviewer is a live concern
(`README.md:233-241`). Neither platform has per-agent turn caps.

- Codex: global `agents.max_threads`/`agents.max_depth` bound fan-out, not
  per-agent depth-of-work.
- **Degraded behavior**: keep the numbers as documented soft budgets in the
  persona bodies ("aim to finish within ~30 turns"), and lean harder on the
  2-FAIL loop cap (which is already instruction-level —
  `templates/persona-protocol.md:122-126`) and the orchestrator's
  "scale effort to the task" rule (`agents/orchestrator.md:37-44`). Flag in the
  port README that hard per-agent cost caps are a Claude-Code-only guarantee.

### 2C. Orchestrator-as-main-agent → AGENTS.md routing (Codex) / custom mode (Cursor)

- **Codex**: no key swaps the root system prompt for a named agent. Put the
  routing table into `AGENTS.md` (so it's in every root session), keep
  `orchestrator` as a real agent for explicit `/agent` switching, and rely on
  description-based delegation for the rest. Risk: the root session isn't
  *forced* to be a thin router the way `"agent": "orchestrator"` forces it.
- **Cursor**: ship an "Orchestrator" custom mode (model + system prompt + tool
  set). Closer than Codex, but a mode is user-selected, not a hard default, and
  whether modes can be shipped inside a plugin is unverified (§5).
- **Degraded behavior**: routing becomes a strong convention carried by
  `AGENTS.md`/rules + the mode, not a hard main-agent replacement. Document that
  the "thin router can't implement" guarantee is softer off Claude Code.

### 2D. Per-agent MCP scoping — Codex OK, Cursor gap

Codex's `mcp_servers` in the agent TOML reproduces explorer-only graph scoping
exactly (row 6). **Cursor cannot**: subagents inherit all parent MCP tools.

- **Cursor degraded behavior**: register the Code Review Graph MCP project-wide
  in `.cursor/mcp.json`. This reintroduces exactly the context-bloat the
  Explorer-as-a-service design exists to prevent (`agents/explorer.md:12-31`).
  Least-bad mitigation: keep the graph MCP project-wide but instruct all
  non-explorer personas (via rules/`AGENTS.md`) to route structural questions to
  the explorer anyway — the same instruction-enforced discipline the shared
  protocol already uses (`templates/persona-protocol.md:11-21`), just without the
  mechanical backstop. Announce the leak in the port notes.

### 2E. `memory: project` → file convention

Neither target has a per-agent persistent-memory primitive with auto-granted
Read/Write/Edit. Emulate: a `<platform-dir>/memory/<agent>.md` file the persona
body tells the agent to read on startup and append to, keeping the existing
"bounded index file + topic files" discipline (`agents/lead-programmer.md:16-20`).
Loses isolation (any agent with write access can touch any memory file) and the
auto-grant. Low risk — it's already the recommended *structure*, just without
the primitive.

### 2F. Agent-teams mode + TaskCompleted gate → parallel subagents, no shared task list

The `start-feature-team` gear depends on named teammates, `SendMessage` async
delivery, a shared task list, and the `TaskCompleted` hook gating `impl:*` tasks
on a `.pass` marker (`commands/start-feature-team.md`, `hooks/scripts/task-gate.sh`).
Neither platform reproduces the messaging + shared-task-list model.

- Both **do** have parallel subagent spawning (Codex `[features] multi_agent`;
  Cursor `is_background`). So the *concurrency* survives; the *coordination
  primitives* don't.
- **Degraded behavior**: for the first port, **drop agent-teams mode entirely**
  and ship only the always-on subagent-orchestrator gear (which is the default
  anyway — teams is "off by default, a deliberate gear", `README.md:36-37`).
  The `TaskCompleted` PASS-marker gate goes with it; the reviewer PASS still
  works in the sequential flow via the orchestrator's single-owner routing
  (`agents/orchestrator.md:51-59`). Revisit teams only if a platform grows a
  real inter-agent messaging model. This is the cleanest degradation available:
  a whole optional gear is disabled, loudly, rather than half-emulated.

## 3. Portability tiers

### Tier 1 — pure prose/logic, ports with zero changes

- **All persona *body* text** (the instructions below the frontmatter in every
  `agents/*.md`): routing philosophy, the Writer/Reviewer discipline, answer
  shape, blast-radius contract, TDD-first, materiality filter, verdict format.
  This is the bulk of AntiSlop's value and it is platform-agnostic English.
- **`skills/coding-discipline/SKILL.md`** — already a portable `SKILL.md`;
  Codex and Cursor both read that format.
- **`templates/persona-protocol.md`** content — role-agnostic prose. *Delivery*
  is Tier 2 (which file it lands in), but the text is unchanged.
- **`templates/persona-config.json`** and its schema — plain JSON the hooks
  read; identical across platforms (row 16). Only the hook *scripts* that parse
  tool payloads are platform-specific, not this config.
- **`persona-config.schema.json`, `protocol-digest.md`, CHANGELOG discipline**.

### Tier 2 — needs a per-platform adapter file

- **Agent definitions**: Claude markdown-frontmatter → **Codex TOML**
  (`developer_instructions` holds the body; `model`/`model_reasoning_effort`/
  `sandbox_mode`/`mcp_servers`). Cursor keeps markdown-frontmatter but with a
  **different, smaller field set** (`model`/`readonly`/`is_background`; drop
  `tools`/`maxTurns`/`memory`/`color`). Shared body text, generated wrappers.
- **Hook scripts**: the gating *logic* is portable bash, but each script's
  **payload extraction is Claude-Code-specific**. `stop-gate.sh` reads
  `.agent_type`, `.stop_hook_active`, `.session_id`, `.source`;
  `reviewer-route-gate.sh` reads `.agent_type` + `.tool_input.subagent_type`;
  the edit hooks read `.tool_input.file_path`. Codex payloads use
  `session_id`/`cwd`/`hook_event_name`/`tool_name`/`tool_input`/`turn_id`;
  Cursor uses `conversation_id`/`generation_id`/`workspace_roots`/... . So each
  script needs a thin per-platform **payload-adapter shim** (a few `jq` lines
  mapping that platform's field names to the internal variables the shared logic
  uses). Best structure: factor each hook into `logic.sh` (shared) + a
  per-platform field-extraction preamble, rather than three full copies.
- **Hook registration**: `hooks/hooks.json` (Claude `${CLAUDE_PLUGIN_ROOT}`) →
  Codex `hooks.json`/`[hooks]` in `config.toml` → Cursor `.cursor/hooks.json`
  (`version: 1`, camelCase event names, `matcher`/`timeout`/`failClosed`).
- **Settings merge**: `templates/settings-fragment.json` (Claude `"agent"` +
  `env` + `permissions`) → Codex `config.toml` fragment → Cursor has no direct
  `"agent"` key (custom mode instead, §2C).
- **Project-instructions delivery**: Claude's one `@.claude/persona-protocol.md`
  import line → Codex likely **inline the protocol into `AGENTS.md`** (pending
  §5 on `@import` support) → Cursor an `alwaysApply: true` rule in
  `.cursor/rules/` or `AGENTS.md`.
- **The scaffolder**: see §4 on whether `bin/cli.js` becomes multi-target or
  three binaries.

### Tier 3 — Claude-Code-only, must drop or degrade (name each explicitly)

1. **Mechanical per-agent tool restriction** beyond read-only (§2A) → degrade to
   `sandbox_mode`/`readonly` + instruction-only for the finer cases. Loud notice
   in reviewer/orchestrator bodies.
2. **`maxTurns` hard per-agent cost caps** (§2B) → soft documented budgets +
   global caps.
3. **Orchestrator-as-hard-main-agent** (§2C) → `AGENTS.md` routing (Codex) /
   custom mode (Cursor).
4. **Per-agent MCP scoping on Cursor** (§2D) → project-wide graph MCP +
   instruction-enforced explorer routing. (Codex keeps this — not Tier 3 there.)
5. **`memory: project` primitive** (§2E) → file convention.
6. **Agent-teams mode**: `SendMessage`, shared task list, `TaskCompleted` gate
   (§2F) → dropped for v1 on both; parallel-subagent fan-out only.
7. **`AskUserQuestion` structured prompts** (row 17) → plain-text Open Questions
   relay.

## 4. Proposed repo layout

Goal: keep the shared prose in one place; add thin per-platform adapter trees;
avoid three diverging copies of the persona bodies.

```
agents/                      # SHARED persona BODIES, platform-neutral prose.
  <persona>.body.md          #   split: body text only, no frontmatter.
adapters/
  claude/
    agents/*.md              # frontmatter wrappers (current format) + body @include
    hooks/                   # current hooks.json + scripts (unchanged)
    plugin/ (.claude-plugin) # current plugin.json + marketplace.json
    settings-fragment.json
  codex/
    agents/*.toml            # name/description/developer_instructions(+body)/mcp_servers
    hooks.json               # Codex event names
    plugin.json              # codex marketplace manifest
    config-fragment.toml
  cursor/
    agents/*.md              # name/description/model/readonly/is_background + body
    hooks.json               # version:1, camelCase events
    rules/persona-protocol.mdc  # alwaysApply
    .cursor-plugin/{plugin.json,marketplace.json}
hooks/
  lib/*.sh                   # SHARED gating logic (payload-agnostic)
  claude/*.sh                # thin field-extraction preambles -> lib
  codex/*.sh
  cursor/*.sh
templates/                   # SHARED persona-config schema/json, protocol prose, digest
skills/                      # SHARED SKILL.md (coding-discipline, install-antislop)
bin/
  cli.js                     # multi-target scaffolder: `npx antislop --target=codex`
```

Design decisions:

- **`agents/` stays the single source of persona prose.** Split each persona
  into a platform-neutral `*.body.md` plus per-platform frontmatter wrappers in
  `adapters/<platform>/agents/`. The wrapper carries only the fields that
  platform understands and `@include`s (or the build step inlines) the shared
  body. This is the highest-leverage decision: it prevents the reviewer's
  adversarial instructions (etc.) from drifting across three copies. Downside: a
  build/assembly step is now required (the scaffolder does the inlining), where
  today the files are hand-authored whole.
- **Hooks: shared logic + per-platform preamble, not three rewrites.** The
  actual decisions (is this a gated agent? is the tree dirty? does the sentinel
  hold a reason?) are identical; only JSON field names differ. `hooks/lib/` holds
  the logic; `hooks/<platform>/` holds ~5-line `jq` shims that populate the same
  variable names from that platform's payload. Avoids the 7×3 = 21-script
  maintenance explosion.
- **`bin/cli.js` becomes multi-target, not three binaries.** It already cleanly
  separates "deterministic scaffolding" from "judgment-driven ADAPT"
  (`bin/cli.js:5-11`). Add a `--target=claude|codex|cursor` flag (default
  detected from which agent dir already exists, or asked). The three targets
  share persona selection, `persona-config.json` emission, `.gitignore` and
  wiki-seeding logic; they diverge only in *which* adapter tree they copy and
  *which* settings/hooks format they emit. One binary, three emit paths — much
  less duplication than three CLIs, and the interactive persona-selection UX
  (reviewer typed-confirmation etc., `bin/cli.js:163-184`) is written once.
- **`install-antislop` skill** stays one skill but grows a target-detection step
  and per-target substitution notes (Codex TOML placeholder substitution vs.
  Cursor frontmatter; Codex keeps graph MCP scoped, Cursor can't — §2D).
- **Plugin manifests** are small and diverge in format, so keep three
  hand-maintained manifests under `adapters/*/`. The Cursor one is nearly a
  rename of the Claude one (`.cursor-plugin/` vs `.claude-plugin/`).

## 5. Phasing

**Recommended order: Codex first, then Cursor, teams-mode never (for now).**

**Why Codex first.** Codex is the closest structural match: near-identical hook
event names and block semantics (`exit 2` / `permissionDecision: deny`), a real
`plugin.json` + `codex marketplace add` flow, AND — critically — it is the *only*
target that keeps **per-agent MCP scoping** (`mcp_servers` in the agent TOML,
row 6), so the explorer-only Code Review Graph connection ports without
degradation. The only significant format cost is markdown-frontmatter → TOML,
which is mechanical. Doing Codex first validates the shared-body/adapter split
(§4) against a platform that stresses the format-translation path but not many
capability gaps.

**Cursor second.** Cursor keeps markdown-frontmatter (less format churn) but
carries the harder capability gaps: no per-agent MCP (§2D forces the graph
project-wide) and no main-agent replacement except custom modes (§2C). It's
better to have the adapter architecture proven on Codex before absorbing
Cursor's degradations. Bonus: because Cursor already reads `.claude/agents/`,
an early smoke test is "point Cursor at the existing Claude adapter and see what
loads" — cheap signal before building the Cursor adapter properly.

**MVP milestone (per platform):** the always-on subagent-orchestrator loop —
orchestrator + explorer + lead-programmer + reviewer — with (a) agent
definitions in the native format, (b) the `stop-gate` + `protected-paths` +
`reviewer-route-gate` + edit hooks wired and payload-adapted, (c)
`persona-protocol.md` reaching subagents (pending the §5 open question — this is
the MVP's biggest risk, verify it *first*), and (d) the multi-target
`bin/cli.js` scaffolding those files. That's a usable AntiSlop: plan-less
route → implement → independent review → gated stop. planner / repo-historian /
milestone-auditor / researcher come after, since they're already opt-in and
mostly add prose + one MCP (researcher/arXiv, which is Codex-easy, Cursor-leaky).

**Explicitly wait on:**
- **Agent-teams mode** (§2F) — no target reproduces the messaging + shared-task
  model. Don't half-emulate it; ship without the gear.
- **Cursor custom-mode-as-orchestrator packaged in a plugin** (§2C/§5 open q) —
  until it's confirmed a mode can ship inside a plugin bundle, treat the Cursor
  orchestrator as a documented manual setup step, not an installed artifact.
- **Tightening the `sed -i` / lockfile bypass** — Cursor's granular
  `beforeShellExecution` hook could finally close the advisory-only gap in
  `protected-paths.sh` (`README.md:328-334`); tempting, but it's a
  Cursor-specific enhancement, not port parity. Backlog it.

## 6. Open questions (need a human decision or a live probe before implementation)

1. **Does `AGENTS.md` / Cursor rules automatically reach *subagents*?** This is
   the single load-bearing assumption. AntiSlop's entire cross-cutting-rules
   design rests on "CLAUDE.md is the only channel that reaches both subagents and
   teammates automatically" (`templates/persona-protocol.md:1-7`,
   `README.md:245-252`). Codex docs are silent on whether `AGENTS.md` cascades
   into spawned subagents (they imply sandbox policy inherits, not instructions);
   Cursor docs don't state rule/`AGENTS.md` inheritance for subagents either.
   **If it doesn't cascade, the shared-protocol delivery model breaks on that
   platform** and the protocol must be re-injected per subagent (e.g. baked into
   each agent's body, losing the "add a persona = one file" property). **Probe
   this on both platforms before anything else** — it gates the whole port.
2. **Does `AGENTS.md` support an `@import` of an arbitrary file** (like Claude's
   `@.claude/persona-protocol.md`), or must the protocol be inlined into
   `AGENTS.md` directly? Affects whether `persona-protocol.md` stays a separate
   versioned file or gets concatenated in.
3. **Codex plugin-provided agent namespacing** — are they bare or namespaced,
   and does a bare-name spawn hard-error the way Claude's does
   (`skills/install-antislop/SKILL.md:33-38`)? Determines whether the
   mandatory-copy-into-project trick is still needed on Codex or is dead weight.
4. **Can a Cursor custom *mode* be shipped inside a plugin** (`.cursor-plugin/`),
   or is it always user-configured? Determines whether the orchestrator is an
   installed artifact or a manual step on Cursor (§2C).
5. **Do Codex/Cursor hook payloads carry the *calling* agent's identity** on
   SubagentStop / subagent-spawn events (Claude's `agent_type`,
   `hooks/scripts/stop-gate.sh:36`, `hooks/scripts/reviewer-route-gate.sh:17`)?
   `stop-gate` (gatedAgents filtering) and `reviewer-route-gate`
   (lead-programmer→reviewer block) are *unimplementable* without it — they'd
   have to become instruction-only, widening §2A. Verify per platform.
6. **Model-tier mapping.** AntiSlop hardcodes haiku/sonnet/opus tiers per persona
   (explorer=haiku cheap/fast, planner/reviewer=opus). What are the intended
   Codex (`gpt-5.x-codex*`) and Cursor model ids per tier? Needs a human/product
   decision, not just research — it's a cost/quality call, and it should live in
   `persona-config.json` so it's tunable per project rather than hardcoded in the
   adapters.
7. **Is `config.toml`/`.cursor/hooks.json` mergeable the way Claude settings
   are** (AntiSlop is careful to *merge, never clobber* — `bin/cli.js:88-108`,
   `templates/settings-fragment.json:2`)? Codex `config.toml` is TOML (mergeable
   with a TOML lib); Cursor `hooks.json` is JSON. Confirm no existing-config
   clobber risk before the scaffolder writes them.

---

## Sources

Codex:
- Subagents — https://learn.chatgpt.com/docs/agent-configuration/subagents (redirect from https://developers.openai.com/codex/subagents) `[codex-subagents]`
- Hooks — https://learn.chatgpt.com/docs/hooks (redirect from https://developers.openai.com/codex/hooks) `[codex-hooks]`
- AGENTS.md — https://developers.openai.com/codex/guides/agents-md `[codex-agentsmd]`
- Config reference — https://developers.openai.com/codex/config-reference , https://developers.openai.com/codex/config-advanced
- MCP — https://developers.openai.com/codex/mcp
- Custom prompts (slash commands) — https://developers.openai.com/codex/custom-prompts
- Customization stack (plugins/skills/marketplace) — https://codex.danielvaughan.com/2026/04/12/codex-cli-customisation-stack-unified-system/ `[codex-stack]`
- Simon Willison, Codex subagents — https://simonwillison.net/2026/Mar/16/codex-subagents/

Cursor:
- Subagents — https://cursor.com/docs/subagents `[cursor-subagents]`
- Hooks — https://cursor.com/docs/hooks `[cursor-hooks]`
- Rules — https://cursor.com/docs/rules
- Plugins reference — https://cursor.com/docs/reference/plugins , https://github.com/cursor/plugins `[cursor-plugins]`
- Marketplace — https://cursor.com/marketplace
- Subagents/Skills changelog (2.4) — https://cursor.com/changelog/2-4
- Cursor 2.5 plugins — https://forum.cursor.com/t/cursor-2-5-plugins/152124
- Modes — https://docs.cursor.com/agent/modes
