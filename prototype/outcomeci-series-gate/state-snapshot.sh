#!/usr/bin/env bash
# Read-only: sha256 + relpath of the marker/flag files a trial run must not change.
set -uo pipefail
dir="${1:?usage: state-snapshot.sh <project-dir>}"
cd "$dir" || exit 2

lines="$(
  {
    find .claude/reviewed .claude/human-review -type f 2>/dev/null
    find .claude -maxdepth 1 -type f \( -name '.pending-review*' -o -name '.review-join.*' -o -name 'wip-handoff.*' \) 2>/dev/null
  } | LC_ALL=C sort | while IFS= read -r f; do sha256sum -- "$f"; done
)"

[ -n "$lines" ] && printf '%s\n' "$lines"
n=0
[ -n "$lines" ] && n="$(printf '%s\n' "$lines" | wc -l)"
printf 'snapshot-files=%s\n' "$n"
