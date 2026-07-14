#!/usr/bin/env bash
# CODEX ADAPTER over the shared graph-update logic (ported from
# hooks/scripts/graph-update.sh via adapters/cursor/hooks/scripts/
# graph-update.sh - decision logic identical, only payload extraction
# differs). Registered on PostToolUse. Runs the Code Review Graph's
# incremental-update command once per changed file. Silently no-ops if the
# graph isn't configured/installed.
#
# Codex payload differences (see protected-paths.sh's header comment for the
# full apply_patch caveat - same UNVERIFIED file-path extraction applies
# here): project dir from `.cwd`; tries `tool_input.file_path` and sibling
# keys first, then falls back to parsing apply_patch's `*** Add/Update/Delete
# File:` headers out of the patch text, potentially yielding MULTIPLE paths
# per invocation (unlike the single-file Claude/Cursor tools).
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.codex/persona-config.json"
[ -f "$config" ] || exit 0

graph_cmd="$(jq -r '.graphUpdateCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$graph_cmd" ] || exit 0

tool_name_lc="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"

paths="$(echo "$input" | jq -r '[.tool_input.file_path, .tool_input.path, .tool_input.target_file, .tool_input.filePath] | map(select(. != null and . != "")) | .[]' 2>/dev/null || true)"
if [ -z "$paths" ]; then
  case "$tool_name_lc" in
    *apply*patch*)
      patch_text="$(echo "$input" | jq -r '.tool_input.input // .tool_input.patch // .tool_input.diff // .tool_input.content // empty' 2>/dev/null || true)"
      if [ -n "$patch_text" ]; then
        paths="$(printf '%s\n' "$patch_text" | grep -oE '^\*\*\* (Add|Update|Delete) File: .+' | sed -E 's/^\*\*\* (Add|Update|Delete) File: //' || true)"
      fi
      ;;
  esac
fi
[ -n "$paths" ] || exit 0

source_globs="$(jq -r '.sourceGlobs[]? // empty' "$config" 2>/dev/null || true)"

while IFS= read -r file_path; do
  [ -n "$file_path" ] || continue
  [ -e "$file_path" ] || continue

  rel_path="$file_path"
  case "$rel_path" in
    "$project_dir"/*) rel_path="${rel_path#"$project_dir"/}" ;;
  esac

  if [ -n "$source_globs" ]; then
    matched=false
    while IFS= read -r glob; do
      [ -n "$glob" ] || continue
      case "$rel_path" in
        $glob) matched=true ;;
      esac
    done <<< "$source_globs"
    [ "$matched" = true ] || continue
  fi

  # file_path passed as a positional parameter, not re-interpolated into the
  # eval'd string, so a crafted filename (e.g. containing $(...)) can't
  # inject commands. graph_cmd itself is user-authored config.
  bash -c "$graph_cmd \"\$1\"" _ "$file_path" >/dev/null 2>&1 || true
done <<< "$paths"
exit 0
