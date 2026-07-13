#!/usr/bin/env bash
# PreToolUse (Agent). Mechanically enforces the "lead-programmer never spawns
# or messages the reviewer directly" rule from persona-protocol.md's Review
# Ownership section, instead of leaving it instruction-only. Also blocks
# dispatching the NEXT gated-agent unit while an earlier one still awaits
# review (the other half of the default-mode "done = reviewer PASS"
# backstop - stop-gate.sh sets/clears the flag this checks; see
# templates/persona-protocol.md's "Pending-review flag" section).
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
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"

agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"
target_type="$(echo "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)"

if [ "$agent_type" = "lead-programmer" ] && [ "$target_type" = "reviewer" ]; then
  echo "BLOCKED: lead-programmer may not spawn the reviewer directly. Report 'ready-for-review' and let the orchestrator (or team lead) route it, per persona-protocol.md's Review Ownership section." >&2
  exit 2
fi

if [ -f "$config" ]; then
  shopt -s nullglob
  pending_flags=( "${project_dir}"/.claude/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ]; then
    gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
    [ -n "$gated" ] || gated="lead-programmer"

    match=false
    while IFS= read -r name; do
      [ -n "$name" ] && [ "$name" = "$target_type" ] && match=true
    done <<< "$gated"

    if [ "$match" = true ]; then
      echo "BLOCKED: a completed unit is awaiting review - route it to the reviewer first, or use the defer:/skip: escape in the flag file (.claude/.pending-review.*), per persona-protocol.md's Pending-review flag section." >&2
      exit 2
    fi
  fi
fi

exit 0
