#!/usr/bin/env bash
# unit-size.sh (st-u4): the lane for one unit, from its PLANNED scope, before any work is dispatched.
# Usage: unit-size.sh <unit> --contract <path> | unit-size.sh <unit> -- <path>...
# Prints `lane: <small|medium|full> files=<n> reason=<word>`, writes .claude/bookkeeping/<unit>.lane and
# <unit>.scope, exit 0 (2 only on a bad unit id). Fails closed: anything it cannot measure is `full`.
# The orchestrator may move a unit to a heavier lane than this prints, never to a lighter one.
set -uo pipefail
[ "$#" -ge 1 ] || { echo "usage: unit-size.sh <unit> (--contract <path> | -- <path>...)" >&2; exit 2; }
unit="$1"; shift
[[ "$unit" =~ ^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$ ]] || { echo "unit-size: bad unit id: $unit" >&2; exit 2; }
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
top="$(git rev-parse --show-toplevel 2>/dev/null)" || top="$PWD"
cd "$top" || exit 2
dot="${CLAUDE_PROJECT_DIR:-$top}/.claude"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
: > "$W/entries"
emit() { # <lane> <n> <reason>
  local line="lane: $1 files=$2 reason=$3"
  mkdir -p "$dot/bookkeeping" && printf '%s\n' "$line" > "$dot/bookkeeping/$unit.lane" \
    && cp "$W/entries" "$dot/bookkeeping/$unit.scope"
  echo "$line"; exit 0
}
lib="$dir/../hooks/scripts/lib"
{ . "$lib/sensitive-paths.sh" && . "$lib/unit-scope.sh"; } 2>/dev/null || emit full 0 unmeasurable
# An empty or cut-short library defines nothing; an undefined function only reads as "false" (rp-u8).
declare -F touches_sensitive_path us_entries us_safe_path >/dev/null || emit full 0 unmeasurable
src=none
if [ "${1:-}" = --contract ]; then
  [ -n "${2:-}" ] && [ -f "$2" ] || emit full 0 no-input
  us_entries "$2" > "$W/raw"; src=contract
elif [ "${1:-}" = -- ]; then
  shift; printf '%s\n' "$@" > "$W/raw"; src=paths
else
  emit full 0 no-input
fi
# Bookkeeping entries never count: .claude/ copies are generated, docs/plans/ is the plan itself.
grep -vE '^(\.claude/|docs/plans/)' "$W/raw" | grep -v '^$' | sort -u > "$W/entries" || true
n="$(wc -l < "$W/entries" | tr -d ' ')"
[ "$n" -gt 0 ] || emit full 0 empty
while IFS= read -r p; do
  # An entry the sensitive-path anchors cannot judge (`./hooks/x.sh`, `src//a.js`, `/x`) is unmeasurable.
  us_safe_path "$p" || emit full "$n" unmeasurable
  case "$p" in *[*?[]*|*/) emit full "$n" unmeasurable ;; esac
  [ -d "$p" ] && emit full "$n" unmeasurable
done < "$W/entries"
while IFS= read -r p; do
  touches_sensitive_path "$p" && emit full "$n" sensitive
done < "$W/entries"
[ -f "$dot/reviewed/$unit.fail" ] && emit full "$n" fail-record
[ "$n" -gt 10 ] && emit full "$n" size
[ "$n" -le 4 ] && emit small "$n" "$src"
emit medium "$n" "$src"
