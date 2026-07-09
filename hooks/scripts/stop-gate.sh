#!/usr/bin/env bash
# Registered on Stop (main session) AND SubagentStop with NO matcher -
# gating which agents this actually checks is config-driven via
# persona-config.json's gatedAgents list (default: ["lead-programmer"]),
# not the hook registration. Adding a future code-writing persona is a
# config edit, not a plugin file edit. Confirmed empirically that the
# SubagentStop payload carries `agent_type`, so this filtering is reliable.
#
# Logic, in order:
#  0) stop_hook_active guard - never re-trigger ourselves in a loop.
#  1) SubagentStop for an agent not in gatedAgents -> ALLOW immediately
#     (cheap/high-frequency personas like explorer never pay this cost).
#  2) per-agent WIP sentinel -> if it holds a non-empty reason, log it to
#     .claude/wip-audit.log, delete it, ALLOW. An empty sentinel (bare
#     `touch`, no stated reason) is rejected: deleted but NOT honored, so it
#     falls through to the normal check instead of silently bypassing it.
#     This is a friction/audit-trail fix, not a guarantee against abuse - a
#     determined agent can still write a bogus reason - but it closes the
#     silent, invisible bare-touch bypass that existed before.
#  3) tree clean AND no commits since this session's baseline -> ALLOW.
#  4) otherwise run the configured test+lint command; non-zero exit -> BLOCK.
# Step 3's baseline check closes a gap where a lead-programmer that commits
# per-step (tree clean at handoff) would otherwise never actually hit the
# check - the reviewer independently re-runs checks before PASS regardless,
# so this is defense-in-depth, not the only safety net.
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"

stop_active="$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
[ "$stop_active" = "true" ] && exit 0

hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

if [ "$hook_event" = "SubagentStop" ]; then
  [ -f "$config" ] || exit 0
  gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
  [ -n "$gated" ] || gated="lead-programmer"
  match=false
  while IFS= read -r name; do
    [ -n "$name" ] && [ "$name" = "$agent_type" ] && match=true
  done <<< "$gated"
  [ "$match" = true ] || exit 0
fi

raw_agent_id="$(echo "$input" | jq -r '.agent_id // .session_id // "main"' 2>/dev/null || echo main)"
agent_id="${raw_agent_id//[^a-zA-Z0-9._-]/_}"
sentinel="${project_dir}/.claude/wip-handoff.${agent_id}"

if [ -f "$sentinel" ]; then
  if [ -s "$sentinel" ]; then
    reason="$(cat "$sentinel")"
    printf '%s agent=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$reason" \
      >> "${project_dir}/.claude/wip-audit.log"
    rm -f "$sentinel"
    exit 0
  fi
  echo "WIP sentinel at ${sentinel} is empty - a reason is required (e.g. 'echo \"blocked on X\" > ${sentinel}'). Ignoring it and running the normal check instead." >&2
  rm -f "$sentinel"
fi

dirty=false
[ -n "$(git -C "$project_dir" status --porcelain 2>/dev/null || true)" ] && dirty=true

raw_session_id="$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
session_id="${raw_session_id//[^a-zA-Z0-9._-]/_}"
baseline_file="${project_dir}/.claude/.session-baseline.${session_id}"

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
