#!/usr/bin/env bash
# Sweep every .pass marker under .claude/reviewed/ through marker-verify.sh,
# defaulting to --list mode (parses and counts each marker's criteria;
# executes nothing). Pass --execute to actually run every marker's criteria
# in a throwaway worktree instead. Read-only sweep; never writes.
# See docs/plans/2026-08-25-harness-trust-gaps.md Step 6.
#
# Usage: marker-audit.sh [project-dir] [--execute]
set -uo pipefail

project_dir="."
execute_flag=""
for arg in "$@"; do
  case "$arg" in
    --execute) execute_flag="--execute" ;;
    *) project_dir="$arg" ;;
  esac
done

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
verifier="$repo_root/hooks/scripts/marker-verify.sh"

reviewed_dir="$project_dir/.claude/reviewed"
[ -d "$reviewed_dir" ] || exit 0

while IFS= read -r marker_file; do
  [ -n "$marker_file" ] || continue
  task_id="${marker_file%.pass}"
  task_id="${task_id##*/}"
  [ -n "$task_id" ] || continue
  "$verifier" "$task_id" "$project_dir" $execute_flag
done < <(ls -1 "$reviewed_dir"/*.pass 2>/dev/null || true)

exit 0
