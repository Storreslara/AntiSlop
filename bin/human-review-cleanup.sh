#!/usr/bin/env bash
# Manual sweep: deletes RESOLVED escalation packets under
# .claude/human-review/<task-id>/ (a valid DECISION file present). Pending
# packets are never touched. Dry-run by default; pass --apply to delete.
# Usage: bin/human-review-cleanup.sh [--project-dir <path>] [--apply]
set -euo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-.}"
apply=false

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=true; shift ;;
    --project-dir)
      [ $# -ge 2 ] || { echo "human-review-cleanup: --project-dir requires an argument" >&2; exit 1; }
      project_dir="$2"; shift 2 ;;
    *)
      echo "human-review-cleanup: unknown argument: $1" >&2
      exit 1 ;;
  esac
done

review_dir="$project_dir/.claude/human-review"

if [ ! -d "$review_dir" ]; then
  echo "human-review-cleanup: no .claude/human-review/ directory - nothing to do"
  exit 0
fi

review_real="$(cd -P "$review_dir" && pwd)"
id_re='^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$'

for entry_path in "$review_dir"/*; do
  [ -d "$entry_path" ] || continue
  entry="$(basename "$entry_path")"
  [[ $entry =~ $id_re ]] || continue

  decision="$entry_path/DECISION"
  resolved=false
  if [ -s "$decision" ]; then
    first_line="$(head -n1 "$decision")"
    case "$first_line" in
      "DECISION $entry "*) resolved=true ;;
    esac
  fi

  if [ "$resolved" != true ]; then
    echo "[skip] pending: $entry"
    continue
  fi

  entry_real="$(cd -P "$entry_path" && pwd)"
  [ "$entry_real" != "$review_real" ] || continue
  case "$entry_real" in
    "$review_real"/*) ;;
    *) echo "human-review-cleanup: refusing unsafe target: $entry_path" >&2; continue ;;
  esac
  case "${entry_real#"$review_real"/}" in
    */*) echo "human-review-cleanup: refusing unsafe target: $entry_path" >&2; continue ;;
  esac

  if [ "$apply" = true ]; then
    rm -rf "$entry_real"
    echo "deleted: .claude/human-review/$entry"
  else
    echo "[dry-run] would delete: .claude/human-review/$entry"
  fi
done
