# AntiSlop

<table align="center"><tr><td>
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
</td></tr></table>

This is the Claude Code setup I use for work and personal projects. It's
pretty decent at not generating slop, but it's a token hog. Still very much in
development — if you hit weird behavior, please raise an issue.

AntiSlop is a modular, persona-based Claude Code system packaged as a private,
reusable plugin. The core loop is three always-on personas — **orchestrator**
(routes requests), **explorer** (maps the code), and **lead-programmer**
(writes it). `hivemind`, `repo-historian`, `reviewer`, `milestone-auditor`, and
`researcher` are opt-in per project. Shipping it as a plugin means a new project
costs one short setup run instead of re-authoring ~500 lines of persona and
hook prose from scratch.

## A few terms used below

- **Persona** — a Claude Code subagent (`.claude/agents/*.md`) with a narrow
  job and its own model tier. `orchestrator` is the one that runs as your
  main session; every other persona is dispatched via the `Agent` tool.
- **Code Review Graph** — an optional tree-sitter/SQLite structural index
  the `explorer` persona can query instead of grepping (see
  [Credits](#credits--third-party-skills--mcps-this-plugin-builds-on)); it's
  a real dependency to install (setup step 4), not built-in.
- **Teammates / agent-teams** — a Claude Code feature (concurrent, not
  sequential, subagents) that `start-feature-team` uses; it's off by default.
- **`fable`** — a Claude model tier (distinct from opus/sonnet/haiku) that
  `hivemind` and `milestone-auditor` can be dispatched on for well-scoped
  work, per the [Cost](#cost) section.
- **Stop-gate** — the hook that blocks a gated persona's turn from ending
  until the `reviewer` has passed its work; see the design notes below for
  how it's enforced.
- **ADAPT** — this repo's internal name for what `/setup-personas` does:
  copying and substituting plugin templates into your project's `.claude/`.
  You won't need to say this word to use the plugin; it shows up if you read
  `skills/setup-personas/SKILL.md` or file an issue.

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
- **`pipx`** (or `pip`) — only if you want the Code Review Graph MCP the
  `explorer` persona can query for blast-radius/dependency answers (setup
  step 4); skip it if you don't set that up.

You won't know which of the conditional ones you need until setup asks —
that's expected, see [First-time setup](#first-time-setup) below.

If you have a local clone, `bin/install-deps.sh` installs the two conditional
dependencies (Code Review Graph, mattpocock/skills) idempotently — it skips
whichever is already present, so it's safe to run any time, on either install
path (marketplace or npx), not just once.

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
(`/plugin install <git-url>` directly is not a real command. `antislop-marketplace`
is the marketplace's own name, from `.claude-plugin/marketplace.json`'s
top-level `name` field — not something you choose.)

**If you don't have collaborator access yet** (or just want to try it before
asking for access), you don't need the marketplace at all — both routes below
work against a local clone and are first-class, not "test only":
```
claude --plugin-dir /path/to/your/clone
```
Confirm it worked with `/agents` — you should see `antislop:explorer`,
`antislop:lead-programmer`, etc. in the list (namespaced, because they're
still loaded from the plugin at this point). Then run setup below. Or, if
you'd rather scaffold plain files into your project instead of loading a
plugin at all, see [npx install](#npx-install-alternative) — it needs the
same clone but no marketplace/collaborator step.

Note: plugin agents load under namespaced names (`antislop:explorer`). Bare-name
spawns like `explorer` hard-error — they don't resolve. That's why setup's
first substantive action is copying every selected agent file into the
project's `.claude/agents/`, which are never namespaced.

## First-time setup

Once per project, run:
```
/antislop:setup-personas
```
(If you scaffolded via `npx` instead of the plugin, the bare `/setup-personas`
— no `antislop:` prefix — is what resolves, since it's then a project-local
skill rather than a plugin one. Same command either way in spirit, just
whichever name your setup actually registered.)

It asks which personas the project needs. `explorer` and `lead-programmer` are
mandatory; the rest are opt-in. **Skipping `reviewer` requires an explicit
confirmation** — it's the system's core safety property. Expect it to also
ask: your test/lint command (and what to do if that command doesn't currently
pass — exclude it, or accept a red gate until it's fixed), which protected
paths to lock, which issue tracker to use, and — if `researcher` is selected —
where to find an arXiv MCP server.

**Two things it does NOT do silently, that you should expect to do yourself:**
- **Install third-party skills interactively.** If you select personas that
  use `mattpocock/skills`, setup will tell you which skills to pick *by
  purpose* and ask **you** to run `npx skills@latest add mattpocock/skills`
  in your own terminal — it can't drive that tool's interactive picker
  itself. Don't walk away expecting it to finish unattended.
- **Modify your repo during hook verification.** On a fresh install, setup
  creates a throwaway branch, makes trial edits (including one deliberately
  failing check) to prove the safety hooks actually block/allow correctly,
  then reverts everything and leaves the repo clean. This is expected and
  self-cleaning, not a leftover mess.

It also sets one environment entry, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, in
`.claude/settings.json` — required for the optional `start-feature-team`
command (see [Using AntiSlop](#using-antislop) below); harmless if you never
use that command, and removed along with everything else if you
[uninstall](#removing-antislop).

Full step-by-step flow (written for the agent executing it, not light
reading, but the ground truth if you want it): `skills/setup-personas/SKILL.md`.

**Note a dated cutoff:** projects whose copied `reviewer.md` still writes the
old (pre-v0.2.0) bare-`touch` PASS marker get a grace-period warning instead
of a hard block — **only through 2026-07-27**. After that, `task-gate.sh`
blocks unconditionally on the old format. Run `--update` (below) before then
if your project predates v0.2.0.

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
then run `/setup-personas` (bare — no `antislop:` prefix, since this route
never installed the plugin) to fill in the parts that need a real repo scan
(test/lint commands, protected paths), install third-party skills, build the
Code Review Graph, and run hook verification. Personas load identically either
way — as project-local `.claude/agents/*.md` files.

## Using AntiSlop

Once setup finishes (either install path), there's nothing special to invoke
for normal work: just prompt your main session as usual. It's running as
`orchestrator`, which routes your request to the right persona (`explorer` to
map code, `lead-programmer` to write it, etc.) and reports back — you don't
address personas by name. If a `reviewer` was installed, expect a PASS/FAIL
cycle after implementation work before it's reported done.

To run the same personas as concurrent teammates instead of sequential
subagents, use the `start-feature-team` command — this is the "deliberate
gear" mentioned earlier; it's off by default and you opt in per task by
invoking it explicitly rather than it ever kicking in on its own.

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

| Persona | Default model | Can drop to `fable`? | `maxTurns` |
|---|---|---|---|
| `orchestrator` | inherit | — | uncapped (main session) |
| `explorer` | haiku | — | 10 |
| `lead-programmer` | sonnet | — | 30 |
| `hivemind` | opus | yes, for well-scoped dispatches | 30 |
| `reviewer` | opus | no | 30 |
| `milestone-auditor` | opus | yes, for well-scoped dispatches | 20 |
| `repo-historian` | haiku | — | (not capped separately) |

`hivemind`, `reviewer`, and `milestone-auditor` are the real spend drivers,
not the haiku-tier `explorer`/`repo-historian`. The orchestrator's per-dispatch
routing rule (see orchestrator.md's "Per-unit model routing" subsection) can
send well-scoped `hivemind`/`milestone-auditor` work to `fable` instead of
opus — but worst case is unchanged (both still run on opus if the heuristic
doesn't fire); it only ever makes the common case cheaper, never the worst
case more expensive. The FAIL→fix→re-review loop is separately capped at 2
iterations before escalating to you — there's no budget mode beyond these
caps yet. Check `/cost`; if it's high, look at how often the full
Explore→Plan→Implement→Verify→Commit pipeline runs for work that didn't need
it — the orchestrator's "scale effort to the task" rule is the lever there,
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

## Why this shape

The maintainer's design rationale — CLAUDE.md wiring, plugin frontmatter
limits, the stop-gate's config-driven scoping, the PASS-marker format, drift
mitigations, and known limitations — moved to
[`docs/design.md`](docs/design.md) so it doesn't sit between setup
instructions and Credits for a first-time reader. Nothing there is required
to install or use the plugin.

## Credits — third-party skills & MCPs this plugin builds on

Several personas lean on external skills and tools installed at setup time.
Exact registered skill names drift between package versions — treat these as
the purpose they serve, not a name to search for; `setup-personas` verifies
the actual installed names on disk rather than trusting this list:

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — installed via
  the `skills.sh` installer (`npx skills@latest add mattpocock/skills`).
  Provides a grill/challenge-the-plan skill and a work-to-tracker-tickets skill
  (used by `hivemind`), a TDD skill and a diagnose-a-bug skill (used by
  `lead-programmer`), and an improve-codebase-architecture skill (used by
  `repo-historian`).
- **[code-review-graph](https://github.com/tirth8205/code-review-graph)** — the
  tree-sitter/SQLite structural graph the `explorer` persona queries for
  blast-radius and dependency answers. It's an MCP server (pip/pipx-installed);
  its own `install` command registers project-wide by default, which
  `setup-personas` step 4 deliberately undoes, re-scoping the connection to
  `explorer.md`'s own `mcpServers:` frontmatter so it doesn't leak into every
  persona's context (see [`docs/design.md`](docs/design.md) for why that
  matters). The tool also generates
  `.claude/skills/code-review-graph/` build-graph/review-delta/review-pr
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
