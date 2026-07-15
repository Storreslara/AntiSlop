---
name: install-antislop
description: >
  Adapt the antislop plugin (persona system + hooks + coding-discipline
  skill) to THIS repository. Run once per new project after installing the
  plugin. Covers only what genuinely can't be pre-baked: version check,
  persona selection, third-party skill installs, the Code Review Graph, the
  arXiv MCP for researcher, repo-specific commands/paths, CLAUDE.md wiring,
  settings merge, wiki seeding, and sandboxed hook verification. Resyncing an
  already-adapted project against a newer plugin version (`--update`) is now
  a deterministic script (`bin/cli.js --update`, zero LLM cost, including for
  projects adapted before this existed — it auto-backfills what it needs from
  disk) — this skill is invoked with `--update` only as that script's
  fallback, and even then only for the one specific gap it names, not a full
  re-adapt.
---
<!-- This skill is the entire "ADAPT-PROMPT" that replaces sections 0, 1, 7,
     and 8 of the original monolithic setup prompt. Everything else (the
     personas, the coding-discipline skill, the hooks) ships once via the
     plugin and is never re-authored per project. Read this whole file, then
     do the work; inspect the actual project rather than guessing. When done,
     report what you did and flag anything incomplete. See section 11 for
     when `--update` lands here at all. -->

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
    stale install; `bin/cli.js --update` (falling back to this skill's
    section 11 only if the script itself says so) is the right flow, not a
    fresh run. Tell the user and ask (AskUserQuestion, don't guess) before
    doing anything — do not fall through into a fresh section 1.
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

- `spec-master` + `task-master` — the planning pipeline (spec-master turns an
  ambiguous request into a finalized spec; task-master slices that spec into
  dispatch-ready work for `lead-programmer`/`scribe`). Ask about them as a
  pair — selecting one without the other breaks the handoff between them.
  Skip both only for projects doing purely mechanical/small work with no real
  planning step.
- `scribe` — skip if the project doesn't want a maintained wiki/ADR
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
  (a single small unit of work) or where `spec-master` was also skipped,
  since it audits a plan's premises and there's no plan to audit. Unlike
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

No per-persona text surgery on copied files: optional routes are already
phrased conditionally ("if present, otherwise <fallback>") in
`orchestrator.md`, `lead-programmer.md`, and `commands/start-feature-team.md`
— a plain copy degrades gracefully even when a persona was deselected.

## 3. Third-party skill installs

- **Check both scopes before asking the human to install anything.** Run
  `npx skills@latest ls -g` (global/user-scope, `~/.claude/skills/` —
  installed once, visible to the Skill tool in every project regardless of
  cwd) and, if `.claude/skills/` already exists in this project,
  `npx skills@latest ls` (project-scope) too. Match what's already listed
  against the purposes below by name/description, not by assuming a fixed
  name. Any purpose already covered in EITHER scope is done — record its
  discovered name straight into the substitution map (step further down) and
  skip the install instruction entirely for that purpose. A global install
  satisfies every project; never tell the human to reinstall a purpose
  that's already present at user scope just because this particular project
  hasn't installed it locally. Only the genuinely missing purposes fall
  through to the steps below.
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
    - a "grill/challenge-the-plan" skill (`grill-me`),
    - a "turn work into tracker tickets" skill (`to-tickets` — NOT `to-issues`),
    - a "TDD / red-green-refactor" skill (`tdd`),
    - a "diagnose a bug" skill (`diagnosing-bugs` — NOT `diagnose`),
    - an "improve codebase architecture" skill (`improve-codebase-architecture`),
    - a "turn conversation into a spec" skill (`to-spec`),
    - a "compact the conversation into a handoff doc for a fresh session"
      skill (`handoff`),
    - the `setup-matt-pocock-skills` setup command.
  Select only the ones the selected personas actually use (e.g. skip the
  grill skill entirely if `spec-master` and `milestone-auditor` were both
  deselected — `milestone-auditor` also preloads the grill skill, aimed at
  the plan's assumptions after the fact rather than the request before
  planning; skip the tickets skill if `task-master` was deselected) — and ask
  them to run the command themselves in their own terminal. After they confirm it's done, verify by listing the installed
  skill names yourself (don't take "done" on faith) — this discovered list,
  not the names above, is the authoritative source for the substitution
  below.
- Run `/setup-matt-pocock-skills` once (issue tracker, triage labels, doc
  layout). RECORD which issue tracker was chosen — it goes in
  `.claude/persona-config.json`'s `issueTracker` field and task-master reads
  it via the retrieval contract.
- Registered names are bare (`tdd`, `diagnosing-bugs`, `to-tickets`, …), not
  namespaced under a `mattpocock-skills:` prefix — confirmed against a live
  `npx skills@latest ls -g` output and a working substitution
  (`persona-config.json`'s `mattpocockSkills` map uses `"to-tickets"`, not
  `"mattpocock-skills:to-tickets"`). List `~/.claude/skills/*/SKILL.md` and
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
- **Substitute placeholders**: the copied `spec-master.md`, `task-master.md`,
  `scribe.md`, and `milestone-auditor.md` (if selected) contain
  `<MATTPOCOCK:skill-name>`
  placeholders in their `skills:` frontmatter — replace each with the
  discovered namespaced name for that purpose (this is expected ADAPT
  substitution, not drift). `lead-programmer.md`
  is different: `tdd` and `diagnose` are deliberately NOT in its `skills:`
  frontmatter (they're invoked on demand via the `Skill` tool instead of
  preloaded every spawn, for token efficiency — see its body's "TDD-first"
  bullet), so its `<MATTPOCOCK:tdd>`/`<MATTPOCOCK:diagnose>` placeholders live
  in that body prose instead. Substitute them there the same way.
- **Record every substitution you just made**: as you resolve each
  `<MATTPOCOCK:slot>` placeholder, add a `slot -> resolved name` entry to a
  running map (e.g. `{"grill-me": "grill-me", "to-issues": "to-tickets"}`)
  — record it, step 6's `substitutions` field depends on it.

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
- **Rescope it to the explorer alone, mechanically — do not hand-edit this.**
  Run `node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" --wire-graph-mcp` (npx-scaffolded
  projects: `node <your-clone>/bin/cli.js --wire-graph-mcp`). This reads the
  `code-review-graph` entry the installer just wrote into `.mcp.json`,
  inlines its launch command into the project's copy of `explorer.md`'s
  `mcpServers:` frontmatter, removes the project-wide `.mcp.json` entry so
  only the explorer connects to it, and records `substitutions.graphMcpLaunch`
  in `.claude/persona-config.json` (creating the file with just that field if
  step 6 hasn't run yet — step 6 must MERGE into it, not overwrite it, so
  this survives). Skipping this and doing it by hand risks the exact trap the
  script exists to avoid: `mcpServers` must be a LIST of single-key dicts,
  each with an explicit `type:` — a flattened bare map connects to nothing
  with no error at all.
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
  connection is NOT working — stop and fix it (re-run `--wire-graph-mcp`, or
  check the tool's own `.mcp.json` entry was correct before that) before
  moving on, don't record this step as done. Also confirm in that same check
  that the connection is scoped to the explorer (e.g. another persona's spawn
  does NOT list the graph's MCP tools) and not leaking project-wide.

## 5. arXiv MCP (powers the researcher — only if selected in step 1)

Skip this entire section if `researcher` wasn't selected. Plugin-shipped
agents ignore the `mcpServers` frontmatter field entirely (a Claude Code
plugin security restriction), which is why `researcher.md` isn't shipped as a
plugin agent at all — it only lives as a template.

- Find a maintained arXiv MCP server (don't guess) and register it in this
  project's `.mcp.json` — via its own docs' recommended path (`claude mcp
  add`, a manual entry, whatever it says) — so its launch command lives
  there, discoverable the same way the graph's does in step 4.
- Copy `templates/researcher.md.tmpl` from the plugin into this project's
  `.claude/agents/researcher.md`, version-stamped like step 2. Do this
  BEFORE the wiring step below — it inlines into an existing file, it
  doesn't create one.
- **Wire the launch command in, mechanically — do not hand-edit this.** Run
  `node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" --wire-arxiv-mcp=<server-key>`
  (the key you registered it under in `.mcp.json`; npx-scaffolded projects:
  `node <your-clone>/bin/cli.js --wire-arxiv-mcp=<server-key>`). Same
  mechanics as step 4's `--wire-graph-mcp`: inlines the launch command into
  `researcher.md`'s `mcpServers:` frontmatter, removes the project-wide
  `.mcp.json` entry, and records `substitutions.arxivMcpLaunch` in
  `persona-config.json` (creating it with just that field if step 6 hasn't
  run yet — step 6 must merge into it, not overwrite it). Hand-editing risks
  the same flattening trap step 4 warns about.
- Verify with the same provenance-self-report requirement as step 4 (fallback
  here = WebFetch/WebSearch); a fallback report means the MCP is NOT wired —
  fix before moving on.
- If no working arXiv MCP can be found: there's nothing to wire, so skip the
  script above entirely. Remove the `mcpServers:` field by hand instead —
  its `tools:` list already includes `WebFetch`/`WebSearch` for a real
  fallback — and add, immediately after the closing `---` of the
  frontmatter, the exact line `<!-- No working arXiv MCP found at ADAPT
  time — operating in WebFetch/WebSearch fallback mode. -->` (this fixed
  wording, not a paraphrase, is what `bin/cli.js --update` looks for to
  regenerate this file deterministically), and say so in your report. Record
  `substitutions.arxivMcpLaunch` as `null` in step 6.

## 6. Repo-specific config → `.claude/persona-config.json`

**If `.claude/persona-config.json` already exists at this point**, it was
created by step 4 and/or 5's `--wire-graph-mcp`/`--wire-arxiv-mcp` (they run
before this step and record `substitutions` into whatever partial file is
there). Read it and MERGE the fields below into it — do not overwrite the
file wholesale, or you'll silently drop the `substitutions` those steps just
recorded.

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
- `substitutions` — the `mattpocockSkills` map (step 3), `graphMcpLaunch`
  (step 4, `null` if the graph wasn't wired), and `arxivMcpLaunch` (step 5,
  `null` if researcher wasn't selected or no working MCP was found). This is
  what makes `bin/cli.js --update` possible — a fresh install without this
  field forces every future update for the project onto the slow LLM path.
- `fileHashes` — **compute this last, after every other file in steps 2-5 has
  its final substituted content on disk.** For each version-stamped file
  (every copied `.claude/agents/*.md`, plus `.claude/persona-protocol.md` and
  `.claude/protocol-digest.md` from step 7 — so this sub-step actually can't
  run until step 7's copies exist either; do it once at the very end of
  ADAPT, not literally inside step 6's file write), compute the sha256 of its
  content with the version-stamp comment line (`<!-- antislop vX.Y.Z | ...
  -->`) stripped out, keyed by project-relative path (e.g.
  `.claude/agents/spec-master.md`). This is the "known-clean" baseline
  `bin/cli.js --update` diffs future runs against to detect local edits
  without an LLM.

Validate the file against `templates/persona-config.schema.json` (a `jq`
check that every required key is present and typed correctly) before moving
on — don't write it freehand and hope. This validation checks shape, not
behavior — it does NOT replace the "run testAndLintCommand once" check
above; a schema-valid config can still contain a command that red-gates on
turn one.

## 6.5 Project constitution (opt-in)

Ask via `AskUserQuestion` whether this project wants a constitution — a
short, versioned set of project-specific principles that `spec-master` checks
plans against and `reviewer`/`milestone-auditor` cite when flagging
violations. Skipping is a plain "no" (this is additive, not a safety
property like step 1's reviewer confirmation).

If yes:
- Elicit 3-7 principles from the user, seeding suggestions from an actual
  scan of this repo (existing test setup, docs, dependency posture) — never
  from a canned list.
- Write `.claude/constitution.md` at Version 1.0.0, in this exact shape:

```
# Project constitution
Version: 1.0.0 | Ratified: YYYY-MM-DD | Last amended: YYYY-MM-DD

## Principles
### 1. <Short name> (MUST | SHOULD)
<1-3 sentences: the rule and why this project holds it.>

## Amendment log
- 1.0.0 (YYYY-MM-DD): ratified.
```

- Ask whether to add `.claude/constitution.md` to `protectedPaths` in
  `.claude/persona-config.json` (recommended — it makes constitution edits
  require explicit human approval via the existing protected-paths hook, no
  new hook needed).

This file is project-authored content, NOT a plugin template copy: no
version-stamp comment, no `fileHashes` entry, never touched by
`bin/cli.js --update`, no schema change to `persona-config.schema.json`.
Presence on disk is the only switch — the persona files' references to it
are already conditional ("if `.claude/constitution.md` exists"), so a
project that skips this section degrades gracefully. Step 12's report
states "constitution created (vX)" or "constitution skipped".

**Versioning** (amendments made later, outside ADAPT — deliberately lighter
than propagating template changes): semver bumped by whoever edits the
file — MAJOR for a principle removed/redefined incompatibly, MINOR for one
added/materially expanded, PATCH for wording/typo clarification. Every
amendment appends one Amendment-log line ending with a short "worth a
look:" list of files a human might want to re-check (typically open plans
in `docs/plans/` and in-flight tracker issues) — that list is surfaced to a
human; nothing acts on it automatically.

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

- If `scribe` was selected: populate its starter wiki
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
  conditional below), and skip the scribe-turn sub-bullet if
  `scribe` wasn't selected.
- **Delegate whatever remains to a subagent**: spawn one general-purpose
  subagent with the repo path, the throwaway-branch instruction, a pointer to
  read `skills/install-antislop/hook-verification.md` for the exact probe
  script (moved out of this file so it's never loaded here — only the
  delegated subagent needs it), the exact sub-bullets that apply (from the
  conditional scoping above), and the instruction to end with the repo clean
  and all sentinels/markers removed. Ask it to return ONLY a pass/fail line
  per sub-bullet plus confirmation the branch was reverted — not the raw hook
  stderr, jq dumps, or intermediate file contents. That raw output is what
  makes this section expensive; it doesn't need to live in your context, only
  the verdict does.

## 11. `--update` mode — run the script FIRST, always

**Your first action, before reading or doing anything else described in this
section, is to run:**

    node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" --update

(npx-scaffolded projects: `node <your-clone>/bin/cli.js --update`.) Do this
even if you already believe you know why you were invoked with `--update` —
`bin/cli.js` now auto-backfills legacy `substitutions`/`fileHashes` entries
from whatever's already on disk (zero LLM cost) and only fails on a genuinely
narrow, specific gap it prints by name. There is no longer a broad
"this project predates the deterministic path" case that needs a human/LLM
to re-derive every file by hand — do not attempt that re-derivation yourself
under any circumstances; it is the exact expensive path this mechanism exists
to eliminate.

Check the exit code, exactly as `commands/update-antislop.md` describes:

- **0** — done (already current, or update complete, possibly after an
  auto-backfill note). Relay its printed summary verbatim and STOP. Nothing
  else in this section applies.
- **2** — files diverged from a fresh copy; diffs are already printed. Ask
  the user accept/keep per file (`commands/update-antislop.md` has the exact
  re-run flags) and STOP once resolved.
- **1**, "no persona-config.json found" — this project was never adapted;
  tell the user to invoke this skill WITHOUT `--update` instead. STOP.
- **1**, a specific file/slot named as unresolvable — read
  `skills/install-antislop/update-fallback.md` now and follow it exactly. This
  is the ONLY remaining case that needs judgment, and it's scoped to the
  one or two items the script named, not a full re-derivation.

## 12. Report back

**Before writing any of the report below, run the placeholder sweep and
confirm zero matches.** This is mandatory on every run — fresh install AND
`--update`:

    grep -rEn '<[A-Z0-9_]+(:[a-zA-Z0-9_-]+)?>' .claude/agents/ .claude/persona-protocol.md .claude/protocol-digest.md

(This is the canonical "placeholder sweep" referenced by step 3b and section
0.5.) Any match is a HARD FAILURE: an unresolved `<MATTPOCOCK:*>`,
`<REAL_LAUNCH_COMMAND_FROM_INSTALL_ANTISLOP_STEP_*>`, or any other `<...>` slot
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
