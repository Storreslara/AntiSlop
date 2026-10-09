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

A persona-based Claude Code plugin: a thin orchestrator routes each request to
a specialised agent, an independent reviewer gates every unit of code, and
hooks enforce what prompts alone can't. 

## Install

Requires Claude Code >= 2.1.248, `jq` (every hook needs it), `git`, and `gh`
if GitHub Issues is your tracker. Node.js runs `bin/cli.js`; `pipx` is only
for the optional Code Review Graph MCP (`bin/install-deps.sh` installs it).

```
/plugin marketplace add Storreslara/AntiSlop
/plugin install antislop@antislop-marketplace
/antislop:install-antislop
```

`install-antislop` runs once per project: it asks which personas you want,
writes `.claude/agents/`, `.claude/persona-config.json` and a
`.claude/settings.json` merge, and verifies the hooks. Confirm with `/agents`.
A local clone works too: `claude --plugin-dir /path/to/clone`. After a plugin
upgrade, resync with `/antislop:update-antislop` (deterministic, no LLM cost).

Codex and Cursor: `node /path/to/AntiSlop/bin/cli.js --target=codex` (or
`--target=cursor`) from your project root scaffolds the four core personas.

## Personas and workflow

Prompt the main session as usual. It runs as the orchestrator, which routes to
the right persona and reports back; you never address personas by name.

| Persona | Model | Role |
|---|---|---|
| `orchestrator` | inherit | Always on. Main agent; routes, never implements. |
| `explorer` | haiku | Always on. Structural lookups via the Code Review Graph. |
| `lead-programmer` | haiku | Always on. Implements a dispatched unit TDD-first. |
| `reviewer` | opus | Independent PASS/FAIL verdict; cannot edit code. The core safety property. |
| `spec-master` | opus | Ambiguous goal to spec with machine-checkable criteria. |
| `task-master` | sonnet | Spec to dispatch-ready units, each with a content-typed contract. |
| `scribe` | haiku | Wiki, `CONTEXT.md`, ADRs; never touches source. |
| `milestone-auditor` | opus | Audits the plan, not the code; findings only, no verdict. |
| `agent-auditor` | haiku | Read-only observability over agent activity (`/antislop:audit-agents`). |
| `researcher` | sonnet | Literature search via an arXiv MCP; project-scoped, not a plugin agent. |

The first three are mandatory; the rest are chosen at install. Skipping
`reviewer` removes the only independent check on implementer output and needs
explicit confirmation.

A unit's path: spec-master writes the spec; task-master slices it into units,
each with a dispatch contract scored by `node bin/contract-score.js
--rubric=v2` before handoff; the orchestrator dispatches lead-programmer;
reviewer returns PASS or FAIL. Implementation starts on `haiku` and climbs an
escalation ladder (`haiku`, `sonnet`, `opus`, two attempts per tier): a tier's
second FAIL moves the unit up automatically, and only the second FAIL on
`opus` stops to ask you (ADR-0040). `/antislop:start-feature-team` runs the
personas as concurrent teammates instead; off by default.

## Configuration

`.claude/persona-config.json`, validated against
`templates/persona-config.schema.json`:

| Key | Default | Meaning |
|---|---|---|
| `testAndLintCommand` | — | Command the stop-gate runs; non-zero exit blocks the turn. |
| `protectedPaths` | — | Globs that need human approval before Write/Edit. |
| `gatedAgents` | `["lead-programmer"]` | Personas the stop-gate's test+lint check applies to. |
| `defaultImplementerModel` | `haiku` | Tier the escalation ladder starts from. |
| `humanReviewMode` | `critical` | `critical`: heavy units are escalated to you before PASS; `all`: every PASS; `off`: never. |
| `reviewGating.mode` | `enforce` | `off` makes reviewer verdicts advisory and the review gates inert. Flip with `/antislop:gate off` or `on`. |

`pluginVersion`, `personaSelection`, `substitutions` and `fileHashes` are
written by install and update; leave them alone. The file is protected: an
edit prompts for confirmation and shows as config drift until committed. An
escalated unit lands in `.claude/human-review/<task-id>/`; you resolve it with
a `DECISION` file from the terminal, the dashboard
(`node bin/cli.js --dashboard`), or the orchestrator's proposed heredoc at the
permission prompt (ADR-0004, ADR-0013, ADR-0039).

## Docs

- `CONTEXT.md` — domain glossary. `docs/harness-glossary.md` — gates,
  markers, hooks, dispatch plumbing. `docs/adr/` — decision records.
- `docs/design.md`, `docs/trust-model.md` — residual risks and trust boundary.
- `docs/microworld/README.md`, `docs/microworld-dashboard-capabilities.md` —
  per-unit runnable fixtures and the dashboard.
- `skills/install-antislop/SKILL.md` — full install flow. `CONTRIBUTING.md` —
  contributing; for odd behaviour try `/antislop:update-antislop` first.

Add a persona by dropping a `.md` with a clear `description:` into
`.claude/agents/` (add it to `gatedAgents` if it writes code). To remove
AntiSlop, delete what setup wrote under `.claude/` and `docs/adr/`, revert the
`agent` key and env entry in `.claude/settings.json`, then
`/plugin uninstall antislop`.

## Credits

- [mattpocock/skills](https://github.com/mattpocock/skills) — 12 skills vendored
  under `skills/` (MIT; see `skills/THIRD-PARTY-NOTICES.md`).
- [code-review-graph](https://github.com/tirth8205/code-review-graph) — the
  structural graph MCP `explorer` queries.
- [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)
  — `coding-discipline` is adapted from it.
