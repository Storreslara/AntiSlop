#!/usr/bin/env bash
# PreToolUse (Write|Edit). Blocks writes to configured protected paths
# (migrations/, generated/, lockfiles, etc.) pending explicit human approval.
# Patterns in persona-config.json are project-root-relative; file_path from
# the tool is typically absolute, so it's normalized against
# CLAUDE_PROJECT_DIR before matching - a directory-anchored pattern like
# 'supabase/migrations/*' would otherwise never match anything.
# ADVISORY ONLY: this matcher covers Write/Edit tool calls, not Bash - a
# persona running `sed -i`, `git mv`, or a package manager that rewrites a
# lockfile bypasses this gate entirely. Treat it as a backstop against
# accidental Write/Edit tool calls, not an airtight guarantee.
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
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
