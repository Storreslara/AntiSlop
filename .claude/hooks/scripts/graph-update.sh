#!/usr/bin/env bash
# PostToolUse (Edit|Write). Claude entry point over the shared graph-update
# decision logic (hooks/scripts/lib/graph-update-core.sh) — sets Claude's
# payload contract (project dir from $CLAUDE_PROJECT_DIR, dot-dir .claude/,
# single tool_input.file_path) then sources the port-invariant core.
# KNOWN LIMITATION: only reads tool_input.file_path - MultiEdit's array form
# and NotebookEdit are not matched (see README).
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
paths="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/graph-update-core.sh"
