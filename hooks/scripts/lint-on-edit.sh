#!/usr/bin/env bash
# PostToolUse (Edit|Write). Runs the project's formatter/linter on the
# changed file only. Silently no-ops if no lint command is configured.
set -euo pipefail

input="$(cat)"
config=".claude/persona-config.json"
[ -f "$config" ] || exit 0

lint_cmd="$(jq -r '.lintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$lint_cmd" ] || exit 0

file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0
[ -e "$file_path" ] || exit 0

eval "$lint_cmd \"$file_path\"" >/dev/null 2>&1 || true
exit 0
