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
#  - writer_lane (optional, read as ${writer_lane:-}): the stopping writer's dispatch-lane record lane,
#    set only on an exact record match; only the Claude entry script sets it.
#  - block() and allow(): every decision ends in one of them, because the loop guard is per port.
#
# Rules, in order:
#  1) reviewGating.mode "off" -> allow.
#  2) this project's reviewer's SubagentStop -> delete every pending-review flag, whatever the
#     verdict, and allow.
#  3) main Stop -> block while a flag's first line starts with none of "skip: <reason>", "defer: <reason>"
#     or "review-dispatched: ". skip: is logged and deletes its flag; defer: is logged and keeps it;
#     review-dispatched: keeps it, logs nothing. The block text names unit-bookkeeping.sh when present.
#  4) a stop by an agent not in gatedAgents (default lead-programmer) -> allow.
#  5) a non-empty WIP sentinel -> log, delete, allow. On a SubagentStop the marker check (rule 6) runs
#     first: when it trips, the sentinel is deleted and logged "wip-ignored d6-trip agent=<id>" to
#     wip-audit.log, not honoured, and rule 6 follows.
#  6) a gated SubagentStop -> write the flag (when writer_lane is "small", write none and log
#     "small-lane agent=<id> no-flag" to review-audit.log, unless the marker check trips: then
#     write it and log "small-lane d6-trip agent=<id> flag"), then block, naming the file, when a
#     *.pass, *.fail or *.blocked marker is newer than reviewed/.writer-dispatch-stamp (touched by
#     dispatch-hygiene.sh at each gated dispatch; no stamp, no check; small lane included). The flag
#     comes first because the loop-guarded stop after a block is allowed without reaching this rule.
#     It replaces whatever stands at the flag path (state_replace_pending_review); when nothing can be
#     written there, block, naming the path.
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
  ns_tail="write 'defer: <reason>' or 'skip: <reason>' into a flag that exists."
  [ ! -f "${dot}/bin/unit-bookkeeping.sh" ] \
    || ns_tail="run: bash ${dot_label}/bin/unit-bookkeeping.sh flag defer|skip <reason> (existing flags only)."
  echo "Reviewer identity '${agent_type}' is not this project's reviewer (unrecognized namespace) - pending-review flags were NOT cleared. Dispatch this project's own reviewer, or ${ns_tail}" >&2
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
      "review-dispatched: "*) ;;
      *) blocked=true ;;
    esac
  done
  if [ "$blocked" = true ]; then
    if [ -f "${dot}/bin/unit-bookkeeping.sh" ]; then
      block "Unit awaiting review. Dispatch reviewer, or: bash ${dot_label}/bin/unit-bookkeeping.sh flag <defer|skip> <reason> (defer: sticky/owed, skip: delete/abandon). Empty reason rejected. Only works on a flag that currently exists."
    fi
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
stamp="${dot}/reviewed/.writer-dispatch-stamp"
tripped=""
if [ "$hook_event" = "SubagentStop" ] && [ -f "$stamp" ]; then
  for marker in "${dot}"/reviewed/*.pass "${dot}"/reviewed/*.fail "${dot}"/reviewed/*.blocked; do
    if [ "$marker" -nt "$stamp" ]; then tripped="$marker"; break; fi
  done
fi
if [ -n "$tripped" ] && state_wip_handoff_exists "$agent_id"; then
  state_delete_wip_handoff "$agent_id"
  state_append_audit_log "wip-audit.log" "$(utc) wip-ignored d6-trip agent=${agent_id}"
elif state_wip_handoff_exists "$agent_id"; then
  reason="$(state_read_wip_handoff "$agent_id")"
  state_delete_wip_handoff "$agent_id"
  if [ -n "$reason" ]; then
    state_append_audit_log "wip-audit.log" "$(printf '%s agent=%s reason=%s' "$(utc)" "$agent_id" "$reason")"
    allow
  fi
  echo "WIP sentinel at ${sentinel} is empty - a reason is required (e.g. 'echo \"blocked on X\" > ${sentinel}'). Ignoring it." >&2
fi

[ "$hook_event" = "SubagentStop" ] || allow

if [ "${writer_lane:-}" = "small" ] && [ -z "$tripped" ]; then
  state_append_audit_log "review-audit.log" "$(utc) small-lane agent=${agent_id} no-flag"
else
  state_replace_pending_review "$agent_id" "$(printf '%s agent=%s' "$(utc)" "$agent_id")" \
    || block "Could not write the pending-review flag ${dot_label}/.pending-review.${agent_id} (a directory or an unwritable path stands there). Report this to your dispatcher and wait."
  [ "${writer_lane:-}" != "small" ] || state_append_audit_log "review-audit.log" "$(utc) small-lane d6-trip agent=${agent_id} flag"
fi
if [ -n "$tripped" ]; then
  block "A verdict marker appeared during this writer's dispatch: ${dot_label}/reviewed/${tripped##*/}. Only the reviewer writes verdict markers. Report this to your dispatcher and wait."
fi

allow
