#!/usr/bin/env bash
# PostToolUse (Edit|Write). Runs the Code Review Graph's incremental-update
# command on the single changed file only - never a full re-index per edit.
# Silently no-ops (exit 0) if the graph isn't configured/installed, so a
# failed/skipped graph install doesn't turn into hook noise on every write.
# KNOWN LIMITATION: only reads tool_input.file_path - MultiEdit's array form
# and NotebookEdit are not matched (see README).
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

graph_cmd="$(jq -r '.graphUpdateCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$graph_cmd" ] || exit 0

file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0
[ -e "$file_path" ] || exit 0

# Patterns in sourceGlobs are project-root-relative; file_path from the tool
# is typically absolute, so normalize before matching.
rel_path="$file_path"
case "$rel_path" in
  "$project_dir"/*) rel_path="${rel_path#"$project_dir"/}" ;;
esac

source_globs="$(jq -r '.sourceGlobs[]? // empty' "$config" 2>/dev/null || true)"
if [ -n "$source_globs" ]; then
  matched=false
  while IFS= read -r glob; do
    [ -n "$glob" ] || continue
    case "$rel_path" in
      $glob) matched=true ;;
    esac
  done <<< "$source_globs"
  [ "$matched" = true ] || exit 0
fi

# file_path passed as a positional parameter, not re-interpolated into the
# eval'd string, so a crafted filename (e.g. containing $(...)) can't inject
# commands. graph_cmd itself is user-authored config, so eval-of-config here
# is fine - only the untrusted file path must never be string-interpolated.
bash -c "$graph_cmd \"\$1\"" _ "$file_path" >/dev/null 2>&1 || true
exit 0
