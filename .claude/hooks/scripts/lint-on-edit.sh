#!/usr/bin/env bash
# PostToolUse (Edit|Write). Runs the project's formatter/linter on the
# changed file only. Silently no-ops if no lint command is configured.
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

lint_cmd="$(jq -r '.lintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$lint_cmd" ] || exit 0

file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0
[ -e "$file_path" ] || exit 0

# See graph-update.sh's comment: file path is a positional parameter, never
# string-interpolated into eval, so a crafted filename can't inject commands.
bash -c "$lint_cmd \"\$1\"" _ "$file_path" >/dev/null 2>&1 || true
exit 0
