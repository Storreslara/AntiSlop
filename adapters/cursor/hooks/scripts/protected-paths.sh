#!/usr/bin/env bash
# CURSOR ADAPTER over the shared protected-paths gating logic (ported from
# hooks/scripts/protected-paths.sh - decision logic identical, only the
# payload extraction differs). Registered on `preToolUse`. Blocks writes to
# configured protected paths (migrations/, generated/, lockfiles, etc.)
# pending explicit human approval.
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
[ -f "$config" ] || exit 0

tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
# Only gate mutating tools; a read of a protected file is fine.
case "$(printf '%s' "$tool_name" | tr '[:upper:]' '[:lower:]')" in
  *edit*|*write*|*create*|*apply*patch*|*str_replace*|*search_replace*|*multi*edit*) ;;
  *) exit 0 ;;
esac

file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.target_file // .tool_input.filePath // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0

rel_path="$file_path"
case "$rel_path" in
  "$project_dir"/*) rel_path="${rel_path#"$project_dir"/}" ;;
esac

protected="$(jq -r '.protectedPaths[]? // empty' "$config" 2>/dev/null || true)"
[ -n "$protected" ] || exit 0

while IFS= read -r pattern; do
  [ -n "$pattern" ] || continue
  case "$rel_path" in
    $pattern)
      echo "BLOCKED: ${rel_path} matches protected path pattern '${pattern}'. Requires explicit human approval - ask the user before editing this file." >&2
      exit 2
      ;;
  esac
done <<< "$protected"
exit 0
