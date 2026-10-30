#!/usr/bin/env bash
# Port-invariant stop-gate decision logic, sourced by all three ports' stop-gate.sh. Hand-edit only
# here; adapters/*/hooks/scripts/lib/stop-gate-core.sh are generated (node bin/cli.js --update
# --force-render).
#
# Caller contract (set before sourcing, with lib/agent-identity.sh and lib/state-access.sh loaded):
#  - project_dir, dot (the port's dot-dir), dot_label (its relative form, for messages), config,
#    review_audit.
#  - hook_event, normalized to "Stop" or "SubagentStop"; agent_type, the (sub)agent identity;
#    raw_agent_id, unsanitized; main_agent_name, the main-agent identity on a "Stop".
#  - block() and allow(): every decision ends in one of them, because the loop guard is per port.
#
# Rules, in order:
#  1) reviewGating.mode "off" -> allow.
#  2) this project's reviewer's SubagentStop -> delete every pending-review flag, whatever the
#     verdict, and allow.
#  3) main Stop -> block while a flag's first line starts with neither "skip: <reason>" nor
#     "defer: <reason>". skip: is logged and deletes its flag; defer: is logged and keeps it.
#  4) a stop by an agent not in gatedAgents (default lead-programmer) -> allow.
#  5) a non-empty WIP sentinel -> log, delete, allow.
#  6) a gated SubagentStop -> block, naming the file, when a *.pass, *.fail or *.blocked marker is
#     newer than reviewed/.writer-dispatch-stamp (touched by dispatch-hygiene.sh at each gated
#     dispatch; no stamp, no check); otherwise write the flag.
set -euo pipefail

utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

if [ "$(jq -r '.reviewGating.mode // "enforce"' "$config" 2>/dev/null || echo enforce)" = "off" ]; then
  allow
fi

identity_drift_log "$agent_type" "$hook_event" "$review_audit"

if [ "$hook_event" = "SubagentStop" ] && [ "$(identity_persona_name "$agent_type")" = "reviewer" ]; then
  if persona_matches_grant "$agent_type" reviewer; then
    for flag in "${dot}"/.pending-review.*; do
      [ -f "$flag" ] && state_delete_pending_review "${flag##*/.pending-review.}"
    done
    state_append_audit_log "review-audit.log" "$(utc) cleared-by=reviewer"
    allow
  fi
  echo "Reviewer identity '${agent_type}' is not this project's reviewer (unrecognized namespace) - pending-review flags were NOT cleared. Dispatch this project's own reviewer, or write 'defer: <reason>' or 'skip: <reason>' into a flag that exists." >&2
fi

if [ "$hook_event" = "Stop" ]; then
  blocked=false
  for flag in "${dot}"/.pending-review.*; do
    [ -f "$flag" ] || continue
    first="$(head -n 1 "$flag" 2>/dev/null || true)"
    case "$first" in
      "defer: "*[![:space:]]*)
        # defer: is sticky, so log it only when it differs from the last logged line.
        last_logged="$(tail -n 1 "$review_audit" 2>/dev/null | cut -d' ' -f2- || true)"
        [ "$last_logged" = "$first" ] || state_append_audit_log "review-audit.log" "$(utc) ${first}"
        ;;
      "skip: "*[![:space:]]*)
        state_append_audit_log "review-audit.log" "$(utc) ${first}"
        state_delete_pending_review "${flag##*/.pending-review.}"
        ;;
      *) blocked=true ;;
    esac
  done
  if [ "$blocked" = true ]; then
    block "Unit awaiting review. Dispatch reviewer, or: printf \"defer|skip: <reason>\\n\" > ${dot_label}/.pending-review.<agent-id> (defer: sticky/owed, skip: delete/abandon). Empty reason rejected. Write defer:/skip: only into a flag that currently exists."
  fi
fi

[ -f "$config" ] || allow
gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
[ -n "$gated" ] || gated="lead-programmer"
if [ "$hook_event" = "SubagentStop" ]; then check_name="$agent_type"; else check_name="$main_agent_name"; fi
# Liberal on both sides: a miss here fails open.
match=false
while IFS= read -r name; do
  [ -n "$name" ] && persona_matches_gate "$name" "$check_name" && match=true
done <<< "$gated"
[ "$match" = true ] || allow

agent_id="${raw_agent_id//[^a-zA-Z0-9._-]/_}"
sentinel="${dot}/wip-handoff.${agent_id}"
if state_wip_handoff_exists "$agent_id"; then
  reason="$(state_read_wip_handoff "$agent_id")"
  state_delete_wip_handoff "$agent_id"
  if [ -n "$reason" ]; then
    state_append_audit_log "wip-audit.log" "$(printf '%s agent=%s reason=%s' "$(utc)" "$agent_id" "$reason")"
    allow
  fi
  echo "WIP sentinel at ${sentinel} is empty - a reason is required (e.g. 'echo \"blocked on X\" > ${sentinel}'). Ignoring it." >&2
fi

[ "$hook_event" = "SubagentStop" ] || allow

stamp="${dot}/reviewed/.writer-dispatch-stamp"
if [ -f "$stamp" ]; then
  for marker in "${dot}"/reviewed/*.pass "${dot}"/reviewed/*.fail "${dot}"/reviewed/*.blocked; do
    if [ "$marker" -nt "$stamp" ]; then
      block "A verdict marker appeared during this writer's dispatch: ${dot_label}/reviewed/${marker##*/}. Only the reviewer writes verdict markers. Report this to your dispatcher and wait."
    fi
  done
fi

state_write_pending_review "$agent_id" "$(printf '%s agent=%s' "$(utc)" "$agent_id")"
allow
