#!/usr/bin/env bash
# unit-bookkeeping.sh (qw-u1): the orchestrator's per-unit bookkeeping in one call per phase.
# dispatch <unit> [--contract <path>]: ladder-tier.sh plus the mechanical RULING lines.
# review <unit> <baseline>: reviewer-tier.sh plus the reviewer dispatch header. Never deletes anything.
dir="$(cd "$(dirname "$0")" && pwd)"
state="${CLAUDE_PROJECT_DIR:-$PWD}/.claude"
ledger="$state/orchestrator-rulings.log"
bk="$state/bookkeeping"
unit_re='^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$'

usage() { echo "usage: unit-bookkeeping.sh dispatch <unit> [--contract <path>] | review <unit> <baseline>" >&2; exit 2; }
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ruling() { mkdir -p "$state"; echo "RULING $(ts) unit=$1 decision=$2" >> "$ledger"; }

check_unit() {
  if [[ ! "$1" =~ $unit_re ]]; then echo "unit-bookkeeping: bad unit id: $1" >&2; exit 2; fi
}

record_tier() {
  if [ "$2" != EXHAUSTED ]; then mkdir -p "$bk"; printf '%s\n' "$2" > "$bk/$1.tier"; fi
}

guard_demote() {
  local g
  if [ -n "${UB_GUARD:-}" ]; then
    g="$(bash "$UB_GUARD" "$1" --unit="$2" | head -n1)"
  else
    g="$(node "$dir/contract-guard.js" "$1" --unit="$2" | head -n1)"
  fi
  echo "guard: $g"
  ruling "$2" "contract-guard sonnet: $g"
}

dispatch_cmd() {
  local unit="$2" contract="" ladder="${UB_LADDER:-$dir/ladder-tier.sh}" line tier
  local -a args f
  if [ "$#" -eq 4 ] && [ "$3" = --contract ]; then contract="$4"; elif [ "$#" -ne 2 ]; then usage; fi
  check_unit "$unit"
  if [ ! -f "$ladder" ]; then
    echo "model: opus"
    ruling "$unit" "helper missing: $ladder: opus"
    return 0
  fi
  args=("$unit")
  if [ -n "$contract" ]; then args+=(--contract "$contract"); fi
  line="$(bash "$ladder" "${args[@]}" | head -n1)"
  read -r -a f <<< "$line"
  tier="${f[1]:-}"
  case "$tier" in haiku|sonnet|opus|EXHAUSTED) ;; *) tier=opus ;; esac
  if [ -n "$line" ]; then echo "$line"; fi
  echo "model: $tier"
  record_tier "$unit" "$tier"
  case " $line " in
    *" reason=guard-demotion "*) guard_demote "$contract" "$unit" ;;
    *" reason=no-contract "*) ruling "$unit" "contract-guard sonnet: no-contract" ;;
  esac
}

review_header() {
  local unit="$1" base="$2" word="$3" tier=""
  if [ -f "$bk/$unit.tier" ]; then tier="$(cat "$bk/$unit.tier")"; fi
  echo "Unit: $unit"
  case "$tier" in haiku|sonnet|opus) echo "Implementer tier: $tier" ;; esac
  echo "Range: $base..$(git rev-parse HEAD)"
  echo "Reviewer model: $word"
  echo "Changed files:"
  git diff --name-only "$base..HEAD" | sed 's/^/- /'
}

review_cmd() {
  local unit="$2" base="$3" word rt="${UB_REVIEWER_TIER:-$dir/../hooks/scripts/reviewer-tier.sh}"
  [ "$#" -eq 3 ] || usage
  check_unit "$unit"
  if ! git rev-parse --verify -q "$base^{commit}" >/dev/null; then
    echo "unit-bookkeeping: bad baseline: $base" >&2; exit 2
  fi
  word="$(bash "$rt" "$unit" "$base..HEAD" 2>/dev/null | head -n1)"
  case "$word" in sonnet|opus) ;; *) word=opus ;; esac
  mkdir -p "$bk"
  review_header "$unit" "$base" "$word" > "$bk/$unit.header"
  cat "$bk/$unit.header"
}

case "${1:-}" in
  dispatch) dispatch_cmd "$@" ;;
  review) review_cmd "$@" ;;
  *) usage ;;
esac
