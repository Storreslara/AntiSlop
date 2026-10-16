#!/usr/bin/env bash
# Tests eval/abtest/lib/stream.py: completion_status classification and the
# counters, over canned stream-json captures. No claude, no usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$REPO_ROOT/eval/abtest/lib/stream.py"
FX="$REPO_ROOT/tests/fixtures/abtest/streams"
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# field STREAM KEY [summarize flags...]: print one summary field.
field() {
  local s="$1" k="$2"
  shift 2
  python3 "$PY" summarize "$s" "$@" | python3 -c 'import json,sys;print(json.load(sys.stdin)[sys.argv[1]])' "$k"
}

check "clean run is complete" "$(field "$FX/complete.jsonl" completion_status)" "complete"
check "error_max_turns is turn-cap" "$(field "$FX/max-turns.jsonl" completion_status)" "turn-cap"
check "AskUserQuestion is stalled-human" "$(field "$FX/stall-ask.jsonl" completion_status)" "stalled-human"
check "permission denial is stalled-human" "$(field "$FX/denied.jsonl" completion_status)" "stalled-human"
check "escalation marker is stalled-human" "$(field "$FX/complete.jsonl" completion_status --escalated 1)" "stalled-human"
check "rate_limit_event rejected is usage-limit" "$(field "$FX/limit-event.jsonl" completion_status)" "usage-limit"
check "plain-text limit message is usage-limit" "$(field "$FX/limit-text.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit text on stderr with exit 1 is usage-limit" "$(field "$FX/no-result.jsonl" completion_status --exit-code 1 --stderr "$FX/limit.stderr")" "usage-limit"
check "limit text on stderr with exit 0 is ignored" "$(field "$FX/complete.jsonl" completion_status --stderr "$FX/limit.stderr")" "complete"
check "a successful result that mentions rate limits stays complete" "$(field "$FX/mentions-limit.jsonl" completion_status)" "complete"
check "exit 124 is timeout" "$(field "$FX/complete.jsonl" completion_status --exit-code 124)" "timeout"
check "no result object is error" "$(field "$FX/no-result.jsonl" completion_status --exit-code 1)" "error"
check "empty capture is error" "$(field /dev/null completion_status --exit-code 1)" "error"
check "tokens_total is input plus output plus cache write" "$(field "$FX/complete.jsonl" tokens_total)" "60"
check "cache read is kept but not in the total" "$(field "$FX/complete.jsonl" tokens_cache_read)" "400"
check "hook events counted" "$(field "$FX/complete.jsonl" hook_events)" "2"
check "SessionStart events counted" "$(field "$FX/complete.jsonl" session_start_events)" "2"
check "subagent spawns counted" "$(field "$FX/complete.jsonl" subagent_spawns)" "1"
check "tool calls counted" "$(field "$FX/complete.jsonl" tool_calls)" "2"
check "turns read from the result" "$(field "$FX/complete.jsonl" num_turns)" "7"
check "human interventions sum asks, denials, escalations" "$(field "$FX/stall-ask.jsonl" human_interventions_required --escalated 2)" "3"

echo "abtest-stream: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-stream checks passed."
exit "$fail"
