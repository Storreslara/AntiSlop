#!/usr/bin/env bash
# CODEX entry point over the shared graph-update decision logic (generated
# from hooks/scripts/lib/graph-update-core.sh - node bin/cli.js --update
# --force-render). Registered on PostToolUse. Sets codex's payload contract
# then sources the port-invariant core.
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

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/graph-update-core.sh"
