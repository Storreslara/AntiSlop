#!/usr/bin/env bash
# PostToolUse (Edit|Write). Claude entry point over the shared lint-on-edit
# decision logic (hooks/scripts/lib/lint-on-edit-core.sh) — sets Claude's
# payload contract (project dir from $CLAUDE_PROJECT_DIR, dot-dir .claude/,
# single tool_input.file_path) then sources the port-invariant core.
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
paths="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/lint-on-edit-core.sh"
