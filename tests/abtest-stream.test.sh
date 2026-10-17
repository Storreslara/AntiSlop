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
check "an error result that only mentions 429 and rate limits is an error" "$(field "$FX/mention-error.jsonl" completion_status --exit-code 1)" "error"
check "a limit phrase in the middle of an error result is an error" "$(field "$FX/mention-mid.jsonl" completion_status --exit-code 1)" "error"
check "an error result that opens with the CLI limit phrase is usage-limit" "$(field "$FX/limit-anchored.jsonl" completion_status --exit-code 1)" "usage-limit"
check "the hit-your-limit phrase is usage-limit" "$(field "$FX/limit-hit.jsonl" completion_status --exit-code 1)" "usage-limit"
# Wider limit wordings (abt-u02c): each positive capture is a real or documented limit message and must be usage-limit;
# each near-miss only mentions limits, 429 or rate_limit_error and must stay a plain error.
check "limit wording: Claude usage limit reached with a reset sentence" "$(field "$FX/lim-claude-usage.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Opus weekly limit reached with a reset time" "$(field "$FX/lim-opus-weekly.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Sonnet session limit reached" "$(field "$FX/lim-sonnet-session.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Haiku weekly limit reached" "$(field "$FX/lim-haiku-weekly.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Session limit reached on its own" "$(field "$FX/lim-session.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: 5-hour limit reached on its own" "$(field "$FX/lim-5hour.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: Error: prefix before the Claude AI phrase" "$(field "$FX/lim-error-prefix.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: API Error: prefix before the usage phrase" "$(field "$FX/lim-api-error-prefix.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: a byte order mark in front of the phrase" "$(field "$FX/lim-bom.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: a zero-width space in front of the phrase" "$(field "$FX/lim-zerowidth.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: leading blank lines and spaces in front of the phrase" "$(field "$FX/lim-leading-space.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: you have hit your limit" "$(field "$FX/lim-have-hit.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: curly-apostrophe weekly hit-your-limit" "$(field "$FX/lim-curly-hit.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: API Error 429 that carries the rate_limit_error type" "$(field "$FX/lim-429-token.jsonl" completion_status --exit-code 1)" "usage-limit"
ZW="$(mktemp -d)"
trap 'rm -rf "$ZW"' EXIT
printf '\xef\xbb\xbfClaude AI usage limit reached|1760000000\n' > "$ZW/bom-noise.jsonl"
printf '\xe2\x80\x8bClaude AI usage limit reached|1760000000\n' > "$ZW/zw-noise.jsonl"
check "limit wording: a byte order mark before a plain-text limit line" "$(field "$ZW/bom-noise.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: a zero-width space before a plain-text limit line" "$(field "$ZW/zw-noise.jsonl" completion_status --exit-code 1)" "usage-limit"
check "limit wording: a tab-indented plain-text limit line" "$(field "$FX/lim-noise-tab.jsonl" completion_status --exit-code 1)" "usage-limit"
check "near miss stays an error: API Error 429 without the rate_limit_error token" "$(field "$FX/men-429-retry.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: an answer about handling 429 and rate limit errors" "$(field "$FX/men-handle.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: a session limit message quoted mid-text" "$(field "$FX/men-session-mid.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: the rate_limit_error type name at the start" "$(field "$FX/men-token-name.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: Error: 429 Too Many Requests from a test server" "$(field "$FX/men-error-429.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: a bare Limit reached sentence about a cart" "$(field "$FX/men-bare-limit.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: hitting a limit of 5 retries in a test" "$(field "$FX/men-hit-retries.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: a limit phrase quoted at the end of a sentence" "$(field "$FX/men-quoted-end.jsonl" completion_status --exit-code 1)" "error"
check "near miss stays an error: Session limit reached for a cart module" "$(field "$FX/men-session-cart.jsonl" completion_status --exit-code 1)" "error"
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
