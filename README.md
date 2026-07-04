# seb-personas

A six-persona Claude Code system (orchestrator + explorer / planner /
lead-programmer / repo-historian / reviewer, plus a researcher template) as a
private, reusable plugin — built so a new project costs one short ADAPT run
instead of re-authoring ~500 lines of persona/hook prose from scratch every
time.

**Requires Claude Code v2.1.178+.** This is a hard pin, not a suggestion:
nested subagent spawning needs v2.1.172+, and `TeamCreate`/`TeamDelete` were
removed in v2.1.178 (team cleanup is automatic from that version on). Earlier
versions are not supported by this plugin — there is no degraded-mode
fallback.

## Install

**Local testing (do this first, on a scratch repo):**
```
claude --plugin-dir ~/seb_claude_setup
```
Confirm the six agents appear. Note: plugin agents load as namespaced names
(`seb-personas:explorer`, confirmed on Claude Code 2.1.201) — bare-name spawns
like `explorer` hard-error, they don't resolve. This is exactly why
`setup-personas`'s first action is copying all 6 agent files into the
project's `.claude/agents/`, which are never namespaced. Don't skip that step
expecting it to work by cross-referencing bare names as shipped.

**Real install, once stable**, from this directory pushed to a private Git
repo:
```
/plugin marketplace add <owner>/<repo>
/plugin install seb-personas@seb-personas-marketplace
```
(`/plugin install <git-url>` directly is not a real command — installation is
always the two-step marketplace-add-then-install flow above.)

**This repo is private.** Each friend needs, before the commands above will
work:
- To be added as a collaborator on the GitHub repo (repo Settings → Collaborators).
- Working git auth on their own machine for a private clone — an SSH key
  added to their GitHub account, or `gh auth login` done once locally. Without
  one of these, `/plugin marketplace add` will fail to clone with a
  permission/auth error, not a "not found" error — if that happens, that's
  what to check first.

## Prerequisites (install before using this plugin)

- **Claude Code ≥2.1.178** (hard pin, no fallback for older versions)
- **`jq`** — every hook script depends on it. If missing, hooks don't error;
  each script suppresses jq's own stderr and treats the resulting empty
  extraction as "nothing to do," so it silently no-ops rather than failing
  loudly. A missing `jq` looks like "nothing happens," not a clear error —
  install it first.
- **Node.js / `npx`** — needed for the `mattpocock/skills` installer in step 1
  of `setup-personas`.
- **`git`**, and **`gh`** if you pick GitHub issues as your tracker during
  `setup-personas`.

**Then, once per new project**, run:
```
/seb-personas:setup-personas
```
This is the only per-project step. It handles everything that can't be
pre-baked: version check, third-party skill installs (mattpocock/skills), the
Code Review Graph, the arXiv MCP for the researcher, repo-specific commands
and protected paths, CLAUDE.md wiring, a settings.json merge, wiki seeding,
and sandboxed hook verification. See `skills/setup-personas/SKILL.md` for the
full flow.

## What ships in the plugin vs. what ADAPT writes per-project

| Ships once (plugin) | Written per-project (ADAPT) |
|---|---|
| 6 agents: orchestrator, explorer, planner, lead-programmer, repo-historian, reviewer | `researcher.md` (needs `mcpServers`, which plugin agents ignore entirely) |
| `coding-discipline` skill | `.claude/persona-config.json` (test/lint/build commands, protected paths, issue tracker) |
| `setup-personas` skill (the ADAPT flow itself) | `.claude/persona-protocol.md` (copied verbatim from the plugin template) + one `@import` line in CLAUDE.md |
| 5 hooks (generic scripts reading runtime config) | `.claude/settings.json` merge (plugins can't ship settings at all) |
| `start-feature-team` command | wiki / CONTEXT.md / docs/adr seeding |

## Why this shape (design rationale, kept out of the agent bodies)

- **CLAUDE.md is the only channel that reaches both subagents and agent-teams
  teammates automatically.** That's why the cross-cutting rules (explorer
  delegation, teams-mode behavior, the WIP sentinel, the retrieval contract,
  machine-checkable criteria, review ownership, the FAIL→fix continuation
  protocol) live in one `templates/persona-protocol.md` imported via a single
  CLAUDE.md line, instead of being pasted into all six persona bodies. Adding
  a seventh persona means one new file — it inherits the protocol for free.
- **Plugin agents ignore `mcpServers`, `hooks`, and `permissionMode`
  frontmatter, and plugins can't ship `settings.json` at all.** This is why
  researcher isn't a plugin agent (it's a template copied in project-scoped),
  and why hooks/settings are bundled in the plugin but their *effective*
  config always comes from a project-local file the generic scripts read at
  runtime.
- **"Teammates cannot spawn subagents" — an assumption in an earlier draft of
  this system — is false.** The real agent-teams restriction is on nested
  *teams*, not on ordinary subagent spawning. Earlier drafts had every
  persona fall back to Grep/Glob as a teammate out of this false belief;
  fixed in the shared protocol.
- **The stop-gate is scoped to `SubagentStop` with `matcher: lead-programmer`
  only** (plus a `Stop` registration for the main session). An unscoped
  version would run a full test+lint suite after every explorer/historian
  call and BLOCK an agent that has no ability to fix anything — the single
  most consequential robustness bug found in the prior draft.
- **The reviewer's PASS marker (`.claude/reviewed/<task-id>.pass`) is an
  explicit, named exception to "never edits."** It's Bash-written bookkeeping
  for the `TaskCompleted` hook, not a change to reviewed code — worth stating
  loudly because an earlier draft told the reviewer to write a marker it was
  simultaneously forbidden from writing, which silently deadlocked agent-teams
  mode.
- **`memory: <scope>` auto-grants Read/Write/Edit for memory management,
  regardless of a persona's declared `tools:` list.** The planner's "never
  write production code" and researcher's restricted tool list are therefore
  instruction-enforced, not mechanically enforced, for personas with memory.
  Noted once in the shared protocol rather than caveated in every file.
- **FLAT MODE (pre-2.1.172 nesting) and the manual TeamCreate/TeamDelete
  cleanup branch (pre-2.1.178) were deleted outright**, not kept as a
  fallback. Maintaining two wiring paths for versions this plugin doesn't
  support was pure complexity with no live use case.
- **Known limitations, not silently papered over**: the graph-update and
  lint hooks only read `tool_input.file_path`, so `MultiEdit`'s array form
  and `NotebookEdit` aren't matched. The protected-paths hook only gates the
  `Write`/`Edit` tools — a persona running `sed -i` or a lockfile-rewriting
  package manager command via `Bash` bypasses it. Both are documented as
  advisory rather than airtight; tightening either is a good candidate for a
  future version bump, not a blocker for v0.1.0.
