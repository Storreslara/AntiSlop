# hooks/

`hooks/hooks.json` wires Claude Code lifecycle events to
`hooks/scripts/*.sh`. Ships as a plugin file (auto-active once the plugin
is enabled — unlike `settings.json`, which plugins cannot ship, hence the
separate merge-in-project-settings step for `agent`/`env`/`permissions`).
All scripts reference `${CLAUDE_PLUGIN_ROOT}` so they run from the
installed plugin location, not a per-project copy (that copying only
happens on the npx/non-plugin scaffold path).

| Script | Event | Purpose |
| --- | --- | --- |
| `graph-update.sh` | PostToolUse (Edit\|Write) | Incremental Code Review Graph update on the changed file; no-ops if graph isn't installed. Known gap: only reads `tool_input.file_path`, misses MultiEdit's array form / NotebookEdit. |
| `lint-on-edit.sh` | PostToolUse (Edit\|Write) | Runs the project's configured formatter/linter (`persona-config.json`'s `lintCommand`) on the changed file only; no-ops if unconfigured. |
| `protected-paths.sh` | PreToolUse (Write\|Edit) | Blocks writes to configured `protectedPaths` (migrations, lockfiles, this repo's `.claude-plugin/*` etc.) pending human approval. Advisory only — covers Write/Edit, not Bash (`sed -i` bypasses it). |
| `reviewed-path-gate.sh` | PreToolUse (Bash) | Blocks Bash commands whose text touches `.claude/reviewed` unless the caller's `agent_type` is `reviewer` (or the main session, only in the no-reviewer fallback). Hit live during this repo's own ADAPT — see [ADR 0002](../../docs/adr/0002-reviewed-dir-owned-by-reviewer.md). |
| `reviewer-route-gate.sh` | PreToolUse (Agent) | Mechanically enforces "lead-programmer never spawns/messages reviewer directly"; also blocks dispatching the next gated unit while an earlier one awaits review. |
| `session-start.sh` | SessionStart | Records session-start HEAD sha for `stop-gate.sh`; drift-checks `persona-config.json`'s stamped `pluginVersion` vs. the installed plugin version; re-injects `protocol-digest.md` as additionalContext on resume/compact only. |
| `stop-gate.sh` | Stop + SubagentStop | Core "done = reviewer PASS" enforcement — checks commits/PASS markers before allowing a gated agent (`persona-config.json`'s `gatedAgents`, default `["lead-programmer"]`) to stop. |
| `task-gate.sh` | TaskCompleted | Agent-teams-mode equivalent of stop-gate: requires a reviewer PASS marker before completing any `impl:*` task; planning/research/doc tasks pass through ungated. |

## Config-driven, not hardcoded
Every gate reads `.claude/persona-config.json` at runtime (via `jq`) — the
same hook scripts are generic across every ADAPTed project;
project-specific behavior (which paths are protected, which agents are
gated, whether a reviewer even exists) comes entirely from that file.
