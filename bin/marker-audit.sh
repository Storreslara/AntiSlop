#!/usr/bin/env bash
# Sweep every .pass marker under .claude/reviewed/ through marker-verify.sh,
# defaulting to --list mode (parses and counts each marker's criteria;
# executes nothing). Pass --execute to actually run every marker's criteria
# in a throwaway worktree instead. Pass --notes to sweep non-blocking notes
# instead, printing each `marker-note=` line then one aggregate
# `marker-notes-sweep=` line; --tag=<spec|code|untagged|all> filters by tag
# (default all), --surface=<substring> is repeatable and keeps only note
# lines whose text contains it. Read-only sweep; never writes.
# See docs/plans/2026-08-25-harness-trust-gaps.md Step 6 and
# docs/plans/2026-09-01-advisory-note-channel-gh295.md Step 1.
#
# Usage: marker-audit.sh [project-dir] [--execute] [--notes [--tag=T] [--surface=S]...]
set -uo pipefail

project_dir="."
execute_flag=""
notes_flag=0
tag_filter="all"
surfaces=()
for arg in "$@"; do
  case "$arg" in
    --execute) execute_flag="--execute" ;;
    --notes) notes_flag=1 ;;
    --tag=*) tag_filter="${arg#--tag=}" ;;
    --surface=*) surfaces+=("${arg#--surface=}") ;;
    *) project_dir="$arg" ;;
  esac
done

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
verifier="$repo_root/hooks/scripts/marker-verify.sh"

reviewed_dir="$project_dir/.claude/reviewed"
[ -d "$reviewed_dir" ] || exit 0

matches_surfaces() {
  local text="$1" s
  [ "${#surfaces[@]}" -eq 0 ] && return 0
  for s in "${surfaces[@]}"; do
    [[ $text == *"$s"* ]] && return 0
  done
  return 1
}

total=0; markers=0; spec=0; code=0; untagged=0
while IFS= read -r marker_file; do
  [ -n "$marker_file" ] || continue
  task_id="${marker_file%.pass}"
  task_id="${task_id##*/}"
  [ -n "$task_id" ] || continue
  if [ "$notes_flag" -ne 1 ]; then
    "$verifier" "$task_id" "$project_dir" $execute_flag
    continue
  fi
  markers=$((markers + 1))
  while IFS= read -r out_line; do
    case "$out_line" in
      marker-note=*)
        tag="${out_line#marker-note=}"; tag="${tag%% *}"
        [ "$tag_filter" = "all" ] || [ "$tag_filter" = "$tag" ] || continue
        note_text="${out_line#marker-note=*unit=* }"
        matches_surfaces "$note_text" || continue
        printf '%s\n' "$out_line"
        total=$((total + 1))
        case "$tag" in
          spec) spec=$((spec + 1)) ;;
          code) code=$((code + 1)) ;;
          *) untagged=$((untagged + 1)) ;;
        esac
        ;;
    esac
  done < <("$verifier" "$task_id" "$project_dir" --notes)
done < <(ls -1 "$reviewed_dir"/*.pass 2>/dev/null || true)

[ "$notes_flag" -eq 1 ] && printf 'marker-notes-sweep=%d markers=%d spec=%d code=%d untagged=%d\n' "$total" "$markers" "$spec" "$code" "$untagged"

exit 0
