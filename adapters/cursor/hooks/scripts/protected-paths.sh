#!/usr/bin/env bash
# CURSOR entry point over the shared protected-paths gating logic (generated
# from hooks/scripts/lib/protected-paths-core.sh - node bin/cli.js --update
# --force-render). Registered on `preToolUse`. Sets cursor's payload contract
# then sources the port-invariant core.
#
# Cursor payload differences vs Claude (see spec §3, cursor.com/docs/hooks):
#  - project dir comes from `.workspace_roots[0]` in the JSON payload, not the
#    $CLAUDE_PROJECT_DIR env var.
#  - the edited path lives in `.tool_input` but the exact key is UNVERIFIED
#    across Cursor's edit tools, so several candidates are tried.
#  - the write-tool name is UNVERIFIED, so this self-filters to write-ish tool
#    names in-script rather than trusting a hooks.json `matcher`.
# ADVISORY ONLY, same as the Claude version: covers tool-driven edits, not a
# persona running `sed -i`/`git mv`/a package manager via Bash.
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.cursor/persona-config.json"

tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
# Only gate mutating tools; a read of a protected file is fine.
case "$(printf '%s' "$tool_name" | tr '[:upper:]' '[:lower:]')" in
  *edit*|*write*|*create*|*apply*patch*|*str_replace*|*search_replace*|*multi*edit*) ;;
  *) exit 0 ;;
esac

paths="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.target_file // .tool_input.filePath // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/protected-paths-core.sh"
