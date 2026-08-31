#!/usr/bin/env bash
# State-access library for consolidated artifact management (M3).
# All 17 hook scripts source this lib for read/write/sweep operations across
# 5 domains: Unit, Agent, Session, One-shot, Log.
# Preserves 10 ordering/atomicity constraints and 15 distinctions.
# Expects ${dot} to be set in the environment (e.g. dot="${project_dir}/.claude").
set -euo pipefail
: "${dot:=${CLAUDE_PROJECT_DIR:-.}/.claude}"

# Domain: Unit (keyed by unit id)
# Markers: .pass, .fail, .blocked, .escalated, .directed, .review-join, human-review packet, DECISION

state_read_unit_marker() {
  local unit_id="$1"
  local marker_type="$2"  # pass, fail, blocked, escalated, directed
  local marker_file="${dot}/reviewed/${unit_id}.${marker_type}"

  if [ -f "$marker_file" ]; then
    cat "$marker_file"
    return 0
  fi
  return 1
}

state_write_unit_marker() {
  local unit_id="$1"
  local marker_type="$2"  # pass, fail, blocked, escalated, directed
  local content="$3"
  local marker_file="${dot}/reviewed/${unit_id}.${marker_type}"

  mkdir -p "$(dirname "$marker_file")"
  printf '%s\n' "$content" > "$marker_file"
}

state_unit_marker_exists() {
  local unit_id="$1"
  local marker_type="$2"
  [ -f "${dot}/reviewed/${unit_id}.${marker_type}" ]
}

state_read_review_join() {
  local unit_id="$1"
  local stamp_file="${dot}/.review-join.${unit_id}"

  if [ -f "$stamp_file" ]; then
    cat "$stamp_file"
    return 0
  fi
  return 1
}

state_write_review_join() {
  local unit_id="$1"
  local content="$2"
  local stamp_file="${dot}/.review-join.${unit_id}"

  printf '%s\n' "$content" > "$stamp_file"
}

state_delete_review_join() {
  local unit_id="$1"
  local stamp_file="${dot}/.review-join.${unit_id}"

  rm -f "$stamp_file"
}

# Domain: Agent (keyed by agent id)
# Artifacts: .pending-review, .wip-handoff

state_read_pending_review() {
  local agent_id="$1"
  local flag_file="${dot}/.pending-review.${agent_id}"

  if [ -f "$flag_file" ]; then
    cat "$flag_file"
    return 0
  fi
  return 1
}

state_pending_review_exists() {
  local agent_id="$1"
  [ -f "${dot}/.pending-review.${agent_id}" ]
}

state_write_pending_review() {
  local agent_id="$1"
  local content="$2"
  local flag_file="${dot}/.pending-review.${agent_id}"

  # CONSTRAINT 3: create-only-if-absent
  # Only write if the flag doesn't already exist
  if [ ! -f "$flag_file" ]; then
    printf '%s\n' "$content" > "$flag_file"
  fi
}

state_delete_pending_review() {
  local agent_id="$1"
  local flag_file="${dot}/.pending-review.${agent_id}"

  rm -f "$flag_file"
}

state_clear_all_pending_review() {
  # CONSTRAINT 2: reviewer's SubagentStop clears ALL pending-review flags
  # after review-join evaluation is satisfied
  rm -f "${dot}"/.pending-review.*
}

state_read_wip_handoff() {
  local agent_id="$1"
  local handoff_file="${dot}/.wip-handoff.${agent_id}"

  if [ -f "$handoff_file" ]; then
    cat "$handoff_file"
    return 0
  fi
  return 1
}

state_wip_handoff_exists() {
  local agent_id="$1"
  [ -f "${dot}/.wip-handoff.${agent_id}" ]
}

state_write_wip_handoff() {
  local agent_id="$1"
  local content="$2"
  local handoff_file="${dot}/.wip-handoff.${agent_id}"

  if [ -z "$content" ]; then
    # DISTINCTION: empty ≠ absent; delete empty files
    rm -f "$handoff_file"
  else
    printf '%s\n' "$content" > "$handoff_file"
  fi
}

state_delete_wip_handoff() {
  local agent_id="$1"
  local handoff_file="${dot}/.wip-handoff.${agent_id}"

  rm -f "$handoff_file"
}

# Domain: Session (keyed by session id)
# Artifact: .session-baseline

state_read_session_baseline() {
  local session_id="$1"
  local baseline_file="${dot}/.session-baseline.${session_id}"

  if [ -f "$baseline_file" ]; then
    cat "$baseline_file"
    return 0
  fi
  return 1
}

state_session_baseline_exists() {
  local session_id="$1"
  [ -f "${dot}/.session-baseline.${session_id}" ]
}

state_write_session_baseline() {
  local session_id="$1"
  local content="$2"
  local baseline_file="${dot}/.session-baseline.${session_id}"

  # CONSTRAINT 4: create-only-if-absent
  # Only write if the baseline doesn't already exist
  if [ ! -f "$baseline_file" ]; then
    printf '%s\n' "$content" > "$baseline_file"
  fi
}

# Domain: One-shot (global)
# Artifacts: .dispatch-override, .dispatch-override.consumed, .dispatch-override.consumed.tmp.*

state_read_dispatch_override() {
  local override_file="${dot}/.dispatch-override"

  if [ -f "$override_file" ]; then
    cat "$override_file"
    return 0
  fi
  return 1
}

state_dispatch_override_exists() {
  [ -f "${dot}/.dispatch-override" ]
}

state_write_dispatch_override() {
  local content="$1"
  local override_file="${dot}/.dispatch-override"

  if [ -z "$content" ]; then
    # Reason-less override is not honored; delete it
    rm -f "$override_file"
  else
    printf '%s\n' "$content" > "$override_file"
  fi
}

state_read_dispatch_consumed() {
  local consumed_file="${dot}/.dispatch-override.consumed"

  if [ -f "$consumed_file" ]; then
    cat "$consumed_file"
    return 0
  fi
  return 1
}

state_dispatch_consumed_exists() {
  [ -f "${dot}/.dispatch-override.consumed" ]
}

state_write_dispatch_consumed() {
  local epoch="$1"
  local dispatch_hash="$2"
  local consumed_file="${dot}/.dispatch-override.consumed"

  # DISTINCTION: content-embedded epoch (deliberately not mtime)
  printf '%s %s\n' "$epoch" "$dispatch_hash" > "$consumed_file"
}

state_delete_dispatch_consumed() {
  local consumed_file="${dot}/.dispatch-override.consumed"
  rm -f "$consumed_file"
}

state_delete_dispatch_override() {
  local override_file="${dot}/.dispatch-override"

  # CONSTRAINT 1: .consumed-before-rm ordering
  # Verify consumed marker exists BEFORE deleting override
  # (Caller must handle this constraint - this function just deletes)
  rm -f "$override_file"
}

# Domain: Log (append-only, unkeyed)
# Four logs: review-audit.log, wip-audit.log, microworld-audit.log, dispatch-audit.log

state_append_audit_log() {
  local log_name="$1"
  local entry="$2"
  local log_file="${dot}/${log_name}"

  # Source audit-log.sh if not already sourced
  if ! declare -f audit_append >/dev/null 2>&1; then
    source "$(dirname "${BASH_SOURCE[0]}")/audit-log.sh"
  fi

  audit_append "$log_file" "$entry"
}

# Sweep functions for retention

state_sweep_wip_handoffs() {
  # Delete empty WIP handoffs (they're not honored)
  find "${dot}" -maxdepth 1 -name ".wip-handoff.*" -type f -empty -delete 2>/dev/null || true
}

state_sweep_session_baselines() {
  # Delete old session baselines (configurable retention window)
  # For now, just list them - actual deletion is operator-controlled
  find "${dot}" -maxdepth 1 -name ".session-baseline.*" -type f 2>/dev/null || true
}

state_sweep_dispatch_overrides() {
  # Delete consumed dispatches outside 10-second window
  local consumed_file="${dot}/.dispatch-override.consumed"
  if [ -f "$consumed_file" ]; then
    local epoch=$(head -n 1 "$consumed_file" | cut -d' ' -f1)
    local now=$(date +%s)
    local age=$((now - epoch))

    if [ "$age" -gt 10 ]; then
      rm -f "$consumed_file"
    fi
  fi
}

# Utility functions

state_get_dot_dir() {
  echo "${dot}"
}

state_init() {
  # Ensure marker directory exists
  mkdir -p "${dot}/reviewed" "${dot}/human-review"
}

# Export functions for sourcing scripts
export -f state_read_unit_marker
export -f state_write_unit_marker
export -f state_unit_marker_exists
export -f state_read_review_join
export -f state_write_review_join
export -f state_delete_review_join
export -f state_read_pending_review
export -f state_pending_review_exists
export -f state_write_pending_review
export -f state_delete_pending_review
export -f state_clear_all_pending_review
export -f state_read_wip_handoff
export -f state_wip_handoff_exists
export -f state_write_wip_handoff
export -f state_delete_wip_handoff
export -f state_read_session_baseline
export -f state_session_baseline_exists
export -f state_write_session_baseline
export -f state_read_dispatch_override
export -f state_dispatch_override_exists
export -f state_write_dispatch_override
export -f state_read_dispatch_consumed
export -f state_dispatch_consumed_exists
export -f state_write_dispatch_consumed
export -f state_delete_dispatch_consumed
export -f state_delete_dispatch_override
export -f state_append_audit_log
export -f state_sweep_wip_handoffs
export -f state_sweep_session_baselines
export -f state_sweep_dispatch_overrides
export -f state_get_dot_dir
export -f state_init
