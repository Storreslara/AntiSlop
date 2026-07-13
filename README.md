# AntiSlop

<p align="center">
<pre>
######################
######################
----------##----------
--------######--------
------####--####------
----####------###-----
--####----------###---
-###-------------####-
##--------##-------###
##--------##--------##
##--------##--------##
##--------##--------##
##--------##--------##
###-------###------###
-####------####--####-
---###-------######---
---#####-------###----
-####-####------####--
###-----####------####
##--------##--------##
##--------##--------##
##--------##--------##
##--------##--------##
##--------##-------###
-###-------------####-
--####----------###---
----####------###-----
------####--####------
--------######--------
----------##----------
</pre>
</p>

This is the Claude Code setup I use for work and personal projects. It's
pretty decent at not generating slop, but it's a token hog. Still very much in
development — if you hit weird behavior, please raise an issue.

AntiSlop is a modular, persona-based Claude Code system packaged as a private,
reusable plugin. The core loop is three always-on personas — **orchestrator**
(routes requests), **explorer** (maps the code), and **lead-programmer**
(writes it). HiveMind, repo-historian, reviewer, milestone-auditor, and
researcher are opt-in per project. Shipping it as a plugin means a new project
costs one short setup run instead of re-authoring ~500 lines of persona and
hook prose from scratch.

## Personas

| Persona | Model | Required? | What it does |
|---|---|---|---|
| `orchestrator` | inherit | Always | Thin router/main agent. Never implements, never loads persona skills — routes requests to the right persona and synthesizes results briefly. |
| `explorer` | haiku | Always | Stateless code cartographer. Answers structural questions (where's X defined, what calls Y, blast radius of a change) via the Code Review Graph, returning distilled answers, not raw dumps. The one persona every other persona defers to for structural facts. |
| `lead-programmer` | sonnet | Always | Executes an approved plan step by step, TDD-first, with surgical diffs. Makes small conventional commits as it goes; reports "ready-for-review" when done, never grades its own work. |
| `hivemind` | opus (fable for well-scoped dispatches) | Opt-in | Turns ambiguous goals into precise plans with machine-checkable acceptance criteria. Explores first, never writes production code, slices approved plans into issues. |
| `repo-historian` | haiku | Opt-in | Maintains the wiki, `CONTEXT.md`, and ADRs — the curated "why" layer the graph can't derive. Never touches source code. |
| `reviewer` | opus | Opt-in (see below) | Independent, adversarial verifier — the Writer/Reviewer split. Did not write the code under review, can't edit it, only returns PASS/FAIL with reasons. **This is the system's core safety property**; skipping it needs an explicit confirmation during setup. |
| `milestone-auditor` | opus (fable for well-scoped dispatches) | Opt-in | Adversarial auditor of the *plan*, not the code — runs at milestone boundaries after every unit has already reviewer-PASSed, hunting for premise gaps and goal drift the reviewer structurally can't see. No PASS/FAIL, no override authority, no Write/Edit — only a findings list relayed to the human. A human pre-audit checkpoint (via `AskUserQuestion`) precedes every dispatch. |
| `researcher` | sonnet | Opt-in, project-scoped only | Bridges academic literature and engineering via an arXiv MCP (or WebSearch fallback) — paper discovery, deep-dive summaries, technique translation briefs for hivemind. Not a plugin agent (see below) since plugin agents ignore `mcpServers`. |

`explorer` and `lead-programmer` are the minimum viable loop; `orchestrator`
is always the main agent. Everything else is chosen per project during setup.
A `start-feature-team` command runs the same personas as concurrent teammates
instead of sequential subagents — off by default, a deliberate gear.

## Requirements

Install these before using the plugin:

- **Claude Code ≥ 2.1.178** — a hard pin, not a suggestion. Nested subagent
  spawning needs 2.1.172+, and automatic team cleanup needs 2.1.178+. There is
  no degraded-mode fallback for older versions.
- **`jq`** — every hook script depends on it. If it's missing, hooks don't
  fail loudly; each script treats the empty result as "nothing to do" and
  silently no-ops. A missing `jq` looks like "nothing happens," not a clear
  error — install it first.
- **Node.js / `npx`** — for the `mattpocock/skills` installer, if a selected
  persona uses one of those skills.
- **`git`**, plus **`gh`** if you choose GitHub Issues as your tracker during
  setup.

## Install

AntiSlop lives in a **private** GitHub repo (`Storreslara/AntiSlop`). Before
the install commands will work, each user needs:
- to be added as a collaborator (repo Settings → Collaborators), and
- working git auth on their own machine — an SSH key added to their GitHub
  account, or `gh auth login` run once locally. Without one of these, `/plugin
  marketplace add` fails to clone with a permission/auth error (not a "not
  found" error) — that's the first thing to check if it happens.

Install is always a two-step marketplace flow:
```
/plugin marketplace add Storreslara/AntiSlop
/plugin install antislop@antislop-marketplace
```
(`/plugin install <git-url>` directly is not a real command.)

**To test locally first** on a scratch repo, point Claude Code at your clone
(the directory can be named anything):
```
claude --plugin-dir /path/to/your/clone
```
Confirm the agents appear, then run setup below. If you'd rather scaffold files
directly instead of using the marketplace, see [npx install](#npx-install-alternative).

Note: plugin agents load under namespaced names (`antislop:explorer`). Bare-name
spawns like `explorer` hard-error — they don't resolve. That's why setup's
first substantive action is copying every selected agent file into the
project's `.claude/agents/`, which are never namespaced.

## First-time setup

Once per project, run:
```
/antislop:setup-personas
```
It asks which personas the project needs. `explorer` and `lead-programmer` are
mandatory; the rest are opt-in. **Skipping `reviewer` requires an explicit
confirmation** — it's the system's core safety property. Setup then handles
everything that can't be pre-baked: the version check, third-party skill
installs, the Code Review Graph, the researcher's arXiv MCP, repo-specific
commands and protected paths, CLAUDE.md wiring, a settings.json merge, wiki
seeding, and sandboxed hook verification. Full flow:
`skills/setup-personas/SKILL.md`.

**When the plugin updates**, re-sync adapted projects:
```
/antislop:setup-personas --update
```
This diffs the project's copied agent files against the current plugin version
before overwriting — it never silently clobbers a local edit. A `SessionStart`
hook warns automatically when a project's adapted version is behind.

## npx install (alternative)

This repo doubles as a runnable npm package — not published to the registry,
so clone it and point `npx` at the local directory. It's a **hybrid**, not a
replacement for `setup-personas`: the CLI does only the mechanical half (file
copying, version-stamping, settings merge). The judgment half — repo-specific
test/lint commands, protected paths, third-party skill installs, graph/MCP
wiring, CLAUDE.md pruning, hook verification — still needs `/setup-personas`
afterward. The same private-repo, collaborator, and git-auth requirements as
the plugin flow apply, since it still needs a clone.

Reuse an existing clone if you have one, or:
```
git clone https://github.com/Storreslara/AntiSlop.git ~/antislop
```
Then, from the project you're adding personas to (substitute your actual clone
path for `~/antislop`):
```
cd ~/your-project
npx ~/antislop
```
It prompts for optional personas the same way `setup-personas` step 1 does
(declining `reviewer` requires typing `skip reviewer`). Non-interactive:
`--yes` includes every optional persona; `--personas=hivemind,reviewer,researcher`
includes only the named ones.

**What it does, deterministically:** copies core + selected persona `.md` files
into `.claude/agents/` (version-stamped); copies `persona-protocol.md` and
`protocol-digest.md`; copies the hook scripts into `.claude/hooks/scripts/` and
registers them in `.claude/settings.json` with `${CLAUDE_PROJECT_DIR}`-relative
commands (merged in, never clobbering existing settings); copies the
`setup-personas` and `coding-discipline` skills project-scoped (so
`/setup-personas` works with no plugin installed at all); adds the CLAUDE.md
import line; appends the standard `.gitignore` entries; writes a skeleton
`.claude/persona-config.json`. By default it refuses to run over an existing
install rather than risk clobbering local edits — use `/setup-personas --update`
or `--overwrite` for that case instead.

**`--overwrite`** re-copies the mechanical files (agents, hooks, skills,
protocol) unconditionally, even over an existing install — useful for pulling
in agent-prose fixes without the LLM-driven `--update` diff flow. It never
touches `persona-config.json`'s judgment-driven fields (`testAndLintCommand`,
`protectedPaths`, etc.); only `personaSelection` and `pluginVersion` get
refreshed. Without `--personas=`/`--yes`, it reuses the project's already-recorded
persona selection rather than silently changing which personas are installed.

**Two third-party installers** can run from the same terminal (the CLI inherits
your stdio, so their interactive prompts show up normally):
- `--with-mattpocock` runs `npx skills@latest add mattpocock/skills` (you still
  pick the skills yourself in its picker; the CLI just launches it).
- `--with-graph` runs `pipx install code-review-graph` + `code-review-graph
  install --platform claude-code`. This does **not** finish the graph wiring:
  that tool registers itself project-wide in `.mcp.json` by default, which
  every persona would inherit. The CLI deliberately stops after the install and
  leaves the `.mcp.json`→`explorer.md` rescoping to `/setup-personas` step 4,
  which needs to inspect what actually got written.

Both are skipped under `--yes`/`--personas=` unless you also pass their
`--with-*` flag — they're real installs with side effects, not pure file copies.

Finally, finish setup inside the project:
```
cd ~/your-project
claude
```
then run `/setup-personas` to fill in the parts that need a real repo scan
(test/lint commands, protected paths), install third-party skills, build the
Code Review Graph, and run hook verification. Personas load identically either
way — as project-local `.claude/agents/*.md` files.

## What ships in the plugin vs. what setup writes per-project

| Ships once (plugin) | Written per-project (setup) |
|---|---|
| Persona agents: orchestrator, explorer, lead-programmer (always); hivemind, repo-historian, reviewer, milestone-auditor (opt-in) | `researcher.md` (needs `mcpServers`, which plugin agents ignore entirely) + persona selection |
| `coding-discipline` skill | `.claude/persona-config.json` (test/lint/build commands, protected/gated paths, issue tracker, plugin version stamp) |
| `setup-personas` skill (the setup flow + `--update` resync) | `.claude/persona-protocol.md` (copied from the plugin template, version-stamped) + one `@import` line in CLAUDE.md + `.claude/protocol-digest.md` (short resume/compact re-anchor, injected only by `session-start.sh`, not imported into CLAUDE.md) |
| 7 hooks (generic scripts reading runtime config) | `.claude/settings.json` merge (plugins can't ship settings at all) |
| `start-feature-team` command | wiki / CONTEXT.md / docs/adr seeding |

## Adding your own persona

Drop a new `.md` file in `.claude/agents/` (project-scoped, so no plugin change
needed) with a clear `description:` — auto-delegation picks it up. Then check
three things:
- If it writes code, add its agent-type name to `gatedAgents` in
  `.claude/persona-config.json` so the stop-gate checks its work.
- If it should be reviewed like everything else, no change needed — the
  reviewer scopes review via the explorer's blast-radius answer, not a
  hardcoded persona list.
- If you want other personas to route to it by name, add one disambiguation
  line to the project's copy of `orchestrator.md`'s routing table.

## Cost

`hivemind`, `reviewer`, and `milestone-auditor` all DEFAULT to Opus and
remain the system's real spend drivers, not the haiku-tier
`explorer`/`repo-historian`. `hivemind` and `milestone-auditor` can be
dispatched on Fable for well-scoped work, per the orchestrator's per-dispatch
routing rule (see orchestrator.md's "Per-unit model routing" subsection) —
honestly: worst case cost is unchanged from today (all three still run on
Opus in the worst case), the common case is cheaper only when the
orchestrator's heuristic actually routes well-scoped work to fable. All
three are capped with `maxTurns: 30`/`20`, and the FAIL→fix→re-review loop is
capped at 2 iterations before escalating to you — but there's no budget mode
beyond that yet. Check `/cost`; if it's high, look at how often the full
Explore→Plan→Implement→Verify→Commit pipeline runs for work that didn't need
it. The orchestrator's "scale effort to the task" rule is the lever there,
not a setting.

## Removing AntiSlop

Setup writes to these locations; removing all of them uninstalls the system
from a project:
- `.claude/agents/*.md` (the copied persona files)
- `.claude/persona-protocol.md`
- `.claude/protocol-digest.md`
- `.claude/persona-config.json`
- `.claude/wiki/`, `CONTEXT.md`, `docs/adr/` (if `repo-historian` was selected)
- `.claude/settings.json`'s `"agent": "orchestrator"` key, the
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env entry, and the permissions it added
- The `@.claude/persona-protocol.md` line in CLAUDE.md
- `.claude/reviewed/`, `.claude/wip-handoff.*`, `.claude/.session-baseline.*`,
  `.claude/wip-audit.log`, `.claude/.pending-review.*`,
  `.claude/review-audit.log` (also in `.gitignore` — safe to delete)
- `/plugin uninstall antislop` to remove the plugin itself

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
  runtime. `explorer.md` leans on the same fact for its Code Review Graph MCP
  connection: it's shipped as a plugin agent, but setup always copies it into
  `.claude/agents/` anyway (bare-name plugin agents don't resolve — see Install
  above), so its `mcpServers:` frontmatter takes effect on the project-scoped
  copy the same way researcher's does, scoping the graph connection to the
  explorer alone instead of every persona.
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
  `/antislop:setup-personas --update` before then.
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
  even without per-project text surgery — the wizard in `setup-personas` only
  decides which files get copied, it doesn't need to edit anyone's prose.
- **The copy-vs-plugin-update tension is real, and has a mechanism now.**
  Because bare-name persona resolution requires copying agent files into every
  project, persona-body bug fixes don't propagate automatically the way
  hooks/skills/commands do (those load via `${CLAUDE_PLUGIN_ROOT}` and stay
  live). Version-stamp comments + `--update` mode + the `SessionStart` drift
  check close that gap without needing every user to remember to check manually.
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

## Credits — third-party skills & MCPs this plugin builds on

Several personas lean on external skills and tools installed at setup time:

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — installed via
  the `skills.sh` installer (`npx skills@latest add mattpocock/skills`).
  Provides `grill-me` and `to-issues` (used by `hivemind`), `tdd` and `diagnose`
  (used by `lead-programmer`), and `improve-codebase-architecture` (used by
  `repo-historian`).
- **[code-review-graph](https://github.com/tirth8205/code-review-graph)** — the
  tree-sitter/SQLite structural graph the `explorer` persona queries for
  blast-radius and dependency answers. It's an MCP server (pip/pipx-installed);
  its own `install` command registers project-wide by default, which
  `setup-personas` step 4 deliberately undoes, re-scoping the connection to
  `explorer.md`'s own `mcpServers:` frontmatter so it doesn't leak into every
  persona's context (see "Why this shape" for why that matters). The tool also
  generates `.claude/skills/code-review-graph/` build-graph/review-delta/review-pr
  workflow skills — those are separate slash commands, not what the explorer
  itself calls.
- **[andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)**
  — the local `coding-discipline` skill (`skills/coding-discipline/SKILL.md`) is
  adapted from Andrej Karpathy's public observations on common LLM coding
  pitfalls, as packaged in this repo.
- **arXiv MCP** — powers the `researcher` persona. Deliberately not pinned to a
  specific server here; `setup-personas` step 5 has you find and wire in a
  currently-maintained one at setup time, since "currently maintained" is a
  moving target this repo shouldn't hardcode.

## Contributing / issues

See `CONTRIBUTING.md`. The bug report template asks for your Claude Code
version, the plugin version vs. your project's adapted version, and whether the
bug is in a plugin-shipped file or a copied project file — version drift (see
above) is the likely root cause of a lot of reports, so it's worth checking
`--update` first.
