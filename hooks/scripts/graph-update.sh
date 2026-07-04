#!/usr/bin/env bash
# PostToolUse (Edit|Write). Runs the Code Review Graph's incremental-update
# command on the single changed file only - never a full re-index per edit.
# Silently no-ops (exit 0) if the graph isn't configured/installed, so a
# failed/skipped graph install doesn't turn into hook noise on every write.
# KNOWN LIMITATION: only reads tool_input.file_path - MultiEdit's array form
# and NotebookEdit are not matched (see README).
set -euo pipefail

input="$(cat)"
config=".claude/persona-config.json"
[ -f "$config" ] || exit 0

graph_cmd="$(jq -r '.graphUpdateCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$graph_cmd" ] || exit 0

file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0
[ -e "$file_path" ] || exit 0

source_globs="$(jq -r '.sourceGlobs[]? // empty' "$config" 2>/dev/null || true)"
if [ -n "$source_globs" ]; then
  matched=false
  while IFS= read -r glob; do
    case "$file_path" in
      $glob) matched=true ;;
    esac
  done <<< "$source_globs"
  [ "$matched" = true ] || exit 0
fi

eval "$graph_cmd \"$file_path\"" >/dev/null 2>&1 || true
exit 0
