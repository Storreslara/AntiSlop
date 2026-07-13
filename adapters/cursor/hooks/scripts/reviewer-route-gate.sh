#!/usr/bin/env bash
# CURSOR ADAPTER over the shared reviewer-route-gate logic (ported from
# hooks/scripts/reviewer-route-gate.sh). Registered on `subagentStart`, which
# "can allow or deny subagent creation" and carries the SPAWN TARGET's type
# (`.subagent_type`).
#
# IMPORTANT DEGRADATION (spec §6 open q #5): the Cursor `subagentStart` payload
# does NOT carry the CALLING agent's identity - only the target's
# `.subagent_type`. So the Claude version's "lead-programmer may not spawn the
# reviewer directly" block is NOT implementable here (we cannot distinguish a
# lead-programmer spawn of the reviewer from a legitimate orchestrator one).
# That half is therefore INSTRUCTION-ONLY on Cursor - stated in the reviewer
# and lead-programmer bodies and the persona-protocol rule. (Cursor's one-level
# subagent nesting also makes a subagent-spawns-subagent path unlikely in
# practice, but we do not rely on that.)
#
# What IS still enforced mechanically: blocking the dispatch of the NEXT gated-
# agent unit (default lead-programmer) while an earlier completed unit still
# awaits review - the other half of the "done = reviewer PASS" backstop.
# stop-gate.sh sets/clears the `.cursor/.pending-review.*` flag this checks.
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.cursor/persona-config.json"

target_type="$(echo "$input" | jq -r '.subagent_type // empty' 2>/dev/null || true)"

if [ -f "$config" ] && [ -n "$target_type" ]; then
  shopt -s nullglob
  pending_flags=( "${project_dir}"/.cursor/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ]; then
    gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
    [ -n "$gated" ] || gated="lead-programmer"

    match=false
    while IFS= read -r name; do
      [ -n "$name" ] && [ "$name" = "$target_type" ] && match=true
    done <<< "$gated"

    if [ "$match" = true ]; then
      echo "BLOCKED: a completed unit is awaiting review - route it to the reviewer first, or use the defer:/skip: escape in the flag file (.cursor/.pending-review.*), per persona-protocol's Pending-review flag section." >&2
      exit 2
    fi
  fi
fi

exit 0
