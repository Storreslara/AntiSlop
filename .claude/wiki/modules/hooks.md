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
line (compared after the timestamp field). The fix (2026-08-01) handles
multi-line reasons correctly: flag content is flattened to a single logical
line (newlines and CRs become spaces) before both the comparison and the
write, ensuring the dedupe works for reasons containing `\n`. **Not
deduped** — these remain one line per event, always: the `skip:` branch,
`cleared-by=reviewer`, and `verdict=blocked flags-kept`. A `defer:` that
changes reason, or one separated from an identical earlier line by any
other line (e.g. a `cleared-by=reviewer` in between), is still logged —
only *consecutive identical* `defer:` lines are suppressed.

**Empty-reason rejection (2026-08-01):** Flag content of exactly `defer: `
or `skip: ` (with no text after the colon) is now rejected — `stop-gate.sh`
exits 2, writes no audit record, and for `skip: ` does not delete the flag.
This operationalizes an Amendment A1 ruling after the pending-review
flag's `defer: `/`skip: ` branch was observed accepting such content
despite the hook's own "Empty reason rejected." block message. The
rejection applies only to empty content after the colon; whitespace-only
reasons (e.g. `defer:  ` with two spaces) remain accepted per WIP-sentinel
precedent (non-empty file is sufficient).

## stop-gate.sh: adapter-port behavioural parity (issue #202)

The two adapter ports (`adapters/codex/hooks/scripts/stop-gate.sh`,
`adapters/cursor/hooks/scripts/stop-gate.sh`) had silently diverged from
the main hook above: neither ported the `defer:`-dedupe fix, so a sticky
`defer:` produced a duplicate audit-log line on every `Stop` in those two
ports even after the main hook was fixed. Nothing in the merge gate could
see this — the existing document-parity check
(`tests/adapter-protocol-parity.test.js`) only verifies that canonical
protocol *sections* are present in the doc ports, not that a script
*behaves* correctly.

`tests/adapter-stop-gate-parity.test.sh` closes that gap and is now
registered in `tests/validate.sh` as its own merge-gate check, alongside
the byte-parity check on `lib/agent-identity.sh` and the document-parity
check above — three distinct parity mechanisms, not one generalized past
what it verifies. It drives all three stop-gate scripts (claude, codex,
cursor) through the same defer-dedupe scenario via each port's own event
name and payload shape, asserting the same audit-log record count and exit
code from each. See [modules/adapters.md](adapters.md)'s "Behavioural
parity guard" section for what the guard covers and what it deliberately
does not.

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

## dispatch-hygiene checks: H1–H4

`dispatch-hygiene.sh` is a PreToolUse gate applied at the Agent/orchestrator
seam, checking dispatch prompts before spawn. Configured via
`.claude/persona-config.json`'s `dispatchHygiene` field (`mode`:
`block`/`warn`/`off`, plus optional overrides `maxPromptBytes`/`maxInlineBlockLines`;
defaults: `block`/30000/80). Single-use escape hatch: `.claude/.dispatch-override`
(content must start with `override: <reason>`). Checks run in sequence:

- **H1 — Oversize prompt** (default 30000 bytes): blocks dispatches where the
  prompt body exceeds the configured byte limit. Fail-closed; a persona
  cannot self-recover from prompt overflow via retries.
- **H2 — Inlined artifact as fenced block** (default 80 interior lines):
  detects markdown fenced code blocks in the dispatch body and blocks if they
  exceed the interior line limit. Intended to catch artifact inlining; a
  fenced block larger than the threshold is presumed an artifact that should
  have been an external artifact instead.
- **H3 — Re-dispatch gate** (best-effort, convention-dependent): fires when
  the dispatch prompt's `Unit:` line (if present) matches a reviewer's marker
  id in `.claude/reviewed/<task-id>.pass`, i.e. when a unit already marked
  done is being re-dispatched. Only fires if the convention `Unit: <id>` is
  reliably followed; read as best-effort protection, not a guaranteed catch,
  until that discipline hardens (documented in issue #153).
- **H4 — Dispatch contract audit** (checks labels, not substance): fires when
  `dispatchHygiene.requireContract` is `true` (default `false`) and the
  dispatch prompt lacks the expected `## Summary` / `## Test plan` / `## STATUS`
  headings recorded in the unit's dispatch template. H4 checks *structure*,
  not content — an agent can emit all headings and fill them with empty
  strings, and H4 passes. The purpose is to detect accidental omissions of
  required framing; it does not validate that the content is complete or
  sensible. When fired, H4 routes to `.claude/.dispatch-override` on first
  failure (allowing a manual override if the structure is intentionally
  nonstandard), then blocks on repeat without override.
