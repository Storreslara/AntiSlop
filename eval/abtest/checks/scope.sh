#!/usr/bin/env bash
# Out-of-scope measure for one run.
# Usage: scope.sh WORKTREE START_SHA ALLOWED_PATHS_FILE lines|files
# Counts added plus deleted lines (lines) or changed files (files) between
# START_SHA and HEAD outside the allowed paths. The persona scaffold (.claude/)
# and the pipeline's own plans (docs/plans/) never count, for either arm.
set -euo pipefail
wt="${1:?usage: scope.sh WORKTREE START_SHA ALLOWED_PATHS_FILE lines|files}"
start="${2:?missing START_SHA}"
allowed="${3:?missing ALLOWED_PATHS_FILE}"
mode="${4:?missing mode}"
specs=('.' ':(exclude).claude' ':(exclude)docs/plans')
while IFS= read -r p || [ -n "$p" ]; do
  [ -n "$p" ] && specs+=(":(exclude)$p")
done < "$allowed"
case "$mode" in
  lines) git -C "$wt" diff --numstat "$start..HEAD" -- "${specs[@]}" | awk '{s+=$1+$2} END{print s+0}' ;;
  files) git -C "$wt" diff --name-only "$start..HEAD" -- "${specs[@]}" | grep -c . || true ;;
  *) echo "scope.sh: mode must be lines or files" >&2; exit 2 ;;
esac
