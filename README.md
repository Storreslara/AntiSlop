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

AntiSlop is a modular, persona-based Claude Code system packaged as a
reusable plugin. The core loop is three always-on personas — **orchestrator**
(routes requests), **explorer** (maps the code), and **lead-programmer**
(writes it). `spec-master`, `task-master`, `scribe`, `reviewer`,
`milestone-auditor`, and `researcher` are opt-in per project. Shipping it as a plugin means a new project
costs one short setup run instead of re-authoring ~500 lines of persona and
hook prose from scratch.

## Personas

| Persona | Model | Required? | What it does |
|---|---|---|---|
| `orchestrator` | inherit | Always | Thin router/main agent. Never implements, never loads persona skills — routes requests to the right persona and synthesizes results briefly. |
| `explorer` | haiku | Always | Stateless code cartographer. Answers structural questions (where's X defined, what calls Y, blast radius of a change) via the Code Review Graph, returning distilled answers, not raw dumps. The one persona every other persona defers to for structural facts. |
| `lead-programmer` | sonnet | Always | Executes an approved plan step by step, TDD-first, with surgical diffs. Makes small conventional commits as it goes; reports "ready-for-review" when done, never grades its own work. |
| `spec-master` | opus | Opt-in | Turns ambiguous goals into precise specs with machine-checkable acceptance criteria — grills the request against a 9-category ambiguity taxonomy, then publishes a finalized spec. Never writes production code. |
| `task-master` | sonnet | Opt-in | Reads a spec-master finalized spec and slices it into dispatch-ready issues, tagging each unit's model and writing detailed per-unit dispatch prompts for `lead-programmer` and `scribe`. |
| `scribe` | haiku | Opt-in | Maintains the wiki, `CONTEXT.md`, and ADRs — the curated "why" layer the graph can't derive. Never touches source code. |
| `reviewer` | opus | Opt-in (see below) | Independent, adversarial verifier — the Writer/Reviewer split. Did not write the code under review, can't edit it, only returns PASS/FAIL with reasons. **This is the system's core safety property**; skipping it needs an explicit confirmation during setup. |
| `milestone-auditor` | opus (fable for well-scoped dispatches) | Opt-in | Adversarial auditor of the *plan*, not the code — runs at milestone boundaries after every unit has already reviewer-PASSed, hunting for premise gaps and goal drift the reviewer structurally can't see. No PASS/FAIL, no override authority, no Write/Edit — only a findings list relayed to the human. A human pre-audit checkpoint (via `AskUserQuestion`) precedes every dispatch. |
| `researcher` | sonnet | Opt-in, project-scoped only | Bridges academic literature and engineering via an arXiv MCP (or WebSearch fallback) — paper discovery, deep-dive summaries, technique translation briefs for spec-master. Not a plugin agent (see below) since plugin agents ignore `mcpServers`. |

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
  silently no-ops. Install it first.
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
whichever is already present, so it's safe to run any time.

## Install

### Claude Code

Marketplace (recommended):
```
/plugin marketplace add Storreslara/AntiSlop
/plugin install antislop@antislop-marketplace
```
It's a **public** repo — no special access or git auth needed. Confirm
it worked with `/agents` — you should see `antislop:explorer`,
`antislop:lead-programmer`, etc. in the list.

Local-clone alternative:
```
claude --plugin-dir /path/to/your/clone
```

Per-project setup: run `/antislop:install-antislop` — one line; full flow at
`skills/install-antislop/SKILL.md`.

Note: plugin agents load under namespaced names (`antislop:explorer`).
Bare-name spawns like `explorer` hard-error — that's why setup's first
substantive action is copying every selected agent file into the project's
`.claude/agents/`, which are never namespaced.

### Codex

```
git clone https://github.com/Storreslara/AntiSlop.git
node AntiSlop/bin/cli.js --target=codex
```
Run from your project root (the clone becomes a subdirectory). Scaffolds
`.codex/` with the MVP four personas (`orchestrator`, `explorer`,
`lead-programmer`, `reviewer`).

### Cursor

```
git clone https://github.com/Storreslara/AntiSlop.git
node AntiSlop/bin/cli.js --target=cursor
```
Run from your project root. Scaffolds `.cursor/` with the same MVP four
personas.

## First-time setup

Once per project (Claude Code target), run:
```
/antislop:install-antislop
```
It asks which personas the project needs — `explorer` and `lead-programmer`
are mandatory, the rest opt-in. **Skipping `reviewer` requires an explicit
confirmation** — it's the system's core safety property.

Two things it does NOT do silently:
- **Install third-party skills interactively** — it tells you which skills
  to pick by purpose and asks you to run `npx skills@latest add
  mattpocock/skills` yourself.
- **Modify your repo during hook verification** — trial edits on a
  throwaway branch prove the safety hooks work, then everything is reverted.

Re-sync after plugin updates with `/antislop:update-antislop`
(deterministic, near-zero token cost).

Full step-by-step flow and deeper caveats (the agent-teams env var, the
dated pre-v0.2.0 grace-period note): `skills/install-antislop/SKILL.md`.

## Using AntiSlop

Once setup finishes, there's nothing special to invoke for normal work: just
prompt your main session as usual. It's running as `orchestrator`, which
routes your request to the right persona (`explorer` to map code,
`lead-programmer` to write it, etc.) and reports back — you don't address
personas by name. If a `reviewer` was installed, expect a PASS/FAIL cycle
after implementation work before it's reported done.

To run the same personas as concurrent teammates instead of sequential
subagents, use the `start-feature-team` command — this is the "deliberate
gear" mentioned earlier; it's off by default and you opt in per task by
invoking it explicitly rather than it ever kicking in on its own.

## What ships in the plugin vs. what setup writes per-project

| Ships once (plugin) | Written per-project (setup) |
|---|---|
| Persona agents: orchestrator, explorer, lead-programmer (always); spec-master, task-master, scribe, reviewer, milestone-auditor (opt-in) | `researcher.md` (needs `mcpServers`, which plugin agents ignore entirely) + persona selection |
| `coding-discipline` skill | `.claude/persona-config.json` (test/lint/build commands, protected/gated paths, issue tracker, plugin version stamp) |
| `install-antislop` skill (the fresh-install flow; also the `--update` fallback for pre-migration projects) + `bin/cli.js --update` (the normal, deterministic resync path) | the protocol inlined per-persona into each `.claude/agents/*.md` body (setup strips any legacy `@import` line from CLAUDE.md rather than writing one) + `.claude/protocol-digest.md` (short resume/compact re-anchor, injected only by `session-start.sh`, not imported into CLAUDE.md) |
| 7 hooks (generic scripts reading runtime config) | `.claude/settings.json` merge (plugins can't ship settings at all) |
| `start-feature-team`, `update-antislop` commands | wiki / CONTEXT.md / docs/adr seeding |
| — | `.claude/constitution.md` (opt-in, project-authored principles doc — never touched by `--update`) |

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

## Removing AntiSlop

Setup writes to these locations; removing all of them uninstalls the system
from a project:
- `.claude/agents/*.md` (the copied persona files)
- `.claude/protocol-digest.md`
- `.claude/persona-config.json`
- `.claude/constitution.md` (if created — opt-in, see "First-time setup")
- `.claude/wiki/`, `CONTEXT.md`, `docs/adr/` (if `scribe` was selected)
- `.claude/settings.json`'s `"agent": "orchestrator"` key, the
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env entry, and the permissions it added
- `.claude/reviewed/`, `.claude/wip-handoff.*`, `.claude/.session-baseline.*`,
  `.claude/wip-audit.log`, `.claude/.pending-review.*`,
  `.claude/review-audit.log` (also in `.gitignore` — safe to delete)
- `/plugin uninstall antislop` to remove the plugin itself

## Credits — third-party skills & MCPs this plugin builds on

Several personas lean on external skills and tools installed at setup time.
Exact registered skill names drift between package versions — treat these as
the purpose they serve, not a name to search for; `install-antislop` verifies
the actual installed names on disk rather than trusting this list:

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — 12 skills
  (`grill-me`, `grilling`, `handoff`, `to-spec`, `to-tickets`, `tdd`,
  `diagnosing-bugs`, `improve-codebase-architecture`, `codebase-design`,
  `domain-modeling`, `implement`, `code-review`) are now vendored first-party
  under `skills/` — no external install step required. MIT licensed; see
  [`skills/THIRD-PARTY-NOTICES.md`](skills/THIRD-PARTY-NOTICES.md) for the
  full license text and the pinned upstream commit.
- **[code-review-graph](https://github.com/tirth8205/code-review-graph)** — the
  tree-sitter/SQLite structural graph the `explorer` persona queries for
  blast-radius and dependency answers. It's an MCP server (pip/pipx-installed);
  its own `install` command registers project-wide by default, which
  `install-antislop` step 4 deliberately undoes, re-scoping the connection to
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
- `skills/fail-triage/SKILL.md` is a first-party skill derived from
  [mattpocock/skills](https://github.com/mattpocock/skills)' `triage` skill,
  scoped to this project's post-FAIL debug-spec path (used by `spec-master`).
- **arXiv MCP** — powers the `researcher` persona. Deliberately not pinned to a
  specific server here; `install-antislop` step 5 has you find and wire in a
  currently-maintained one at setup time, since "currently maintained" is a
  moving target this repo shouldn't hardcode.

## Contributing / issues

See `CONTRIBUTING.md`. The bug report template asks for your Claude Code
version, the plugin version vs. your project's adapted version, and whether the
bug is in a plugin-shipped file or a copied project file — version drift is
the likely root cause of a lot of reports, so it's worth checking `--update`
first.
