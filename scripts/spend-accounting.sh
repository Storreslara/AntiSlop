#!/usr/bin/env bash
# Cost accounting script: reports per-model spend and per-period FAIL rate
# from the transcript corpus and .claude/reviewed/ markers.
#
# Modeled on scripts/agent-audit.sh. Reads Claude Code's existing transcript
# store (~/.claude/projects/<slug>/) and .claude/reviewed/ markers; read-only,
# no repo modification. Requires an explicit cutoff (--until <ISO-8601>) to
# bound the corpus, since transcripts grow with every session.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CUTOFF_ISO8601=""
for arg in "$@"; do
  case "$arg" in
    --until=*) CUTOFF_ISO8601="${arg#--until=}" ;;
    *)
      echo "spend-accounting.sh: unrecognized argument: $arg" >&2
      exit 1
      ;;
  esac
done

if [ -z "$CUTOFF_ISO8601" ]; then
  echo "spend-accounting.sh: --until cutoff is required" >&2
  exit 1
fi

# Published rates, $/MTok, as (input:output). Cache reads price at 0.1x
# input; cache writes (cache_creation_input_tokens) price at 1.25x input.
declare -A PRICING=(
  [claude-haiku-4-5]="1:5"
  [claude-sonnet-5]="3:15"
  [claude-opus-5]="5:25"
  [claude-opus-4-8]="5:25"
  [claude-fable-5]="10:50"
)

# Collapses a dispatched model string (which may carry a dated suffix, e.g.
# claude-haiku-4-5-20251001) to the family bucket used for pricing/reporting.
normalize_model() {
  case "$1" in
    claude-haiku-4-5*) echo "claude-haiku-4-5" ;;
    claude-sonnet-5*) echo "claude-sonnet-5" ;;
    claude-opus-4-8*) echo "claude-opus-4-8" ;;
    claude-opus-5*) echo "claude-opus-5" ;;
    claude-fable-5*) echo "claude-fable-5" ;;
    *) echo "$1" ;;
  esac
}

slugify() {
  local p="$1" out="" c i
  for (( i = 0; i < ${#p}; i++ )); do
    c="${p:i:1}"
    case "$c" in
      [A-Za-z0-9]) out+="$c" ;;
      *) out+="-" ;;
    esac
  done
  printf '%s' "$out"
}

ROOT="$HOME/.claude/projects/$(slugify "$PROJECT_DIR")"
MARKER_DIR="$PROJECT_DIR/.claude/reviewed"

if [ ! -d "$ROOT" ]; then
  jq -n --arg error "no transcript corpus found at $ROOT" '{error: $error}'
  exit 0
fi

# --- spend aggregation ------------------------------------------------
# One row per usage-bearing assistant message, across every session and
# subagent transcript file: model, input_tokens, cache_creation_input_tokens,
# cache_read_input_tokens, output_tokens. "<synthetic>" is a non-billable
# marker Claude Code emits and is excluded.
RAW="$(mktemp)"
TOTALS="$(mktemp)"
trap 'rm -f "$RAW" "$TOTALS"' EXIT

while IFS= read -r -d '' f; do
  jq -r --arg cutoff "$CUTOFF_ISO8601" '
    select(.message.usage != null and (.timestamp // "") != "" and .timestamp <= $cutoff) |
    select(.message.model != "<synthetic>") |
    [
      (.message.model // "unknown"),
      (.message.usage.input_tokens // 0),
      (.message.usage.cache_creation_input_tokens // 0),
      (.message.usage.cache_read_input_tokens // 0),
      (.message.usage.output_tokens // 0)
    ] | @tsv
  ' "$f" 2>/dev/null || true
done < <(find "$ROOT" -name '*.jsonl' -print0) >> "$RAW"

if [ ! -s "$RAW" ]; then
  jq -n --arg error "no usage records found in corpus (cutoff: $CUTOFF_ISO8601)" '{error: $error}'
  exit 0
fi

while IFS=$'\t' read -r model in_tok cache_w cache_r out_tok; do
  [ -n "$model" ] || continue
  family="$(normalize_model "$model")"
  printf '%s\t%s\t%s\t%s\t%s\n' "$family" "$in_tok" "$cache_w" "$cache_r" "$out_tok"
done < "$RAW" | sort | awk -F'\t' '
  {
    m = $1
    msgs[m]++
    in_tok[m] += $2
    cache_w[m] += $3
    cache_r[m] += $4
    out_tok[m] += $5
  }
  END {
    for (m in msgs) printf "%s\t%d\t%d\t%d\t%d\t%d\n", m, msgs[m], in_tok[m], cache_w[m], cache_r[m], out_tok[m]
  }
' > "$TOTALS"

# --- cost per model -----------------------------------------------------
SPEND_JSON="[]"
TOTAL_SPEND="0"
while IFS=$'\t' read -r model msgs in_tok cache_w cache_r out_tok; do
  [ -n "$model" ] || continue
  rates="${PRICING[$model]:-0:0}"
  in_rate="${rates%:*}"
  out_rate="${rates#*:}"
  cost="$(awk -v in_t="$in_tok" -v cw="$cache_w" -v cr="$cache_r" -v out_t="$out_tok" \
               -v in_r="$in_rate" -v out_r="$out_rate" \
    'BEGIN {
       c = (in_t * in_r / 1000000) + (cw * in_r * 1.25 / 1000000) + (cr * in_r * 0.1 / 1000000) + (out_t * out_r / 1000000)
       printf "%.2f", c
     }')"
  TOTAL_SPEND="$(awk -v a="$TOTAL_SPEND" -v b="$cost" 'BEGIN {printf "%.2f", a + b}')"
  SPEND_JSON="$(jq -c --argjson arr "$SPEND_JSON" --arg model "$model" --argjson msgs "$msgs" --argjson cost "$cost" \
    '$arr + [{model: $model, messages: $msgs, cost: $cost}]' <<< '{}')"
done < "$TOTALS"

# Recompute with share percentages now that total is known.
SPEND_JSON="$(jq -c --argjson total "$TOTAL_SPEND" \
  'map(. + {share: (if $total > 0 then (((.cost / $total) * 1000 | round) / 10 | tostring) + "%" else "0.0%" end)})' \
  <<< "$SPEND_JSON")"

# --- FAIL rate aggregation from markers ---------------------------------
# One row per marker (task-id, mtime ISO-8601, pass|fail); split at
# ADR-0010's date (2026-08-02) by mtime, unique per task-id.
FAIL_RAW="$(mktemp)"
trap 'rm -f "$RAW" "$TOTALS" "$FAIL_RAW"' EXIT

if [ -d "$MARKER_DIR" ]; then
  for marker in "$MARKER_DIR"/*.pass "$MARKER_DIR"/*.fail; do
    [ -e "$marker" ] || continue
    mtime_sec="$(stat -c '%Y' "$marker" 2>/dev/null || echo 0)"
    mtime_iso="$(date -u -d @"$mtime_sec" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")"
    [ -n "$mtime_iso" ] || continue
    [ "$mtime_iso" \> "$CUTOFF_ISO8601" ] && continue
    base="$(basename "$marker")"
    case "$base" in
      *.pass) printf '%s\t%s\tpass\n' "${base%.pass}" "$mtime_iso" >> "$FAIL_RAW" ;;
      *.fail) printf '%s\t%s\tfail\n' "${base%.fail}" "$mtime_iso" >> "$FAIL_RAW" ;;
    esac
  done
fi

# Counts unique task-ids (units) and unique task-ids with >=1 .fail marker
# (with_fail), both within [lo, hi) by marker mtime — never raw marker rows,
# so a unit with two .fail markers before its eventual PASS still counts once.
fail_rate_for_period() {
  local label="$1" lo="$2" hi="$3"
  local units=0 fails=0 seen_units="" seen_fails=""
  while IFS=$'\t' read -r taskid mtime verdict; do
    [ -n "$taskid" ] || continue
    if [[ "$mtime" < "$lo" ]]; then continue; fi
    if [ -n "$hi" ] && [[ ! "$mtime" < "$hi" ]]; then continue; fi
    case "$seen_units" in
      *"|$taskid|"*) : ;;
      *) seen_units="${seen_units}|$taskid|"; units=$((units + 1)) ;;
    esac
    if [ "$verdict" = "fail" ]; then
      case "$seen_fails" in
        *"|$taskid|"*) : ;;
        *) seen_fails="${seen_fails}|$taskid|"; fails=$((fails + 1)) ;;
      esac
    fi
  done < "$FAIL_RAW"
  local rate="0.0"
  [ "$units" -gt 0 ] && rate="$(awk -v f="$fails" -v u="$units" 'BEGIN {printf "%.1f", (f/u)*100}')"
  jq -nc --arg period "$label" --argjson units "$units" --argjson with_fail "$fails" --arg rate "${rate}%" \
    '{period: $period, units: $units, with_fail: $with_fail, rate: $rate}'
}

FAIL_RATE_PRE="$(fail_rate_for_period "before 2026-08-02" "0000-01-01T00:00:00Z" "2026-08-02T00:00:00Z")"
FAIL_RATE_POST="$(fail_rate_for_period "from 2026-08-02" "2026-08-02T00:00:00Z" "")"

# --- output --------------------------------------------------------------
jq -n --arg cutoff "$CUTOFF_ISO8601" --argjson total_spend "$TOTAL_SPEND" \
  --argjson per_model_spend "$SPEND_JSON" \
  --argjson fail_rate_pre "$FAIL_RATE_PRE" \
  --argjson fail_rate_post "$FAIL_RATE_POST" \
  '{
    cutoff: $cutoff,
    per_model_spend: $per_model_spend,
    total_spend: $total_spend,
    per_period_fail_rate: [$fail_rate_pre, $fail_rate_post]
  }'
