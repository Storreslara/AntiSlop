#!/usr/bin/env bash
# Classifies a .pass marker's `commit:` field against git history: does the
# cited commit belong to the unit the marker is about? Advisory only - always
# exits 0, prints exactly one line, and never decides policy for its caller.
# See docs/plans/2026-08-15-marker-commit-attribution.md Step 6.
#
# Usage: marker-commit-check.sh <task-id> [project-dir]
# Output (always): marker-commit-check=<ok|mismatch|unverifiable> unit=<id>
#                   commit=<sha|none> [candidates=<sha,sha,sha>]
set -uo pipefail

task_id="${1:-}"
project_dir="${2:-.}"

emit() {
  # $1=state $2=sha $3=candidates (comma-joined, optional)
  local line="marker-commit-check=$1 unit=${task_id} commit=${2}"
  [ -n "${3:-}" ] && line="$line candidates=$3"
  printf '%s\n' "$line"
  exit 0
}

[ -n "$task_id" ] || emit unverifiable none

marker="$project_dir/.claude/reviewed/${task_id}.pass"
[ -f "$marker" ] || emit unverifiable none

first_line="$(head -n 1 "$marker" 2>/dev/null || true)"
sha=""
if [[ $first_line =~ commit:[[:space:]]+([0-9a-f]{7,40}|none)([[:space:]]|$) ]]; then
  sha="${BASH_REMATCH[1]}"
fi
[ -n "$sha" ] || emit unverifiable none
[ "$sha" != none ] || emit unverifiable none

git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit unverifiable "$sha"
git -C "$project_dir" cat-file -e "${sha}^{commit}" >/dev/null 2>&1 || emit unverifiable "$sha"

# --- id token set: the task-id itself, plus (only if it matches this shape)
# the bare numeric core. ---
lower_id="$(printf '%s' "$task_id" | tr '[:upper:]' '[:lower:]')"
numeric_core=""
if [[ $task_id =~ ^(gh-?)?([0-9]+)([-.].*)?$ ]]; then
  numeric_core="${BASH_REMATCH[2]}"
fi
purely_numeric=0
[[ $task_id =~ ^[0-9]+$ ]] && purely_numeric=1

references() {
  # $1 = subject+body text -> 0 (true) if it references the unit id.
  # A purely-numeric id skips the raw-substring arm entirely: that arm would
  # otherwise degenerate into exactly the forbidden bare-digit match (id "31"
  # inside "0.31.53"). Only the id-bearing-context arm counts for it.
  local text_lower="${1,,}"
  if [ "$purely_numeric" -eq 0 ] && [[ $text_lower == *"$lower_id"* ]]; then
    return 0
  fi
  if [ -n "$numeric_core" ] \
     && [[ $text_lower =~ (gh-?${numeric_core}|\#${numeric_core}|unit[[:space:]]+\#?${numeric_core})([^0-9]|$) ]]; then
    return 0
  fi
  return 1
}

own_text="$(git -C "$project_dir" log -1 --format='%s%n%b' "$sha" 2>/dev/null || true)"
references "$own_text" && emit ok "$sha"

# One bulk scan over history reachable from HEAD - never a per-commit loop.
# %x1e marks the start of each record so the record's own trailing newline
# (git prints one after every --format entry) lands inside the record instead
# of leaking into the next one's sha field.
history="$(git -C "$project_dir" log --format='%x1e%H%x01%s%x02%b' 2>/dev/null || true)"
candidates=""
count=0
while IFS= read -r -d $'\x1e' record || [ -n "$record" ]; do
  [ -n "$record" ] || continue
  rec_sha="${record%%$'\x01'*}"
  [ -n "$rec_sha" ] || continue
  rest="${record#*$'\x01'}"
  if references "${rest//$'\x02'/$'\n'}"; then
    [ "$count" -lt 3 ] && candidates="${candidates:+$candidates,}$rec_sha"
    count=$((count + 1))
  fi
done <<< "$history"

[ "$count" -gt 0 ] && emit mismatch "$sha" "$candidates"

emit unverifiable "$sha"
