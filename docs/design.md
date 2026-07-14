# Why this shape

Design rationale for AntiSlop, kept out of the agent bodies and out of the
README so first-time setup isn't interrupted by maintainer-facing reasoning.
None of this is required reading to install or use the plugin — see the
[README](../README.md) for that. It's here for contributors, and for anyone
debugging a surprising interaction.

- **CLAUDE.md is the only channel that reaches both subagents and agent-teams
  teammates automatically.** That's why the cross-cutting rules (explorer
  delegation, teams-mode behavior, the WIP sentinel, the retrieval contract,
  machine-checkable criteria, review ownership, the FAIL→fix continuation
  protocol and its 2-FAIL cap) live in one `templates/persona-protocol.md`
  imported via a single CLAUDE.md line, instead of being pasted into every
  persona body. Adding a new persona means one new file — it inherits the
  protocol for free.
- **Plugin agents ignore `mcpServers`, `hooks`, and `permissionMode`
  frontmatter, and plugins can't ship `settings.json` at all.** This is why
  researcher isn't a plugin agent (it's a template copied in project-scoped),
  and why hooks/settings are bundled in the plugin but their *effective*
  config always comes from a project-local file the generic scripts read at
  runtime. `explorer.md` leans on the same fact for its Code Review Graph MCP
  connection: it's shipped as a plugin agent, but setup always copies it into
  `.claude/agents/` anyway (bare-name plugin agents don't resolve — see the
  README's Install section), so its `mcpServers:` frontmatter takes effect on
  the project-scoped copy the same way researcher's does, scoping the graph
  connection to the explorer alone instead of every persona.
- **"Teammates cannot spawn subagents" — an assumption in an earlier draft of
  this system — is false.** The real agent-teams restriction is on nested
  *teams*, not on ordinary subagent spawning. Earlier drafts had every persona
  fall back to Grep/Glob as a teammate out of this false belief; fixed in the
  shared protocol.
- **The stop-gate's `SubagentStop` scoping is config-driven (`gatedAgents` in
  `persona-config.json`), not hardcoded in `hooks.json`.** Confirmed
  empirically that the `SubagentStop` payload carries `agent_type`, so the hook
  itself decides who it applies to. An earlier, hardcoded-matcher version was
  the single most consequential robustness bug found in v0.1.0 — making it
  config-driven means a future code-writing persona is a config edit, not a
  plugin file edit.
- **The reviewer's PASS marker (`.claude/reviewed/<task-id>.pass`) is an
  explicit, named exception to "never edits."** It's Bash-written bookkeeping
  for the `TaskCompleted` hook (agent-teams mode) and the pending-review gate
  (default mode), not a change to reviewed code. Marker format v2: a bare
  `touch` no longer satisfies `task-gate.sh` — the file must be non-empty and
  its first line must read exactly `PASS <task-id> <UTC ISO-8601 timestamp>
  criteria: <acceptance-criteria command(s) run>`, written via `printf`; an
  accepted marker is logged to `.claude/review-audit.log`. This closes the
  bare-`touch`-is-anyone-with-Bash forgery gap the v1 format left open. Setup
  pre-creates the directory so the first-ever marker write doesn't fail on a
  missing path — a real bug found and fixed in v0.2.0. **v2 rollout has a
  two-week legacy-marker grace period**, through 2026-07-27: a project whose
  copied `reviewer.md` still writes the old bare `touch` gets a loud warning
  (and is still allowed to complete) instead of an immediate block, logged to
  `.claude/review-audit.log` as `legacy-marker-grace-period-warning`. On or
  after 2026-07-27, `task-gate.sh` blocks unconditionally — run
  `/antislop:update-antislop` before then. (See the README's
  First-time setup section for the user-facing version of this deadline.)
- **`memory: <scope>` auto-grants Read/Write/Edit for memory management,
  regardless of a persona's declared `tools:` list.** hivemind's "never
  write production code" and researcher's restricted tool list are therefore
  instruction-enforced, not mechanically enforced, for personas with memory.
  Noted once in the shared protocol rather than caveated in every file.
- **Behavioral drift — an agent quietly stops following its own instructions as
  a session runs long — is fought with mechanism where possible, not more prose
  to remember.** `maxTurns` caps (explorer=10, milestone-auditor=20,
  hivemind/reviewer/lead-programmer=30) already bound the highest-drift sessions
  by length; the orchestrator's main session is deliberately uncapped and is
  correspondingly the biggest open drift surface — now *partially* closed by
  the pending-review gate (`stop-gate.sh` sets `.claude/.pending-review.<id>`
  on a gated agent's un-reviewed stop; the reviewer's own stop clears it; while
  it stands, `stop-gate.sh` blocks main-session turn-end and
  `reviewer-route-gate.sh` blocks the next gated-agent dispatch). It is still
  uncapped and can still `rm` the flag via Bash — friction and an audit trail
  in `.claude/review-audit.log`, not a guarantee — so "biggest open drift
  surface" stands, just with its first mechanical backstop. `session-start.sh`
  re-injects a short `.claude/protocol-digest.md` via `additionalContext`, but
  only on `source: resume` and `source: compact` — never `startup`/`clear`,
  where the full protocol is already fresh — because compaction/resume is
  exactly when a long session is likely to have summarized the protocol away.
  This is mechanical *timing* of when the rules reappear, not a bigger dose of
  the same static context. The WIP sentinel got a matching hardening: a bare
  `touch` no longer bypasses the stop-gate — the sentinel must contain a
  reason, which `stop-gate.sh` logs to `.claude/wip-audit.log` before honoring
  it, closing a silent, unauditable escape hatch from the one mechanical gate
  that existed.
- **FLAT MODE (pre-2.1.172 nesting) and the manual TeamCreate/TeamDelete
  cleanup branch (pre-2.1.178) were deleted outright**, not kept as a fallback.
  Maintaining two wiring paths for versions this plugin doesn't support was pure
  complexity with no live use case.
- **Persona opt-out is graceful by construction, not by a wizard alone.** Every
  optional-persona cross-reference is phrased conditionally ("if this project
  has a `researcher`... otherwise..."), so a plain file copy degrades gracefully
  even without per-project text surgery — the wizard in `install-antislop` only
  decides which files get copied, it doesn't need to edit anyone's prose.
- **The copy-vs-plugin-update tension is real, and has a mechanism now.**
  Because bare-name persona resolution requires copying agent files into every
  project, persona-body bug fixes don't propagate automatically the way
  hooks/skills/commands do (those load via `${CLAUDE_PLUGIN_ROOT}` and stay
  live). Version-stamp comments + `--update` mode + the `SessionStart` drift
  check close that gap without needing every user to remember to check manually.
- **`--update` is a deterministic script, not an LLM skill invocation.**
  `bin/cli.js --update` regenerates each version-stamped file directly from
  the plugin's own source plus the `substitutions`/`fileHashes` recorded in
  `persona-config.json` at ADAPT time, so re-syncing a project against a
  newer plugin version costs no meaningful tokens in the common (no local
  edits) case — it only escalates to a human decision (never an LLM one) for
  a file that's genuinely diverged. `install-antislop --update`'s section 11 is
  now that script's one-time fallback, for projects adapted before
  `substitutions`/`fileHashes` existed.
- **`AskUserQuestion` is unavailable to subagents, even if listed in their
  `tools:`** — confirmed against the Claude Code docs, not assumed. This is why
  hivemind returns plain-text "Open Questions" instead of asking
  interactively, and why the *orchestrator* (which runs as the main session,
  not a subagent) is the one that has `AskUserQuestion` in its tools and turns
  those open questions into a real structured prompt when they reduce to
  discrete choices.
- **Known limitations, not silently papered over:** the graph-update and lint
  hooks only read `tool_input.file_path`, so `MultiEdit`'s array form and
  `NotebookEdit` aren't matched. The protected-paths hook only gates the
  `Write`/`Edit` tools — a persona running `sed -i` or a lockfile-rewriting
  package manager command via `Bash` bypasses it. The `reviewed-path-gate.sh`
  hook (PreToolUse/Bash) attributes the caller from the top-level
  `agent_type` field on the payload — confirmed present empirically, see
  `docs/experiments/2026-07-probe-hook-payloads.md` — and blocks any `Bash`
  command whose text merely *contains* the substring `.claude/reviewed`;
  read-only commands (a `cat` of a marker) are collateral, and a determined
  agent can still obfuscate the path past the substring match. All three are
  documented as advisory rather than airtight; tightening any of them is a
  good candidate for a future version bump.
