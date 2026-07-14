#!/usr/bin/env bash
# CODEX ADAPTER over the shared protected-paths gating logic (ported from
# hooks/scripts/protected-paths.sh via adapters/cursor/hooks/scripts/
# protected-paths.sh - decision logic identical, only payload extraction
# differs). Registered on PreToolUse. Blocks writes to configured protected
# paths (migrations/, generated/, lockfiles, etc.) pending explicit human
# approval.
#
# Codex payload differences vs Claude/Cursor (see docs/specs/codex-plugin.md
# §6, §12 #8 - UNVERIFIED against a real build):
#  - project dir comes from the payload's `.cwd`, not an env var.
#  - the write-tool name and its tool_input shape are UNVERIFIED. Codex's
#    documented canonical edit tool is `apply_patch`, which - unlike Claude's
#    Edit/Write or Cursor's edit tools - takes a UNIFIED-DIFF-STYLE PATCH that
#    can touch MULTIPLE files in one call, not a single `tool_input.file_path`.
#    This script therefore: (a) tries several plausible single-file keys
#    first (mirroring the Cursor port's defensive candidate list), and (b) if
#    the tool looks like apply_patch and none of those keys hit, falls back
#    to parsing OpenAI's documented apply_patch patch-header format
#    (`*** Add File: <path>` / `*** Update File: <path>` / `*** Delete File:
#    <path>`) out of whichever tool_input field holds the raw patch text,
#    trying several candidate field names since the exact one is unconfirmed.
#    ANY path touched by the patch is checked, not just the first.
# ADVISORY ONLY, same as every other platform's version: covers tool-driven
# edits, not a persona running `sed -i`/`git mv`/a package manager via Bash.
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.codex/persona-config.json"
[ -f "$config" ] || exit 0

tool_name="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
tool_name_lc="$(printf '%s' "$tool_name" | tr '[:upper:]' '[:lower:]')"
# Only gate mutating tools; a read of a protected file is fine.
case "$tool_name_lc" in
  *apply*patch*|*edit*|*write*|*create*|*str_replace*|*multi*edit*) ;;
  *) exit 0 ;;
esac

# Candidate 1: a simple single-file key, same candidates the Cursor port
# tries defensively.
paths="$(echo "$input" | jq -r '[.tool_input.file_path, .tool_input.path, .tool_input.target_file, .tool_input.filePath] | map(select(. != null and . != "")) | .[]' 2>/dev/null || true)"

# Candidate 2: apply_patch's own patch-header format, if no single-file key
# hit and the tool looks like apply_patch. Try several plausible field names
# for where the raw patch text lives.
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

protected="$(jq -r '.protectedPaths[]? // empty' "$config" 2>/dev/null || true)"
[ -n "$protected" ] || exit 0

while IFS= read -r file_path; do
  [ -n "$file_path" ] || continue
  rel_path="$file_path"
  case "$rel_path" in
    "$project_dir"/*) rel_path="${rel_path#"$project_dir"/}" ;;
  esac
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    case "$rel_path" in
      $pattern)
        echo "BLOCKED: ${rel_path} matches protected path pattern '${pattern}'. Requires explicit human approval - ask the user before editing this file." >&2
        exit 2
        ;;
    esac
  done <<< "$protected"
done <<< "$paths"
exit 0
