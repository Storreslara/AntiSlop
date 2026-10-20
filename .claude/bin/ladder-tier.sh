#!/usr/bin/env bash
# Implementer-tier ladder arithmetic (ptr-u9). Prints exactly one line and exits 0:
#   ladder-tier: <haiku|sonnet|opus|EXHAUSTED> n=<n> ladder=<a,b,...> reason=<word>
# Usage: bin/ladder-tier.sh <unit-id> [--contract <path>] [--project <dir>]
#        bin/ladder-tier.sh --census [--project <dir>]
# It never writes anything; the rulings ledger stays the orchestrator's job.
#
# The rules (agents/orchestrator.md, "Per-unit model routing", points here):
# - Default tier: defaultImplementerModel from the project's persona config via one
#   lone jq read. An absent key (or an absent file) resolves to the frontmatter
#   `model:` of agents/lead-programmer.md; a present value outside haiku|sonnet|opus
#   resolves to opus (the more capable tier); an unreadable config is fail-closed.
# - Ladder: two entries per tier from the start tier upward. From haiku:
#   haiku,haiku,sonnet,sonnet,opus,opus. From sonnet: sonnet,sonnet,opus,opus.
#   From opus: opus,opus. Attempt n+1 runs on entry n+1 (0-based index n).
# - n is the unit's FAIL-block count (bin/fail-count.sh's grep, same state-access lib).
#   A PASS marker newer than the .fail record means n=0 (expiry, reason=expired).
#   n >= the ladder length prints EXHAUSTED (ladder exhaustion).
# - Haiku-default cutover: the timestamp on the "Haiku-default cutover:" line of
#   agents/orchestrator.md, read from there and never duplicated. A unit with any FAIL
#   block dated before it starts at the more capable of sonnet and the default tier
#   (reason=pre-cutover).
# - Contract-score guard: when the ladder starts at haiku and --contract is given, run
#   `node bin/contract-guard.js <contract> --unit=<unit-id>`; unless its first line starts
#   `contract-guard: haiku `, use the sonnet ladder (reason=guard-demotion). With no
#   --contract, use the sonnet ladder (reason=no-contract).
# - Any read error prints opus with reason=fail-closed (n=unknown).
# - reason is the first that applies of: fail-closed, guard-demotion, no-contract,
#   pre-cutover, expired, guard-pass, default.
# - --census prints one line per existing .fail record, prefixed "<unit-id> ", with n the
#   raw block count (no expiry) and no guard; it is how the real record set is audited.
set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

unit=""
contract=""
project="."
census=0
while [ $# -gt 0 ]; do
  case "$1" in
    --census) census=1; shift ;;
    --contract) contract="${2:-}"; shift 2 || break ;;
    --project) project="${2:-.}"; shift 2 || break ;;
    *) unit="$1"; shift ;;
  esac
done

dot="${project}/.claude"
. "$repo_root/hooks/scripts/lib/state-access.sh"
set +e

ladder_of() {
  case "$1" in
    haiku) echo "haiku,haiku,sonnet,sonnet,opus,opus" ;;
    sonnet) echo "sonnet,sonnet,opus,opus" ;;
    *) echo "opus,opus" ;;
  esac
}

emit() { printf 'ladder-tier: %s n=%s ladder=%s reason=%s\n' "$1" "$2" "$3" "$4"; }
closed() { emit opus unknown opus fail-closed; }

# Default tier: one lone jq read of the config, else the lead-programmer frontmatter model.
resolve_default() {
  local cfg="${project}/.claude/persona-config.json" v
  if [ -f "$cfg" ]; then
    v="$(jq -r 'if has("defaultImplementerModel") then (.defaultImplementerModel | if . == "haiku" or . == "sonnet" or . == "opus" then . else "opus" end) else "" end' "$cfg" 2>/dev/null)" || return 1
  else
    v=""
  fi
  if [ -z "$v" ]; then
    v="$(sed -n '1,/^---$/{s/^model: *//p}' "$repo_root/agents/lead-programmer.md" | head -1)"
    [ -n "$v" ] || return 1
  fi
  case "$v" in
    haiku|sonnet|opus) echo "$v" ;;
    *) echo opus ;;
  esac
}

cutover_ts() {
  sed -n 's/.*\*\*Haiku-default cutover: \([0-9TZ:-]*\)\.\*\*.*/\1/p' "$repo_root/agents/orchestrator.md" | head -1
}

# compute <unit> <census 0|1> <contract> -> prints the one line
compute() {
  local id="$1" raw="$2" ctr="$3" marker pass n=0 default cut start ladder reason ts pre=0 expired=0 g
  default="$(resolve_default)" || { closed; return; }
  cut="$(cutover_ts)"
  [ -n "$cut" ] || { closed; return; }
  marker="$(unit_id_marker_path "$id" fail)"
  if [ -f "$marker" ]; then
    n="$(grep -cE "^FAIL ${id} " "$marker")" || n=0
    [ "$n" -gt 0 ] 2>/dev/null || { closed; return; }
    pass="$(unit_id_marker_path "$id" pass)"
    if [ "$raw" = 0 ] && [ -f "$pass" ] && [ "$pass" -nt "$marker" ]; then
      n=0; expired=1
    else
      while read -r ts; do
        [ -n "$ts" ] && [[ "$ts" < "$cut" ]] && pre=1
      done < <(grep -E "^FAIL ${id} " "$marker" | awk '{print $3}')
    fi
  fi
  start="$default"
  reason=default
  if [ "$pre" = 1 ]; then
    [ "$start" = haiku ] && start=sonnet
    reason=pre-cutover
  elif [ "$expired" = 1 ]; then
    reason=expired
  fi
  if [ "$start" = haiku ] && [ "$raw" = 0 ]; then
    if [ -z "$ctr" ]; then
      start=sonnet; reason=no-contract
    else
      g="$(node "$repo_root/bin/contract-guard.js" "$ctr" --unit="$id" 2>/dev/null | head -1)"
      case "$g" in
        "contract-guard: haiku "*) [ "$reason" = default ] && reason=guard-pass ;;
        *) start=sonnet; reason=guard-demotion ;;
      esac
    fi
  fi
  ladder="$(ladder_of "$start")"
  IFS=, read -ra arr <<< "$ladder"
  if [ "$n" -ge "${#arr[@]}" ]; then
    emit EXHAUSTED "$n" "$ladder" "$reason"
  else
    emit "${arr[$n]}" "$n" "$ladder" "$reason"
  fi
}

if [ "$census" = 1 ]; then
  for f in "$dot"/reviewed/*.fail; do
    [ -f "$f" ] || continue
    id="$(basename "$f" .fail)"
    printf '%s ' "$id"
    compute "$id" 1 ""
  done
  exit 0
fi

if [ -z "$unit" ] || ! unit_id_valid "$unit"; then
  closed
  exit 0
fi
compute "$unit" 0 "$contract"
exit 0
