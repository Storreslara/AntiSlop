#!/usr/bin/env bash
# CURSOR ADAPTER over the shared lint-on-edit logic (ported from
# hooks/scripts/lint-on-edit.sh - decision logic identical, only payload
# extraction differs). Registered on `afterFileEdit`. Runs the project's
# formatter/linter on the changed file only. Silently no-ops if no lint
# command is configured.
#
# Cursor payload differences: project dir from `.workspace_roots[0]`; the
# edited path is a TOP-LEVEL `.file_path` (not under `.tool_input`).
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.cursor/persona-config.json"
[ -f "$config" ] || exit 0

lint_cmd="$(jq -r '.lintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$lint_cmd" ] || exit 0

file_path="$(echo "$input" | jq -r '.file_path // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0
[ -e "$file_path" ] || exit 0

# See graph-update.sh: file path is a positional parameter, never
# string-interpolated into eval, so a crafted filename can't inject commands.
bash -c "$lint_cmd \"\$1\"" _ "$file_path" >/dev/null 2>&1 || true
exit 0
