#!/usr/bin/env bash
# unit-size.sh (st-u4): the lane for one unit, from its PLANNED scope, before any work is dispatched.
# Usage: unit-size.sh <unit> [--at-least <medium|full>] --contract <path> | unit-size.sh <unit> [--at-least <medium|full>] -- <path>...
# --at-least lifts the printed lane to the heavier of the measured lane and the floor (reason=at-least).
# Prints `lane: <small|medium|full> files=<n> reason=<word>`, writes .claude/bookkeeping/<unit>.lane and
# <unit>.scope, exit 0 (2 only on a bad unit id). Fails closed: anything it cannot measure is `full`.
# The orchestrator may move a unit to a heavier lane than this prints, never to a lighter one.
set -uo pipefail
[ "$#" -ge 1 ] || { echo "usage: unit-size.sh <unit> [--at-least <medium|full>] (--contract <path> | -- <path>...)" >&2; exit 2; }
unit="$1"; shift
[[ "$unit" =~ ^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$ ]] || { echo "unit-size: bad unit id: $unit" >&2; exit 2; }
floor=""
if [ "${1:-}" = --at-least ]; then
  case "${2:-}" in medium|full) floor="$2"; shift 2 ;; *) echo "unit-size: --at-least takes medium or full" >&2; exit 2 ;; esac
fi
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
top="$(git rev-parse --show-toplevel 2>/dev/null)" || top="$PWD"
cd "$top" || exit 2
dot="${CLAUDE_PROJECT_DIR:-$top}/.claude"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
: > "$W/entries"
emit() { # <lane> <n> <reason>
  local lane="$1" reason="$3" line
  case "$floor:$lane" in medium:small) lane=medium; reason=at-least ;; full:small|full:medium) lane=full; reason=at-least ;; esac
  line="lane: $lane files=$2 reason=$reason"
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
  shift
  # An argument that is an option or holds a newline cannot be one path: unmeasurable.
  for a in "$@"; do
    case "$a" in -*|*$'\n'*) emit full 0 unmeasurable ;; esac
  done
  printf '%s\n' "$@" > "$W/raw"; src=paths
else
  emit full 0 no-input
fi
# Bookkeeping entries never count: .claude/ copies are generated, docs/plans/ is the plan itself.
grep -vE '^(\.claude/|docs/plans/)' "$W/raw" | grep -v '^$' | sort -u > "$W/entries" || true
n="$(wc -l < "$W/entries" | tr -d ' ')"
# ONE judge for every raw entry, bookkeeping ones included, so the loops cannot disagree (st-u4 fix 2).
# sp_head <pattern>: reads one SENSITIVE_PATHS regex. Sets SP_HEAD to its literal head (the text between the
# leading ^ and the first regex metacharacter; a backslash-escaped character counts as literal; a character
# followed by * + ? or { is not literal) and SP_OPEN to 0 only when the rest of the pattern is exactly `$`
# (the pattern names one path), else 1 (a path beneath the head may match). Returns 1 for a pattern it cannot
# read (no leading ^, or any |): the caller then treats every directory-like entry as sensitive.
sp_head() {
  local re="$1" c n
  SP_HEAD=""; SP_OPEN=1
  case "$re" in '^'*) re="${re#^}" ;; *) return 1 ;; esac
  case "$re" in *'|'*) return 1 ;; esac
  while [ -n "$re" ]; do
    c="${re:0:1}"
    case "$c" in
      '\') SP_HEAD+="${re:1:1}"; re="${re:2}" ;;
      '.'|'*'|'+'|'?'|'['|']'|'('|')'|'{'|'}'|'$'|'^') break ;;
      *) n="${re:1:1}"
         case "$n" in '*'|'+'|'?'|'{') break ;; esac
         SP_HEAD+="$c"; re="${re:1}" ;;
    esac
  done
  [ "$re" = '$' ] && SP_OPEN=0
  return 0
}
# under_sensitive <entry>: exit 0 when some path beneath <entry>/ could be in the sensitive class: the entry is
# an ancestor of a pattern's head (`.claude` of `.claude/hooks/`, `bin` of `bin/cli.js`), or a pattern with an
# open tail has a head that is a prefix of <entry>/ (`adapters/.*hooks` and `adapters/windsurf`).
under_sensitive() {
  local e="$1/" re
  for re in ${SENSITIVE_PATHS[@]+"${SENSITIVE_PATHS[@]}"}; do
    sp_head "$re" || return 0
    case "$SP_HEAD" in "$e"*) return 0 ;; esac
    if [ "$SP_OPEN" = 1 ]; then case "$e" in "$SP_HEAD"*) return 0 ;; esac; fi
  done
  return 1
}
# judge_entry <path>: 0 = measurable and clean, 1 = unmeasurable, 2 = sensitive. An entry is a directory
# prefix (us_listed: the entry, or anything beneath entry/), so every entry that is not an existing regular
# file is judged by what could sit beneath it, never as a file (st-u4 fix 3). Sensitive: the class matches the
# entry or entry/, or under_sensitive. Unmeasurable: an unsafe path, glob, option-like or trailing-slash entry,
# an existing directory, and a not-yet-existing plain name with no dot (a new directory is a bigger task than
# small). Free zones: generated .claude/agents/ and .claude/bin/ copies and the docs/plans/ plan itself.
judge_entry() {
  local p="$1"
  us_safe_path "$p" || return 1
  case "$p" in *[*?[]*|*/|-*) return 1 ;; esac
  case "$p" in .claude/agents/*|.claude/bin/*|docs/plans/*) return 0 ;; esac
  touches_sensitive_path "$p" && return 2
  touches_sensitive_path "$p/" && return 2
  [ -f "$p" ] || { under_sensitive "$p" && return 2; }
  [ -d "$p" ] && return 1
  [ -e "$p" ] || case "${p##*/}" in *[!A-Za-z0-9_-]*) ;; *) return 1 ;; esac
  return 0
}
grep -v '^$' "$W/raw" | sort -u > "$W/all" || true
sens=0
while IFS= read -r p; do
  judge_entry "$p"; rc=$?
  [ "$rc" = 1 ] && emit full "$n" unmeasurable
  [ "$rc" = 2 ] && sens=1
done < "$W/all"
[ "$sens" = 1 ] && emit full "$n" sensitive
[ "$n" -gt 0 ] || emit full 0 empty
[ -f "$dot/reviewed/$unit.fail" ] && emit full "$n" fail-record
[ "$n" -gt 10 ] && emit full "$n" size
[ "$n" -le 4 ] && emit small "$n" "$src"
emit medium "$n" "$src"
