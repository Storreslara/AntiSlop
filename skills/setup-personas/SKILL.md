---
name: setup-personas
description: >
  Adapt the seb-personas plugin (persona system + hooks + coding-discipline
  skill) to THIS repository, or resync an already-adapted project against a
  newer plugin version with `--update`. Run once per new project after
  installing the plugin. Covers only what genuinely can't be pre-baked:
  version check, persona selection, third-party skill installs, the Code
  Review Graph, the arXiv MCP for researcher, repo-specific commands/paths,
  CLAUDE.md wiring, settings merge, wiki seeding, and sandboxed hook
  verification.
---
<!-- This skill is the entire "ADAPT-PROMPT" that replaces sections 0, 1, 7,
     and 8 of the original monolithic setup prompt. Everything else (the
     personas, the coding-discipline skill, the hooks) ships once via the
     plugin and is never re-authored per project. Read this whole file, then
     do the work; inspect the actual project rather than guessing. When done,
     report what you did and flag anything incomplete.

     If invoked as `/seb-personas:setup-personas --update`, skip straight to
     section 11 instead of running sections 0-10 fresh. -->

## 0. Version gate (no FLAT MODE fallback — this plugin targets one baseline)

- Run `claude --version`. Require **v2.1.178+** (nested subagent spawning
  works from v2.1.172, and TeamCreate/TeamDelete were removed in v2.1.178 —
  the `start-feature-team` command assumes automatic cleanup). If the
  installed version is older, STOP and tell the user to upgrade; do not
  attempt a degraded/flat wiring.
- Plugin-provided agents are namespaced (`seb-personas:explorer`, not
  `explorer`) — confirmed on Claude Code 2.1.201, a bare-name spawn
  hard-errors (`Agent type 'explorer' not found`), it does not fall back to
  fuzzy/description-based resolution. This is WHY step 2 below copies every
  selected persona file into the project's `.claude/agents/` as its first
  substantive action — project-scoped agents are never namespaced and always
  override the plugin version. (If a future Claude Code version resolves
  bare names against plugin agents automatically, re-test before skipping
  the copy — don't assume it without checking the installed version.)

## 1. Persona selection

Ask the user which personas this project needs. `orchestrator`, `explorer`,
and `lead-programmer` are mandatory (the minimum viable loop — don't ask
about them). Ask individually about the rest:

- `planner` — skip only for projects doing purely mechanical/small work with
  no real planning step.
- `repo-historian` — skip if the project doesn't want a maintained wiki/ADR
  system.
- `researcher` — skip if the project won't need literature/technique
  research (this one's a template, not a plugin agent — see step 4).
- `reviewer` — **this is the system's core safety property (the
  Writer/Reviewer split).** Skipping it means the lead-programmer's own
  "ready-for-review" report becomes the closest thing to a done-check that
  exists (the orchestrator does a lightweight sanity pass instead of a real
  independent review — see orchestrator.md's "if no reviewer persona exists"
  branch). Require an EXPLICIT typed confirmation before skipping this one,
  not just a yes/no — the risk is materially different from skipping the
  others.

Record the selection as `personaSelection` in `.claude/persona-config.json`
(step 6) — `--update` mode (section 11) reads this to know which files to
re-derive.

## 2. Copy selected personas into the project

Copy every selected persona's `.md` file from the plugin's `agents/`
directory into this project's `.claude/agents/` (always: orchestrator,
explorer, lead-programmer; plus whichever optional ones were selected in
step 1). This is a plain file copy, not re-authoring, so it costs no
meaningful tokens.

**Version-stamp each copied file**: prepend one comment line before the
frontmatter: `<!-- seb-personas vX.Y.Z | source: agents/<file> | ADAPT-substituted -->`,
where X.Y.Z is this plugin's version (read from its `.claude-plugin/plugin.json`).
This is what makes `--update` mode (section 11) possible later — don't skip
it even though it looks like inert metadata.

Do NOT copy `agents/orchestrator.md`'s routing table verbatim if a persona
was deselected — the shipped file already phrases each optional route as
"if present, otherwise <fallback>" conditionally, so a plain copy degrades
gracefully without needing per-project text surgery. Same for
`lead-programmer.md`'s researcher/historian references and
`commands/start-feature-team.md`'s teammate list.

## 3. Third-party skill installs

- `npx skills@latest add mattpocock/skills` — select `grill-me`, `to-issues`,
  `tdd`, `diagnose`, `improve-codebase-architecture`, and
  `setup-matt-pocock-skills`, but only for skills the selected personas
  actually use (e.g. skip `grill-me`/`to-issues` entirely if `planner` was
  deselected).
- Run `/setup-matt-pocock-skills` once (issue tracker, triage labels, doc
  layout). RECORD which issue tracker was chosen — it goes in
  `.claude/persona-config.json`'s `issueTracker` field and the planner reads
  it via the retrieval contract.
- These install as a plugin, so their registered names are namespaced. Check
  the skill list and record the exact names.
- **Substitute placeholders**: the copied `planner.md` and `repo-historian.md`
  contain `<MATTPOCOCK:skill-name>` placeholders in their `skills:`
  frontmatter — replace with the real namespaced names in the project's
  copies (this is expected ADAPT substitution, not drift). `lead-programmer.md`
  is different: `tdd` and `diagnose` are deliberately NOT in its `skills:`
  frontmatter (they're invoked on demand via the `Skill` tool instead of
  preloaded every spawn, for token efficiency — see its body's "TDD-first"
  bullet), so its `<MATTPOCOCK:tdd>`/`<MATTPOCOCK:diagnose>` placeholders live
  in that body prose instead. Substitute them there the same way.

## 4. Code Review Graph (install as a PROJECT skill, never global MCP)

- Get the current install command from the code-review-graph marketplace
  listing (don't guess) and install it as a bare-named project skill into
  `.claude/skills/code-review-graph/` — NOT via `claude mcp add`, NOT with
  `enableAllProjectMcpServers`, and do not reference it from root CLAUDE.md.
  Any of those drifts every persona into exactly the context bloat the
  Explorer-as-a-service design exists to prevent. `explorer.md` as shipped
  assumes the bare name `code-review-graph`; if the real registered name
  differs, correct that one field in the project's copy.
- Build the index once. Identify the incremental-update command and its
  file-argument syntax — this becomes `graphUpdateCommand` in
  `.claude/persona-config.json` (see step 6).
- Add the persistent store (SQLite db / index dir) to `.gitignore` unless you
  deliberately want a shared prebuilt index (if so, commit it and say so in
  your report).
- Confirm it works: spawn the explorer with one real query (e.g. "what calls
  `<some real function in this repo>`") and paste its answer in your report.

## 5. arXiv MCP (powers the researcher — only if selected in step 1)

Skip this entire section if `researcher` wasn't selected. Plugin-shipped
agents ignore the `mcpServers` frontmatter field entirely (a Claude Code
plugin security restriction), which is why `researcher.md` isn't shipped as a
plugin agent at all — it only lives as a template.

- Find a maintained arXiv MCP server's launch command (don't guess).
- Copy `templates/researcher.md.tmpl` from the plugin into this project's
  `.claude/agents/researcher.md`, substituting the real launch command into
  the inline `mcpServers:` field, and version-stamp it like step 2. Inline +
  project-scoped means it connects only when the researcher starts and
  disconnects when it finishes, and actually takes effect.
- Verify it works by having the researcher use it once.
- If no working arXiv MCP can be found: remove the `mcpServers:` field, and
  its `tools:` list already includes `WebFetch`/`WebSearch` for a real
  fallback — note in the file's body that it's operating in that fallback
  mode, and say so in your report.

## 6. Repo-specific config → `.claude/persona-config.json`

Copy `templates/persona-config.schema.json`'s shape and fill in from an
actual scan of this repo (package.json / pyproject.toml / Makefile / etc.),
don't guess:
- `testAndLintCommand` — what the stop-gate hook runs; must be a single
  command with a meaningful non-zero exit code.
- `lintCommand` — formatter/linter invoked per-file by the lint-on-edit hook.
- `graphUpdateCommand` — from step 4.
- `sourceGlobs` — project-root-relative patterns worth graph-indexing (empty
  = index everything edited).
- `protectedPaths` — real protected paths in THIS repo, project-root-relative
  (migrations, generated code, lockfiles — detect them, don't assume a
  generic list; the hook normalizes the tool's absolute path against
  `CLAUDE_PROJECT_DIR` before matching, so relative patterns here are
  correct, not a mistake).
- `gatedAgents` — leave as the default `["lead-programmer"]` unless this
  project has another code-writing persona that should also be stop-gated.
- `issueTracker` — from step 3.
- `personaSelection` — from step 1.
- `pluginVersion` — this plugin's current version (same value used for the
  file stamps in step 2).

Validate the file against `templates/persona-config.schema.json` (a `jq`
check that every required key is present and typed correctly) before moving
on — don't write it freehand and hope.

## 7. CLAUDE.md wiring

- Run `/init` first if no CLAUDE.md exists, then prune hard — apply "would
  removing this line cause Claude to make a mistake?" to every line that
  survives. If one exists, append/trim, don't overwrite.
- Copy `templates/persona-protocol.md` from the plugin into this project's
  `.claude/persona-protocol.md` verbatim (it's role-agnostic; nothing to
  fill in) and version-stamp it like step 2.
- Copy `templates/protocol-digest.md` verbatim into this project's
  `.claude/protocol-digest.md` and version-stamp it the same way. This is
  what `session-start.sh` re-injects on `resume`/`compact` — don't skip it,
  the hook silently no-ops without it (no error, just no re-anchor).
- Add exactly one line to CLAUDE.md: `@.claude/persona-protocol.md` — this is
  the only channel that reaches both subagents and agent-teams teammates
  automatically, which is why the shared protocol lives here instead of being
  duplicated into every persona body.
- Do NOT duplicate the orchestrator's routing table here — `settings.json`
  already makes it the main agent (step 8), so a routing table in CLAUDE.md
  would just ship dead weight into every persona's context.

## 8. settings.json merge (MERGE, never clobber)

Merge `templates/settings-fragment.json` into this project's
`.claude/settings.json`, replacing its two placeholder permission entries
with this repo's real test/build/lint/git commands plus the graph's
incremental-update command, so permission prompts don't constantly interrupt.
Note in your report: the default teammate model has no reliable settings key
— that's a manual `/config` step for the user.

## 9. Wiki / CONTEXT / ADR seeding, directory scaffolding, and .gitignore

- If `repo-historian` was selected: populate its starter wiki
  (`.claude/wiki/`), a starter `CONTEXT.md`, and a `docs/adr/` layout from an
  actual scan of this repo — spawn the `explorer` for the structural facts
  rather than crawling yourself.
- `mkdir -p .claude/reviewed` once now, regardless of whether `reviewer` was
  selected — this is what makes the reviewer's PASS-marker `touch` succeed on
  the very first agent-teams run instead of erroring on a missing directory.
- Append to this project's `.gitignore`: `.claude/reviewed/`,
  `.claude/wip-handoff.*`, `.claude/.session-baseline.*`, and
  `.claude/wip-audit.log` — none of these should be committed (the audit log
  is a growing local operational record, not project documentation).

## 10. Hook verification (sandboxed — do not leave the repo red or trap yourself)

On a throwaway branch:
- Make a trivial edit; confirm `graph-update.sh` and `lint-on-edit.sh` fired
  (check the graph index timestamp / lint output).
- Confirm the stop-gate does **NOT** block a trivial explorer or
  repo-historian turn even with a dirty tree — proof that `gatedAgents`
  scoping (read from `persona-config.json`, not hardcoded in `hooks.json`) is
  working and won't strangle the cheap, high-frequency personas.
- Introduce a failing check, end a lead-programmer-style turn, confirm
  BLOCK; `touch .claude/wip-handoff.<agent-id>` (empty, no reason), confirm
  it is REJECTED (deleted, but the BLOCK still fires) — this proves the
  empty-sentinel bypass is actually closed, not just documented as closed.
  Then `echo "test reason" > .claude/wip-handoff.<agent-id>`, confirm ALLOW,
  the sentinel is deleted, and the reason appears as a new line in
  `.claude/wip-audit.log`.
- Pipe a synthetic `{"session_id":"test","source":"resume"}` into
  `session-start.sh` directly (real compaction/resume isn't reliably
  triggerable inside a sandboxed verification run) and confirm the output
  JSON's `additionalContext` contains `.claude/protocol-digest.md`'s content.
  Repeat with `"source":"startup"` and confirm additionalContext is empty
  (no version drift, no digest) — the digest must NOT appear on a fresh
  start, only resume/compact.
- Test the protected-paths hook with a dry write against one of the
  configured `protectedPaths` patterns; confirm BLOCK with the human-approval
  message (this specifically re-verifies the path-anchoring fix — a pattern
  like `supabase/migrations/*` must now actually match the tool's absolute
  file path).
- If `reviewer` was selected: run one task named `impl:*` through to a
  reviewer PASS in agent-teams mode and confirm the completion marker write
  succeeds (no "No such file or directory" error) thanks to step 9's `mkdir`.
- Pipe a synthetic `{"agent_type":"lead-programmer","tool_input":{"subagent_type":"reviewer"}}`
  into `reviewer-route-gate.sh` directly and confirm BLOCK; repeat with
  `subagent_type":"explorer"` and with `"agent_type":"orchestrator"` (target
  `reviewer`) and confirm both ALLOW — proves the gate only fires for the
  specific lead-programmer→reviewer pair, not every Agent-tool call.
- Revert the branch completely. Your final turn must end with the repo clean
  and all sentinels/markers removed.

## 11. `--update` mode (re-run after a plugin version bump)

Invoked as `/seb-personas:setup-personas --update`. Purpose: the copy in
section 2 is what makes bare-name persona references work, but it also means
persona-body bug fixes in a newer plugin version never reach an
already-adapted project on their own — hooks/skills/commands propagate
automatically via `${CLAUDE_PLUGIN_ROOT}`, but the copied agent files and
`persona-protocol.md` don't.

- Read this project's `persona-config.json` (`personaSelection`,
  `pluginVersion`) and the plugin's current `plugin.json` version. If they
  match, report "already current" and stop.
- For each version-stamped file in `.claude/agents/`,
  `.claude/persona-protocol.md`, and `.claude/protocol-digest.md`: re-derive
  what a fresh copy at the CURRENT plugin version would look like,
  re-applying the same deterministic substitutions recorded in
  `persona-config.json` (mattpocock skill names, graph skill name, persona
  selection, any model-tier edit you can detect was intentional vs. a stale
  stamp).
- If the project's actual file is byte-identical to that re-derivation,
  overwrite it and bump its stamp — safe, no local customization existed
  beyond the recorded substitutions.
- If it differs (real local edits — a model-tier downgrade, a hand-tuned
  routing line, anything not explained by the recorded substitutions), show
  the diff and ask before overwriting. Never silently clobber a local edit.
- Update `pluginVersion` in `persona-config.json` to the current version once
  done. Does NOT re-run sections 3-9 (no re-installing mattpocock skills, no
  rebuilding the graph index, no re-seeding the wiki) — only the copy/
  substitution logic.

## 12. Report back

State: the Claude Code version confirmed; which personas were selected
(and, if `reviewer` was skipped, that the explicit confirmation was
obtained); the exact mattpocock skill names and issue tracker chosen; the
code-review-graph registered name and one real structural query + answer as
proof; the arXiv MCP result (server name, or fallback mode, or "researcher
not selected"); the one manual `/config` step required (default teammate
model); each hook-verification result from step 10; confirmation the repo
ended clean.
