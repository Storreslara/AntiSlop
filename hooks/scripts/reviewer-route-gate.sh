#!/usr/bin/env bash
# PreToolUse (Agent). Mechanically enforces the "lead-programmer never spawns
# or messages the reviewer directly" rule from persona-protocol.md's Review
# Ownership section, instead of leaving it instruction-only.
#
# Confirmed empirically (not assumed) that a nested Agent-tool call carries
# both the CALLING agent's identity and the call's own tool_input: when a
# subagent invokes the Agent tool, PreToolUse's JSON payload includes a
# top-level `agent_type` (the caller) alongside `tool_input.subagent_type`
# (the spawn target) - the same attribution CHANGELOG 0.3.0 left unverified.
# This only covers the `Agent` tool (a direct spawn attempt); it does not
# cover SendMessage to an existing reviewer teammate in agent-teams mode -
# that's a different tool with a different payload shape, out of scope here.
set -euo pipefail

input="$(cat)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"
target_type="$(echo "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)"

if [ "$agent_type" = "lead-programmer" ] && [ "$target_type" = "reviewer" ]; then
  echo "BLOCKED: lead-programmer may not spawn the reviewer directly. Report 'ready-for-review' and let the orchestrator (or team lead) route it, per persona-protocol.md's Review Ownership section." >&2
  exit 2
fi
exit 0
