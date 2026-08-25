#!/usr/bin/env bash
# PreToolUse (Write|Edit). Claude entry point over the shared protected-paths
# gating logic (hooks/scripts/lib/protected-paths-core.sh) — sets Claude's
# payload contract (project dir from $CLAUDE_PROJECT_DIR, dot-dir .claude/,
# single tool_input.file_path; no in-script tool-name filter, since Claude's
# hooks.json matcher already restricts this script to Write/Edit) then
# sources the port-invariant core.
# ADVISORY ONLY: this matcher covers Write/Edit tool calls, not Bash - a
# persona running `sed -i`, `git mv`, or a package manager that rewrites a
# lockfile bypasses this gate entirely. Treat it as a backstop against
# accidental Write/Edit tool calls, not an airtight guarantee.
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
paths="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/protected-paths-core.sh"
