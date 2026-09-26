#!/usr/bin/env bash
# Prints a unit's FAIL-block count from its .fail marker; 0 if none exists.
# Usage: fail-count.sh <task-id> [project-dir]
set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

task_id="${1:-}"
project_dir="${2:-.}"
dot="${project_dir}/.claude"

. "$repo_root/hooks/scripts/lib/state-access.sh"

if [ -z "$task_id" ]; then
  echo 0
  exit 0
fi

marker_file="$(unit_id_marker_path "$task_id" fail)"
count=0
if [ -f "$marker_file" ]; then
  count="$(grep -cE "^FAIL ${task_id} " "$marker_file")" || true
fi
printf '%s\n' "$count"
exit 0
