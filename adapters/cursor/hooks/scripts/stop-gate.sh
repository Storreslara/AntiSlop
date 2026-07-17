#!/usr/bin/env bash
# CURSOR ADAPTER over the shared stop-gate logic (ported from
# hooks/scripts/stop-gate.sh - the ordered decision logic is identical; only
# the payload field extraction and the loop guard differ). Registered on
# `stop` (main session) AND `subagentStop`. Gating is config-driven via
# persona-config.json's gatedAgents list (default ["lead-programmer"]).
#
# Cursor payload differences vs Claude (spec §3, §6 open q #5):
#  - `hook_event_name` is "stop" | "subagentStop" (camelCase).
#  - the caller-agent identity on subagentStop is `.subagent_type` (Claude's
#    `.agent_type`). CONFIRMED present per cursor.com/docs/hooks.
#  - the plain `stop` payload carries NO agent identity (same as Claude), so
#    that case keys off the configured main agent - read here from
#    persona-config.json's `mainAgent` (default "orchestrator"), since Cursor
#    has no settings.json `.agent` key.
#  - there is no `stop_hook_active`; the infinite-loop guard keys off Cursor's
#    `.loop_count` instead.
#  - there is no per-subagent id on subagentStop, so the pending-review flag is
#    keyed by `subagent_type` (LIMITATION: two concurrent same-type subagents
#    would share one flag - acceptable for the sequential MVP flow).
#  - session/baseline id is `.conversation_id` (Claude's `.session_id`).
#
# Ordered logic (identical to the Claude version):
#  0) loop guard - never re-trigger ourselves into an infinite loop.
#  0.5) reviewer's subagentStop -> CLEAR every pending-review flag, log, ALLOW.
#  0.75) main stop with any pending-review flag -> BLOCK (defer:/skip: escape).
#  1) non-gated stop/subagentStop -> ALLOW immediately.
#  2) per-agent WIP sentinel with a non-empty reason -> log, delete, ALLOW.
#  2.5) a gated subagentStop reaching here -> CREATE the pending-review flag
#     if absent (idempotent: does not clobber an existing defer:/skip:).
#  3) tree clean AND no commits since baseline -> ALLOW.
#  4) otherwise run the configured test+lint command; non-zero -> BLOCK.
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.cursor/persona-config.json"
review_audit="${project_dir}/.cursor/review-audit.log"

loop_count="$(echo "$input" | jq -r '.loop_count // 0' 2>/dev/null || echo 0)"
case "$loop_count" in ''|*[!0-9]*) loop_count=0 ;; esac
[ "$loop_count" -ge 5 ] && exit 0

hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.subagent_type // empty' 2>/dev/null || true)"

if [ "$hook_event" = "subagentStop" ] && [ "$agent_type" = "reviewer" ]; then
  [ -f "$config" ] || exit 0
  rm -f "${project_dir}"/.cursor/.pending-review.* 2>/dev/null || true
  printf '%s cleared-by=reviewer\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
  exit 0
fi

if [ "$hook_event" = "stop" ]; then
  shopt -s nullglob
  pending_flags=( "${project_dir}"/.cursor/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ]; then
    blocked=false
    for flag in "${pending_flags[@]}"; do
      [ -f "$flag" ] || continue
      flag_content="$(cat "$flag" 2>/dev/null || true)"
      case "$flag_content" in
        "defer: "*)
          printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$flag_content" >> "$review_audit"
          ;;
        "skip: "*)
          printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$flag_content" >> "$review_audit"
          rm -f "$flag"
          ;;
        *)
          blocked=true
          ;;
      esac
    done
    if [ "$blocked" = true ]; then
      echo "Unit awaiting review - spawn the reviewer (persona-protocol's Review ownership section). Escape hatch: 'printf \"defer|skip: <reason>\\n\" > .cursor/.pending-review.<agent-id>' - defer keeps the flag (still owed), skip deletes it (abandoned). Empty reason rejected." >&2
      exit 2
    fi
    exit 0
  fi
fi

if [ "$hook_event" = "stop" ] || [ "$hook_event" = "subagentStop" ]; then
  [ -f "$config" ] || exit 0
  gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
  [ -n "$gated" ] || gated="lead-programmer"

  if [ "$hook_event" = "subagentStop" ]; then
    check_name="$agent_type"
  else
    check_name="$(jq -r '.mainAgent // "orchestrator"' "$config" 2>/dev/null || echo orchestrator)"
  fi

  match=false
  while IFS= read -r name; do
    [ -n "$name" ] && [ "$name" = "$check_name" ] && match=true
  done <<< "$gated"
  [ "$match" = true ] || exit 0
fi

raw_agent_id="$(echo "$input" | jq -r '.subagent_type // .conversation_id // "main"' 2>/dev/null || echo main)"
agent_id="${raw_agent_id//[^a-zA-Z0-9._-]/_}"
sentinel="${project_dir}/.cursor/wip-handoff.${agent_id}"

if [ -f "$sentinel" ]; then
  if [ -s "$sentinel" ]; then
    reason="$(cat "$sentinel")"
    printf '%s agent=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$reason" \
      >> "${project_dir}/.cursor/wip-audit.log"
    rm -f "$sentinel"
    exit 0
  fi
  echo "WIP sentinel at ${sentinel} is empty - a reason is required (e.g. 'echo \"blocked on X\" > ${sentinel}'). Ignoring it and running the normal check instead." >&2
  rm -f "$sentinel"
fi

if [ "$hook_event" = "subagentStop" ]; then
  pending_flag="${project_dir}/.cursor/.pending-review.${agent_id}"
  [ -f "$pending_flag" ] || printf '%s agent=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" > "$pending_flag"
fi

dirty=false
[ -n "$(git -C "$project_dir" status --porcelain 2>/dev/null || true)" ] && dirty=true

raw_session_id="$(echo "$input" | jq -r '.conversation_id // "unknown"' 2>/dev/null || echo unknown)"
session_id="${raw_session_id//[^a-zA-Z0-9._-]/_}"
baseline_file="${project_dir}/.cursor/.session-baseline.${session_id}"

moved=false
if [ -f "$baseline_file" ]; then
  baseline_sha="$(cat "$baseline_file" 2>/dev/null || true)"
  current_sha="$(git -C "$project_dir" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$baseline_sha" ] && [ -n "$current_sha" ] && [ "$baseline_sha" != "$current_sha" ]; then
    moved=true
  fi
fi

if [ "$dirty" = false ] && [ "$moved" = false ]; then
  exit 0
fi

[ -f "$config" ] || exit 0
check_cmd="$(jq -r '.testAndLintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$check_cmd" ] || exit 0

tmp_out="$(mktemp)"
if ! (cd "$project_dir" && eval "$check_cmd") >"$tmp_out" 2>&1; then
  echo "Test/lint check failed - fix before ending the turn, or 'echo \"<reason>\" > ${sentinel}' if this is a legitimate mid-task pause (TDD red phase, blocked report, plan-is-wrong escalation). The sentinel must contain a reason - an empty file is ignored." >&2
  cat "$tmp_out" >&2
  rm -f "$tmp_out"
  exit 2
fi
rm -f "$tmp_out"
exit 0
