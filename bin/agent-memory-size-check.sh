#!/usr/bin/env bash
# Non-blocking size warning over .claude/agent-memory/<persona>/ namespaces
# (item05-3-pruning-policy, docs/plans/2026-09-25-item05-agent-memory-dedup.md
# Step 3). Never exits non-zero: memory hygiene is advisory, not a gate.
# Usage: bin/agent-memory-size-check.sh [--project-dir <path>] [--threshold-kb N]
set -uo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-.}"
threshold_kb=512

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)
      [ $# -ge 2 ] || { echo "agent-memory-size-check: --project-dir requires an argument" >&2; exit 0; }
      project_dir="$2"; shift 2 ;;
    --threshold-kb)
      [ $# -ge 2 ] || { echo "agent-memory-size-check: --threshold-kb requires an argument" >&2; exit 0; }
      threshold_kb="$2"; shift 2 ;;
    *)
      shift ;;
  esac
done

mem_root="$project_dir/.claude/agent-memory"
[ -d "$mem_root" ] || exit 0

for ns_dir in "$mem_root"/*/; do
  [ -d "$ns_dir" ] || continue
  ns_name="$(basename "$ns_dir")"
  size_kb="$(du -sk "$ns_dir" 2>/dev/null | cut -f1)"
  [ -n "$size_kb" ] || continue
  if [ "$size_kb" -gt "$threshold_kb" ]; then
    echo "WARN agent-memory namespace '$ns_name' is ${size_kb}K (threshold ${threshold_kb}K) — completion records don't belong in memory (derivable from .pass markers and CHANGELOG.md); prune at release (see agents/scribe.md)" >&2
  fi
done

exit 0
