# seb-personas

This is the Claude set up I've been using for work and personal projects.
Seems to be pretty decent at not generating too much slop but is a token
whore. Note this still very much in development so raise an issue you notice
weird shit.

A modular, persona-based Claude Code system (orchestrator + explorer +
lead-programmer are the core loop; planner / repo-historian / reviewer /
researcher are selected per-project) as a private, reusable plugin — built so
a new project costs one short ADAPT run instead of re-authoring ~500 lines of
persona/hook prose from scratch every time.

**Requires Claude Code v2.1.178+.** This is a hard pin, not a suggestion:
nested subagent spawning needs v2.1.172+, and `TeamCreate`/`TeamDelete` were
removed in v2.1.178 (team cleanup is automatic from that version on). Earlier
versions are not supported by this plugin — there is no degraded-mode
fallback.

## Personas

| Persona | Model | Required? | What it does |
|---|---|---|---|
| `orchestrator` | inherit | Always | Thin router/main agent. Never implements, never loads persona skills — routes requests to the right persona and synthesizes results briefly. |
| `explorer` | haiku | Always | Stateless code cartographer. Answers structural questions (where's X defined, what calls Y, blast radius of a change) via the Code Review Graph, returning distilled answers, not raw dumps. The one persona every other persona defers to for structural facts. |
| `lead-programmer` | sonnet | Always | Executes an approved plan step by step, TDD-first, with surgical diffs. Makes small conventional commits as it goes; reports "ready-for-review" when done, never grades its own work. |
| `planner` | opus | Opt-in | Turns ambiguous goals into precise plans with machine-checkable acceptance criteria. Explores first, never writes production code, slices approved plans into issues. |
| `repo-historian` | haiku | Opt-in | Maintains the wiki, `CONTEXT.md`, and ADRs — the curated "why" layer the graph can't derive. Never touches source code. |
| `reviewer` | opus | Opt-in (see below) | Independent, adversarial verifier — the Writer/Reviewer split. Did not write the code under review, can't edit it, only returns PASS/FAIL with reasons. **This is the system's core safety property**; skipping it needs an explicit confirmation during setup. |
| `researcher` | sonnet | Opt-in, project-scoped only | Bridges academic literature and engineering via an arXiv MCP (or WebSearch fallback) — paper discovery, deep-dive summaries, technique translation briefs for the planner. Not a plugin agent (see below) since plugin agents ignore `mcpServers`. |

`explorer` and `lead-programmer` are the minimum viable loop; `orchestrator`
is always the main agent. Everything else is selected per-project by
`setup-personas` (see Install below). There's also an `start-feature-team`
command for agent-teams mode (the same personas as concurrent teammates
instead of sequential subagents) — off by default, a deliberate gear.

## Install

**Local testing (do this first, on a scratch repo):**
```
claude --plugin-dir ~/seb_claude_setup
```
Confirm the agents appear. Note: plugin agents load as namespaced names
(`seb-personas:explorer`, confirmed on Claude Code 2.1.201) — bare-name spawns
like `explorer` hard-error, they don't resolve. This is exactly why
`setup-personas`'s first substantive action is copying every selected agent
file into the project's `.claude/agents/`, which are never namespaced. Don't
skip that step expecting it to work by cross-referencing bare names as
shipped.

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
- **Node.js / `npx`** — needed for the `mattpocock/skills` installer, if any
  selected persona uses one of those skills.
- **`git`**, and **`gh`** if you pick GitHub issues as your tracker during
  `setup-personas`.

**Then, once per new project**, run:
```
/seb-personas:setup-personas
```
This asks which personas the project needs (`explorer`/`lead-programmer` are
mandatory; `planner`/`repo-historian`/`reviewer`/`researcher` are opt-in —
skipping `reviewer` needs an explicit confirmation, since it's the system's
core safety property), then handles everything else that can't be pre-baked:
version check, third-party skill installs, the Code Review Graph, the arXiv
MCP for the researcher, repo-specific commands and protected paths, CLAUDE.md
wiring, a settings.json merge, wiki seeding, and sandboxed hook verification.
See `skills/setup-personas/SKILL.md` for the full flow.

**When the plugin updates**, re-run adapted projects with:
```
/seb-personas:setup-personas --update
```
This re-syncs the project's copied agent files against the current plugin
version — diffing before overwriting, never silently clobbering a local
edit. A `SessionStart` hook warns automatically when a project's adapted
version is behind the plugin's current version.

## What ships in the plugin vs. what ADAPT writes per-project

| Ships once (plugin) | Written per-project (ADAPT) |
|---|---|
| Persona agents: orchestrator, explorer, lead-programmer (always); planner, repo-historian, reviewer (opt-in) | `researcher.md` (needs `mcpServers`, which plugin agents ignore entirely) + persona selection |
| `coding-discipline` skill | `.claude/persona-config.json` (test/lint/build commands, protected/gated paths, issue tracker, plugin version stamp) |
| `setup-personas` skill (the ADAPT flow + `--update` resync) | `.claude/persona-protocol.md` (copied from the plugin template, version-stamped) + one `@import` line in CLAUDE.md |
| 6 hooks (generic scripts reading runtime config) | `.claude/settings.json` merge (plugins can't ship settings at all) |
| `start-feature-team` command | wiki / CONTEXT.md / docs/adr seeding |

## Adding your own persona

Drop a new `.md` file in `.claude/agents/` (project-scoped, so no plugin
change needed) with a clear `description:` — auto-delegation picks it up.
Three things to check depending on what it does:
- If it writes code, add its agent-type name to `gatedAgents` in
  `.claude/persona-config.json` so the stop-gate actually checks its work.
- If it should be reviewed like everything else, no change needed — the
  reviewer scopes review via the explorer's blast-radius answer, not a
  hardcoded persona list.
- If you want other personas to route to it by name, add one disambiguation
  line to the project's copy of `orchestrator.md`'s routing table.

## Removing seb-personas

`setup-personas` writes to these locations; removing all of them uninstalls
the system from a project:
- `.claude/agents/*.md` (the copied persona files)
- `.claude/persona-protocol.md`
- `.claude/persona-config.json`
- `.claude/wiki/`, `CONTEXT.md`, `docs/adr/` (if `repo-historian` was selected)
- `.claude/settings.json`'s `"agent": "orchestrator"` key, the
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env entry, and the permissions it
  added
- The `@.claude/persona-protocol.md` line in CLAUDE.md
- `.claude/reviewed/`, `.claude/wip-handoff.*`, `.claude/.session-baseline.*`
  (also in `.gitignore` — safe to delete)
- `/plugin uninstall seb-personas` to remove the plugin itself

## Cost

`planner` and `reviewer` are Opus-tier and are the system's real spend
drivers, not the haiku-tier `explorer`/`repo-historian`. Both are capped with
`maxTurns: 30` and the FAIL→fix→re-review loop is capped at 2 iterations
before escalating to you instead of looping — but there's no budget mode
beyond that yet. Check `/cost`, and if it's high, look at how often the full
Explore→Plan→Implement→Verify→Commit pipeline is running for work that
didn't need it (the orchestrator's "scale effort to the task" rule is the
lever, not a setting).

## Why this shape (design rationale, kept out of the agent bodies)

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
  runtime.
- **"Teammates cannot spawn subagents" — an assumption in an earlier draft of
  this system — is false.** The real agent-teams restriction is on nested
  *teams*, not on ordinary subagent spawning. Earlier drafts had every
  persona fall back to Grep/Glob as a teammate out of this false belief;
  fixed in the shared protocol.
- **The stop-gate's `SubagentStop` scoping is config-driven (`gatedAgents` in
  `persona-config.json`), not hardcoded in `hooks.json`.** Confirmed
  empirically that the `SubagentStop` payload carries `agent_type`, so the
  hook itself decides who it applies to. An earlier, hardcoded-matcher
  version was the single most consequential robustness bug found in v0.1.0 —
  making it config-driven means a future code-writing persona is a config
  edit, not a plugin file edit.
- **The reviewer's PASS marker (`.claude/reviewed/<task-id>.pass`) is an
  explicit, named exception to "never edits."** It's Bash-written bookkeeping
  for the `TaskCompleted` hook, not a change to reviewed code. `setup-personas`
  pre-creates the directory so the first-ever marker write doesn't fail on a
  missing path — a real bug found and fixed in v0.2.0.
- **`memory: <scope>` auto-grants Read/Write/Edit for memory management,
  regardless of a persona's declared `tools:` list.** The planner's "never
  write production code" and researcher's restricted tool list are therefore
  instruction-enforced, not mechanically enforced, for personas with memory.
  Noted once in the shared protocol rather than caveated in every file.
- **FLAT MODE (pre-2.1.172 nesting) and the manual TeamCreate/TeamDelete
  cleanup branch (pre-2.1.178) were deleted outright**, not kept as a
  fallback. Maintaining two wiring paths for versions this plugin doesn't
  support was pure complexity with no live use case.
- **Persona opt-out is graceful by construction, not by a wizard alone.**
  Every optional-persona cross-reference is phrased conditionally ("if this
  project has a `researcher`... otherwise..."), so a plain file copy degrades
  gracefully even without per-project text surgery — the wizard in
  `setup-personas` only decides which files get copied, it doesn't need to
  edit anyone's prose.
- **The ADAPT-copy-vs-plugin-update tension is real, and has a mechanism
  now.** Because bare-name persona resolution requires copying agent files
  into every project, persona-body bug fixes don't propagate automatically
  the way hooks/skills/commands do (those load via `${CLAUDE_PLUGIN_ROOT}`
  and stay live). Version-stamp comments + `--update` mode + the
  `SessionStart` drift check close that gap without needing every user to
  remember to check manually.
- **`AskUserQuestion` is unavailable to subagents, even if listed in their
  `tools:`** — confirmed against the Claude Code docs, not assumed. This is
  why the planner returns plain-text "Open Questions" instead of asking
  interactively, and why the *orchestrator* (which runs as the main session,
  not a subagent) is the one that has `AskUserQuestion` in its tools and
  turns those open questions into a real structured prompt when they reduce
  to discrete choices.
- **Known limitations, not silently papered over**: the graph-update and
  lint hooks only read `tool_input.file_path`, so `MultiEdit`'s array form
  and `NotebookEdit` aren't matched. The protected-paths hook only gates the
  `Write`/`Edit` tools — a persona running `sed -i` or a lockfile-rewriting
  package manager command via `Bash` bypasses it. Both are documented as
  advisory rather than airtight; tightening either is a good candidate for a
  future version bump.

## Credits — third-party skills & MCPs this plugin builds on

This plugin doesn't invent everything itself — several personas lean on
external skills/tools installed at ADAPT time:

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — installed
  via the `skills.sh` installer (`npx skills@latest add mattpocock/skills`).
  Provides `grill-me` and `to-issues` (used by `planner`), `tdd` and
  `diagnose` (used by `lead-programmer`), and `improve-codebase-architecture`
  (used by `repo-historian`).
- **[code-review-graph](https://github.com/tirth8205/code-review-graph)** —
  the tree-sitter/SQLite structural graph the `explorer` persona queries for
  blast-radius and dependency answers. Installed as a project-scoped skill,
  never a global MCP server (see "Why this shape" above for why that
  distinction matters here).
- **[andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)**
  — the local `coding-discipline` skill (`skills/coding-discipline/SKILL.md`)
  is adapted from Andrej Karpathy's public observations on common LLM coding
  pitfalls, as packaged in this repo.
- **arXiv MCP** — powers the `researcher` persona. Deliberately not pinned to
  a specific server here; `setup-personas` step 5 has you find and wire in a
  currently-maintained one at ADAPT time, since "currently maintained" is a
  moving target this repo shouldn't hardcode.

## Contributing / issues

See `CONTRIBUTING.md`. The bug report template asks for your Claude Code
version, the plugin version vs. your project's adapted version, and whether
the bug is in a plugin-shipped file or an ADAPT-copied project file — version
drift (see above) is the likely root cause of a lot of reports, so it's
worth checking `--update` first.
