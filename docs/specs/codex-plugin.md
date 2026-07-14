# AntiSlop → Codex CLI plugin: v1/MVP implementation spec

Status: implementation spec, ready to build against. Supersedes the Codex
column of `docs/specs/codex-cursor-plugin.md` (that doc's §0/§1/§5 framing —
"do Codex first" — is still correct; it just didn't get built first. This
spec picks that thread back up now that `adapters/cursor/` (v0.7.0, see
`docs/cursor-port-notes.md`) exists as a working precedent for the
scaffolder/plugin/hook-adapter pattern). No Codex code exists yet — this
scopes it; it does not do it.

Scope: the same MVP milestone the original spec defined for every platform —
the always-on subagent-orchestrator loop (orchestrator + explorer +
lead-programmer + reviewer), the enforcement hooks that back it, the shared
protocol delivered into every session, plugin packaging, and
`bin/cli.js --target=codex` scaffolding. Agent-teams mode and the optional
personas (hivemind, repo-historian, milestone-auditor, researcher) are
explicitly out of scope for v1, same as the Cursor MVP.

Research basis: `docs/specs/codex-cursor-plugin.md` §1/§2/§3/§6, re-verified
live against `learn.chatgpt.com/docs/*` on 2026-07-14 (the redirect target of
`developers.openai.com/codex/*`). Where this pass changed or resolved a
finding from that doc, it's called out explicitly in §2 below — treat this
spec as authoritative over the older doc for anything they disagree on, and
still re-verify before implementing regardless (Codex moves fast; this is a
snapshot, not a guarantee).

## 1. Why Codex, and why now

Two things haven't changed since the original doc argued for building Codex
before Cursor:

- **Structural closeness.** Near-identical hook event names and block
  semantics (`exit 2` / stderr, or a JSON `permissionDecision`/`decision`
  field) to Claude Code's model. A real plugin manifest + marketplace add
  flow. The `adapters/cursor/` pattern (shared decision logic + thin
  per-platform payload preamble, scaffolder as a second `--target`) already
  proved out the architecture this spec reuses — this is the second data
  point, not a novel design.
- **Codex is the only target that keeps per-agent MCP scoping.** Confirmed
  again in this pass (§2): `mcp_servers` is a documented optional field on a
  custom agent TOML, inheriting from the parent session only when omitted.
  Cursor could not do this (`adapters/cursor/agents/explorer.md`'s port note:
  "Cursor has NO per-agent MCP scoping"); its Code Review Graph connection had
  to go project-wide, reintroducing the context-bloat the
  explorer-as-a-service design exists to prevent
  (`docs/cursor-port-notes.md` §2D). Codex restores the clean version of that
  design. That alone is worth the build.

## 2. What this pass verified or changed vs. the original spec

Live-fetched `learn.chatgpt.com/docs/{agent-configuration/subagents, hooks,
agent-configuration/agents-md, config-file/config-reference, build-plugins}`
on 2026-07-14. Findings, mapped to the original spec's §6 open questions:

| # | Question | Original spec status | This pass |
|---|---|---|---|
| 1 | Does AGENTS.md reach subagents? | Unknown, "gates the whole port" | **Better than expected.** The subagents doc states outright: "Custom agents automatically inherit applicable AGENTS.md and project instructions," and that Codex "can also follow applicable AGENTS.md or skill instructions that request delegation" when spawning. This is doc-stated, not just implied — meaningfully stronger than what Cursor's docs gave us. Still unverified *empirically* (see §12 — a live smoke test remains the first thing to do, doc claims deserve a real check) but no longer the coin-flip §6 called it. |
| 2 | `@import` of an arbitrary file in AGENTS.md? | Unknown | **Confirmed NO.** "The documentation makes no mention of an `@import` or include mechanism... You can only use the predefined filenames (`AGENTS.md`, `AGENTS.override.md`, and configured fallbacks)." Files concatenate root-to-leaf, closer-to-cwd wins on conflict. The protocol must be inlined into AGENTS.md text directly — see §5. |
| 3 | Plugin-provided agent namespacing / bare-name hard-error? | Unknown | **Reframed, not resolved.** Project-scoped custom agents in `.codex/agents/*.toml` clearly override a built-in of the same name ("If a custom agent name matches a built-in agent such as `explorer`, your custom agent takes precedence") — no hard-error like Claude's. But the plugin-manifest doc (`build-plugins`) is explicit that its documented bundleable components are **skills, MCP servers, apps, and hooks — not custom agent definitions**. There is no confirmed mechanism for a *plugin* to ship agent TOMLs at all, namespaced or otherwise. Design decision in §4/§9: don't rely on the plugin manifest to deliver agents; scaffold them straight into the project's `.codex/agents/` the same way Claude's ADAPT copy and Cursor's scaffolder do, sidestepping the question entirely. |
| 5 | Do hook payloads carry the calling agent's identity? | Unknown | **Still open, more precisely.** `SubagentStart`/`SubagentStop` payloads carry `agent_id` and `agent_type` — but the fetched summary describes these as the subagent's own identifier/profile, with no separate documented field for the *parent* that spawned it (mirrors Cursor's `subagent_type`-is-the-target-not-the-caller gap exactly). Treat as unresolved until probed live (§12); design defaults to the same graceful degradation Cursor shipped (§10). |
| 6 | Model-tier mapping (haiku/opus → Codex ids)? | Unknown, product decision | Still a product decision, not a research question. `model` (e.g. `gpt-5.5`) and `model_reasoning_effort` (`minimal\|low\|medium\|high\|xhigh`) are per-agent-overridable, confirmed. Left as `model: inherit`-equivalent (omit the field) in the MVP, same as Cursor shipped `model: inherit` — see §4. |
| 7 | Is config mergeable without clobber risk? | Unknown | `config.toml` is TOML; hooks register via `hooks.json` **or** an inline `[hooks]` table in `config.toml`. This spec uses a standalone `hooks.json` (never touches the user's `config.toml`) specifically to keep the "merge, never clobber" discipline as simple as Cursor's plain-JSON deep-merge — see §6. |

New findings with no prior open-question number, all load-bearing for §4/§7:

- **Plugin manifest lives at `.codex-plugin/plugin.json`** (mirrors Claude's
  `.claude-plugin/` and Cursor's `.cursor-plugin/` naming exactly). Required
  fields `name`/`version`/`description`; optional component pointers
  `skills`, `mcpServers` (path to `.mcp.json`), `apps`, `hooks` (defaults to
  `./hooks/hooks.json`). **No `agents` pointer field is documented.** This is
  the basis for the §4/§9 design decision above.
- **Hook trust is an explicit, separate step.** "Non-managed command hooks
  must be reviewed and trusted before they run," recorded per hook hash via
  the `/hooks` CLI command. This has no analogue in the Claude or Cursor
  ports and must be called out as a manual post-install step (§9, §14) — a
  scaffolded `hooks.json` that nothing has trusted yet is silently inert, not
  silently broken, which is its own kind of loud-vs-silent risk worth a
  README/scaffolder-output line.
- **Plugin hook env vars**: `PLUGIN_ROOT`, `PLUGIN_DATA` — plus, notably,
  **`CLAUDE_PLUGIN_ROOT`/`CLAUDE_PLUGIN_DATA` are documented as compatibility
  aliases**. Use the native `PLUGIN_ROOT` in the shipped `hooks.json` for
  clarity (same choice Cursor made with `${CURSOR_PLUGIN_ROOT}`), but this
  alias is worth knowing about if a stray Claude-authored script ever ends up
  on this path.
- **Marketplace manifest placement is a genuine open question, not an
  assumption to carry forward.** The `build-plugins` fetch describes
  `marketplace.json` living at `~/.agents/plugins/marketplace.json` (user) or
  `$REPO_ROOT/.agents/plugins/marketplace.json` (project) — a *different*
  top-level directory (`.agents/`) than the plugin manifest itself
  (`.codex-plugin/`). This is unlike Claude and Cursor, where `plugin.json`
  and `marketplace.json` sit side by side in the same directory and this repo
  self-hosts both (`source: "./"`). Do not assume the Claude/Cursor sibling
  layout carries over — verify live with `codex plugin marketplace add
  ./adapters/codex` (or wherever it ends up) before finalizing §7's layout.
- **`agents.max_threads` defaults to 6, `agents.max_depth` defaults to 1** —
  confirms the original spec's "cost bound becomes global, not per-agent"
  finding (§2B original), with concrete numbers now.
- **A per-agent `skills.config` field exists** on the custom-agent TOML,
  undocumented in the original spec. Worth investigating during
  implementation (§12) as a possible *partial* fix for the §2A gap
  specifically for the orchestrator's "no Skill tool" isolation — even if it
  can't express general tool restriction (Bash yes, Edit no), it might let
  the orchestrator ship with zero invokable skills mechanically, which no
  other platform can currently do. Don't design around it until confirmed;
  treat instruction-only as the default and this as a possible upgrade.

## 3. Repo layout

Mirrors the `adapters/cursor/` choice: one self-contained tree, not the
original spec's fuller shared-body split (§4 of the old doc). That refactor
is deferred again here for the same reason it was deferred for Cursor — it's
only worth its build-step cost once a third platform's hand-ported copy makes
the drift risk concrete twice over. `docs/cursor-port-notes.md`'s
"duplication-drift risk" note already flags this as the thing to revisit once
Codex exists; after this pass, revisit it for real rather than deferring a
third time.

```
adapters/codex/
  .codex-plugin/
    plugin.json                # name/version/description + hooks pointer
    marketplace.json            # placement TBD - see §2, §7
  agents/
    orchestrator.toml
    explorer.toml
    lead-programmer.toml
    reviewer.toml
  hooks/
    hooks.json                  # event names, PLUGIN_ROOT-relative commands
    scripts/
      protected-paths.sh
      graph-update.sh
      lint-on-edit.sh
      stop-gate.sh
      reviewer-route-gate.sh
  agents-md-fragment.md         # protocol content, inlined into AGENTS.md by
                                 # the scaffolder (no @import - see §5)
```

None of the existing Claude (`agents/*.md`, `hooks/`, `.claude-plugin/`,
`templates/`, `skills/`) or Cursor (`adapters/cursor/`) artifacts change.

## 4. Persona → Codex TOML mapping

Confirmed fields on a custom agent TOML (`.codex/agents/<name>.toml`):
required `name`, `description`, `developer_instructions`; optional `model`,
`model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config`,
`nickname_candidates`. `developer_instructions` holds the persona body as a
TOML multi-line string — this is where the Claude/Cursor markdown body prose
ports verbatim (Tier 1 in the original spec: routing philosophy, Writer/
Reviewer discipline, answer shape, blast-radius contract — all
platform-agnostic English, unchanged).

Field mapping, one row per MVP persona:

| Persona | Claude `tools:`/`maxTurns:`/`memory:` | Codex TOML |
|---|---|---|
| orchestrator | no Write/Edit/Skill (mechanical isolation) | no `sandbox_mode` override needed if it only reads + spawns — default to `sandbox_mode = "read-only"` if it does zero mutating Bash, else `workspace-write` with the no-Write/no-Edit/no-Skill rule stated as instruction-only in `developer_instructions` (§10, same degradation Cursor shipped). No `model` override (`inherit`-equivalent = omit the field). |
| explorer | `tools: Read, Grep, Glob, Bash, Skill, SendMessage`, `maxTurns: 10`, `mcpServers:` scoped to explorer alone | `sandbox_mode = "read-only"`. **`mcp_servers`** carries the Code Review Graph launch command — this is the row that Cursor could not port; Codex can. `model_reasoning_effort = "low"` (or the project's chosen cheap tier once §2's tier-mapping decision is made) as the nearest analogue to Claude's `haiku`. `maxTurns` has no per-agent equivalent (§10) — state 10 as a soft budget in `developer_instructions`, same as Cursor. |
| lead-programmer | full tool access, `maxTurns: 30` | `sandbox_mode = "workspace-write"`. No per-tool allowlist exists (§10) — nothing to restrict here anyway, this persona needs full access. |
| reviewer | `tools: Read, Grep, Glob, Bash, Agent, Skill, SendMessage` (no Write/Edit), `maxTurns: 30` | `sandbox_mode = "read-only"` — the mechanical half that ports (mirrors Cursor's `readonly: true`). **Same unverified sub-assumption Cursor flagged**: does `read-only` still permit the Bash `printf` that writes the PASS/FAIL marker? If not, fall back to `workspace-write` + instruction-only "never edit code" — the pending-review gate is resilient either way (§6). `model_reasoning_effort = "high"` (or the opus-tier mapping once chosen) as the nearest analogue to Claude's `opus`. |

Example (`adapters/codex/agents/explorer.toml`, illustrative — verify TOML
multi-line string escaping against a real Codex build before shipping):

```toml
name = "explorer"
description = "Use PROACTIVELY for any structural question - where is X defined, what calls Y, blast radius of a change to Z..."
sandbox_mode = "read-only"
model_reasoning_effort = "low"

[mcp_servers.code-review-graph]
command = "<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_4>"
# args / env as needed - same substitution slot bin/cli.js already renders
# for the Claude explorer.md via applyMcpPlaceholder (§9)

developer_instructions = """
You are a lightweight, stateless code cartographer. ...
[persona body ported verbatim from agents/explorer.md]
...

## Shared protocol essentials (inlined backstop)
[same inlined-digest pattern as the Cursor port - see §5]
"""
```

Row 18 of the original spec ("stamp must follow frontmatter, not precede
it") doesn't apply the same way here — TOML has no leading-delimiter
discovery constraint like Claude's markdown frontmatter. Verify a leading
`#` comment doesn't break TOML parsing (it shouldn't; TOML comments are
unambiguous), but there's no known reason to expect the Claude-specific
"stamp breaks discovery" bug to recur.

## 5. Protocol delivery

No `@import` (§2). The shared protocol content (currently
`templates/persona-protocol.md`) must be **inlined directly into AGENTS.md
text**, not referenced. Design:

- `adapters/codex/agents-md-fragment.md` holds the protocol content,
  wrapped in a scaffolder-managed marker block:
  ```
  <!-- ANTISLOP:BEGIN persona-protocol v{version} -->
  ...protocol content...
  <!-- ANTISLOP:END persona-protocol -->
  ```
- The scaffolder finds-and-replaces between the markers (create if absent,
  replace in place if present) rather than blind-appending — this is the
  Codex-specific version of the `appendUnique` idempotency `bin/cli.js`
  already uses for Claude's one-line `@.claude/persona-protocol.md` import
  and needs to be a new, small helper (`upsertMarkedBlock` or similar) since
  the existing `appendUnique` only dedupes whole lines, not a multi-line
  block.
- **Belt-and-suspenders, same as Cursor, despite the stronger doc claim in
  §2.** The subagents doc *says* AGENTS.md reaches spawned agents, but "the
  docs say so" is not the same bar AntiSlop holds itself to for its own
  safety system (`agents/orchestrator.md:63`, "loud not silent" — and this
  is the exact reasoning `docs/cursor-port-notes.md` gives for inlining
  despite Cursor's docs being merely silent rather than affirmatively
  contradicting). Inline the same load-bearing digest — review ownership,
  structural-questions-to-explorer, FAIL cap, WIP sentinel, answer shape —
  into every persona's `developer_instructions`, matching
  `templates/protocol-digest.md`'s existing condensed-reinjection precedent.
  If the live probe (§12) confirms AGENTS.md really does cascade, the inlined
  digest is redundant but harmless; if it doesn't, the safety-critical rules
  still land in every subagent regardless.

## 6. Hook adapter design

Confirmed event names: `SessionStart`, `PreToolUse`, `PostToolUse`,
`PermissionRequest`, `PreCompact`, `PostCompact`, `UserPromptSubmit`,
`SubagentStart`, `SubagentStop`, `Stop`. No `TaskCompleted` — `task-gate.sh`
stays dropped, same as Cursor (§11).

Common payload fields: `session_id`, `cwd`, `hook_event_name`,
`transcript_path`; turn-scoped events add `turn_id`, `permission_mode`.
Tool events (`PreToolUse`/`PostToolUse`/`PermissionRequest`) add `tool_name`,
`tool_input`, `tool_use_id` (`PostToolUse` also gets `tool_response`).
Subagent events add `agent_id`, `agent_type`. Blocking: exit code `2` +
stderr works everywhere; `PreToolUse` can alternatively return
`{"permissionDecision": "deny", "permissionDecisionReason": "..."}`,
`PermissionRequest`/`UserPromptSubmit` use `{"decision": "block", "reason":
"..."}`. This spec uses exit-2-plus-stderr uniformly, same choice Claude and
Cursor both made — one mechanism, not three.

MVP hook set (same five as Cursor shipped, not the full seven Claude has —
`session-start.sh` and `reviewed-path-gate.sh` stay deferred, see §11):

| Event (Codex) | Script | Payload extraction (vs. Claude's `.agent_type`/`.tool_input.file_path`/etc.) |
|---|---|---|
| `PreToolUse` | `protected-paths.sh` | `.tool_name`, `.tool_input.file_path` (verify exact key against a real `apply_patch`/edit-tool payload — Cursor's port defensively tried several candidate keys for the same reason; do the same here rather than assuming). Project dir from `.cwd`. |
| `PostToolUse` | `graph-update.sh`, `lint-on-edit.sh` | Same `.tool_input.file_path`. Matcher restricts to edit-shaped `tool_name`s (`apply_patch` per the original spec's row 10b; confirm the canonical name — the payload doc's own example uses `"Bash"` and `"apply_patch"`). |
| `SubagentStart` | `reviewer-route-gate.sh` | `.agent_type` as the spawn target (mirrors Cursor's `.subagent_type`). Caller identity: unresolved (§2 row 5) — ship the same partial degradation Cursor did: block dispatch of the next gated unit while a pending-review flag exists (mechanical), leave "lead-programmer must not spawn reviewer directly" as instruction-only until §12 resolves whether a caller field exists. |
| `Stop` | `stop-gate.sh` | No agent identity on plain `Stop` (matches Claude and Cursor) — key off `persona-config.json`'s `mainAgent` field, same solution Cursor's port used for the same gap. |
| `SubagentStop` | `stop-gate.sh` | `.agent_type` for gated-agent matching, `.agent_id` for the per-agent pending-review-flag/WIP-sentinel filename (Cursor had to key off `.subagent_type` alone since it had no per-subagent id, accepting a known limitation for concurrent same-type subagents — **Codex's `.agent_id` fixes that limitation outright** if it's genuinely a stable per-instance id; verify it's not just a repeat of `.agent_type`). Session/baseline id: `.session_id` (Codex has this natively, unlike Cursor's `.conversation_id` reuse). |

`hooks.json` registration (`hooks` pointer defaults to
`./hooks/hooks.json` relative to the plugin root per §2's `build-plugins`
finding — no need for a custom pointer unless the layout in §3 changes):

```json
{
  "hooks": {
    "PreToolUse": [
      { "command": "${PLUGIN_ROOT}/hooks/scripts/protected-paths.sh" }
    ],
    "PostToolUse": [
      { "command": "${PLUGIN_ROOT}/hooks/scripts/graph-update.sh" },
      { "command": "${PLUGIN_ROOT}/hooks/scripts/lint-on-edit.sh" }
    ],
    "SubagentStart": [
      { "command": "${PLUGIN_ROOT}/hooks/scripts/reviewer-route-gate.sh" }
    ],
    "Stop": [
      { "command": "${PLUGIN_ROOT}/hooks/scripts/stop-gate.sh" }
    ],
    "SubagentStop": [
      { "command": "${PLUGIN_ROOT}/hooks/scripts/stop-gate.sh" }
    ]
  }
}
```

(Verify the exact wrapper shape — Claude nests hook entries under
`matcher`/`hooks: [{type, command}]`; Cursor uses a flat `{command}` list
under `version: 1`. Codex's shape isn't confirmed by this pass — check
`learn.chatgpt.com/docs/hooks`'s registration example directly before
shipping, don't copy Cursor's flat shape by assumption.)

Each script keeps the exact ordered decision logic already proven twice
(`hooks/scripts/stop-gate.sh` → `adapters/cursor/hooks/scripts/stop-gate.sh`
→ this one): loop guard, reviewer's-stop clears pending flags, main-stop
with a pending flag blocks (defer:/skip: escape), non-gated stop allows,
WIP sentinel with a reason allows, gated subagent-stop creates the pending
flag, clean-tree-no-new-commits allows, otherwise run the configured
test/lint command. Only the jq field names at the top of the script change.

## 7. Plugin packaging

```
adapters/codex/.codex-plugin/plugin.json
```

```json
{
  "name": "antislop-codex",
  "version": "0.8.0",
  "description": "AntiSlop persona system ported to Codex CLI (MVP): orchestrator + explorer + lead-programmer + reviewer, enforcement hooks, and the shared persona-protocol inlined into AGENTS.md. Per-agent MCP scoping is preserved (Codex-only advantage over the Cursor port). Agent-teams mode and per-agent tool/turn/memory scoping are dropped or degraded - see docs/codex-port-notes.md.",
  "hooks": "./hooks/hooks.json",
  "author": { "name": "Sebastian Torres Lara" },
  "repository": "https://github.com/Storreslara/AntiSlop",
  "license": "MIT",
  "keywords": ["multi-agent", "orchestrator", "code-review", "subagents", "codex"]
}
```

No `skills` or `mcpServers` pointer at the plugin-manifest level — the MVP's
skills (`coding-discipline`) are out of scope for v1 (§11), and per-agent MCP
scoping is expressed inside each agent TOML (§4), not the plugin-wide
`mcpServers` field (which would just reintroduce the project-wide leak §1
argues Codex should avoid).

**`marketplace.json` placement is unresolved — do not build the scaffolder's
packaging step until this is checked live** (§2, §12). Two candidates:
- Sibling to `plugin.json`, mirroring Claude/Cursor: `adapters/codex/
  .codex-plugin/marketplace.json`, `source: "local"`, `path: "./"`.
- The `build-plugins`-documented convention: `adapters/codex/.agents/
  plugins/marketplace.json` as a separate directory from the plugin root.

Whichever it is, keep the same self-hosting pattern the Claude and Cursor
manifests use (this repo IS the marketplace listing for its own plugin,
`source` pointing at itself) rather than inventing a new distribution model.

## 8. `persona-config.json` additions

Same schema Claude and Cursor both already read
(`templates/persona-config.schema.json`); only the hook scripts' payload
parsing differs, not the config they consult (original spec row 16, still
true). New fields needed, both precedented by the Cursor port:

- `target: "codex"` (Cursor's port added the same field for the same reason
  — `stop-gate.sh` and friends need to know which platform's config
  conventions apply if this ever needs to branch).
- `mainAgent` (default `"orchestrator"`) — Codex has no config key that
  swaps the root session's identity the way Claude's `settings.json` `agent`
  field does (§2C of the original spec, unresolved for Codex same as
  Cursor), so `stop-gate.sh`'s plain-`Stop` branch needs this the same way
  Cursor's does.

## 9. Scaffolder: `bin/cli.js --target=codex`

New `scaffoldCodex(args)` function, structurally identical to
`scaffoldCursor` (`bin/cli.js:747-891`) with these Codex-specific
differences:

1. Copies `adapters/codex/agents/*.toml` → `.codex/agents/` (existence check
   / `--overwrite` semantics identical to the Cursor path). This is the §2/§4
   design decision made concrete: agents are delivered by the scaffolder
   copying TOML into the project, never by relying on an undocumented
   plugin-bundled-agents mechanism.
2. Copies `hooks/scripts/*.sh` → `.codex/hooks/scripts/`, rewrites
   `${PLUGIN_ROOT}` → a project-relative path in `hooks.json`, deep-merges
   into any existing `.codex/hooks.json` with the same dedupe-aware
   per-event merge `scaffoldCursor` already implements
   (`bin/cli.js:816-836`) — reuse that function, don't reimplement it.
3. **New**: `upsertMarkedBlock(claudeMdPath /* really AGENTS.md */,
   beginMarker, endMarker, content)` — replaces `appendUnique`'s role for
   Codex's AGENTS.md, per §5. Create `AGENTS.md` with the block if absent;
   find-and-replace the block if present; leave everything else in the file
   untouched (a project's existing AGENTS.md content outside the markers is
   not this scaffolder's business, same "merge, never clobber" principle
   `bin/cli.js`'s header comment already commits to).
4. Writes `.codex/persona-config.json` with the `target`/`mainAgent` fields
   from §8, otherwise identical skeleton to the Claude/Cursor versions.
5. `.gitignore` entries: `.codex/reviewed/`, `.codex/wip-handoff.*`,
   `.codex/.session-baseline.*`, `.codex/wip-audit.log`,
   `.codex/.pending-review.*`, `.codex/review-audit.log` — same set, `.cursor`
   → `.codex` prefix swap.
6. Final console output must say, explicitly (mirroring
   `scaffoldCursor`'s closing block, `bin/cli.js:876-890`):
   - AGENTS.md-reaches-subagents is doc-stated but not yet empirically
     confirmed by this project — verify it (§12) before trusting it over the
     inlined backstop.
   - **Hooks are scaffolded but not yet trusted** — run `codex hooks` (or
     whatever the confirmed trust-approval command is, §2) to review and
     approve them, or they're silently inert.
   - Fill in `.codex/persona-config.json`'s `testAndLintCommand`,
     `sourceGlobs`, `protectedPaths`, `graphUpdateCommand` for this repo.
   - If using the Code Review Graph, wire its launch command into
     `explorer.toml`'s `mcp_servers.code-review-graph` block — same
     `--wire-graph-mcp`-style flow `bin/cli.js` already has for Claude
     (`bin/cli.js:642-730`); extend `applyMcpPlaceholder`'s TOML rendering
     (a new `renderMcpTomlBlock`, since the existing `renderMcpBlock`
     produces YAML-shaped output) rather than writing a parallel command.
   - Set `model_reasoning_effort` per agent once the tier-mapping decision
     (§2 row 6) is made.

`main()`'s `--target=` dispatch (`bin/cli.js:906-914`) gains a third branch;
the error message's "(supported: claude, cursor)" becomes "(supported:
claude, cursor, codex)".

## 10. Degradations (loud, matching §2 of the original spec) — and what's actually better

Carried over from the Cursor precedent, same reasoning:

- **§2A per-agent tool allowlist → `sandbox_mode` only.** `read-only` /
  `workspace-write` preserves "reviewer/explorer cannot edit"; finer
  restriction (orchestrator's no-Skill isolation, lead-programmer's precise
  tool set) is instruction-only — *unless* `skills.config` (§2) turns out to
  mechanically restrict the orchestrator's skill surface, which would be a
  genuine improvement worth adopting once confirmed, not assumed.
- **§2B `maxTurns` → soft budget + global `agents.max_threads`/
  `agents.max_depth` (defaults 6/1, §2).**
- **§2C orchestrator-as-main-agent → AGENTS.md routing convention.** No
  config key swaps the root session's identity. Put the routing table in the
  inlined AGENTS.md content (§5); `stop-gate.sh` reads `mainAgent` from
  config (§8) the same way Cursor's does.
- **§6-row-5 reviewer-route-gate's caller-block half → instruction-only**,
  pending §12's live probe. The pending-review dispatch-block half stays
  mechanical (§6).
- **§2E `memory: project` → file convention**, same as Cursor
  (`.codex/memory/<agent>.md`).

What's **not** degraded, unlike Cursor:

- **§2D per-agent MCP scoping — fully preserved** (§1, §4). This is the
  headline reason to build this adapter at all.
- **Per-subagent stable id** (`.agent_id`) may close Cursor's "two concurrent
  same-type subagents share one pending-review flag" limitation (§6) — verify
  it's a real per-instance id, not a repeat of `.agent_type`, before relying
  on it.

## 11. Explicitly out of scope for v1

Same Tier-3 list as the original spec, same reasoning as the Cursor MVP
(`docs/cursor-port-notes.md` "Explicitly dropped"):

- Agent-teams mode (`start-feature-team`, `SendMessage`, shared task list) —
  no `TaskCompleted` event (§6), no shared-task-list primitive. Ship without
  the gear; the sequential orchestrator flow already delivers "done = reviewer
  PASS."
- `session-start.sh` (baseline-sha + version-drift + digest re-injection) —
  Codex's clean `SessionStart` + `PreCompact`/`PostCompact` events make this
  an easy *follow-up* port, not a v1 blocker; deferred for the same reason
  Cursor deferred it (keep the first pass to the proven five-hook set).
- `reviewed-path-gate.sh` (Bash-tool protected-path advisory) — same
  deferral as Cursor's MVP.
- The optional personas (hivemind, repo-historian, milestone-auditor,
  researcher) — the orchestrator body still routes to them conditionally
  ("if present"), so adding them later needs no edit to the MVP files.
- `AskUserQuestion`-style structured prompts — plain-text Open Questions
  relay, same as every other platform.

## 12. Open questions needing a live probe before/during implementation

In priority order — #1 gates the safety-system delivery model, the rest gate
specific hook behaviors:

1. **Does AGENTS.md content actually reach a spawned subagent's context, in
   a real session?** The doc says yes (§2); confirm with a synthetic
   project — put a unique sentinel string in AGENTS.md, spawn a subagent, ask
   it to recite anything unusual in its instructions. Do this *first*; it
   determines how much weight §5's inlined backstop is really carrying.
2. **Do `SubagentStart`/`SubagentStop` payloads expose the calling agent's
   identity anywhere**, distinct from `agent_id`/`agent_type` of the spawned/
   stopped subagent itself? Determines whether §6's reviewer-route-gate
   caller-block half can be mechanical or stays instruction-only.
3. **Is `agent_id` a stable, unique per-spawn-instance identifier** (fixing
   Cursor's concurrent-same-type-subagent limitation), or does it collapse to
   the same value as `agent_type` in practice?
4. **Exact `hooks.json` registration shape** — nested matcher/hooks array
   (Claude-style) or flat command list (Cursor-style)? §6's example is a
   guess; don't ship it unverified.
5. **`marketplace.json` placement** (§7) — sibling to `plugin.json` or under
   a separate `.agents/plugins/` tree? Test `codex plugin marketplace add`
   against both layouts before picking one.
6. **Does `read-only` `sandbox_mode` still permit a Bash-invoked file write**
   (the reviewer's PASS/FAIL marker, §4)? If not, the reviewer needs
   `workspace-write` + instruction-only "never edit code," same fallback
   Cursor documented.
7. **Does `skills.config` express "zero invokable skills" per-agent** (§2)?
   If yes, apply it to the orchestrator as a mechanical upgrade over
   instruction-only §2A/§10.
8. **Canonical `tool_name` values** for edit operations (`apply_patch` per
   one doc example — confirm it's the only one, or enumerate the set)
   feeding `protected-paths.sh`/`graph-update.sh`/`lint-on-edit.sh`'s
   matchers.
9. **Model-tier mapping** (§2 row 6, §4) — product decision: what are the
   intended `model`/`model_reasoning_effort` values for the cheap/explorer
   tier and the judgment/reviewer tier on Codex?

## 13. Validation/testing additions

`tests/validate.sh` gained a Cursor-artifacts section for v0.7.0
(bash-syntax check on hook scripts, JSON-parse on hooks/plugin/marketplace
manifests, frontmatter check on agent files). Add a parallel Codex section:

- TOML parse check on every `adapters/codex/agents/*.toml` (needs a TOML
  parser available to the test script — check what's already a project
  dependency before adding one; `python3 -c "import tomllib"` is stdlib on
  3.11+ and may be sufficient without a new dependency).
- JSON-parse check on `adapters/codex/hooks/hooks.json` and
  `.codex-plugin/{plugin,marketplace}.json`.
- Bash syntax check (`bash -n`) on `adapters/codex/hooks/scripts/*.sh`, same
  as the Cursor section.
- A check that `agents-md-fragment.md` contains the `ANTISLOP:BEGIN`/
  `ANTISLOP:END` markers §5/§9 rely on.

## 14. Implementation checklist (the actual "first pass")

Ordered so each step's output de-risks the next; §12's probes are folded in
at the point they're needed rather than front-loaded, since some need a
scaffolded-but-unfinished project to test against:

1. **Probe #1 and #4 from §12** (AGENTS.md-reaches-subagents; hooks.json
   registration shape) against a throwaway Codex project — these two gate
   whether §5 and §6 need to change shape before any files are written.
2. Write the four agent TOMLs (`adapters/codex/agents/*.toml`) — port the
   persona bodies verbatim from `agents/*.md` (Tier 1, unchanged text) into
   `developer_instructions`, add the inlined protocol-digest backstop (§5),
   set `sandbox_mode`/`model_reasoning_effort` per §4's table.
3. Write `adapters/codex/agents-md-fragment.md` with the full protocol
   content (ported from `templates/persona-protocol.md`, plus a "Codex
   platform notes" section documenting §10's degradations — mirrors
   `adapters/cursor/rules/persona-protocol.mdc`'s closing section).
4. Port the five hook scripts, one at a time, cheapest-payload-risk first:
   `protected-paths.sh` → `stop-gate.sh` → `reviewer-route-gate.sh` →
   `graph-update.sh`/`lint-on-edit.sh`. Each keeps the exact decision logic
   from its Claude/Cursor siblings; only the jq field-extraction preamble
   changes (§6's table). Smoke-test each against synthetic payloads before
   moving to the next, same discipline the Cursor port notes claim
   ("functionally smoke-tested... block/allow, defer/skip escape, WIP
   sentinel, loop guard, pending-flag set/clear").
5. **Probe #5 from §12** (marketplace.json placement) and write
   `.codex-plugin/plugin.json` + `marketplace.json` (§7).
6. Implement `scaffoldCodex` in `bin/cli.js` (§9), including the new
   `upsertMarkedBlock` helper and the TOML-rendering MCP-wiring extension.
   Add the third `--target=` branch.
7. Run the full scaffolder end-to-end into a scratch project (the existing
   `scratch/update-install/` pattern already used for this repo's own
   dogfooding is the right place). Fix whatever the dry run surfaces.
8. **Probe #6 and #2/#3 from §12** (sandbox_mode-blocks-Bash-writes?
   caller-identity? agent_id stability?) against the scratch project with a
   real reviewer run and a real lead-programmer→reviewer spawn attempt.
   Update §10's degradation list to match reality, not assumption.
9. Extend `tests/validate.sh` (§13).
10. Write `docs/codex-port-notes.md` — the retrospective counterpart to
    `docs/cursor-port-notes.md`: what ported cleanly, what's still degraded
    for real (not hypothetically), which §12 questions got resolved vs. are
    still assumptions, and what was explicitly dropped. This is where the
    "resolved vs. still-assumed" table this spec couldn't fill in yet (§2,
    §12) gets its final answers.
11. CHANGELOG entry, version bump, README mention (mirroring the v0.7.0
    entry's shape for the Cursor port).

## 15. Definition of done for v1

Matches the original spec's §5 MVP milestone definition, restated concretely:
a project can run `bin/cli.js --target=codex`, get a working
orchestrator → explorer/lead-programmer → reviewer loop inside Codex CLI,
with (a) all four agent TOMLs registering and spawnable by name, (b) the
five MVP hooks firing and gating correctly (protected-path block, graph/lint
update on edit, pending-review block on both `Stop` and the next
gated-agent `SubagentStart`), (c) the shared protocol content reaching every
subagent (confirmed empirically, not just doc-claimed — §12 #1), and (d) the
Code Review Graph MCP scoped to the explorer alone and confirmed reachable
only from there. `docs/codex-port-notes.md` documents anything on this list
that shipped degraded instead.
