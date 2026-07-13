#!/usr/bin/env bash
# CURSOR ADAPTER over the shared graph-update logic (ported from
# hooks/scripts/graph-update.sh - decision logic identical, only payload
# extraction differs). Registered on `afterFileEdit`. Runs the Code Review
# Graph's incremental-update command on the single changed file only.
# Silently no-ops if the graph isn't configured/installed.
#
# Cursor payload differences: project dir from `.workspace_roots[0]`; the
# edited path is a TOP-LEVEL `.file_path` on the afterFileEdit payload (not
# nested under `.tool_input`).
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.cursor/persona-config.json"
[ -f "$config" ] || exit 0

graph_cmd="$(jq -r '.graphUpdateCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$graph_cmd" ] || exit 0

file_path="$(echo "$input" | jq -r '.file_path // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0
[ -e "$file_path" ] || exit 0

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

# file_path passed positionally, never re-interpolated into the eval'd string,
# so a crafted filename can't inject commands. graph_cmd is user-authored config.
bash -c "$graph_cmd \"\$1\"" _ "$file_path" >/dev/null 2>&1 || true
exit 0
