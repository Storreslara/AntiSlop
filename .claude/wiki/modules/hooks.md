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
| `reviewed-path-gate.sh` | PreToolUse (Bash \| Write\|Edit) | Two matchers, one script: on Bash, allows a command mentioning `.claude/reviewed` only if it's provably read-only or text-only (an allowlist), blocking write-intent commands; on Write\|Edit, blocks any write to the path outright. Both defer to the caller's `agent_type` (`reviewer`, or the main session only in the no-reviewer fallback). Hit live during this repo's own ADAPT — see [ADR 0002](../../docs/adr/0002-reviewed-dir-owned-by-reviewer.md). |
| `reviewer-route-gate.sh` | PreToolUse (Agent) | Mechanically enforces "lead-programmer never spawns/messages reviewer directly"; also blocks dispatching the next gated unit while an earlier one awaits review. |
| `session-start.sh` | SessionStart | Records session-start HEAD sha for `stop-gate.sh`; drift-checks `persona-config.json`'s stamped `pluginVersion` vs. the installed plugin version; re-injects `protocol-digest.md` as additionalContext on resume/compact only. |
| `stop-gate.sh` | Stop + SubagentStop | Core "done = reviewer PASS" enforcement — checks commits/PASS markers before allowing a gated agent (`persona-config.json`'s `gatedAgents`, default `["lead-programmer"]`) to stop. |
| `task-gate.sh` | TaskCompleted | Agent-teams-mode equivalent of stop-gate: requires a reviewer PASS marker before completing any `impl:*` task; planning/research/doc tasks pass through ungated. |

## Sticky `defer:` semantics and the audit-log dedupe (issue #190, F3)

`stop-gate.sh`'s pending-review flag (`.claude/.pending-review.<agent-id>`)
accepts two contents from a persona confirming a unit is under review:
`defer: <reason>` or `skip: <reason>`. **A `defer:` is sticky, not
one-shot**: writing it once persists on the flag and permits turn-end
(`Stop`) on **every** subsequent turn — not just the one that wrote it —
until either the reviewer's own `SubagentStop` clears the flag or a
`skip:` deletes it. This was **always** the implemented behaviour; prior
documentation (in `templates/persona-protocol.md`, this repo's own
`stop-gate.sh` comments, and both adapter ports) claimed the opposite —
"that one Stop allowed, review still owed next turn" — and was corrected
in place rather than the code being changed to match the stale prose.

**Why this is safe to leave sticky:** the strong guard lives in
`reviewer-route-gate.sh`, which blocks dispatching the next gated unit on
the pending-review flag's **existence alone** — it never reads the flag's
content, so a `defer:` cannot unblock it. "No next implementation unit
until the reviewer runs" is untouched by the sticky semantics; only the
weaker per-turn nag (which the orchestrator was needlessly re-satisfying
every turn while a background reviewer ran) is relaxed. The orchestrator's
convention as of this pass: write `defer: reviewer dispatched (agent <id>),
awaiting verdict` once, at the moment it dispatches the reviewer in the
background — not on every subsequent turn.

**Audit-log dedupe:** `stop-gate.sh` used to append the flag's content to
`.claude/review-audit.log` on every `Stop`, so a sticky defer produced one
duplicate log line per turn (this is what misled the original efficiency
audit — "5 identical defers in 21 minutes" was one write plus five
turn-ends, not five separate decisions). `stop-gate.sh` now appends a
`defer:` line only when it differs from the immediately preceding log
line (compared after the timestamp field). **Not deduped** — these remain
one line per event, always: the `skip:` branch, `cleared-by=reviewer`, and
`verdict=blocked flags-kept`. A `defer:` that changes reason, or one
separated from an identical earlier line by any other line (e.g. a
`cleared-by=reviewer` in between), is still logged — only *consecutive
identical* `defer:` lines are suppressed.

## Measured reviewer tier: `reviewer-tier.sh` is not a hook

`hooks/scripts/reviewer-tier.sh` lives alongside the registered hook
scripts above but is **deliberately absent from `hooks/hooks.json`** — it
is an orchestrator-invoked helper (`reviewer-tier.sh <task-id> <git-range>`
→ prints `sonnet` or `opus`), not a lifecycle hook. It lives under
`hooks/scripts/` only so `tests/validate.sh`'s bash-syntax sweep covers it
automatically. See the glossary entry in [CONTEXT.md](../../CONTEXT.md)
and [ADR 0009](../../docs/adr/0009-reviewer-tier-measured-eligibility.md)
for what it decides and why.

## Config-driven, not hardcoded
Every gate reads `.claude/persona-config.json` at runtime (via `jq`) — the
same hook scripts are generic across every ADAPTed project;
project-specific behavior (which paths are protected, which agents are
gated, whether a reviewer even exists) comes entirely from that file.
