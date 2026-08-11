#!/usr/bin/env bash
# PreToolUse (Bash, Write|Edit). Blocks EVERY agent identity - reviewer
# included, empty/main-session agent_type included - from writing
# .claude/human-review/<task-id>/DECISION, the human's own resolution of a
# pending ESCALATE-TO-HUMAN packet. No grant branch and no fallback: unlike
# reviewed-path-gate.sh, no identity may ever write this file. Reads stay
# allowed.
#
# No adapter port exists for this gate, following the same precedent already
# set by reviewed-path-gate.sh, which likewise has none under
# adapters/*/hooks/scripts/.
#
# The sanctioned way to discard a resolved escalation packet is
# `rm -rf .claude/human-review/<task-id>` (the whole directory) - its command
# text never spells DECISION, so it passes the substring early-exit below and
# is never routed through command_is_provably_benign() at all. A per-file
# `rm .../DECISION` is blocked for every identity, reviewer included; that is
# intended, not a defect.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/benign-command.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
audit="${project_dir}/.claude/review-audit.log"

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

deny() {
  { printf '%s decision-gate-denied identity=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
      >> "$audit"; } 2>/dev/null || true
  echo "BLOCKED: '${agent_type}' may not write .claude/human-review/<task-id>/DECISION - that file records the human's own resolution of a pending escalation and no agent identity may create or modify it, reviewer included. To discard a resolved packet, delete the whole directory with 'rm -rf .claude/human-review/<task-id>' (its command text never spells DECISION)." >&2
  exit 2
}

if [ -z "$command" ]; then
  has_path="$(echo "$input" | jq -r '(.tool_input|type) == "object" and (.tool_input|has("file_path"))' 2>/dev/null)" || exit 0
  [ "$has_path" = true ] || exit 0
  file_path="$(echo "$input" | jq -r '.tool_input.file_path // "" | tostring' 2>/dev/null || true)"
  subject="$(normalize_path "$file_path")"
  case "$subject" in
    "$project_dir"/*) subject="${subject#"$project_dir"/}" ;;
  esac
  case "$subject" in
    .claude/human-review/*/DECISION) deny ;;
    *) exit 0 ;;
  esac
fi

case "$command" in
  *human-review*) ;;
  *) exit 0 ;;
esac
case "$command" in
  *DECISION*) ;;
  *) exit 0 ;;
esac

command_is_provably_benign "$command" && exit 0
deny
