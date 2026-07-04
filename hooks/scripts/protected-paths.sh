#!/usr/bin/env bash
# PreToolUse (Write|Edit). Blocks writes to configured protected paths
# (migrations/, generated/, lockfiles, etc.) pending explicit human approval.
# ADVISORY ONLY: this matcher covers Write/Edit tool calls, not Bash - a
# persona running `sed -i`, `git mv`, or a package manager that rewrites a
# lockfile bypasses this gate entirely. Treat it as a backstop against
# accidental Write/Edit tool calls, not an airtight guarantee.
set -euo pipefail

input="$(cat)"
config=".claude/persona-config.json"
[ -f "$config" ] || exit 0

file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0

protected="$(jq -r '.protectedPaths[]? // empty' "$config" 2>/dev/null || true)"
[ -n "$protected" ] || exit 0

while IFS= read -r pattern; do
  [ -n "$pattern" ] || continue
  case "$file_path" in
    $pattern)
      echo "BLOCKED: ${file_path} matches protected path pattern '${pattern}'. Requires explicit human approval - ask the user before editing this file." >&2
      exit 2
      ;;
  esac
done <<< "$protected"
exit 0
