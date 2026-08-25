#!/usr/bin/env bash
# Port-invariant decision logic for graph-update.sh, shared byte-for-byte by
# all three ports (Claude/codex/cursor) — hand-edit only here;
# adapters/*/hooks/scripts/lib/graph-update-core.sh are generated copies
# (node bin/cli.js --update --force-render). Sourced, never executed.
#
# Caller contract (set before sourcing): project_dir, config (absolute path
# to persona-config.json), paths (newline-separated candidate file path(s),
# already extracted from the port's own payload shape — zero, one, or many).
set -euo pipefail

[ -f "$config" ] || exit 0

graph_cmd="$(jq -r '.graphUpdateCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$graph_cmd" ] || exit 0

[ -n "$paths" ] || exit 0

source_globs="$(jq -r '.sourceGlobs[]? // empty' "$config" 2>/dev/null || true)"

while IFS= read -r file_path; do
  [ -n "$file_path" ] || continue
  [ -e "$file_path" ] || continue

  # Patterns in sourceGlobs are project-root-relative; file_path is typically
  # absolute, so normalize before matching.
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
  # eval'd string, so a crafted filename (e.g. containing $(...)) can't inject
  # commands. graph_cmd itself is user-authored config, so eval-of-config here
  # is fine - only the untrusted file path must never be string-interpolated.
  bash -c "$graph_cmd \"\$1\"" _ "$file_path" >/dev/null 2>&1 || true
done <<< "$paths"
exit 0
