---
name: setup-personas
description: >
  Adapt the seb-personas plugin (6 shipped agents + hooks + coding-discipline
  skill) to THIS repository. Run once per new project after installing the
  plugin. Covers only what genuinely can't be pre-baked: version check, third-
  party skill installs, the Code Review Graph, the arXiv MCP for researcher,
  repo-specific commands/paths, CLAUDE.md wiring, settings merge, wiki seeding,
  and sandboxed hook verification.
---
<!-- This skill is the entire "ADAPT-PROMPT" that replaces sections 0, 1, 7,
     and 8 of the original monolithic setup prompt. Everything else (the 6
     personas, the coding-discipline skill, the hooks) ships once via the
     plugin and is never re-authored per project. Read this whole file, then
     do the work; inspect the actual project rather than guessing. When done,
     report what you did and flag anything incomplete. -->

## 0. Version gate (no FLAT MODE fallback — this plugin targets one baseline)

- Run `claude --version`. Require **v2.1.178+** (nested subagent spawning
  works from v2.1.172, and TeamCreate/TeamDelete were removed in v2.1.178 —
  the `start-feature-team` command assumes automatic cleanup). If the
  installed version is older, STOP and tell the user to upgrade; do not
  attempt a degraded/flat wiring.
- **Copy all 6 plugin agents into the project — mandatory, confirmed by
  testing, not a maybe.** Plugin-provided agents are namespaced
  (`seb-personas:explorer`, not `explorer`), and every persona body in this
  plugin cross-references the others by bare name ("spawn `explorer`").
  Verified on Claude Code 2.1.201: a bare-name spawn hard-errors —
  `Agent type 'explorer' not found. Available agents: ... seb-personas:explorer ...`
  — it does not fall back to fuzzy/description-based resolution. Do this
  copy as the FIRST action of every ADAPT run: copy all 6 files from the
  plugin's `agents/` directory into this project's `.claude/agents/` —
  project-scoped agents are never namespaced and always override the plugin
  version. It's a plain file copy, not re-authoring, so it costs no
  meaningful tokens; re-run it after any plugin version bump to pick up
  updates. (If a future Claude Code version resolves bare names against
  plugin agents automatically, re-test before skipping this step — don't
  assume it without checking the installed version.)

## 1. Third-party skill installs

- `npx skills@latest add mattpocock/skills` — select `grill-me`, `to-issues`,
  `tdd`, `diagnose`, `improve-codebase-architecture`, and
  `setup-matt-pocock-skills`, plus this coding agent.
- Run `/setup-matt-pocock-skills` once (issue tracker, triage labels, doc
  layout). RECORD which issue tracker was chosen — it goes in
  `.claude/persona-config.json`'s `issueTracker` field and the planner reads
  it via the retrieval contract.
- These install as a plugin, so their registered names are namespaced. Check
  the skill list and record the exact names.
- **Substitute placeholders**: `planner.md`, `lead-programmer.md`, and
  `repo-historian.md` (as shipped in the plugin) contain
  `<MATTPOCOCK:skill-name>` placeholders in their `skills:` frontmatter.
  Since plugin files live in a read-only cache, copy the three affected files
  into this project's `.claude/agents/` with the real namespaced names
  substituted (project agents override plugin agents, so this is safe and
  expected — not drift).

## 2. Code Review Graph (install as a PROJECT skill, never global MCP)

- Get the current install command from the code-review-graph marketplace
  listing (don't guess) and install it as a bare-named project skill into
  `.claude/skills/code-review-graph/` — NOT via `claude mcp add`, NOT with
  `enableAllProjectMcpServers`, and do not reference it from root CLAUDE.md.
  Any of those drifts every persona into exactly the context bloat the
  Explorer-as-a-service design exists to prevent. `explorer.md` as shipped
  assumes the bare name `code-review-graph`; if the real registered name
  differs, correct that one field (copy explorer.md into the project's
  `.claude/agents/` with the fix, same override mechanism as step 1).
- Build the index once. Identify the incremental-update command and its
  file-argument syntax — this becomes `graphUpdateCommand` in
  `.claude/persona-config.json` (see step 5).
- Add the persistent store (SQLite db / index dir) to `.gitignore` unless you
  deliberately want a shared prebuilt index (if so, commit it and say so in
  your report).
- Confirm it works: spawn the explorer with one real query (e.g. "what calls
  `<some real function in this repo>`") and paste its answer in your report.

## 3. arXiv MCP (powers the researcher — must be project-scoped)

Plugin-shipped agents ignore the `mcpServers` frontmatter field entirely
(a Claude Code plugin security restriction), which is why `researcher.md`
isn't shipped as a plugin agent at all — it only lives as a template.

- Find a maintained arXiv MCP server's launch command (don't guess).
- Copy `templates/researcher.md.tmpl` from the plugin into this project's
  `.claude/agents/researcher.md`, substituting the real launch command into
  the inline `mcpServers:` field. Inline + project-scoped means it connects
  only when the researcher starts and disconnects when it finishes, and
  actually takes effect (unlike a plugin-shipped copy would).
- Verify it works by having the researcher use it once.
- If no working arXiv MCP can be found: remove the `mcpServers:` field from
  the copied `researcher.md`, and its `tools:` list already includes
  `WebFetch`/`WebSearch` for a real fallback (not just curl) — note in the
  file's body that it's operating in that fallback mode, and say so in your
  report.

## 4. Repo-specific config → `.claude/persona-config.json`

Copy `templates/persona-config.schema.json`'s shape and fill in from an
actual scan of this repo (package.json / pyproject.toml / Makefile / etc.),
don't guess:
- `testAndLintCommand` — what the stop-gate hook runs; must be a single
  command with a meaningful non-zero exit code.
- `lintCommand` — formatter/linter invoked per-file by the lint-on-edit hook.
- `graphUpdateCommand` — from step 2.
- `sourceGlobs` — patterns worth graph-indexing (empty = index everything
  edited).
- `protectedPaths` — real protected paths in THIS repo (migrations,
  generated code, lockfiles — detect them, don't assume a generic list).
- `issueTracker` — from step 1.

## 5. CLAUDE.md wiring

- Run `/init` first if no CLAUDE.md exists, then prune hard — apply "would
  removing this line cause Claude to make a mistake?" to every line that
  survives. If one exists, append/trim, don't overwrite.
- Copy `templates/persona-protocol.md` from the plugin into this project's
  `.claude/persona-protocol.md` verbatim (it's role-agnostic; nothing to
  fill in).
- Add exactly one line to CLAUDE.md: `@.claude/persona-protocol.md` — this is
  the only channel that reaches both subagents and agent-teams teammates
  automatically, which is why the shared protocol lives here instead of being
  duplicated into every persona body.
- Do NOT duplicate the orchestrator's routing table here — `settings.json`
  already makes it the main agent (step 6), so a routing table in CLAUDE.md
  would just ship dead weight into every persona's context.

## 6. settings.json merge (MERGE, never clobber)

Merge `templates/settings-fragment.json` into this project's
`.claude/settings.json`, replacing its two placeholder permission entries
with this repo's real test/build/lint/git commands plus the graph's
incremental-update command, so permission prompts don't constantly interrupt.
Note in your report: the default teammate model has no reliable settings key
— that's a manual `/config` step for the user.

## 7. Wiki / CONTEXT / ADR seeding

Populate `repo-historian`'s starter wiki (`.claude/wiki/`), a starter
`CONTEXT.md`, and a `docs/adr/` layout from an actual scan of this repo —
spawn the `explorer` for the structural facts rather than crawling yourself.

## 8. Hook verification (sandboxed — do not leave the repo red or trap yourself)

On a throwaway branch:
- Make a trivial edit; confirm `graph-update.sh` and `lint-on-edit.sh` fired
  (check the graph index timestamp / lint output).
- Confirm the stop-gate does **NOT** block a trivial explorer or
  repo-historian turn even with a dirty tree — this is the proof that
  `SubagentStop` is correctly scoped to `lead-programmer` only and won't
  strangle the cheap, high-frequency personas.
- Introduce a failing check, end a lead-programmer-style turn, confirm
  BLOCK; create `.claude/wip-handoff.<agent-id>`, confirm ALLOW and that the
  sentinel is deleted.
- Test the protected-paths hook with a dry write against one of the
  configured `protectedPaths` patterns; confirm BLOCK with the human-approval
  message.
- Revert the branch completely. Your final turn must end with the repo clean
  and all sentinels/markers removed.

## 9. Report back

State: the Claude Code version confirmed and whether any agent needed the
bare-name-resolution fallback (step 0); the exact mattpocock skill names and
issue tracker chosen; the code-review-graph registered name and one real
structural query + answer as proof; the arXiv MCP result (server name, or
fallback mode); the one manual `/config` step required (default teammate
model); each hook-verification result from step 8; confirmation the repo
ended clean.
