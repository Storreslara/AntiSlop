#!/usr/bin/env bash
# General-purpose artifact sweeper: deletes RESOLVED escalation packets under
# .claude/human-review/<task-id>/ (a valid DECISION file present), marker files
# under .claude/reviewed/, session baselines (.claude/.session-baseline.*), stale
# WIP handoffs (.claude/wip-handoff.*), and rotates the four append-only audit
# logs. Pending packets and markers with active .review-join stamps are never
# touched. Retention window (default 30 days) gates deletion. Dry-run by default;
# pass --apply to delete and rotate.
# Usage: bin/human-review-cleanup.sh [--project-dir <path>] [--retention-days N] [--apply]
set -euo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-.}"
apply=false
retention_days=30

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=true; shift ;;
    --retention-days)
      [ $# -ge 2 ] || { echo "human-review-cleanup: --retention-days requires an argument" >&2; exit 1; }
      retention_days="$2"; shift 2 ;;
    --project-dir)
      [ $# -ge 2 ] || { echo "human-review-cleanup: --project-dir requires an argument" >&2; exit 1; }
      project_dir="$2"; shift 2 ;;
    *)
      echo "human-review-cleanup: unknown argument: $1" >&2
      exit 1 ;;
  esac
done

# Calculate cutoff time (files older than this are eligible for deletion)
cutoff_epoch=$(( $(date +%s) - retention_days * 86400 ))

# Check if a file is older than the retention window
is_older_than_window() {
  local file_path="$1"
  if [ ! -e "$file_path" ]; then
    return 1
  fi
  local file_epoch
  file_epoch=$(stat -c %Y "$file_path" 2>/dev/null || date +%s)
  [ "$file_epoch" -lt "$cutoff_epoch" ]
}

review_dir="$project_dir/.claude/human-review"

# Human-review packet sweep (original logic)
if [ -d "$review_dir" ]; then
  review_real="$(cd -P "$review_dir" && pwd)"
  id_re='^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$'

  for entry_path in "$review_dir"/*; do
    [ -d "$entry_path" ] || continue
    entry="$(basename "$entry_path")"
    [[ $entry =~ $id_re ]] || continue

    decision="$entry_path/DECISION"
    resolved=false
    if [ -f "$decision" ] && [ -s "$decision" ]; then
      first_line="$(head -n1 "$decision" 2>/dev/null)" || first_line=""
      case "$first_line" in
        "DECISION $entry "*) resolved=true ;;
      esac
    fi

    if [ "$resolved" != true ]; then
      echo "[skip] pending: $entry"
      continue
    fi

    entry_real="$(cd -P "$entry_path" && pwd)" || continue
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
fi

# Marker file sweep (.claude/reviewed/*.{pass,fail,blocked,escalated,directed})
marker_dir="$project_dir/.claude/reviewed"
if [ -d "$marker_dir" ]; then
  for marker_path in "$marker_dir"/*.pass "$marker_dir"/*.fail "$marker_dir"/*.blocked "$marker_dir"/*.escalated "$marker_dir"/*.directed; do
    [ -f "$marker_path" ] || continue

    marker_name="$(basename "$marker_path")"
    marker_base="${marker_name%.*}"

    # Check if a review-join stamp exists for this unit
    review_join_stamp="$project_dir/.claude/.review-join.$marker_base"
    if [ -f "$review_join_stamp" ]; then
      echo "[skip] marker $marker_name: active review-join stamp"
      continue
    fi

    # Check retention window
    if ! is_older_than_window "$marker_path"; then
      echo "[skip] marker $marker_name: within retention window"
      continue
    fi

    if [ "$apply" = true ]; then
      rm -f "$marker_path"
      echo "deleted: .claude/reviewed/$marker_name"
    else
      echo "[dry-run] would delete: .claude/reviewed/$marker_name"
    fi
  done
fi

# Session-baseline sweep (.claude/.session-baseline.*)
claude_dir="$project_dir/.claude"
if [ -d "$claude_dir" ]; then
  for baseline_path in "$claude_dir"/.session-baseline.*; do
    [ -f "$baseline_path" ] || continue

    baseline_name="$(basename "$baseline_path")"

    # Check retention window
    if ! is_older_than_window "$baseline_path"; then
      echo "[skip] $baseline_name: within retention window"
      continue
    fi

    if [ "$apply" = true ]; then
      rm -f "$baseline_path"
      echo "deleted: .claude/$baseline_name"
    else
      echo "[dry-run] would delete: .claude/$baseline_name"
    fi
  done
fi

# WIP-handoff sweep (.claude/wip-handoff.*)
if [ -d "$claude_dir" ]; then
  for handoff_path in "$claude_dir"/wip-handoff.*; do
    [ -f "$handoff_path" ] || continue

    handoff_name="$(basename "$handoff_path")"

    # Check retention window
    if ! is_older_than_window "$handoff_path"; then
      echo "[skip] $handoff_name: within retention window"
      continue
    fi

    if [ "$apply" = true ]; then
      rm -f "$handoff_path"
      echo "deleted: .claude/$handoff_name"
    else
      echo "[dry-run] would delete: .claude/$handoff_name"
    fi
  done
fi

# Log rotation (never truncate, rotate to timestamped archive and preserve tail)
rotate_log() {
  local log_file="$1"

  if [ ! -f "$log_file" ]; then
    return
  fi

  # Get the last line to preserve for dedup logic
  local last_line
  last_line="$(tail -n 1 "$log_file" 2>/dev/null)" || last_line=""

  if [ -z "$last_line" ]; then
    return
  fi

  # Generate timestamp for archive filename (ISO-8601 compact)
  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  local archive_file="${log_file}.${timestamp}"

  # Guard against a same-second collision: two --apply runs within the same
  # second would otherwise compute the same archive name and mv would
  # clobber the first run's archive. Append a counter until the name is free.
  if [ -e "$archive_file" ]; then
    local counter=1
    while [ -e "${log_file}.${timestamp}.${counter}" ]; do
      counter=$((counter + 1))
    done
    archive_file="${log_file}.${timestamp}.${counter}"
  fi

  if [ "$apply" = true ]; then
    # Move old log to archive
    mv "$log_file" "$archive_file"
    # Create new log with the preserved last line (for dedup to work)
    printf '%s\n' "$last_line" > "$log_file"
    echo "rotated: $(basename "$log_file") -> $(basename "$archive_file"), tail preserved"
  else
    echo "[dry-run] would rotate: $(basename "$log_file") -> $(basename "$archive_file"), tail preserved for defer dedup"
  fi
}

# Rotate the four append-only audit logs. Unlike the marker/baseline/handoff
# sweeps above, rotation is NOT retention-gated: these logs are append-only
# and stay in active use, so their mtime is always recent and a retention
# check would mean --apply never rotates them. Rotate unconditionally.
if [ -d "$claude_dir" ]; then
  rotate_log "$claude_dir/review-audit.log"
  rotate_log "$claude_dir/dispatch-audit.log"
  rotate_log "$claude_dir/microworld-audit.log"
  rotate_log "$claude_dir/wip-audit.log"
fi
