#!/usr/bin/env bash
# unit-bookkeeping.sh (qw-u1): the orchestrator's per-unit bookkeeping in one call per phase.
# dispatch <unit> [--contract <path>]: ladder-tier.sh plus the mechanical RULING lines.
# review <unit> <baseline> [--implementer-tier <t>]: reviewer-tier.sh plus the reviewer dispatch header.
# The header names the implementer tier only from that flag; no tier is stored. Never deletes anything.
# check <unit> <baseline> [--contract <path>]: the small-lane check that replaces the reviewer (rules C1-C8).
# flag <defer|skip> <reason>: puts "<kind>: <reason>" first in every existing pending-review flag.
# repo: prints "repo: small|large files=<n> lines=<n>" for the tracked files outside .claude and docs/plans.
dir="$(cd "$(dirname "$0")" && pwd)"
state="${CLAUDE_PROJECT_DIR:-$PWD}/.claude"
ledger="$state/orchestrator-rulings.log"
bk="$state/bookkeeping"
unit_re='^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$'

usage() { echo "usage: unit-bookkeeping.sh dispatch <unit> [--contract <path>] | review <unit> <baseline> [--implementer-tier <t>] | check <unit> <baseline> [--contract <path>] | flag <defer|skip> <reason> | repo" >&2; exit 2; }
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
  if [ "$(jq -r '.reviewGating.mode // "enforce"' "$state/persona-config.json" 2>/dev/null)" = off ]; then
    echo "Review gating: off"
  else
    echo "Review gating: enforce"
  fi
  if [ -f "$state/constitution.md" ]; then echo "Constitution: present"; else echo "Constitution: absent"; fi
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

# C1-C2c: lane, fail record, clean tree, baseline is an ancestor, range changes something.
check_tree() {
  local st rc
  CK_TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || finish fail uncommitted
  [ "$(sed -n '1s/^lane: \([a-z]*\) .*/\1/p' "$bk/$CK_UNIT.lane" 2>/dev/null)" = small ] || finish escalate not-small
  [ ! -e "$state/reviewed/$CK_UNIT.fail" ] || finish escalate fail-record
  st="$(git -C "$CK_TOP" status --porcelain --untracked-files=all -- . ':(exclude).claude/agent-memory' 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] && [ -z "$st" ] || finish fail uncommitted
  git merge-base --is-ancestor "$CK_BASE" HEAD 2>/dev/null || finish escalate bad-baseline
  git diff --quiet "$CK_BASE" HEAD 2>/dev/null; [ "$?" -eq 1 ] || finish escalate empty-range
}

# C3-C5: the precheck's first line, then sensitive paths, size and judge counts. Sets CK_PACKET, CK_DEF.
check_packet() {
  local pc="$1" rc first re n res fails jd; shift
  CK_PACKET="$(bash "$pc" "$CK_UNIT" "$CK_BASE" "$@" 2>/dev/null)"; rc=$?
  first="$(printf '%s\n' "$CK_PACKET" | head -n1)"
  re="^precheck: result=(pass|fail) unit=${CK_UNIT//./\\.} range=[^ ]+ fails=([0-9]+) deferred=([0-9]+) judge=([0-9]+)\$"
  [ "$rc" -eq 0 ] && [[ "$first" =~ $re ]] || finish escalate precheck-error
  res="${BASH_REMATCH[1]}"; fails="${BASH_REMATCH[2]}"; CK_DEF="${BASH_REMATCH[3]}"; jd="${BASH_REMATCH[4]}"
  [ "$res" = pass ] || finish fail precheck
  [ "$fails" = 0 ] || finish escalate precheck-error
  n="$(printf '%s\n' "$CK_PACKET" | grep -c '^sensitive: ')"
  [[ "$n" =~ ^[0-9]+$ ]] || finish escalate precheck-error
  [ "$n" = 0 ] || finish escalate sensitive
  n="$(printf '%s\n' "$CK_PACKET" | grep -cE '^size: files=[0-9]+ ')"
  [ "$n" = 1 ] || finish escalate precheck-error
  n="$(printf '%s\n' "$CK_PACKET" | sed -n 's/^size: files=\([0-9]*\) .*/\1/p')"
  [[ ! "$n" =~ ^0+$ ]] || finish escalate empty-range
  [ "$jd" = 0 ] || finish escalate judge
}

# C6: re-run every deferred criterion; the deferred lines and the re-runs must match the packet's count.
check_deferred() {
  local pc="$1" n line re cnt i=0; shift
  cnt="$(printf '%s\n' "$CK_PACKET" | grep -cE '^criterion [0-9]+: deferred long$')"
  [ "$cnt" = "$CK_DEF" ] || finish escalate precheck-error
  while read -r n; do
    i=$((i + 1))
    line="$(bash "$pc" "$CK_UNIT" "$CK_BASE" "$@" --criterion "$n" 2>/dev/null </dev/null | head -n1)"
    re="^criterion $n: pass exit=[0-9]+\$"
    if [[ "$line" =~ $re ]]; then continue; fi
    case "$line" in "criterion $n: fail exit=124 timeout"*) finish escalate timeout ;; esac
    finish fail "criterion-$n" "$line"
  done < <(printf '%s\n' "$CK_PACKET" | sed -n 's/^criterion \([0-9]*\): deferred long$/\1/p')
  [ "$i" = "$cnt" ] || finish escalate precheck-error
}

# C7 with a contract: the packet's criteria are exactly the numbers the contract declares. A contract
# where us_section could read the criteria differently (a second heading, a fence) escalates instead.
check_declared() {
  local contract="$1" bad got sec decl
  bad="$(printf '%s\n' "$CK_PACKET" | grep '^criterion ' | grep -vE '^criterion [0-9]+: (pass exit=[0-9]+|deferred long)$')"
  [ -z "$bad" ] || finish escalate precheck-error
  got="$(printf '%s\n' "$CK_PACKET" | sed -n 's/^criterion \([0-9][0-9]*\):.*/\1/p' | sort -n)"
  [ -n "$got" ] || finish escalate no-criteria
  case "$contract" in /*) ;; *) contract="$CK_TOP/$contract" ;; esac
  [ -r "$contract" ] || finish escalate criteria-mismatch
  [ "$(grep -c '^## Acceptance criteria' "$contract")" = 1 ] || finish escalate criteria-mismatch
  sec="$(sed -n '/^## Acceptance criteria/,/^## /p' "$contract")" || finish escalate criteria-mismatch
  ! printf '%s\n' "$sec" | grep -qE '^[[:space:]]*(~~~|```)' || finish escalate criteria-mismatch
  decl="$(printf '%s\n' "$sec" | sed -n 's/^\([0-9][0-9]*\)\. .*/\1/p' | sort -n)"
  [ -n "$decl" ] && [ "$decl" = "$got" ] && [ "$decl" = "$(printf '%s\n' "$decl" | sort -nu)" ] || finish escalate criteria-mismatch
}

# C7 without a contract: the project's test command passes from the repo top.
check_command() {
  local cmd out rc
  cmd="$(jq -r '.testAndLintCommand // empty' "$state/persona-config.json" 2>/dev/null)"
  [ -n "$cmd" ] || finish escalate no-criteria
  out="$(cd "$(git rev-parse --show-toplevel)" && timeout 590 bash -c "$cmd" 2>&1)"; rc=$?
  [ "$rc" -ne 124 ] || finish escalate timeout
  [ "$rc" -eq 0 ] || finish fail test-command "$(printf '%s\n' "$out" | tail -n 20)"
}

check_cmd() {
  local unit="$2" base="$3" contract="" pc="${UB_PRECHECK:-$dir/review-precheck.sh}"
  local -a cargs=()
  case "$#" in 3) ;; 5) if [ "$4" = --contract ]; then contract="$5"; cargs=(--contract "$contract"); else usage; fi ;; *) usage ;; esac
  check_unit "$unit"
  if ! git rev-parse --verify -q "$base^{commit}" >/dev/null; then
    echo "unit-bookkeeping: bad baseline: $base" >&2; exit 2
  fi
  CK_UNIT="$unit"; CK_PACKET=""; CK_BASE="$(git rev-parse "$base^{commit}")"
  check_tree
  check_packet "$pc" ${cargs[@]+"${cargs[@]}"}
  check_deferred "$pc" ${cargs[@]+"${cargs[@]}"}
  if [ -n "$contract" ]; then check_declared "$contract"; else check_command; fi
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

repo_cmd() {
  local top n l
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "repo: large files=0 lines=0"; return 0; }
  n="$(cd "$top" && git ls-files -- . ':(exclude).claude' ':(exclude)docs/plans' | wc -l | tr -d ' ')"
  l="$(cd "$top" && git ls-files -z -- . ':(exclude).claude' ':(exclude)docs/plans' | xargs -0 -r cat 2>/dev/null | wc -l | tr -d ' ')"
  case "$n$l" in ''|*[!0-9]*) echo "repo: large files=0 lines=0"; return 0 ;; esac
  if [ "$n" -le 10 ] || [ "$l" -lt 1000 ]; then echo "repo: small files=$n lines=$l"; else echo "repo: large files=$n lines=$l"; fi
}

case "${1:-}" in
  repo) repo_cmd ;;
  check) check_cmd "$@" ;;
  flag) flag_cmd "$@" ;;
  dispatch) dispatch_cmd "$@" ;;
  review) review_cmd "$@" ;;
  *) usage ;;
esac
