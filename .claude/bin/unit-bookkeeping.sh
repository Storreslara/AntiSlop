#!/usr/bin/env bash
# unit-bookkeeping.sh (qw-u1): the orchestrator's per-unit bookkeeping in one call per phase.
# dispatch <unit> [--contract <path>]: ladder-tier.sh plus the mechanical RULING lines.
# review <unit> <baseline> [--implementer-tier <t>]: reviewer-tier.sh plus the reviewer dispatch header.
# The header names the implementer tier only from that flag; no tier is stored. Never deletes anything.
# check <unit> <baseline> [--contract <path>]: the small-lane check that replaces the reviewer (rules C1-C8).
# flag <defer|skip> <reason>: puts "<kind>: <reason>" first in every existing pending-review flag.
dir="$(cd "$(dirname "$0")" && pwd)"
state="${CLAUDE_PROJECT_DIR:-$PWD}/.claude"
ledger="$state/orchestrator-rulings.log"
bk="$state/bookkeeping"
unit_re='^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$'

usage() { echo "usage: unit-bookkeeping.sh dispatch <unit> [--contract <path>] | review <unit> <baseline> [--implementer-tier <t>] | check <unit> <baseline> [--contract <path>] | flag <defer|skip> <reason>" >&2; exit 2; }
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ruling() { mkdir -p "$state"; echo "RULING $(ts) unit=$1 decision=$2" >> "$ledger"; }

check_unit() {
  if [[ ! "$1" =~ $unit_re ]]; then echo "unit-bookkeeping: bad unit id: $1" >&2; exit 2; fi
}

guard_demote() {
  local g
  if [ -n "${UB_GUARD:-}" ]; then
    g="$(bash "$UB_GUARD" "$1" --unit="$2" 2>/dev/null | head -n1)"
  else
    g="$(node "$dir/contract-guard.js" "$1" --unit="$2" 2>/dev/null | head -n1)"
  fi
  if [ -z "$g" ]; then g="guard unavailable"; fi
  echo "guard: $g"
  ruling "$2" "contract-guard sonnet: $g"
}

dispatch_cmd() {
  local unit="$2" contract="" ladder="${UB_LADDER:-$dir/ladder-tier.sh}" line tier rc
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
  line="$(bash "$ladder" "${args[@]}")"; rc=$?
  line="$(printf '%s\n' "$line" | head -n1)"
  read -r -a f <<< "$line"
  tier="${f[1]:-}"
  if [ "${f[0]:-}" != ladder-tier: ]; then tier=opus; fi
  case "$tier" in haiku|sonnet|opus|EXHAUSTED) ;; *) tier=opus ;; esac
  # A failed helper forces opus, except that exhaustion stays EXHAUSTED: that stop goes to the human.
  if [ "$rc" -ne 0 ] && [ "$tier" != EXHAUSTED ]; then tier=opus; fi
  if [ -n "$line" ]; then echo "$line"; fi
  echo "model: $tier"
  # A failed helper's reason word describes a run that did not complete: record the failure, never a
  # guard demotion or a no-contract ruling for a tier that is not used.
  if [ "$rc" -ne 0 ]; then
    ruling "$unit" "helper failed rc=$rc: $tier"
    return 0
  fi
  case " $line " in
    *" reason=guard-demotion "*) guard_demote "$contract" "$unit" ;;
    *" reason=no-contract "*) ruling "$unit" "contract-guard sonnet: no-contract" ;;
  esac
}

review_header() {
  local unit="$1" base="$2" word="$3" tier="$4"
  echo "Unit: $unit"
  case "$tier" in haiku|sonnet|opus) echo "Implementer tier: $tier" ;; esac
  echo "Range: $(git rev-parse "$base^{commit}")..$(git rev-parse HEAD)"
  echo "Reviewer model: $word"
  echo "Changed files:"
  git diff --name-only "$base..HEAD" | sed 's/^/- /'
}

review_cmd() {
  local unit="$2" base="$3" word rc itier="" rt="${UB_REVIEWER_TIER:-$dir/../hooks/scripts/reviewer-tier.sh}"
  case "$#" in
    3) ;;
    5) if [ "$4" = --implementer-tier ]; then itier="$5"; else usage; fi ;;
    *) usage ;;
  esac
  check_unit "$unit"
  if ! git rev-parse --verify -q "$base^{commit}" >/dev/null; then
    echo "unit-bookkeeping: bad baseline: $base" >&2; exit 2
  fi
  word="$(bash "$rt" "$unit" "$base..HEAD" 2>/dev/null)"; rc=$?
  word="$(printf '%s\n' "$word" | head -n1)"
  if [ "$rc" -ne 0 ]; then word=opus; fi
  case "$word" in sonnet|opus) ;; *) word=opus ;; esac
  mkdir -p "$bk"
  review_header "$unit" "$base" "$word" "$itier" > "$bk/$unit.header"
  cat "$bk/$unit.header"
}

# finish <outcome> <reason> [extra text]: the one exit of check; always rc 0.
finish() {
  echo "check: $1 unit=$CK_UNIT reason=$2"
  if [ "$1" = fail ]; then printf '%s\n' "$CK_PACKET"; [ -z "${3:-}" ] || printf '%s\n' "$3"; fi
  ruling "$CK_UNIT" "small-lane check: $1 $2"
  exit 0
}

check_cmd() {
  local unit="$2" base="$3" contract="" pc="${UB_PRECHECK:-$dir/review-precheck.sh}" rc first n line cmd out
  local -a cargs=()
  case "$#" in 3) ;; 5) if [ "$4" = --contract ]; then contract="$5"; cargs=(--contract "$contract"); else usage; fi ;; *) usage ;; esac
  check_unit "$unit"
  if ! git rev-parse --verify -q "$base^{commit}" >/dev/null; then
    echo "unit-bookkeeping: bad baseline: $base" >&2; exit 2
  fi
  CK_UNIT="$unit"; CK_PACKET=""
  [ "$(sed -n '1s/^lane: \([a-z]*\) .*/\1/p' "$bk/$unit.lane" 2>/dev/null)" = small ] || finish escalate not-small
  [ ! -e "$state/reviewed/$unit.fail" ] || finish escalate fail-record
  git diff --quiet HEAD 2>/dev/null || finish fail uncommitted
  [ "$(git rev-parse "$base^{commit}")" != "$(git rev-parse HEAD)" ] || finish escalate empty-range
  CK_PACKET="$(bash "$pc" "$unit" "$base" ${cargs[@]+"${cargs[@]}"} 2>/dev/null)"; rc=$?
  first="$(printf '%s\n' "$CK_PACKET" | head -n1)"
  { [ "$rc" -eq 0 ] && [[ "$first" == "precheck: result="* ]]; } || finish escalate precheck-error
  case " $first " in *" result=fail "*) finish fail precheck ;; esac
  printf '%s\n' "$CK_PACKET" | grep -q '^sensitive: ' && finish escalate sensitive
  n="${first##* judge=}"
  [[ "$n" =~ ^[0-9]+$ ]] || finish escalate precheck-error
  [ "$n" -gt 0 ] && finish escalate judge
  while read -r n; do
    line="$(bash "$pc" "$unit" "$base" ${cargs[@]+"${cargs[@]}"} --criterion "$n" 2>/dev/null </dev/null | head -n1)"
    case "$line" in
      "criterion $n: pass"*) ;;
      "criterion $n: fail exit=124 timeout"*) finish escalate timeout ;;
      *) finish fail "criterion-$n" "$line" ;;
    esac
  done < <(printf '%s\n' "$CK_PACKET" | sed -n 's/^criterion \([0-9]*\): deferred long.*/\1/p')
  if [ -n "$contract" ]; then
    printf '%s\n' "$CK_PACKET" | grep -qE '^criterion [0-9]+:' || finish escalate no-criteria
  else
    cmd="$(jq -r '.testAndLintCommand // empty' "$state/persona-config.json" 2>/dev/null)"
    [ -n "$cmd" ] || finish escalate no-criteria
    out="$(cd "$(git rev-parse --show-toplevel)" && timeout 590 bash -c "$cmd" 2>&1)"; rc=$?
    [ "$rc" -ne 124 ] || finish escalate timeout
    [ "$rc" -eq 0 ] || finish fail test-command "$(printf '%s\n' "$out" | tail -n 20)"
  fi
  finish pass precheck
}

flag_cmd() {
  local kind="${2:-}" reason f n=0 tmp
  case "$kind" in defer|skip) ;; *) usage ;; esac
  reason="${*:3}"
  case "$reason" in *$'\n'*) usage ;; esac
  [ -n "$(printf '%s' "$reason" | tr -d '[:space:]')" ] || usage
  for f in "$state"/.pending-review.*; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    tmp="$(mktemp)"
    { printf '%s: %s\n' "$kind" "$reason"; cat "$f"; } > "$tmp" \
      && dd if="$tmp" of="$f" conv=notrunc,nocreat status=none 2>/dev/null && n=$((n + 1))
    rm -f "$tmp"
  done
  echo "flag: $kind flags=$n"
  [ "$n" -gt 0 ]
}

case "${1:-}" in
  check) check_cmd "$@" ;;
  flag) flag_cmd "$@" ;;
  dispatch) dispatch_cmd "$@" ;;
  review) review_cmd "$@" ;;
  *) usage ;;
esac
