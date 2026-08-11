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
#
# The spawn target may arrive namespaced ("<plugin>:<persona>"), so the
# gatedAgents comparison goes through lib/agent-identity.sh's LIBERAL matcher -
# this is a GATE, where a miss fails open and silently stops enforcing.
#
# REVIEW-JOIN STAMP - DEGRADED ON THIS PLATFORM (spec Step 3, porting Step 1).
# The Claude version reads the reviewer's dispatch prompt from
# `.tool_input.prompt` on a PreToolUse(Agent) payload and parses `Unit: <id>`
# off its first non-blank line. This platform's `subagentStart` payload has NO
# DOCUMENTED prompt field - docs/specs/codex-cursor-plugin.md row 10d lists only the spawn
# target's identity and records the shape as unresolved until probed live. The
# block below therefore reads a FALLBACK CHAIN of plausible field names, the
# same shape as the `.agent_id // .agent_type // .session_id` chain stop-gate.sh
# already uses for the unverified caller identity, and is UNVERIFIED here for
# the same reason. If none of them carries the prompt, no `Unit:` line is
# found, no stamp is written, and the stop-gate side fail-opens on bootstrap -
# i.e. exactly the behaviour that preceded this block, never a false block.
# Writing a stamp never changes this hook's exit status on any path.
set -euo pipefail

# shellcheck source=lib/agent-identity.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.cursor/persona-config.json"
review_audit="${project_dir}/.cursor/review-audit.log"

target_type="$(echo "$input" | jq -r '.subagent_type // empty' 2>/dev/null || true)"

if [ -f "$config" ] && [ -n "$target_type" ]; then
  identity_drift_log "$target_type" subagentStart "$review_audit"

  shopt -s nullglob
  pending_flags=( "${project_dir}"/.cursor/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ]; then
    gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
    [ -n "$gated" ] || gated="lead-programmer"

    match=false
    while IFS= read -r name; do
      persona_matches_gate "$name" "$target_type" && match=true
    done <<< "$gated"

    if [ "$match" = true ]; then
      echo "BLOCKED: a completed unit is awaiting review - route it to the reviewer first, or use the defer:/skip: escape in the flag file (.cursor/.pending-review.*), per persona-protocol's Pending-review flag section." >&2
      exit 2
    fi
  fi
fi

if [ -f "$config" ] && persona_matches_gate "$target_type" reviewer; then
  dispatch_name="$(echo "$input" | jq -r '.name // empty' 2>/dev/null || true)"
  if [ -n "$dispatch_name" ]; then
    dispatch_persona="$(identity_persona_name "$dispatch_name")"
    if [ "$dispatch_persona" != "reviewer" ]; then
      echo "BLOCKED: a reviewer dispatch must carry no \`name:\` parameter, or exactly \`name: \"reviewer\"\`. This dispatch's \`name: \"$dispatch_name\"\` will report an \`agent_type\` of '$dispatch_name', which fails the grant matcher. The reviewer will be unable to write its verdict marker or clear the pending-review flag. Fix: re-dispatch with no \`name\` at all, or (in agent-teams mode) with exactly \`name: \"reviewer\"\`." >&2
      exit 2
    fi
  fi

  prompt="$(echo "$input" | jq -r '.prompt // .instructions // .task // empty' 2>/dev/null || true)"
  first_line=""
  while IFS= read -r line; do
    if [ -n "${line//[[:space:]]/}" ]; then first_line="$line"; break; fi
  done <<< "$prompt"

  if [[ $first_line =~ ^Unit:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._#-]{0,63})[[:space:]]*$ ]]; then
    unit_id="${BASH_REMATCH[1]}"
    case "$unit_id" in
      */*|*..*) ;;
      *)
        reviewed_dir="${project_dir}/.cursor/reviewed"
        pass_marker="${reviewed_dir}/${unit_id}.pass"
        pass_valid=false
        if [ -f "$pass_marker" ] && [ -s "$pass_marker" ]; then
          first="$(head -n 1 "$pass_marker")"
          case "$first" in
            "PASS ${unit_id} "*) pass_valid=true ;;
          esac
        fi
        if [ "$pass_valid" = false ]; then
          prior=none
          prior_mtime=-
          fail_marker="${reviewed_dir}/${unit_id}.fail"
          blocked_marker="${reviewed_dir}/${unit_id}.blocked"
          if [ -f "$fail_marker" ]; then
            prior=fail
            prior_mtime="$(stat -L -c %Y "$fail_marker" 2>/dev/null || stat -L -f %m "$fail_marker" 2>/dev/null || echo -)"
          elif [ -f "$blocked_marker" ]; then
            prior=blocked
            prior_mtime="$(stat -L -c %Y "$blocked_marker" 2>/dev/null || stat -L -f %m "$blocked_marker" 2>/dev/null || echo -)"
          fi
          stamp="${project_dir}/.cursor/.review-join.${unit_id}"
          printf '%s unit=%s prior=%s prior_mtime=%s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$unit_id" "$prior" "$prior_mtime" > "$stamp"
          printf 'review-join=%s\n' "$unit_id" >> "$review_audit"
        fi
        ;;
    esac
  fi
fi

exit 0
