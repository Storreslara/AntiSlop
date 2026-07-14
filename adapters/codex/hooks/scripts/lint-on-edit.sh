#!/usr/bin/env bash
# CODEX ADAPTER over the shared lint-on-edit logic (ported from
# hooks/scripts/lint-on-edit.sh via adapters/cursor/hooks/scripts/
# lint-on-edit.sh - decision logic identical, only payload extraction
# differs). Registered on PostToolUse. Runs the project's formatter/linter on
# each changed file. Silently no-ops if no lint command is configured.
#
# Codex payload differences: see graph-update.sh's header comment - same
# UNVERIFIED file-path extraction (single-file keys, falling back to parsing
# apply_patch's patch-header format for potentially multiple paths).
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.codex/persona-config.json"
[ -f "$config" ] || exit 0

lint_cmd="$(jq -r '.lintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$lint_cmd" ] || exit 0

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

while IFS= read -r file_path; do
  [ -n "$file_path" ] || continue
  [ -e "$file_path" ] || continue
  # See graph-update.sh: file path is a positional parameter, never
  # string-interpolated into eval, so a crafted filename can't inject
  # commands.
  bash -c "$lint_cmd \"\$1\"" _ "$file_path" >/dev/null 2>&1 || true
done <<< "$paths"
exit 0
