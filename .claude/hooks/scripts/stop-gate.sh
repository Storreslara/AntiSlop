#!/usr/bin/env bash
# Claude entry point for the stop gate, registered on Stop and SubagentStop with no matcher. It sets
# Claude's payload contract and sources lib/stop-gate-core.sh, which holds the rules. The plain Stop
# payload carries no agent identity, so a Stop is gated as settings.json's `.agent` (default
# "orchestrator"). Loop guard: the stop that follows a block carries stop_hook_active and is allowed.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/harness-arm.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
dot="${project_dir}/.claude"
dot_label=".claude"
config="${dot}/persona-config.json"
review_audit="${dot}/review-audit.log"
harness_arm_or_deny "$project_dir" "$dot_label"

block() { echo "$1" >&2; exit 2; }
allow() { exit 0; }

[ "$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)" = "true" ] && allow
hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"
raw_agent_id="$(echo "$input" | jq -r '.agent_id // .session_id // "main"' 2>/dev/null || echo main)"

main_agent_name=""
if [ "$hook_event" != "SubagentStop" ]; then
  main_agent_name="$(jq -r '.agent // "orchestrator"' "${dot}/settings.json" 2>/dev/null || echo orchestrator)"
fi

# writer_lane (D3): the lane= word of the first dispatch-lane.log record whose tool_use_id is the
# transcript's toolUseId (its .meta.json) and whose prompt hash is that of the transcript's first user
# message, hashed as writer-scope-gate.sh hashes it. Any miss leaves it empty, so the flag is written.
writer_lane=""
if [ "$hook_event" = "SubagentStop" ]; then
  lane_tr="$(echo "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null || true)"
  lane_tu=""
  [ -n "$lane_tr" ] && [ -f "$lane_tr" ] && lane_tu="$(jq -r '.toolUseId // empty' "${lane_tr%.jsonl}.meta.json" 2>/dev/null || true)"
  if [[ $lane_tu =~ ^[A-Za-z0-9_]{1,128}$ ]]; then
    lane_prompt="$(jq -cR 'fromjson? | select(type == "object")' "$lane_tr" 2>/dev/null \
      | jq -rs 'try (map(select(.type == "user"))[0].message.content
          | if type == "string" then . else (map(select(.type? == "text") | .text) | join("\n")) end) catch ""' 2>/dev/null || true)"
    lane_ph="$(printf '%s' "$lane_prompt" | _portable_sha256 - 2>/dev/null | cut -d' ' -f1 || true)"
    lane_rec="$(awk -v t="tool_use_id=$lane_tu" '$2 == t { print; exit }' "${dot}/reviewed/dispatch-lane.log" 2>/dev/null || true)"
    if [[ $lane_ph =~ ^[0-9a-f]{64}$ ]] && [ -n "$lane_rec" ]; then
      read -r _ _ lane_rp _ lane_lw _ <<< "$lane_rec"
      if [ "$lane_rp" = "prompt=$lane_ph" ]; then
        case "$lane_lw" in lane=*) writer_lane="${lane_lw#lane=}" ;; esac
      fi
    fi
  fi
fi

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/stop-gate-core.sh"
