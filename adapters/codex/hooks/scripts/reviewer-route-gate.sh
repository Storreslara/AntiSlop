#!/usr/bin/env bash
# CODEX ADAPTER over the shared reviewer-route-gate logic (ported from
# hooks/scripts/reviewer-route-gate.sh via adapters/cursor/hooks/scripts/
# reviewer-route-gate.sh). Registered on `SubagentStart`.
#
# IMPORTANT DEGRADATION (docs/specs/codex-plugin.md §6, §12 #2 - UNRESOLVED):
# Codex's `SubagentStart` payload is confirmed to carry `.agent_id`/
# `.agent_type` for the subagent being spawned (the SPAWN TARGET), but no
# field distinct from those has been confirmed to carry the CALLING agent's
# identity. So, same as the Cursor port, the "lead-programmer may not spawn
# the reviewer directly" block is NOT implementable here with confidence (we
# cannot distinguish a lead-programmer spawn of the reviewer from a
# legitimate orchestrator one). That half is therefore INSTRUCTION-ONLY on
# Codex - stated in the reviewer/lead-programmer/orchestrator bodies and
# agents-md-fragment.md.
#
# What IS still enforced mechanically: blocking the dispatch of the NEXT
# gated-agent unit (default lead-programmer) while an earlier completed unit
# still awaits review - the other half of the "done = reviewer PASS"
# backstop. stop-gate.sh sets/clears the `.codex/.pending-review.*` flag this
# checks.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.codex/persona-config.json"
review_audit="${project_dir}/.codex/review-audit.log"

target_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

if [ -f "$config" ] && [ -n "$target_type" ]; then
  identity_drift_log "$target_type" SubagentStart "$review_audit"
  shopt -s nullglob
  pending_flags=( "${project_dir}"/.codex/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ]; then
    gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
    [ -n "$gated" ] || gated="lead-programmer"

    # Liberal on both sides, as at the stop-gate's gatedAgents check: a miss
    # here fails OPEN (the next gated unit dispatches while review is owed).
    match=false
    while IFS= read -r name; do
      [ -n "$name" ] && persona_matches_gate "$name" "$target_type" && match=true
    done <<< "$gated"

    if [ "$match" = true ]; then
      echo "BLOCKED: a completed unit is awaiting review - route it to the reviewer first, or use the defer:/skip: escape in the flag file (.codex/.pending-review.*), per the persona protocol's Pending-review flag section." >&2
      exit 2
    fi
  fi
fi

exit 0
