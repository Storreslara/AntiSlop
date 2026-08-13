---
name: claude-transcript-store
description: Claude Code already persists every agent dispatch, tool call and skill invocation on disk under ~/.claude/projects/<slug>/ — check here before ever speccing new hook instrumentation to capture agent activity.
metadata:
  type: reference
---

Agent activity is **already fully recorded** by Claude Code itself. Verified
live 2026-08-09 in this repo (38 sessions, 235 MB, 636 dispatches, 15,991
subagent tool calls):

- `~/.claude/projects/<project-slug>/<session-id>.jsonl` — main-session
  transcript; `Agent` dispatches appear as `tool_use` blocks whose `.input`
  carries `subagent_type`, `description`, and optionally `model`, `name`,
  `isolation`.
- `~/.claude/projects/<project-slug>/<session-id>/subagents/agent-<id>.meta.json`
  — `{agentType, description, toolUseId, spawnDepth, model}`, **plus
  `parentAgentId` whenever `spawnDepth >= 1`** (measured 2026-08-12 on a real
  nested spawn: `{"agentType":"reviewer",...,"parentAgentId":"a69bee...","spawnDepth":2}`).
  This pair is what makes a nested spawn reconstructable after the fact.
- `~/.claude/projects/<project-slug>/<session-id>/subagents/agent-<id>.jsonl`
  — every `tool_use` that subagent made. Skill invocations appear as
  `name: "Skill"` with `input: {"skill":"antislop:tdd"}`.
- Agent-teams (teammate) dispatches land under the same `subagents/` dir, and
  a teammate's own nested subagents appear there too.

**Why this matters:** a request to "track what the agents are doing" reads like
it needs new always-on hook instrumentation. It does not. In this repo a new
log file alone must be added to four separate gitignore scaffold lists in
`bin/cli.js`, plus `hooks/hooks.json` and possibly Cursor/Codex adapter
mirrors — whereas reading the transcript store costs nothing, adds no
per-tool-call latency, and works retroactively over all history.

**How to apply:** before speccing any capture mechanism, check what's already
here. The repo's own `.claude/*-audit.log` files are gate-OUTCOME logs
(`dispatch-audit.log` records only *blocked* dispatches), not activity logs —
they complement this store rather than substitute for it.

**Two calibration traps** if you build a detector over it (both measured, not
theoretical):

1. "Tool used outside the persona's declared `tools:`" gives ~98% false
   positives raw — 115 hits, 2 real. A `memory:` field auto-grants
   Read/Write/Edit regardless of `tools:`, and the user-scope auto-memory
   system grants Write even to personas with no `memory:` field (the write
   target is under a `memory/` dir).
2. Dispatched-model != declared-model is **normal**, not an anomaly: 195 of
   636, because `task-master` assigns per-unit model tags. Report it as a
   distribution.

**Do not confuse this store with the hook payload** (measured 2026-08-12,
spec #347). A `PreToolUse:Agent` hook receives a *different, smaller* shape:
top-level `agent_type` (the CALLER's identity) plus `tool_input.subagent_type`
/ `.name` / `.prompt` (the spawn target). It carries **no `spawnDepth` and no
`parentAgentId`** — those live only in the `meta.json` above, i.e. they are
available for post-hoc audit (`scripts/agent-audit.sh` finding A3) but never
for prevention at dispatch time. So when speccing a gate meant to stop a
nested or wrongly-typed spawn, key it on the caller's `agent_type`, which is
already parsed by `reviewer-route-gate.sh` and `reviewed-path-gate.sh`; a spec
that proposes checking `spawnDepth` in a hook is proposing a field that is not
there. Related measured fact: `agent_type` is **empty exactly when**
`settings.json`'s `.agent` is unset, and antislop's ADAPT always sets
`"agent": "orchestrator"` — so `{empty, orchestrator}` is the complete
main-session identity set across all shipped configurations.

Caveat: the format is undocumented and records carry a `version` field, so any
tool reading it needs a format probe that distinguishes "no data" from
"format changed". See [[verify-own-criteria-nonvacuous]] — the calibration
numbers above exist only because the detector was prototyped rather than
reasoned about. Full write-up:
`docs/plans/2026-08-09-agent-auditor-persona.md`.
