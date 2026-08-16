#!/usr/bin/env bash
# Audit all .pass markers under .claude/reviewed/: enumerate them, check each
# against git history via marker-commit-check.sh, and report per-state counts
# plus one line per mismatch. Read-only inspection only — performs no writes.
# See docs/plans/2026-08-15-marker-commit-attribution.md Step 9.

set -uo pipefail

project_dir="${1:-.}"
reviewed_dir="$project_dir/.claude/reviewed"

# Locate the classifier script (in the repo root)
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
classifier="$repo_root/hooks/scripts/marker-commit-check.sh"

# Counters
ok_count=0
mismatch_count=0
unverifiable_count=0
mismatches=""  # lines to report

# Enumerate .pass markers using ls (plain read-only inspection)
if [ ! -d "$reviewed_dir" ]; then
  # No .claude/reviewed/ directory — report all zeros
  printf 'ok=0 mismatch=0 unverifiable=0\n'
  exit 0
fi

# Use ls to enumerate .pass files; process each task-id
while IFS= read -r marker_file; do
  [ -n "$marker_file" ] || continue

  # Extract task-id from filename (remove .pass suffix)
  task_id="${marker_file%.pass}"
  task_id="${task_id##*/}"  # strip directory path if present
  [ -n "$task_id" ] || continue

  # Invoke the classifier
  if ! classification=$("$classifier" "$task_id" "$project_dir" 2>/dev/null); then
    # Classifier error; treat as unverifiable
    ((unverifiable_count++))
    continue
  fi

  # Parse the classification token
  state=""
  if [[ $classification =~ marker-commit-check=([^[:space:]]+) ]]; then
    state="${BASH_REMATCH[1]}"
  fi

  case "$state" in
    ok)
      ((ok_count++))
      ;;
    mismatch)
      ((mismatch_count++))
      # Extract commit and candidates from the classification line
      mismatches="${mismatches}${classification}
"
      ;;
    unverifiable)
      ((unverifiable_count++))
      ;;
    *)
      # Unknown state; treat as unverifiable
      ((unverifiable_count++))
      ;;
  esac
done < <(ls -1 "$reviewed_dir"/*.pass 2>/dev/null || true)

# Print summary line first
printf 'ok=%d mismatch=%d unverifiable=%d\n' "$ok_count" "$mismatch_count" "$unverifiable_count"

# Print mismatch lines (if any)
if [ -n "$mismatches" ]; then
  printf '%s' "$mismatches"
fi

exit 0
