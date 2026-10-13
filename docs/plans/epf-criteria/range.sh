#!/usr/bin/env bash
# range.sh <unit-id> trailer          : distinct per-commit trailer-line counts
# range.sh <unit-id> tail <files...>   : commits after the unit's last one on its content files
# range.sh <unit-id> subjects          : count of the unit's commits whose subject lacks a body trailer-free form
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
unit=$1; mode=$2; shift 2
need_unit "$unit"
case "$mode" in
  trailer)
    for c in $(ucommits "$unit"); do
      git log -1 --format=%B "$c" | grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'
    done | sort -u | tr '\n' ' '; echo ;;
  tail)
    git log --format=%s "$L"..HEAD -- "$@" | grep -vcE "^[a-z]+\\($(printf '%s' "$unit" | sed 's/\./\\./g')\\): " ;;
  *) echo "unknown mode $mode"; exit 2 ;;
esac
