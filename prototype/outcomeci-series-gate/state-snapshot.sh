#!/usr/bin/env bash
# Read-only: sha256 + relpath of the marker/flag files a trial run must not change.
set -uo pipefail
dir="${1:?usage: state-snapshot.sh <project-dir>}"
cd "$dir" || exit 2
[ -d .claude ] || { echo "state-snapshot: no .claude/ in $dir" >&2; exit 2; }

# A symlink is never followed: its line hashes the link target string instead (D-E).
entry() {
  if [ -L "$1" ]; then
    printf 'link:%s  %s\n' "$(printf '%s' "$(readlink -- "$1")" | sha256sum | cut -d' ' -f1)" "$1"
  else
    sha256sum -- "$1"
  fi
}

lines="$(
  {
    find .claude/reviewed .claude/human-review \( -type f -o -type l \) 2>/dev/null
    find .claude -maxdepth 1 \( -type f -o -type l \) \( -name '.pending-review*' -o -name '.review-join.*' -o -name 'wip-handoff.*' \) 2>/dev/null
  } | LC_ALL=C sort | while IFS= read -r f; do entry "$f"; done
)"

[ -n "$lines" ] && printf '%s\n' "$lines"
n=0
[ -n "$lines" ] && n="$(printf '%s\n' "$lines" | wc -l)"
printf 'snapshot-files=%s\n' "$n"
