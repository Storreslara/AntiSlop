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

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/stop-gate-core.sh"
