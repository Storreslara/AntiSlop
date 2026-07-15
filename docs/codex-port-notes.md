# AntiSlop → Codex CLI port notes (v0.8.0, MVP)

Scope: implements `docs/specs/codex-plugin.md` in full - the always-on
subagent-orchestrator loop (orchestrator + explorer + lead-programmer +
reviewer), the five MVP hooks, the shared protocol inlined into AGENTS.md,
plugin packaging, and `bin/cli.js --target=codex` scaffolding. Mirrors
`docs/cursor-port-notes.md`'s role for the Cursor port: this is the
retrospective "what actually happened" counterpart to the forward-looking
spec.

**No `codex` CLI was available in the sandbox this port was built in** (`which
codex` found nothing). Every finding below that would normally come from a
live probe (spec §12) instead comes from either (a) live-fetching
`learn.chatgpt.com/docs/*` on 2026-07-14, or (b) synthetic-payload testing of
the hook scripts and the scaffolder against throwaway git repos - real shell
execution, real TOML/JSON parsing, but never a real Codex session. Treat
everything marked UNVERIFIED below as exactly that until someone runs this
against a live Codex build.

## Layout choice

Same self-contained single-tree choice the Cursor port made, for the same
reason (spec §3): a shared `agents/*.body.md` + per-platform-wrapper refactor
(spec's original §4) is deferred again. Two platforms' hand-ported copies now
exist (Cursor, Codex); the drift risk that refactor removes is now real
rather than hypothetical, and it should be the next piece of work considered
after this port, not before it.

```
adapters/codex/
  .codex-plugin/{plugin.json,marketplace.json}
  agents/{orchestrator,explorer,lead-programmer,reviewer}.toml
  agents-md-fragment.md
  hooks/hooks.json
  hooks/scripts/*.sh
```

## What ported cleanly

- **All persona body prose**, ported into each TOML's `developer_instructions`
  as a literal (`'''...'''`) multi-line string, not a basic one - the bodies
  contain backslash sequences inside shell/printf examples (`\n` in the
  reviewer's marker-write command) that a TOML *basic* multi-line string would
  have silently reinterpreted as escape sequences, corrupting the example.
  Literal strings don't process escapes at all, which is what's wanted here.
- **Per-agent MCP scoping** (the headline reason to build this adapter,
  spec §1) - confirmed live: `mcp_servers` is a documented optional field on
  a custom agent TOML. `explorer.toml` connects to the Code Review Graph
  alone, exactly like the Claude version and unlike Cursor's forced
  project-wide fallback.
- **The `hooks.json` registration shape turned out to be the SAME nested
  `{matcher?, hooks:[{type,command}]}` shape Claude uses**, not Cursor's
  flatter `{command}` list (confirmed live via a targeted second fetch of
  `learn.chatgpt.com/docs/hooks` asking for the literal JSON example - the
  first, broader fetch hadn't surfaced this). This meant `hooks/hooks.json`
  (Claude's) was a much closer template than `adapters/cursor/hooks/hooks.json`
  was, for this one file.
- **Plugin manifest location**: `.codex-plugin/plugin.json`, confirmed live
  (mirrors `.claude-plugin/`/`.cursor-plugin/` naming exactly).
- **`@import` is confirmed NOT supported** in AGENTS.md - this was a genuine
  unknown in the original spec, now resolved: the protocol content must be
  (and is) physically inlined, never referenced.
- **All 32 synthetic-payload tests pass** against the five hook scripts:
  block/allow on both a simple `tool_input.file_path` key and a parsed
  `apply_patch` header fallback, the defer:/skip: escape hatches, WIP
  sentinel (both a genuine reason and an empty/ignored one), the
  pending-review flag's full lifecycle (create -> block -> clear), the
  reviewer-route-gate's dispatch-block half, and the self-tracked loop guard
  tripping after 5 consecutive blocks.
- **The full scaffolder round-trip** (`--target=codex` fresh install,
  `--overwrite` rerun, `--wire-graph-mcp --target=codex`) was run end-to-end
  against throwaway git repos, not just unit-tested in isolation - see "Bugs
  found and fixed during this port" below for what that caught.

## Resolved vs. still-assumed (spec §12, final status this pass)

| # | Question | Status after this pass |
|---|---|---|
| 1 | Does AGENTS.md reach subagents? | **Doc-stated yes, empirically UNVERIFIED.** Codex's own subagents doc states custom agents "automatically inherit applicable AGENTS.md and project instructions" - stronger than what Cursor's docs gave that port - but no live session was available to confirm it. Mitigated the same way Cursor's port was: every persona TOML also inlines the load-bearing protocol digest directly in `developer_instructions`, so the safety-critical rules reach every subagent even if the AGENTS.md channel turns out not to cascade in practice. **First thing to check against a real build**, per spec §12 #1. |
| 2 | Calling-agent identity on SubagentStart/SubagentStop? | **Still unresolved.** Confirmed fields are `agent_id`/`agent_type` for the subagent itself; no field was found describing the *parent* distinctly. `reviewer-route-gate.sh`'s "lead-programmer must not spawn the reviewer directly" half ships instruction-only, same degradation Cursor shipped for the same reason. The dispatch-block half (blocking the next gated unit while one awaits review) is mechanical regardless and was exercised in the synthetic tests. |
| 3 | Is `agent_id` a stable per-instance id? | **Unverified**, but the port is written to benefit if it is: `stop-gate.sh` keys the pending-review flag and WIP sentinel off `agent_id` (falling back to `agent_type` then `session_id`), which - if `agent_id` really is per-spawn-instance - fixes the Cursor port's known "two concurrent same-type subagents share one flag" limitation outright. If it turns out to just repeat `agent_type`, behavior degrades gracefully back to Cursor's limitation, not a hard failure. |
| 4 | Exact `hooks.json` registration shape? | **RESOLVED.** Nested `{matcher?, hooks:[{type,command}]}`, confirmed live (see "What ported cleanly" above) - same shape as Claude's, not Cursor's flat list. |
| 5 | `marketplace.json` placement? | **Still unresolved.** Shipped sibling to `plugin.json` (`.codex-plugin/marketplace.json`), matching the Claude/Cursor precedent, over the alternative the build-plugins doc also described (`.agents/plugins/marketplace.json`, a separate tree). Untested against a real `codex plugin marketplace add` - do this before relying on the packaging step. |
| 6 | Does `read-only` sandbox_mode block a Bash-invoked file write? | **Not left as an open question - decided.** Unlike Cursor (an IDE tool-availability gate, genuinely ambiguous), Codex's `sandbox_mode` is a real OS-level sandbox; `read-only` almost certainly blocks the reviewer's Bash `printf > .codex/reviewed/<id>.pass` marker write outright. `reviewer.toml` therefore ships `sandbox_mode = "workspace-write"` with "never edit the code under review" as an instruction-only rule, not `read-only` - see the port note in that file for the full reasoning. Still worth confirming against a real build, but this isn't a coin flip the way the analogous Cursor question was. |
| 7 | Does `skills.config` express "zero invokable skills" per-agent? | **Not investigated this pass** - noted in the spec as a possible upgrade over the orchestrator's instruction-only no-Skill isolation, not pursued given the MVP's time budget. Worth a follow-up. |
| 8 | Canonical `tool_name` values for edit operations? | **Partially addressed, not resolved.** No live confirmation of the exact set. `protected-paths.sh`/`graph-update.sh`/`lint-on-edit.sh` all self-filter on a case-insensitive substring match (`*apply*patch*`, `*edit*`, `*write*`, etc.) rather than an exact name, and additionally parse OpenAI's documented `apply_patch` header format (`*** Add/Update/Delete File: <path>`) as a fallback when no single-file `tool_input` key is present - this is the single biggest structural difference from the Claude/Cursor ports, whose edit tools are one-file-per-call. Verified against synthetic payloads of both shapes (see "What ported cleanly"), not a real `apply_patch` invocation. |
| — | Loop-guard field (`stop_hook_active`/`loop_count` equivalent)? | **No new question, but a NEW self-implemented workaround** wasn't in the original spec's list at all: no common/turn-scoped payload field was found that plays this role for Codex. `stop-gate.sh` implements its own per-session consecutive-block counter (`.codex/.stop-loop-guard.<session_id>`), capped at 5, forcing an ALLOW past that point rather than looping forever. Verified via a synthetic 5-iteration test. If Codex turns out to expose its own re-trigger signal, prefer that over this workaround. |

## Degradations (loud, per spec §2/§10)

Same shape as the Cursor port's degradation list, restated for Codex:

- **Per-tool allowlist beyond `sandbox_mode`**: none exists. The
  orchestrator's no-Skill isolation and the lead-programmer's precise tool
  set are instruction-only (`sandbox_mode` only distinguishes
  read-only/workspace-write/danger-full-access, nothing finer).
- **`maxTurns` caps**: soft documented budgets only, leaning on
  `agents.max_threads`/`agents.max_depth` (confirmed defaults: 6 and 1)
  as the global, not per-agent, backstop.
- **Orchestrator-as-main-agent**: no config.toml key swaps the root session's
  identity. Carried as a strong convention via the AGENTS.md-inlined routing
  table plus `persona-config.json`'s `mainAgent` field (which `stop-gate.sh`
  reads to know which name is "the main session" for gating purposes) -
  same mechanism Cursor's port uses for the identical gap.
- **`memory: project`**: file convention at `.codex/memory/<agent>.md`, same
  as Cursor - no auto-grant, no cross-agent isolation.
- **reviewer-route-gate's caller-block half**: instruction-only (§12 #2).

## Explicitly dropped for v1 (spec §11)

- Agent-teams mode (`SendMessage`, shared task list) - no such primitive.
- The `TaskCompleted`/task-gate mechanism - confirmed no `TaskCompleted`
  event exists in Codex's hook event list.
- `session-start.sh` (baseline-sha/version-drift/digest re-injection) and
  `reviewed-path-gate.sh` (Bash-tool protected-path advisory) - deferred
  past the MVP's five-hook set, same as the Cursor port deferred them.
- The optional personas (hivemind, scribe, milestone-auditor,
  researcher) - the orchestrator body still routes to them conditionally
  ("if present"), so adding them later needs no edit to the MVP files.
- `AskUserQuestion`-style structured prompts - plain-text relay.
- **Deterministic `--update` support for the Codex target** - not
  implemented, matching the Cursor port's own scope (it also shipped
  scaffold + `--overwrite` only, no `--update` integration). A plain
  `--overwrite` re-copies the pristine source TOMLs, which resets any
  previously-wired MCP launch command back to the placeholder - this is
  consistent with how the Claude target's own bare `--overwrite` behaves
  today (only `--update`'s `renderCleanBody` path re-substitutes), not a
  new Codex-specific gap.

## Bugs found and fixed during this port (both caught by the end-to-end scaffold test, not by unit tests in isolation)

Both were in `applyMcpTomlPlaceholder`/`renderMcpTomlBlock` (the new
TOML-rendering MCP-wiring path in `bin/cli.js`), surfaced only once
`--wire-graph-mcp --target=codex` was actually run against a scaffolded
project rather than reasoned about on paper:

1. **A prose comment containing the literal text `[mcp_servers.code-review-graph]`
   (explaining TOML key-ordering in `explorer.toml`) matched the naive regex
   before the real table header did**, and the non-greedy span between that
   false match and the real header swallowed the ENTIRE
   `developer_instructions` field, deleting the persona's whole body on
   substitution. Fixed by anchoring the match to an actual line start
   (`(^|\n)\[mcp_servers\.code-review-graph\]`) instead of a bare substring
   search, and, as defense in depth, rewording the comment in `explorer.toml`
   to never spell out the literal bracket syntax in prose at all.
2. **The fix for bug 1 initially used the regex `m` (multiline) flag together
   with a `$` end anchor** - under `m`, `$` matches end-of-*line*, not
   end-of-string, so the lazy quantifier satisfied the lookahead immediately
   after the header line itself, leaving the placeholder's `command`/`args`
   lines behind. Those orphaned lines then got silently absorbed into the
   *newly inserted* `[mcp_servers.code-review-graph.env]` sub-table by
   TOML's own key-into-most-recent-table rule on the next parse - a second
   corruption, structurally different from the first, that only showed up
   once the fixed-for-bug-1 code was run against a real launch command that
   included an `env` block. Fixed by dropping the `m` flag and anchoring the
   opening bracket with `(^|\n)` instead, so `$` unambiguously means true
   end-of-string.

Both are now called out inline in `bin/cli.js`'s `applyMcpTomlPlaceholder`
comment so a future edit doesn't reintroduce either failure mode. Lesson for
any future TOML-block-replacement logic in this repo: verify with an actual
round-trip parse of the *result*, not just a syntax check that the regex
compiles - both bugs produced syntactically valid TOML that parsed "successfully"
into subtly wrong data (a missing field, or a value nested one table too
deep) rather than throwing.

## Unverified assumptions (do not treat as confirmed)

- The exact set of `tool_name` values Codex's edit-capable tools report
  (spec §12 #8, table above).
- Whether `sandbox_mode = "read-only"` blocks Bash-invoked filesystem writes
  outright (§12 #6 above) - decided against rather than left open, but still
  worth a live check.
- `marketplace.json`'s placement (§12 #5).
- Whether `agent_id` is genuinely a stable per-spawn-instance identifier
  (§12 #3).
- Whether a Codex-native loop-guard-equivalent field exists that should
  replace the self-tracked counter in `stop-gate.sh`.
