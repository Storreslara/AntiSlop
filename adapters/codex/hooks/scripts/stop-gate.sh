#!/usr/bin/env bash
# CODEX ADAPTER over the shared stop-gate logic (ported from
# hooks/scripts/stop-gate.sh via adapters/cursor/hooks/scripts/stop-gate.sh -
# the ordered decision logic is identical; only the payload field extraction
# and the loop guard differ). Registered on `Stop` (main session) AND
# `SubagentStop`. Gating is config-driven via persona-config.json's
# gatedAgents list (default ["lead-programmer"]).
#
# Codex payload differences vs Claude/Cursor (docs/specs/codex-plugin.md §6,
# §12):
#  - `hook_event_name` is "Stop" | "SubagentStop" (PascalCase, confirmed).
#  - caller-agent identity on SubagentStop: `.agent_type` (the stopped
#    subagent's own profile/type - confirmed field, though whether it's
#    distinct from any PARENT identity is unresolved, see
#    reviewer-route-gate.sh).
#  - `.agent_id`: CONFIRMED per-subagent field, used here as the pending-
#    review-flag / WIP-sentinel filename key. If this is genuinely a stable
#    per-spawn-instance id (not just a repeat of agent_type - unverified),
#    this FIXES the Cursor port's known limitation where two concurrent
#    same-type subagents shared one flag.
#  - the plain `Stop` payload carries NO agent identity (same as every
#    platform), so that case keys off the configured main agent - read here
#    from persona-config.json's `mainAgent` (default "orchestrator"), since
#    Codex has no config.toml key equivalent to Claude's settings.json
#    `.agent` field.
#  - NO CONFIRMED loop-guard field (Claude's `stop_hook_active`, Cursor's
#    `.loop_count`) exists in Codex's documented common/turn-scoped payload
#    fields. Rather than skip the guard, this implements a SELF-TRACKED
#    fallback: a per-session counter file incremented each time this script
#    is about to BLOCK (exit 2), reset whenever it reaches a genuine ALLOW
#    after running the real check. If 5 consecutive blocks accumulate, force
#    an ALLOW instead of blocking again, logging that the guard tripped. This
#    is a workaround for an unconfirmed primitive, not a confirmed platform
#    behavior - revisit if Codex turns out to expose its own re-trigger
#    signal (docs/codex-port-notes.md).
#  - session/baseline id: `.session_id` (Codex has this natively, unlike
#    Cursor's reused `.conversation_id`).
#
# Ordered logic (identical to the Claude/Cursor versions):
#  0) loop guard (self-tracked fallback, see above).
#  0.5) reviewer's SubagentStop -> CLEAR every pending-review flag, log, ALLOW.
#  0.75) main Stop with any pending-review flag -> BLOCK (defer:/skip: escape).
#  1) non-gated stop/SubagentStop -> ALLOW immediately.
#  2) per-agent WIP sentinel with a non-empty reason -> log, delete, ALLOW.
#  2.5) a gated SubagentStop reaching here -> CREATE the pending-review flag
#     if absent (idempotent: does not clobber an existing defer:/skip:).
#  3) tree clean AND no commits since baseline -> ALLOW.
#  4) otherwise run the configured test+lint command; non-zero -> BLOCK.
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.codex/persona-config.json"
review_audit="${project_dir}/.codex/review-audit.log"

hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

raw_session_id="$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
session_id="${raw_session_id//[^a-zA-Z0-9._-]/_}"
loop_guard_file="${project_dir}/.codex/.stop-loop-guard.${session_id}"

block() {
  # $1 = message to write to stderr before exiting 2.
  local count=0
  [ -f "$loop_guard_file" ] && count="$(cat "$loop_guard_file" 2>/dev/null || echo 0)"
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  count=$((count + 1))
  if [ "$count" -ge 5 ]; then
    printf '%s loop-guard tripped (5 consecutive blocks) - forcing ALLOW\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
    rm -f "$loop_guard_file"
    exit 0
  fi
  echo "$count" > "$loop_guard_file"
  echo "$1" >&2
  exit 2
}

allow() {
  rm -f "$loop_guard_file"
  exit 0
}

if [ "$hook_event" = "SubagentStop" ] && [ "$agent_type" = "reviewer" ]; then
  [ -f "$config" ] || allow
  rm -f "${project_dir}"/.codex/.pending-review.* 2>/dev/null || true
  printf '%s cleared-by=reviewer\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
  allow
fi

if [ "$hook_event" = "Stop" ]; then
  shopt -s nullglob
  pending_flags=( "${project_dir}"/.codex/.pending-review.* )
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
      block "Unit awaiting review - spawn the reviewer (persona-protocol's Review ownership section). Escape hatch: 'printf \"defer|skip: <reason>\\n\" > .codex/.pending-review.<agent-id>' - defer keeps the flag (still owed), skip deletes it (abandoned). Empty reason rejected."
    fi
    allow
  fi
fi

if [ "$hook_event" = "Stop" ] || [ "$hook_event" = "SubagentStop" ]; then
  [ -f "$config" ] || allow
  gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
  [ -n "$gated" ] || gated="lead-programmer"

  if [ "$hook_event" = "SubagentStop" ]; then
    check_name="$agent_type"
  else
    check_name="$(jq -r '.mainAgent // "orchestrator"' "$config" 2>/dev/null || echo orchestrator)"
  fi

  match=false
  while IFS= read -r name; do
    [ -n "$name" ] && [ "$name" = "$check_name" ] && match=true
  done <<< "$gated"
  [ "$match" = true ] || allow
fi

raw_agent_id="$(echo "$input" | jq -r '.agent_id // .agent_type // .session_id // "main"' 2>/dev/null || echo main)"
agent_id="${raw_agent_id//[^a-zA-Z0-9._-]/_}"
sentinel="${project_dir}/.codex/wip-handoff.${agent_id}"

if [ -f "$sentinel" ]; then
  if [ -s "$sentinel" ]; then
    reason="$(cat "$sentinel")"
    printf '%s agent=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$reason" \
      >> "${project_dir}/.codex/wip-audit.log"
    rm -f "$sentinel"
    allow
  fi
  echo "WIP sentinel at ${sentinel} is empty - a reason is required (e.g. 'echo \"blocked on X\" > ${sentinel}'). Ignoring it and running the normal check instead." >&2
  rm -f "$sentinel"
fi

if [ "$hook_event" = "SubagentStop" ]; then
  pending_flag="${project_dir}/.codex/.pending-review.${agent_id}"
  [ -f "$pending_flag" ] || printf '%s agent=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" > "$pending_flag"
fi

dirty=false
[ -n "$(git -C "$project_dir" status --porcelain 2>/dev/null || true)" ] && dirty=true

baseline_file="${project_dir}/.codex/.session-baseline.${session_id}"

moved=false
if [ -f "$baseline_file" ]; then
  baseline_sha="$(cat "$baseline_file" 2>/dev/null || true)"
  current_sha="$(git -C "$project_dir" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$baseline_sha" ] && [ -n "$current_sha" ] && [ "$baseline_sha" != "$current_sha" ]; then
    moved=true
  fi
fi

if [ "$dirty" = false ] && [ "$moved" = false ]; then
  allow
fi

[ -f "$config" ] || allow
check_cmd="$(jq -r '.testAndLintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$check_cmd" ] || allow

tmp_out="$(mktemp)"
if ! (cd "$project_dir" && eval "$check_cmd") >"$tmp_out" 2>&1; then
  out="$(cat "$tmp_out")"
  rm -f "$tmp_out"
  block "Test/lint check failed - fix before ending the turn, or 'echo \"<reason>\" > ${sentinel}' if this is a legitimate mid-task pause (TDD red phase, blocked report, plan-is-wrong escalation). The sentinel must contain a reason - an empty file is ignored.
${out}"
fi
rm -f "$tmp_out"
allow
