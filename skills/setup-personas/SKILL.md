---
name: setup-personas
description: >
  Adapt the antislop plugin (persona system + hooks + coding-discipline
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

     If invoked as `/antislop:setup-personas --update` — or via the
     `/antislop:update-antislop` command, which is just a dedicated entry
     point into this same section for plugin-installed projects — skip
     straight to section 11 instead of running sections 0-10 fresh. -->

## 0. Version gate (no FLAT MODE fallback — this plugin targets one baseline)

- Run `claude --version`. Require **v2.1.178+** (nested subagent spawning
  works from v2.1.172, and TeamCreate/TeamDelete were removed in v2.1.178 —
  the `start-feature-team` command assumes automatic cleanup). If the
  installed version is older, STOP and tell the user to upgrade; do not
  attempt a degraded/flat wiring.
- Plugin-provided agents are namespaced (`antislop:explorer`, not
  `explorer`) — confirmed on Claude Code 2.1.201, a bare-name spawn
  hard-errors (`Agent type 'explorer' not found`), it does not fall back to
  fuzzy/description-based resolution. This is WHY step 2 below copies every
  selected persona file into the project's `.claude/agents/` as its first
  substantive action — project-scoped agents are never namespaced and always
  override the plugin version. (If a future Claude Code version resolves
  bare names against plugin agents automatically, re-test before skipping
  the copy — don't assume it without checking the installed version.)

## 0.5 Existing-config detection (only when NOT invoked with --update)

Skip this section entirely if invoked with `--update` (that path is already
handled — go to section 11). Otherwise, before starting section 1:

- Check whether `.claude/persona-config.json` already exists.
- If it does NOT exist: this is a genuine fresh install — proceed to
  section 1, nothing to do here.
- If it DOES exist: read its `pluginVersion` and compare to this plugin's
  current version (`.claude-plugin/plugin.json`).
  - If `pluginVersion` is OLDER than the current version: this looks like a
    stale install; `--update` (section 11) is the right flow, not a fresh
    run. Tell the user and ask (AskUserQuestion, don't guess) before doing
    anything — do not fall through into a fresh section 1.
  - If `pluginVersion` MATCHES the current version: this is very likely a
    leftover partial/uncommitted run, not a genuine fresh install. Ask the
    user (AskUserQuestion — this is a first-class step now, not an ad hoc
    disambiguation) which of these they want:
    1. **Resume** — inspect which outputs already exist
       (`.claude/agents/*.md`, `.claude/persona-protocol.md`,
       `.claude/protocol-digest.md`, `.claude/settings.json`,
       `.claude/persona-config.json`) to infer how far the prior run got,
       and continue from the first incomplete section.
    2. **Patch gaps only** — run the step 12 placeholder sweep now, then
       re-run only the sections whose output is missing or still contains
       unresolved placeholders.
    3. **Full restart** — re-run sections 1-10 from scratch, overwriting.
  - Never silently clobber or ignore an existing config; always ask first.

## 1. Persona selection

Ask the user which personas this project needs. `orchestrator`, `explorer`,
and `lead-programmer` are mandatory (the minimum viable loop — don't ask
about them). Ask individually about the rest:

- `hivemind` — skip only for projects doing purely mechanical/small work with
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
- `milestone-auditor` — skip for projects with no real milestone structure
  (a single small unit of work) or where `hivemind` was also skipped, since
  it audits a plan's premises and there's no plan to audit. Unlike
  `reviewer`, this one checks the SPEC against reality, not code against the
  spec — it's a second, orthogonal safety property, not a duplicate of the
  reviewer, so don't let a "we already have reviewer" answer talk the user
  out of it if the project has real milestones.

Record the selection as `personaSelection` in `.claude/persona-config.json`
(step 6) — `--update` mode (section 11) reads this to know which files to
re-derive.

## 2. Copy selected personas into the project

Copy every selected persona's `.md` file from the plugin's `agents/`
directory into this project's `.claude/agents/` (always: orchestrator,
explorer, lead-programmer; plus whichever optional ones were selected in
step 1). This is a plain file copy, not re-authoring, so it costs no
meaningful tokens.

**Version-stamp each copied file**: insert one comment line immediately
*after* the closing `---` of the frontmatter (never before the opening
`---` — confirmed on a live probe that Claude Code's subagent discovery
requires the file to start with the frontmatter delimiter as its very first
bytes; a leading comment silently breaks discovery, the agent never
registers as an invocable type, no error at copy time):
`<!-- antislop vX.Y.Z | source: agents/<file> | ADAPT-substituted -->`,
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

- **`npx skills@latest add mattpocock/skills` opens an interactive
  terminal menu (pick skills, pick target agents) — it has no documented
  non-interactive/flag-driven mode.** Do NOT run this yourself via Bash and
  assume a selection; a non-interactive agent shell can't drive a TUI picker
  and the command will hang or silently take defaults, leaving stale
  `<MATTPOCOCK:*>` placeholders in copied persona files with no error
  surfaced. Instead: tell the human which skills to select, BY PURPOSE, and
  let the package's own menu supply the exact registered names (they change
  between package versions — do not treat any name written here as ground
  truth):
    - a "grill/challenge-the-plan" skill (registered as `grill-me` at the
      time of writing — verify on disk),
    - a "turn work into tracker tickets" skill (registered as `to-tickets`
      at the time of writing — NOT `to-issues`; verify on disk),
    - a "TDD / red-green-refactor" skill (registered as `tdd` at the time of
      writing — verify on disk),
    - a "diagnose a bug" skill (registered as `diagnosing-bugs` at the time
      of writing — NOT `diagnose`; verify on disk),
    - an "improve codebase architecture" skill (registered as
      `improve-codebase-architecture` at the time of writing — verify on
      disk),
    - the `setup-matt-pocock-skills` setup command.
  Select only the ones the selected personas actually use (e.g. skip the
  grill and tickets skills entirely if `hivemind` and `milestone-auditor`
  were both deselected — `milestone-auditor` also preloads the grill skill,
  aimed at the plan's assumptions after the fact rather than the request
  before planning) — and ask them to run the command themselves in their own
  terminal. After they confirm it's done, verify by listing the installed
  skill names yourself (don't take "done" on faith) — this discovered list,
  not the names above, is the authoritative source for the substitution
  below.
- Run `/setup-matt-pocock-skills` once (issue tracker, triage labels, doc
  layout). RECORD which issue tracker was chosen — it goes in
  `.claude/persona-config.json`'s `issueTracker` field and hivemind reads
  it via the retrieval contract.
- These install as a plugin, so their registered names are namespaced. List
  `.claude/skills/*/SKILL.md` (read each frontmatter `name:` field) and
  record the exact discovered names. This recorded list is the ONLY source
  for the substitution values below — resolve each `<MATTPOCOCK:*>` from a
  discovered `name:`, never by copying a name written in this skill's prose
  (those are illustrative and go stale). Match by PURPOSE: the placeholder
  label after the colon (e.g. `<MATTPOCOCK:to-issues>`,
  `<MATTPOCOCK:diagnose>`) is a slot marker in the shipped file, not
  necessarily the current registered name — e.g. resolve the "tickets" slot
  to the discovered `to-tickets`, and the "diagnose" slot to the discovered
  `diagnosing-bugs`. If a purpose has no matching discovered skill, STOP and
  surface it to the human — do not substitute a guessed name.
- **Substitute placeholders**: the copied `hivemind.md`, `repo-historian.md`,
  and `milestone-auditor.md` (if selected) contain `<MATTPOCOCK:skill-name>`
  placeholders in their `skills:` frontmatter — replace each with the
  discovered namespaced name for that purpose (this is expected ADAPT
  substitution, not drift). `lead-programmer.md`
  is different: `tdd` and `diagnose` are deliberately NOT in its `skills:`
  frontmatter (they're invoked on demand via the `Skill` tool instead of
  preloaded every spawn, for token efficiency — see its body's "TDD-first"
  bullet), so its `<MATTPOCOCK:tdd>`/`<MATTPOCOCK:diagnose>` placeholders live
  in that body prose instead. Substitute them there the same way.

### 3b. Fail-fast placeholder check (mattpocock scope)

Immediately after the substitution above, run the canonical placeholder
sweep from step 12, scoped to the agents directory:

    grep -rEn '<MATTPOCOCK(:[a-zA-Z0-9_-]+)?>' .claude/agents/

Any match is a HARD FAILURE — a placeholder is still unresolved. Fix it (or
surface an unresolvable one to the human) before doing any work in sections
4-12; catching it here avoids paying for the rest of the flow on a broken
substitution. (Step 12's full sweep is the final backstop across all
placeholder kinds; this is the early, mattpocock-only tripwire.)

## 4. Code Review Graph (MCP server, scoped to explorer alone — never project-wide)

The Code Review Graph (github.com/tirth8205/code-review-graph) installs
itself as a pip/pipx package whose own `install` command is NOT a plain
skill installer — check its current docs before running anything (its
integration has changed shape before; don't assume this section stays
accurate forever):
- `pipx install code-review-graph` (or `pip install`, per its current docs).
- `code-review-graph install --platform claude-code` — this auto-writes a
  PROJECT-WIDE `.mcp.json` MCP server entry (every persona would inherit it
  by default) AND generates `.claude/skills/code-review-graph/` containing
  build-graph/review-delta/review-pr WORKFLOW skills (slash commands, not an
  ad-hoc query interface).
- **Do not leave the project-wide `.mcp.json` entry in place.** Extract that
  MCP server's launch command (`uv run`/`uvx`/`poetry run`, whatever the tool
  emitted) and inline it into the project's copy of `explorer.md`'s
  `mcpServers:` frontmatter instead (replacing the
  `<REAL_LAUNCH_COMMAND_FROM_SETUP_PERSONAS_STEP_4>` placeholder with
  `command:`/`args:` lines at the SAME indentation as the placeholder,
  nested under the existing `type: stdio` line — do not flatten
  `mcpServers:` back into a bare map keyed by server name; Claude Code
  requires a LIST of single-key dicts here, each with an explicit `type:`,
  and the flattened form connects to nothing with no error at all) — the
  same scoping trick used for the researcher's arXiv MCP in step 5. Then
  remove or empty out the tool's project-wide `.mcp.json` registration so
  only the explorer (not every persona) connects to it. This is the whole
  point of this section: skipping this step silently reintroduces the
  context-bloat problem the Explorer-as-a-service design exists to prevent.
- The generated `.claude/skills/code-review-graph/*` workflow skills
  (build-graph/review-delta/review-pr) are legitimate and can stay — they're
  just not what the explorer calls; leave them for the user/other personas to
  invoke directly if wanted, and don't wire them into `explorer.md`.
- Build the index once (`code-review-graph build` or equivalent — check the
  tool's current CLI). Identify the incremental-update command and its
  file-argument syntax — this becomes `graphUpdateCommand` in
  `.claude/persona-config.json` (see step 6).
- Add the persistent store (SQLite db / index dir) to `.gitignore` unless you
  deliberately want a shared prebuilt index (if so, commit it and say so in
  your report).
- Confirm it works: spawn the explorer with one real query (e.g. "what calls
  `<some real function in this repo>`") and paste its answer in your report.
  **A correct-looking answer is not sufficient proof** — grep alone can
  answer a simple structural query on a small/medium repo even with the MCP
  server completely disconnected, and a schema error in `mcpServers:`
  produces no visible error anywhere (see `explorer.md`'s own comment on
  this). Explicitly instruct the explorer to self-report provenance
  (graph-derived vs. grep-derived — its body already has a fallback rule
  that does this if asked) and require that self-report, not just a
  plausible answer, in your report. If it reports grep-derived, the MCP
  connection is NOT working — stop and fix the `mcpServers:` schema/launch
  command before moving on, don't record this step as done. Also confirm in
  that same check that the connection is scoped to the explorer (e.g.
  another persona's spawn does NOT list the graph's MCP tools) and not
  leaking project-wide.

## 5. arXiv MCP (powers the researcher — only if selected in step 1)

Skip this entire section if `researcher` wasn't selected. Plugin-shipped
agents ignore the `mcpServers` frontmatter field entirely (a Claude Code
plugin security restriction), which is why `researcher.md` isn't shipped as a
plugin agent at all — it only lives as a template.

- Find a maintained arXiv MCP server's launch command (don't guess).
- Copy `templates/researcher.md.tmpl` from the plugin into this project's
  `.claude/agents/researcher.md`, substituting the real launch command into
  the inline `mcpServers:` field (the `command:`/`args:` lines nested under
  the existing `type: stdio` line, at the placeholder's indentation — do
  NOT flatten `mcpServers:` back into a bare map keyed by server name;
  Claude Code requires a LIST of single-key dicts here, each with an
  explicit `type:`, and the flattened form connects to nothing with no
  error at all), and version-stamp it like step 2. Inline + project-scoped
  means it connects only when the researcher starts and disconnects when it
  finishes, and actually takes effect.
- Verify it works by having the researcher use it once, and **explicitly
  require it to self-report provenance** (arXiv-MCP-derived vs. a
  WebFetch/WebSearch fallback) in its answer — a plausible-looking answer is
  not sufficient proof the MCP connection is live; a schema error here
  produces no visible failure and the researcher's `WebFetch`/`WebSearch`
  tools can silently cover for a disconnected MCP server. If it reports the
  fallback path, the connection is NOT working — fix it before moving on.
- If no working arXiv MCP can be found: remove the `mcpServers:` field, and
  its `tools:` list already includes `WebFetch`/`WebSearch` for a real
  fallback — note in the file's body that it's operating in that fallback
  mode, and say so in your report.

## 6. Repo-specific config → `.claude/persona-config.json`

Copy `templates/persona-config.schema.json`'s shape and fill in from an
actual scan of this repo (package.json / pyproject.toml / Makefile / etc.),
don't guess:
- `testAndLintCommand` — what the stop-gate hook runs; must be a single
  command with a meaningful non-zero exit code. **Do not assume a documented
  command currently passes — verify it before it becomes a gate.** After
  composing it, run it once against the current clean tree:
  - If it exits 0: write it as-is.
  - If it exits non-zero: this command would permanently red-gate every
    gated-agent turn end (the stop-gate can't distinguish pre-existing debt
    from a new regression). Do NOT silently bake in a perpetually-red gate.
    Surface the failing command and its output to the human and let THEM
    choose (AskUserQuestion — don't decide unilaterally, it's a judgment
    call about the project's tolerance for pre-existing debt):
    (a) exclude the failing sub-command from the composed string, and
        record the exclusion + reason in the step 12 report; or
    (b) include it anyway, accepting the gate will BLOCK until the
        pre-existing failure is fixed.
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
on — don't write it freehand and hope. This validation checks shape, not
behavior — it does NOT replace the "run testAndLintCommand once" check
above; a schema-valid config can still contain a command that red-gates on
turn one.

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
  selected — this is what makes the reviewer's v2 PASS-marker `printf`
  succeed on the very first run instead of erroring on a missing directory.
- Append to this project's `.gitignore`: `.claude/reviewed/`,
  `.claude/wip-handoff.*`, `.claude/.session-baseline.*`,
  `.claude/wip-audit.log`, `.claude/.pending-review.*`, and
  `.claude/review-audit.log` — none of these should be committed (the audit
  logs are a growing local operational record, not project documentation).

## 10. Hook verification (sandboxed — do not leave the repo red or trap yourself)

**Run this section conditionally, and delegate the actual probing to a
subagent — don't run it inline in your own context.**

- **Fresh install** (no prior `persona-config.json`): always run the full
  suite below.
- **`--update` runs** (section 11): skip this section entirely UNLESS one of
  the following is true, in which case run only the sub-bullets that test
  the changed surface, not the whole suite:
  - `gatedAgents` or `protectedPaths` changed in this run's
    `persona-config.json` compared to the previous version → re-run the
    stop-gate and protected-paths sub-bullets only.
  - The plugin version bump's CHANGELOG (or a diff of the hook scripts
    themselves, if accessible) indicates a hooks.json/hook-script fix →
    re-run only the sub-bullets covering the changed hook.
  - Neither is true → skip section 10 outright and report "hooks/gating
    unchanged since last verified install, skipped re-verification."
- **Scope even a fresh-install run to selected personas**: e.g. skip the
  reviewer PASS-marker sub-bullet if `reviewer` wasn't selected (already
  conditional below), and skip the repo-historian-turn sub-bullet if
  `repo-historian` wasn't selected.
- **Delegate whatever remains to a subagent**: spawn one general-purpose
  subagent with the repo path, the throwaway-branch instruction, the exact
  sub-bullets that apply (from the conditional scoping above), and the
  instruction to end with the repo clean and all sentinels/markers removed.
  Ask it to return ONLY a pass/fail line per sub-bullet plus confirmation the
  branch was reverted — not the raw hook stderr, jq dumps, or intermediate
  file contents. That raw output is what makes this section expensive; it
  doesn't need to live in your context, only the verdict does.

On a throwaway branch:
- Make a trivial edit; confirm `graph-update.sh` and `lint-on-edit.sh` fired
  (check the graph index timestamp / lint output).
- Confirm the stop-gate does **NOT** block a trivial explorer or
  repo-historian turn even with a dirty tree — proof that `gatedAgents`
  scoping (read from `persona-config.json`, not hardcoded in `hooks.json`) is
  working and won't strangle the cheap, high-frequency personas.
  Additionally confirm the stop-gate does NOT block a trivial main-session
  (orchestrator) Stop even with a dirty tree from an in-flight subagent —
  this is the regression test for the main-session allowlist; pipe a
  synthetic `{"hook_event_name":"Stop","session_id":"test"}` into the hook
  with a dirty tree and a default config and confirm exit 0.
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
- **PASS marker v2 (`task-gate.sh`)**: `touch .claude/reviewed/test.pass`
  (bare, empty) then pipe `{"task":{"subject":"impl:test","id":"test"}}` into
  `task-gate.sh` and confirm BLOCK (exit 2) naming the required `printf`
  format and the `--update` remedy; then write a valid first line —
  `printf 'PASS test %s criteria: <cmd>\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > .claude/reviewed/test.pass`
  — and confirm ALLOW plus a new `marker-accepted` line in
  `.claude/review-audit.log` — proves the existence-only check is gone.
- **Pending-review flag (`stop-gate.sh`)**: pipe a synthetic
  `{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","agent_id":"test"}`
  and confirm `.claude/.pending-review.test` is created; then pipe
  `{"hook_event_name":"Stop","session_id":"test"}` and confirm BLOCK
  ("awaiting review"); then pipe a reviewer `SubagentStop`
  (`"agent_type":"reviewer"`) and confirm the flag is gone and
  `cleared-by=reviewer` appears in `.claude/review-audit.log`. Also confirm
  the `defer: <reason>`/`skip: <reason>` escape hatch: overwriting the flag
  with `defer: ...` allows that one Stop and keeps the flag; `skip: ...`
  allows it and deletes the flag; both log to `.claude/review-audit.log`.
- **Pending-review dispatch block (`reviewer-route-gate.sh`)**: with a
  `.claude/.pending-review.*` flag present, pipe
  `{"agent_type":"","tool_input":{"subagent_type":"lead-programmer"}}` and
  confirm BLOCK; repeat with `"subagent_type":"reviewer"` and confirm
  ALLOW — proves the next gated-agent dispatch is blocked while a unit
  awaits review, without blocking the reviewer dispatch itself.
- Revert the branch completely. Your final turn must end with the repo clean
  and all sentinels/markers removed.

## 11. `--update` mode (re-run after a plugin version bump)

Invoked as `/antislop:setup-personas --update`, or as `/antislop:update-antislop`
(same flow, dedicated command — plugin-installed projects only; npx-scaffolded
projects don't get project-local commands, so `--update` on the bare
`/setup-personas` skill remains the only path there). Purpose: the copy in
section 2 is what makes bare-name persona references work, but it also means
persona-body bug fixes in a newer plugin version never reach an
already-adapted project on their own — hooks/skills/commands propagate
automatically via `${CLAUDE_PLUGIN_ROOT}`, but the copied agent files and
`persona-protocol.md` don't.

- Read this project's `persona-config.json` (`personaSelection`,
  `pluginVersion`) and the plugin's current `plugin.json` version. If they
  match, report "already current" and stop.
- **Legacy `planner` → `hivemind` migration**: if the project's
  `personaSelection` contains the legacy token `planner` (the persona was
  renamed `hivemind` in plugin v0.6.0): rename/re-derive the legacy file
  `.claude/agents/planner.md` (legacy) as `.claude/agents/hivemind.md` at the
  current version, delete the old legacy file, rewrite `personaSelection` replacing
  the legacy `planner` token with `hivemind`, and say so in the report.
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

**Before writing any of the report below, run the placeholder sweep and
confirm zero matches.** This is mandatory on every run — fresh install AND
`--update`:

    grep -rEn '<[A-Z0-9_]+(:[a-zA-Z0-9_-]+)?>' .claude/agents/ .claude/persona-protocol.md .claude/protocol-digest.md

(This is the canonical "placeholder sweep" referenced by step 3b and section
0.5.) Any match is a HARD FAILURE: an unresolved `<MATTPOCOCK:*>`,
`<REAL_LAUNCH_COMMAND_FROM_SETUP_PERSONAS_STEP_*>`, or any other `<...>` slot
means the adapt is not done. Do NOT report success until every match is
either resolved by substituting the real value, or — if it genuinely can't
be resolved — explicitly called out to the human as an unresolved gap (same
"don't guess, surface it" rule used elsewhere in this skill). Never report
"done" with a live placeholder still on disk.

State: the Claude Code version confirmed; which personas were selected
(and, if `reviewer` was skipped, that the explicit confirmation was
obtained); the exact mattpocock skill names and issue tracker chosen; the
code-review-graph registered name and one real structural query + answer as
proof; the arXiv MCP result (server name, or fallback mode, or "researcher
not selected"); the one manual `/config` step required (default teammate
model); each hook-verification result from step 10 (or, if step 10 was
skipped per its conditional rules, say so and why); confirmation the repo
ended clean.
