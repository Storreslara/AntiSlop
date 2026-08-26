#!/usr/bin/env bash
# Port-invariant decision logic for protected-paths.sh, shared byte-for-byte
# by all three ports (Claude/codex/cursor) — hand-edit only here;
# adapters/*/hooks/scripts/lib/protected-paths-core.sh are generated copies
# (node bin/cli.js --update --force-render). Sourced, never executed.
#
# Caller contract (set before sourcing): project_dir, config (absolute path
# to persona-config.json), paths (newline-separated candidate file path(s),
# already extracted from the port's own payload shape AND already filtered
# to mutating tool calls only — a read of a protected file is fine, and
# which tool names count as "mutating" is itself port-specific).
set -euo pipefail

[ -f "$config" ] || exit 0
[ -n "$paths" ] || exit 0

protected="$(jq -r '.protectedPaths[]? | .pattern // . // empty' "$config" 2>/dev/null || true)"
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
