# AntiSlop → Cursor port notes (v0.7.0, MVP)

Scope: the Cursor half of `docs/specs/codex-cursor-plugin.md` only. The Codex
adapter is deliberately not built here. This delivers the spec's §5 MVP
milestone: the always-on subagent-orchestrator loop (orchestrator + explorer +
lead-programmer + reviewer) with the four MVP hooks, the shared protocol as a
rule, plugin packaging, and `bin/cli.js --target=cursor` scaffolding.

All Cursor artifacts live under `adapters/cursor/` (self-contained) plus the
new `--target=cursor` path in `bin/cli.js`. None of the Claude-only artifacts
(`agents/*.md`, `hooks/`, `.claude-plugin/`, `templates/`, `skills/`) were
modified.

## Layout choice

```
adapters/cursor/
  .cursor-plugin/plugin.json          # Cursor plugin manifest
  .cursor-plugin/marketplace.json     # source "./" -> plugin root = adapters/cursor/
  agents/{orchestrator,explorer,lead-programmer,reviewer}.md
  hooks/hooks.json                    # version:1, camelCase events
  hooks/scripts/*.sh                  # cursor payload preamble + ported logic
  rules/persona-protocol.mdc          # alwaysApply rule
```

I chose a single self-contained `adapters/cursor/` tree (rather than the spec's
fuller §4 multi-platform layout with a shared `agents/*.body.md` split) because
this is a Cursor-only pass. `adapters/cursor/` doubles as both the Cursor plugin
root (`.cursor-plugin/marketplace.json` `source: "./"` resolves the plugin root
to `adapters/cursor/`, mirroring how the Claude `.claude-plugin/` resolves to
the repo root) and the source the scaffolder copies into a project's `.cursor/`.
This keeps it from colliding with the Claude plugin that is rooted at the repo
root. Trade-off: it duplicates the persona bodies and hook logic from the Claude
tree instead of sharing them — see "Duplication-drift" below.

## What ported cleanly (Tier 1 / Tier 2)

- **All persona body prose.** Routing philosophy, the Writer/Reviewer
  discipline, answer shape, blast-radius contract, TDD-first, materiality
  filter, verdict format — ported faithfully; only frontmatter and
  platform-specific mechanics changed.
- **Frontmatter format.** Cursor keeps markdown+YAML frontmatter (like Claude),
  so the fields map directly to `name`/`description`/`model`/`readonly`. The
  version stamp still lands *after* the closing `---` (spec row 73's assumption
  confirmed by the scaffolder's own `insertStampAfterFrontmatter`, reused
  unchanged).
- **Hook decision logic.** The ordered gating logic in every script is the same
  as the Claude version; only a thin Cursor payload-extraction preamble differs
  (project dir from `.workspace_roots[0]`; caller identity `.subagent_type`;
  loop guard `.loop_count`; baseline id `.conversation_id`). All five scripts
  were functionally smoke-tested against synthetic Cursor payloads (block/allow,
  defer/skip escape, WIP sentinel, loop guard, pending-flag set/clear).
- **`persona-config.json`.** Same schema, read by the hooks. One field added:
  `mainAgent` (default `orchestrator`), because Cursor has no `settings.json`
  `"agent"` key for `stop-gate.sh` to read the main-agent name from.
- **`readonly: true`** on the reviewer and explorer — the half of the tool
  restriction that Cursor *can* express mechanically (spec §2A).

## Open questions from spec §6: resolved vs. still-assumed

| # | Question | Status |
|---|---|---|
| 1 | Do alwaysApply rules / AGENTS.md reach **subagents**? | **UNVERIFIED** — both `cursor.com/docs/subagents` and `.../docs/rules` are explicitly silent (fetched and checked). This is the load-bearing assumption. Mitigation below. |
| 4 | Can a Cursor **custom mode** ship inside a plugin? | Not resolved; treated as a manual step. The orchestrator body is shipped as an agent, and the port notes flag that on Cursor it is best run as a user-selected "Orchestrator" mode, not a hard main-agent replacement (spec §2C). |
| 5 | Do hook payloads carry the **calling agent's identity**? | **PARTIALLY RESOLVED.** `subagentStop` carries `subagent_type` (the agent that just stopped) — so `stop-gate.sh`'s gated-agent filtering works. `subagentStart` carries `subagent_type` (the spawn *target*) but **no caller identity** — so `reviewer-route-gate.sh`'s "lead-programmer must not spawn the reviewer" block is not implementable and degrades to instruction-only (see below). |
| 6 | **Model-tier mapping** (haiku/opus → Cursor ids). | Not resolved (product decision). All four agents ship `model: inherit`; the reviewer/explorer bodies note that opus/cheap-tier ids should be filled in once chosen. This loses the cost-tiering guarantee until then. |
| 2 | `@import` support in AGENTS.md. | N/A for Cursor — the protocol is delivered as an alwaysApply rule, not an import. |
| 3 | Codex namespacing. | Codex-only, out of scope. |
| 7 | Is hooks.json mergeable without clobber? | **RESOLVED yes** — `.cursor/hooks.json` is plain JSON; the scaffolder does a dedupe-aware per-event merge (idempotent across re-runs; preserves user-added hook entries — verified). |

## The load-bearing assumption (open q #1) and the mitigation I chose

The spec calls rule-cascade-into-subagents "the single load-bearing assumption"
that "gates the whole port." I could not confirm it: the Cursor subagents and
rules docs do not state that rules or AGENTS.md reach subagents.

Decision: **belt-and-suspenders.** I ship the full protocol as the alwaysApply
rule (`rules/persona-protocol.mdc`, the row-12 deliverable) **and** inline the
load-bearing invariants — review ownership, structural-questions-to-explorer,
FAIL cap, WIP sentinel, answer shape — into each subagent body under a clearly
labelled "Shared protocol essentials (inlined backstop)" section.

Rationale: the protocol *is* the safety system. Relying on an unverified channel
to deliver it would be exactly the silent degradation AntiSlop forbids
(`agents/orchestrator.md:63`). If the rule does cascade, the inlined digest is
redundant but harmless; if it does not, the safety-critical rules still reach
every subagent. I inlined the *digest* (the essentials), not the full ~180-line
protocol, to keep the duplication cost bounded — this mirrors the repo's
existing `templates/protocol-digest.md` concept (a condensed re-injection
artifact), so it is a precedent, not an invention. The alternative (rule-only)
was rejected as too risky; the alternative (full-protocol inlined 4×) was
rejected as needless bloat given the digest carries the load-bearing subset.

## Degradations (loud, per spec §2)

- **§2A per-agent tool allowlist → `readonly` only.** Reviewer/explorer
  `readonly: true` preserves "cannot edit." Everything finer — the
  orchestrator's no-Write/no-Skill isolation, the lead-programmer's precise tool
  set — is instruction-only. Stated in-band in each affected body and in the
  rule's "Cursor platform notes."
  - **One unverified sub-assumption:** the reviewer keeps `readonly: true` and
    still writes its PASS/FAIL marker via Bash `printf`. This assumes Cursor's
    `readonly` restricts the file-editing tools but permits Bash. If `readonly`
    also blocks Bash file writes, the marker write fails — the fallback is to set
    the reviewer `readonly: false` and rely on instruction-only "never edit
    code." The review gate itself is resilient either way: the pending-review
    flag clears on the reviewer *having run* (PASS or FAIL), independent of the
    marker.
- **§2A/§6-q5 reviewer-route-gate half is instruction-only.** `subagentStart`
  exposes the spawn target but not the caller, so the hook cannot distinguish a
  lead-programmer spawn of the reviewer from a legitimate orchestrator one. The
  hook still mechanically enforces the *other* half — blocking the next
  gated-agent dispatch while a completed unit awaits review. The direct-spawn
  ban is now prose in the reviewer/lead-programmer bodies and the rule. (Cursor's
  one-level subagent nesting likely makes a subagent-spawns-subagent path
  impossible anyway, but the port does not rely on that.)
- **§2B maxTurns → soft budget.** No per-agent turn cap on Cursor; the old
  numeric caps become documented soft targets, leaning on the 2-FAIL cap and
  "scale effort to the task."
- **§2D per-agent MCP scoping → project-wide.** Cursor subagents inherit all
  parent MCP tools, so the Code Review Graph MCP must be registered project-wide
  in `.cursor/mcp.json`. This reintroduces the context-bloat the
  explorer-as-a-service design avoids; the least-bad mitigation (instruct every
  non-explorer persona to route structural questions to the explorer anyway) is
  carried by the rule + inlined digest.
- **§2E `memory: project` → file convention.** Emulated by
  `.cursor/memory/lead-programmer.md` the persona reads/appends; loses the
  auto-grant and cross-agent isolation.
- **§2C orchestrator-as-main-agent → convention/mode.** No `settings.json`
  `"agent"` key on Cursor; the orchestrator is best a user-selected custom mode,
  not a forced default. `stop-gate.sh` reads `mainAgent` from persona-config to
  know which name to treat as the main agent.

## Explicitly dropped (spec Tier 3 / §2F)

- **Agent-teams mode** (`start-feature-team`, `SendMessage`, shared task list) —
  no Cursor equivalent; dropped entirely for v1 rather than half-emulated. The
  reviewer PASS flow still works via the orchestrator's sequential single-owner
  routing.
- **The `TaskCompleted` / task-gate mechanism** — no such event on Cursor; the
  default-mode pending-review gate (`stop-gate.sh` + `reviewer-route-gate.sh`)
  is the equivalent enforcement.
- **`AskUserQuestion` structured prompts** — Open Questions relay as plain text.
- The optional personas (hivemind, scribe, milestone-auditor,
  researcher) are **not ported in this MVP pass** — the orchestrator body still
  routes to them conditionally ("if present") so adding them later needs no edit
  here.

## Duplication-drift risk (deliberate, per task scope)

This pass does **not** do the spec §4 shared-body refactor (splitting
`agents/*.md` into `*.body.md` + per-platform wrappers, and hooks into a shared
`lib/` + per-platform preambles). So the Cursor persona bodies and hook decision
logic are hand-ported copies of the Claude ones. If the Claude reviewer's
adversarial instructions change, the Cursor copy must be updated by hand — a
drift risk the §4 architecture would remove once the Codex adapter also exists
and makes the shared-body split worth its build-step cost.

## Unverified field names (do not treat as confirmed)

The following came from `cursor.com/docs/hooks` but the exact per-tool shapes
were not empirically exercised against a live Cursor build:

- The **edit tool's name and its `tool_input` file-path key** on `preToolUse`.
  `protected-paths.sh` self-filters to write-ish tool names and tries several
  candidate keys (`file_path`/`path`/`target_file`/`filePath`) defensively.
- Whether Cursor **resolves hook-command paths relative to the workspace root**
  (the scaffolded `hooks.json` uses `.cursor/hooks/scripts/…`). The scripts
  themselves are robust to cwd because they derive the project dir from
  `.workspace_roots[0]` in the payload, but the command path in `hooks.json`
  must still resolve.
- The exact env var (if any) for a Cursor **plugin root**; the bundled
  `hooks.json` uses `${CURSOR_PLUGIN_ROOT}` by analogy with Claude's
  `${CLAUDE_PLUGIN_ROOT}` and the scaffolder rewrites it away for project
  installs.
