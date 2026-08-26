#!/usr/bin/env bash
# Cost accounting script: reports per-model spend and per-model FAIL rate
# from the transcript corpus and .claude/reviewed/ markers.
#
# Modeled on scripts/agent-audit.sh. Reads Claude Code's existing transcript
# store (~/.claude/projects/<slug>/) and .claude/reviewed/ markers; reads-only,
# no repo modification. Requires an explicit cutoff (--until <ISO-8601>) to
# bound the corpus, since transcripts grow with every session.
#
# Outputs stable, parseable JSON with:
#   - per_model_spend: { model: string, messages: number, cost: number, share: string }
#   - per_period_fail_rate: { period: string, units: number, with_fail: number, rate: string }
#
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

# --- pricing table (published rates as of spec authoring) -----
# Haiku 4.5 $1/$5, Sonnet 5 $3/$15, Opus 5 $5/$25, Fable 5 $10/$50 per MTok
# Cache reads at 0.1×, cache writes at 1.25×; this script ignores cache
# (messages with usage.cache_* fields are rare in the corpus).
declare -A PRICING=(
  [claude-haiku-4-5]="0.001:0.005"
  [claude-haiku-4]="0.001:0.005"
  [claude-sonnet-5]="0.003:0.015"
  [claude-sonnet-4-20250514]="0.003:0.015"
  [claude-opus-5]="0.005:0.025"
  [claude-opus-4-8]="0.005:0.025"
  [claude-fable-5]="0.010:0.050"
)

cost_for_model() {
  local model="$1" input_tokens="$2" output_tokens="$3"
  local rates="${PRICING[$model]:-}"
  if [ -z "$rates" ]; then
    echo "0"
    return
  fi
  local in_rate="${rates%:*}" out_rate="${rates#*:}"
  awk -v in_tok="$input_tokens" -v out_tok="$output_tokens" -v in_r="$in_rate" -v out_r="$out_rate" \
    'BEGIN {printf "%.2f", (in_tok * in_r / 1000000) + (out_tok * out_r / 1000000)}'
}

# Root resolution: transcript corpus at ~/.claude/projects/<slug>/,
# markers at .claude/reviewed/
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

# --- spend aggregation from transcripts ----
SPEND_FILE="$(mktemp)"
trap "rm -f '$SPEND_FILE'" EXIT

# Iterate sessions, extract usage.input_tokens and usage.output_tokens per message,
# look up dispatched model from meta.json, sum by model.
for sid in "$ROOT"/*; do
  [ -d "$sid" ] || continue
  # Session .jsonl files
  for f in "$sid"/*.jsonl; do
    [ -e "$f" ] || continue
    # Filter by timestamp <= cutoff
    jq -r --arg cutoff "$CUTOFF_ISO8601" \
      '.message.usage? | select((.timestamp // "") <= $cutoff) |
       (.model // "unknown") as $m | ($_.input_tokens // 0) as $in | ($_.output_tokens // 0) as $out |
       "\($m)\t\($in)\t\($out)"' "$f" 2>/dev/null || true
  done | while read -r model in_tok out_tok; do
    [ -n "$model" ] || continue
    printf '%s\t%s\t%s\n' "$model" "$in_tok" "$out_tok" >> "$SPEND_FILE"
  done

  # Dispatch .jsonl files (subagents)
  subdir="$sid/subagents"
  [ -d "$subdir" ] || continue
  for meta in "$subdir"/*.meta.json; do
    [ -e "$meta" ] || continue
    jsonl="${meta%.meta.json}.jsonl"
    [ -f "$jsonl" ] || continue
    dispatch_model="$(jq -r '.model // empty' "$meta" 2>/dev/null || true)"
    [ -n "$dispatch_model" ] || dispatch_model="unknown"
    # Filter by timestamp <= cutoff
    jq -r --arg cutoff "$CUTOFF_ISO8601" --arg dmodel "$dispatch_model" \
      '.message.usage? | select((.timestamp // "") <= $cutoff) |
       ($_.input_tokens // 0) as $in | ($_.output_tokens // 0) as $out |
       "\($dmodel)\t\($in)\t\($out)"' "$jsonl" 2>/dev/null || true
  done | while read -r model in_tok out_tok; do
    [ -n "$model" ] || continue
    printf '%s\t%s\t%s\n' "$model" "$in_tok" "$out_tok" >> "$SPEND_FILE"
  done
done

# Aggregate by model
if [ ! -s "$SPEND_FILE" ]; then
  jq -n --arg error "no usage records found in corpus (cutoff: $CUTOFF_ISO8601)" '{error: $error}'
  exit 0
fi

TOTALS="$(mktemp)"
trap "rm -f '$SPEND_FILE' '$TOTALS'" EXIT

sort "$SPEND_FILE" | awk '
  {
    model = $1
    in_tok = $2 + 0
    out_tok = $3 + 0
    if (!(model in models)) {
      models[model] = 0
      in_tokens[model] = 0
      out_tokens[model] = 0
      msgs[model] = 0
    }
    in_tokens[model] += in_tok
    out_tokens[model] += out_tok
    msgs[model] += 1
  }
  END {
    for (m in models) {
      printf "%s\t%d\t%d\t%d\n", m, msgs[m], in_tokens[m], out_tokens[m]
    }
  }
' > "$TOTALS"

# Calculate spend per model
SPEND_JSON="$(mktemp)"
trap "rm -f '$SPEND_FILE' '$TOTALS' '$SPEND_JSON'" EXIT

while read -r model msgs in_tok out_tok; do
  [ -n "$model" ] || continue
  cost="$(cost_for_model "$model" "$in_tok" "$out_tok")"
  printf '%s\t%s\t%s\t%s\n' "$model" "$msgs" "$cost" "$in_tok:$out_tok" >> "$SPEND_JSON"
done < "$TOTALS"

# --- FAIL rate aggregation from markers ----
# Markers: .claude/reviewed/<task-id>.pass or .fail
# Extract mtime to approximate dispatch date, count pre/post ADR-0010 (2026-08-02)
FAIL_FILE="$(mktemp)"
trap "rm -f '$SPEND_FILE' '$TOTALS' '$SPEND_JSON' '$FAIL_FILE'" EXIT

if [ -d "$MARKER_DIR" ]; then
  for marker in "$MARKER_DIR"/*.{pass,fail}; do
    [ -e "$marker" ] || continue
    mtime_sec="$(stat -c '%Y' "$marker" 2>/dev/null || echo 0)"
    # Convert to ISO-8601
    mtime_iso="$(date -u -d @"$mtime_sec" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")"
    [ -n "$mtime_iso" ] || continue
    # Filter by cutoff
    if [ "$mtime_iso" \> "$CUTOFF_ISO8601" ]; then
      continue
    fi
    case "$(basename "$marker")" in
      *.pass) printf '%s\t%s\tpass\n' "$(basename "$marker" .pass)" "$mtime_iso" >> "$FAIL_FILE" ;;
      *.fail) printf '%s\t%s\tfail\n' "$(basename "$marker" .fail)" "$mtime_iso" >> "$FAIL_FILE" ;;
    esac
  done
fi

# Calculate FAIL rate per period (pre/post ADR-0010 2026-08-02)
FAIL_RATE_PRE="{\"period\": \"before 2026-08-02\", \"units\": 0, \"with_fail\": 0, \"rate\": \"0.0%\"}"
FAIL_RATE_POST="{\"period\": \"from 2026-08-02\", \"units\": 0, \"with_fail\": 0, \"rate\": \"0.0%\"}"

if [ -s "$FAIL_FILE" ]; then
  PRE_UNITS=0
  PRE_FAILS=0
  POST_UNITS=0
  POST_FAILS=0

  # Track unique task-ids per period (each task-id counts once)
  while read -r taskid mtime verdict; do
    [ -n "$taskid" ] || continue
    if [ "$mtime" \< "2026-08-02T00:00:00Z" ]; then
      if ! echo "$PRE_SEEN" | grep -q "^$taskid$"; then
        PRE_UNITS=$((PRE_UNITS + 1))
        PRE_SEEN="${PRE_SEEN}$taskid"$'\n'
      fi
      if [ "$verdict" = "fail" ]; then
        PRE_FAILS=$((PRE_FAILS + 1))
      fi
    else
      if ! echo "$POST_SEEN" | grep -q "^$taskid$"; then
        POST_UNITS=$((POST_UNITS + 1))
        POST_SEEN="${POST_SEEN}$taskid"$'\n'
      fi
      if [ "$verdict" = "fail" ]; then
        POST_FAILS=$((POST_FAILS + 1))
      fi
    fi
  done < "$FAIL_FILE"

  if [ "$PRE_UNITS" -gt 0 ]; then
    PRE_RATE=$(awk "BEGIN {printf \"%.1f\", ($PRE_FAILS / $PRE_UNITS) * 100}")
    FAIL_RATE_PRE="{\"period\": \"before 2026-08-02\", \"units\": $PRE_UNITS, \"with_fail\": $PRE_FAILS, \"rate\": \"${PRE_RATE}%\"}"
  fi
  if [ "$POST_UNITS" -gt 0 ]; then
    POST_RATE=$(awk "BEGIN {printf \"%.1f\", ($POST_FAILS / $POST_UNITS) * 100}")
    FAIL_RATE_POST="{\"period\": \"from 2026-08-02\", \"units\": $POST_UNITS, \"with_fail\": $POST_FAILS, \"rate\": \"${POST_RATE}%\"}"
  fi
fi

# --- output ----
# Emit JSON with spend and FAIL rate data
TOTAL_SPEND=0
SPEND_LINES=""
while read -r model msgs cost tok_info; do
  [ -n "$model" ] || continue
  TOTAL_SPEND=$(awk -v ts="$TOTAL_SPEND" -v c="$cost" 'BEGIN {printf "%.2f", ts + c}')
  SPEND_LINES="${SPEND_LINES}{\"model\": \"$model\", \"messages\": $msgs, \"cost\": $cost},"
done < "$SPEND_JSON"

# Remove trailing comma
SPEND_LINES="${SPEND_LINES%,}"

jq -n --arg cutoff "$CUTOFF_ISO8601" --argjson total_spend "$TOTAL_SPEND" \
  --argjson fail_rate_pre "$(echo "$FAIL_RATE_PRE")" \
  --argjson fail_rate_post "$(echo "$FAIL_RATE_POST")" \
  '{
    cutoff: $cutoff,
    per_model_spend: ('"$([[ -n "$SPEND_LINES" ]] && echo "[$SPEND_LINES]" || echo "[]")"'),
    total_spend: $total_spend,
    per_period_fail_rate: [$fail_rate_pre, $fail_rate_post]
  }'
