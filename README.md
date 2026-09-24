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

AntiSlop is a persona-based Claude Code system packaged as a reusable plugin.
Three always-on personas form the core loop — **orchestrator** (routes
requests), **explorer** (maps the code), and **lead-programmer** (writes it) —
and the rest are opt-in per project. A new project costs one short setup run.

## Personas

| Persona | Model | Required? | What it does |
|---|---|---|---|
| `orchestrator` | inherit | Always | Thin router / main agent. Never implements; routes to the right persona and summarizes. |
| `explorer` | haiku | Always | Stateless code cartographer: where is X, what calls Y, blast radius of Z. Uses the Code Review Graph. |
| `lead-programmer` | sonnet | Always | Executes an approved plan TDD-first with surgical diffs and small commits. Never grades its own work. |
| `spec-master` | opus | Opt-in | Turns ambiguous goals into specs with machine-checkable acceptance criteria. Never writes production code. |
| `task-master` | sonnet | Opt-in | Slices a finalized spec into dispatch-ready issues with per-unit prompts. |
| `scribe` | haiku | Opt-in | Maintains the wiki, `CONTEXT.md`, and ADRs. Never touches source. |
| `reviewer` | opus | Opt-in | Independent adversarial verifier — returns PASS/FAIL, can't edit the code. **The core safety property**; skipping it needs explicit confirmation at setup. |
| `milestone-auditor` | opus | Opt-in | Audits the *plan*, not the code, at milestone boundaries. Findings only — no verdict, no override. |
| `researcher` | sonnet | Opt-in, project-scoped | Literature search and technique briefs via an arXiv MCP (or WebSearch). Not a plugin agent — plugin agents ignore `mcpServers`. |
| `agent-auditor` | haiku | Opt-in | Read-only observability over agent activity. Flags anomalies; never gates or fixes. |

The `start-feature-team` command runs the same personas as concurrent
teammates instead of sequential subagents — off by default.

## Requirements

- **Claude Code ≥ 2.1.248** — a hard pin; no fallback for older versions.
- **`jq`** — every hook depends on it. Without it, hooks silently no-op.
- **Node.js / `npx`** — for the `mattpocock/skills` installer, if a selected
  persona uses one.
- **`git`**, plus **`gh`** if you pick GitHub Issues as your tracker.
- **`pipx`** (or `pip`) — only for the optional Code Review Graph MCP.

With a local clone, `bin/install-deps.sh` installs the two conditional
dependencies idempotently.

## Install

### Claude Code

Marketplace (recommended):
```
/plugin marketplace add Storreslara/AntiSlop
/plugin install antislop@antislop-marketplace
```
Public repo, no auth needed. Confirm with `/agents` — you should see
`antislop:explorer`, `antislop:lead-programmer`, etc.

Local-clone alternative:
```
claude --plugin-dir /path/to/your/clone
```

Plugin agents load under namespaced names (`antislop:explorer`); setup copies
every selected agent into the project's `.claude/agents/`, which are not.

### Codex

```
git clone https://github.com/Storreslara/AntiSlop.git
node AntiSlop/bin/cli.js --target=codex
```
Run from your project root. Scaffolds `.codex/` with the MVP four personas
(`orchestrator`, `explorer`, `lead-programmer`, `reviewer`).

### Cursor

```
git clone https://github.com/Storreslara/AntiSlop.git
node AntiSlop/bin/cli.js --target=cursor
```
Run from your project root. Scaffolds `.cursor/` with the same MVP four.

## First-time setup

Once per project (Claude Code target):
```
/antislop:install-antislop
```
It asks which personas the project needs, wires hooks and config, and verifies
the safety hooks on a throwaway branch (everything reverted afterwards). It
does not install third-party skills for you — it tells you which to pick and
asks you to run `npx skills@latest add mattpocock/skills` yourself.

Re-sync after plugin updates with `/antislop:update-antislop` (deterministic,
near-zero token cost). Full flow: `skills/install-antislop/SKILL.md`.

## Using AntiSlop

Just prompt your main session as usual. It runs as `orchestrator`, which
routes your request to the right persona and reports back — you don't address
personas by name. If a `reviewer` is installed, expect a PASS/FAIL cycle after
implementation work before it's reported done.

### Human review of critical units (`humanReviewMode`)

**On by default.** When a `reviewer` is installed, a unit it would have passed
is instead escalated to you if it meets the heavy-unit trigger: the reviewer
snapshots the unit into `.claude/human-review/<task-id>/` (with `PACKET.md`,
a literate `CHANGES.md`, and worked `EXAMPLES.md` — skipped, with a one-line
reason recorded on the escalation marker, for pure docs/formatting/comment/
rename changes with no behavioral surface) and turn-end blocks until you
decide. The knob is `humanReviewMode` in `.claude/persona-config.json`:

| Value | Behaviour |
|---|---|
| `critical` | **Default.** Escalate only units meeting the heavy-unit trigger (ADR-0004, as amended by ADR-0013). |
| `all` | Escalate every would-be PASS. |
| `off` | Never escalate. |

An absent or unrecognised value resolves to `critical` — it fails toward
asking you, never toward silently approving. The friction is the feature: this
is the one place the system is designed to cost you time.

## Microworld bundles

A **microworld bundle** is a per-unit runnable fixture under
`microworlds/<unit-slug>/`: a `manifest.json` (`unit`, `watch` globs,
`description`, `timeoutSeconds`), a `run.sh` (exit 0 = pass — the only
execution contract), plus `inputs/`, `expected/`, and a one-screen `README.md`.
`lead-programmer` produces one alongside a unit; `reviewer` runs it.

Bundles are gitignored working-tree scratch — never committed, not part of the
reviewed diff, and expected to be absent in a fresh clone. A `PostToolUse` hook
reruns `run.sh` on edits matching `watch` and surfaces failures as feedback,
never a block. Results are advisory unless a spec step's acceptance criteria
names the `run.sh` explicitly. More in `docs/microworld/README.md`.

## Microworld dashboard

A browser-based workbench for exploring bundles, invoking their declared
functions, and resolving escalation decisions:

```
node bin/cli.js --dashboard
```

It binds to loopback on an ephemeral port and prints a per-launch token to
your terminal; every request needs it (`?t=<token>` or `X-Antislop-Token`).
Writing a DECISION file requires a confirmation code delivered to your
controlling terminal, so a human must be present at decision time. For CI or
containers without a terminal, `--dashboard-no-tty` starts a read-only mode.
The dashboard is never a gate. Route inventory and the trust boundary:
`docs/microworld-dashboard-capabilities.md`, `docs/trust-model.md`.

## Known limitations

Residual risks, gate edge cases, and accepted trade-offs live in
[`docs/design.md`](docs/design.md), [`docs/trust-model.md`](docs/trust-model.md),
and the ADRs under [`docs/adr/`](docs/adr/).

## What ships in the plugin vs. what setup writes per-project

| Ships once (plugin) | Written per-project (setup) |
|---|---|
| Persona agents: orchestrator, explorer, lead-programmer (always); the rest (opt-in) | Persona selection + `.claude/persona-config.json` (commands, protected/gated paths, tracker, plugin version stamp) |
| `coding-discipline` skill + the other vendored skills | The protocol inlined into each `.claude/agents/*.md` body + `.claude/protocol-digest.md` |
| `install-antislop` skill (fresh install + `--update` fallback) and `bin/cli.js --update` (the normal resync path) | `.claude/settings.json` merge (plugins can't ship settings at all) |
| 7 hooks (generic scripts reading runtime config) | wiki / `CONTEXT.md` / `docs/adr/` seeding (if `scribe` selected) |
| `start-feature-team`, `update-antislop` commands | `.claude/constitution.md` (opt-in, never touched by `--update`) |

## Adding your own persona

- Drop a new `.md` file in `.claude/agents/` with a clear `description:` —
  auto-delegation picks it up.
- If it writes code, add its name to `gatedAgents` in
  `.claude/persona-config.json` so the stop-gate checks its work.
- To route to it by name, add one line to the project's `orchestrator.md`
  routing table.

## Removing AntiSlop

Delete what setup wrote:
- `.claude/agents/*.md`, `.claude/protocol-digest.md`,
  `.claude/persona-config.json`, `.claude/constitution.md` (if created)
- `.claude/wiki/`, `CONTEXT.md`, `docs/adr/` (if `scribe` was selected)
- `.claude/settings.json`'s `"agent": "orchestrator"` key, the
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env entry, and the permissions it added
- `.claude/reviewed/`, `.claude/wip-handoff.*`, `.claude/.session-baseline.*`,
  `.claude/wip-audit.log`, `.claude/.pending-review.*`, `.claude/review-audit.log`
- `/plugin uninstall antislop` for the plugin itself

## Credits

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — 12 skills
  vendored first-party under `skills/` (MIT; see
  [`skills/THIRD-PARTY-NOTICES.md`](skills/THIRD-PARTY-NOTICES.md)).
  `skills/fail-triage` is derived from its `triage` skill.
- **[code-review-graph](https://github.com/tirth8205/code-review-graph)** — the
  structural graph MCP `explorer` queries; setup scopes it to `explorer` alone.
- **[andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)**
  — the `coding-discipline` skill is adapted from it.
- **arXiv MCP** — powers `researcher`; not pinned, wired in at setup time.

## Contributing / issues

See `CONTRIBUTING.md`. Version drift between plugin and project is the likely
root cause of many reports — try `/antislop:update-antislop` first.
