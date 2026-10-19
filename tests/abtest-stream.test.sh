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
ZW="$(mktemp -d)" && [ -d "${ZW:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }
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
# Stricter and wider limit wording (abt-u02d). Each capture below is written with JSON escapes only (no literal invisible
# or non-ASCII character): mkerr NAME TEXT writes an error result and mkok NAME TEXT a success result in $ZW.
mkerr() { printf '{"type":"result","subtype":"error_during_execution","is_error":true,"result":"%s"}\n' "$2" > "$ZW/$1.jsonl"; }
mkok() { printf '{"type":"result","subtype":"success","is_error":false,"result":"%s"}\n' "$2" > "$ZW/$1.jsonl"; }
lw() { mkerr "$1" "$3"; check "limit wording: $2" "$(field "$ZW/$1.jsonl" completion_status --exit-code 1)" "usage-limit"; }
nm() { mkerr "$1" "$3"; check "near miss stays an error: $2" "$(field "$ZW/$1.jsonl" completion_status --exit-code 1)" "error"; }
lw x-mid-dot "out of extra usage with a middle dot" 'You\u0027re out of extra usage \u00b7 resets 3pm'
lw x-bullet "out of extra usage with a curly apostrophe and a bullet operator" 'You\u2019re out of extra usage \u2219 resets Monday'
lw x-en-extra "out of extra usage with an en dash" 'You\u0027re out of extra usage \u2013 resets 3pm'
lw x-hyphen-extra "out of extra usage with a hyphen and a dated reset" 'You\u0027re out of extra usage - resets Oct 20, 3pm'
lw x-extra-alone "out of extra usage on its own" 'You\u0027re out of extra usage'
lw x-extra-bare "out of extra usage without the you-are" 'Out of extra usage \u00b7 resets 3pm'
lw x-you-are "you are out of extra usage" 'You are out of extra usage \u00b7 resets 3pm'
lw x-rate-pipe "API Error: Rate limit reached with a pipe and an epoch" 'API Error: Rate limit reached|1760000000'
lw x-bang-claude "a trailing exclamation mark after the Claude AI phrase" 'Claude AI usage limit reached!'
lw x-bang-hit "a trailing exclamation mark after hit your limit" 'You\u0027ve hit your limit!'
lw x-period-alone "a trailing full stop after the Claude AI phrase" 'Claude AI usage limit reached.'
lw x-reset-period "a full stop after the reset" 'Session limit reached \u2219 resets 3pm.'
lw x-reset-bang "an exclamation mark after the reset" 'Session limit reached \u2219 resets 3pm!'
lw x-en-dash "an en dash before the reset" 'Session limit reached \u2013 resets 3pm'
lw x-em-dash "an em dash before the reset" 'Session limit reached \u2014 resets 3pm'
lw x-paren "a parenthesised reset" 'Session limit reached (resets 3pm)'
lw x-tz "a reset with a time zone" 'Opus weekly limit reached \u2219 resets Oct 20, 3pm (America/New_York)'
lw x-comma "a comma before the reset" 'Session limit reached, resets 3pm'
lw x-pipe-reset "a pipe before the reset" 'Session limit reached | resets 3pm'
lw x-relative "a relative reset in hours" 'Claude usage limit reached. Your weekly limit will reset in 2 hours'
lw x-hour "a relative reset in one hour" 'Claude usage limit reached. Your limit will reset in 1 hour'
lw x-minutes "a relative reset in minutes" 'Claude usage limit reached. Your limit will reset in 30 minutes'
lw x-minute "a relative reset in one minute" 'Claude usage limit reached. Your limit will reset in 1 minute'
lw x-days "a relative reset in days" 'Session limit reached \u2219 resets in 3 days'
lw x-day "a relative reset in one day" 'Session limit reached \u2219 resets in 1 day'
lw x-on "a reset on a weekday" 'Session limit reached \u2219 resets on Monday'
lw x-tomorrow "a reset tomorrow" 'Session limit reached \u2219 resets tomorrow at 9am'
lw x-today-utc "a reset today in UTC" 'Session limit reached \u2219 resets today 9am UTC'
lw x-clock "a reset with minutes" 'Session limit reached \u2219 resets 10:30pm'
lw x-am "a reset in the morning" 'Session limit reached \u2219 resets 9am'
lw x-space-pm "a reset with a space before pm" 'Session limit reached \u2219 resets 3 pm'
lw x-two-lines "the reset on the second line" 'Claude usage limit reached.\nYour limit will reset at 5pm'
lw x-wordjoiner "a word joiner (U+2060) in front of the phrase" '\u2060Session limit reached \u2219 resets 3pm'
lw x-zwnj "a zero-width non-joiner (U+200C) in front of the phrase" '\u200cSession limit reached \u2219 resets 3pm'
lw x-zwj "a zero-width joiner (U+200D) in front of the phrase" '\u200dSession limit reached \u2219 resets 3pm'
nm y-usage-added "Usage limit reached followed by agent prose" 'Usage limit reached. I added a test for the retry path'
nm y-session-403 "Session limit reached, so the server returns 403" 'Session limit reached, so the server returns 403 for the next call'
nm y-hit-copy "hit your limit followed by agent prose" 'You\u0027ve hit your limit. That\u0027s the copy the banner shows'
nm y-error-429-py "error: 429 handling in rate_limit_error.py" 'error: 429 handling in rate_limit_error.py is untested'
nm y-resets-are "Resets used as a noun after the phrase" 'Usage limit reached. Resets are handled in billing.py'
nm y-resets-counter "a reset clause that is a sentence" 'Session limit reached - resets the counter after the fix'
nm y-resets-bare "a reset clause with no time" 'Usage limit reached. Resets'
nm y-reset-trailing "prose after a full reset clause" 'Session limit reached \u2219 resets 3pm and then I added a retry'
nm y-pipe-docs "a pipe followed by prose" 'Session limit reached | see the retry docs'
nm y-pipe-short "a pipe followed by a short number" 'Session limit reached|123'
nm y-pipe-trailing "prose after a pipe and an epoch" 'Session limit reached|1760000000 and I added a test'
nm y-extra-prose "out of extra usage followed by agent prose" 'You\u0027re out of extra usage, so I skipped the live test'
nm y-extra-mid "out of extra usage quoted mid-text" 'The banner said You\u0027re out of extra usage \u00b7 resets 3pm'
nm y-two-lines "the phrase then a prose line" 'Session limit reached\nI added a test for it'
nm y-rate-cart "Rate limit reached for an API under test" 'Rate limit reached for the cart API, so I added a retry'
nm y-credit "Credit balance is too low (API-key billing, out of scope)" 'Credit balance is too low'
nm y-overloaded "Error: Overloaded" 'Error: Overloaded'
nm y-529 "API Error 529" 'API Error: 529 {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Overloaded\"}}'
nm y-500 "API Error 500" 'API Error: 500 {\"type\":\"error\",\"error\":{\"type\":\"api_error\",\"message\":\"Internal server error\"}}'
nm y-429-overloaded "API Error 429 with a different error type" 'API Error: 429 {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\"}}'
for d in Monday Tuesday Wednesday Thursday Friday Saturday Sunday Mon Tue Wed Thu Fri Sat Sun; do
  lw "d-$d" "the weekday $d in a reset" "Session limit reached \\u2219 resets $d"
done
for m in January February March April May June July August September October November December Jan Feb Mar Apr Jun Jul Aug Sep Oct Nov Dec; do
  lw "m-$m" "the month $m in a reset" "Session limit reached \\u2219 resets $m 20"
done
mkok z-success 'Session limit reached \u2219 resets 3pm'
check "a successful result that opens with a limit phrase stays complete" "$(field "$ZW/z-success.jsonl" completion_status)" "complete"
# Every non-warning limit-hit template of claude CLI 2.1.302 (abt-u02e) must read as usage-limit; every warning, notice and prose near miss stays an error.
i=0
for nm in "5-hour limit" "session limit" "weekly limit" "Opus limit" "Sonnet limit" "Fable limit" "fast limit" "usage limit" "limit" "team\u0027s shared budget" "channel\u0027s monthly spend limit" "channel\u0027s monthly usage limit" "individual spend limit" "individual usage limit" "org\u0027s monthly spend limit" "org\u0027s monthly usage limit" "monthly spend limit"; do
  i=$((i + 1))
  lw "cli-name$i" "the CLI name $nm in a hit message" "You\\u0027ve hit your $nm \\u00b7 resets 3pm (Europe/Madrid)"
done
i=0
for sfx in "contact your admin to increase it" "raise it at claude.ai/settings" "ask your admin to raise it at claude.ai/settings" "run /usage-credits to raise it, or visit claude.ai/settings" "visit claude.ai/settings to raise it" "run /usage-credits to ask your admin for a higher limit" "ask your admin for a higher limit" "an org owner or channel manager can raise it in the channel\u0027s Claude settings" "your session limit resets 3pm" "your Opus limit resets Jan 2, 2027, 3pm (UTC)"; do
  i=$((i + 1))
  lw "cli-admin$i" "the CLI clause $sfx after a hit message" "You\\u0027ve hit your org\\u0027s monthly spend limit \\u00b7 $sfx"
done
for z in UTC GMT PST PDT MST MDT CST CDT EST EDT CET CEST BST; do
  lw "zone-$z" "the zone $z after a reset time" "Session limit reached \\u2219 resets 3pm $z"
done
lw cli-reached "You have reached your Fable limit with a full stop" 'You\u0027ve reached your Fable limit.'
lw cli-reached-reset "reached your limit with a reset" 'You\u0027ve reached your weekly limit \u00b7 resets Monday'
lw cli-year "a reset with a year" 'You\u0027ve hit your session limit \u00b7 resets Jan 2, 2027, 3pm (America/New_York)'
lw cli-midnight "a reset at midnight" 'Session limit reached \u2219 resets midnight'
lw cli-noon "a reset at noon" 'Session limit reached \u2219 resets tomorrow noon'
lw cli-saved "the progress saved suffix" 'You\u0027ve hit your weekly limit \u00b7 resets 3pm (Europe/Madrid) \u00b7 progress saved'
lw cli-saved2 "the progress saved suffix after a credits message" 'You\u0027re out of usage credits \u00b7 resets Oct 20, 3pm \u00b7 progress saved'
lw cli-credits "out of usage credits on its own" 'You\u0027re out of usage credits'
lw cli-credits-reset "out of usage credits with a reset" 'You\u0027re out of usage credits \u00b7 resets 3pm'
lw cli-org-funds "the org is out of usage, add funds" 'Your org is out of usage \u00b7 add funds to continue'
lw cli-org-admin "the org is out of usage, contact your admin" 'Your org is out of usage \u00b7 contact your admin'
lw cli-seat1 "a seat type without usage credits" 'Your seat type doesn\u0027t include usage credits'
lw cli-seat2 "a seat type without usage" 'Your seat type doesn\u0027t include usage'
lw cli-seat3 "a seat type without extra usage" 'Your seat type doesn\u0027t include extra usage'
lw cli-alloc "a usage allocation disabled by the admin" 'Your usage allocation has been disabled by your admin'
lw cli-alloc2 "a usage allocation disabled with a clause" 'Your usage allocation has been disabled by your admin \u00b7 ask your admin for a higher limit'
lw cli-group "a group limit of zero" 'Your group\u0027s usage limit is set to $0'
lw cli-group2 "a group limit of zero with a clause" 'Your group\u0027s usage limit is set to $0 \u00b7 run /usage-credits to ask your admin for a higher limit'
for mdl in Fable Haiku Mythos Opus Sonnet; do
  lw "cli-model-$mdl" "the model $mdl requires usage credits" "$mdl 5 requires usage credits."
done
lw cli-three-parts "three clauses after a hit message" 'You\u0027ve hit your org\u0027s monthly spend limit \u00b7 visit claude.ai/settings to raise it \u00b7 your session limit resets 3pm \u00b7 progress saved'
lw cli-fable-req "Fable 5 requires usage credits" 'Fable 5 requires usage credits.'
lw cli-opus-req "Opus 4.6 requires usage credits" 'Opus 4.6 requires usage credits.'
lw cli-sw-a "team budget with a switch sentence" 'You\u0027ve hit your team\u0027s shared budget. Switch to another model to continue.'
lw cli-sw-b "out of credits with a switch sentence and a link" 'You\u0027re out of usage credits. Switch to another model, or manage usage credits at claude.ai/settings, to continue.'
lw cli-sw-c "a monthly spend limit with a switch sentence" 'You\u0027ve hit your monthly spend limit. Switch to another model to continue.'
lw cli-sw-d "Fable limit with a switch sentence" 'You\u0027ve reached your Fable limit. Switch to another model to continue.'
lw cli-sw-e "team budget with a usage-credits sentence" 'You\u0027ve hit your team\u0027s shared budget. Run /usage-credits to raise it and keep using Fable 5 or switch models to continue this chat.'
lw cli-sw-f "team budget with a model sentence" 'You\u0027ve hit your team\u0027s shared budget. /model to switch models.'
lw cli-sw-g "out of credits with a usage-credits sentence" 'You\u0027re out of usage credits. Run /usage-credits to keep using Fable 5 or /model to switch models.'
lw cli-sw-h "out of credits with a model sentence" 'You\u0027re out of usage credits. /model to switch models.'
lw cli-sw-i "a channel spend limit with a manage sentence" 'You\u0027ve hit your channel\u0027s monthly spend limit. Run /usage-credits to manage your limit and keep using Opus 4.6 or switch models to continue this chat.'
lw cli-sw-j "a requires-credits message with a continue sentence" 'Fable 5 requires usage credits. Run /usage-credits to continue or switch models with /model.'
nm w-used "a warning that uses a percentage" 'You\u0027ve used 90% of your session limit \u00b7 resets 3pm'
nm w-approach "an Approaching warning" 'Approaching weekly limit \u00b7 resets Monday'
nm w-close "a close-to-your-limit warning" 'You\u0027re close to your usage limit'
nm w-now "a now-using-usage-credits notice" 'You\u0027re now using usage credits \u00b7 Your session limit resets 3pm'
nm w-now2 "a Now using usage credits for Fable notice" 'Now using usage credits for Fable \u00b7 Your Fable limit resets 3pm'
nm w-fast "the fast limit notice" 'Fast limit reached and temporarily disabled \u00b7 resets in 8m'
nm w-wrap "the wrapping up banner" 'Usage limit reached \u00b7 wrapping up'
nm w-context "the context limit message" 'Context limit reached'
nm w-disabled "a service disabled for the org (not a limit)" 'This service is disabled for your org'
nm w-credit "a low credit balance (API billing)" 'Credit balance is too low'
nm p-hit-prose "a CLI hit message followed by agent prose" 'You\u0027ve hit your session limit. I added a test for the retry path'
nm p-credits-prose "out of usage credits followed by agent prose" 'You\u0027re out of usage credits, so I skipped the live test'
nm p-requires-prose "requires usage credits followed by agent prose" 'Opus requires usage credits. I added a mock for it'
nm p-org-prose "the org is out of usage followed by prose" 'Your org is out of usage. I added a fallback'
nm p-clause-prose "a CLI clause followed by agent prose" 'You\u0027ve hit your limit \u00b7 contact your admin and then I added a test'
nm p-switch-prose "a switch sentence followed by agent prose" 'You\u0027re out of usage credits. Switch to another model to continue. I added a test'
nm p-name "an unknown name after hit your" 'You\u0027ve hit your rate of five requests per second'
nm p-seat-prose "a seat message followed by prose" 'Your seat type doesn\u0027t include usage credits, so I mocked the call'
nm r-key "a bare rate_limit_error token inside a 429 body" 'API Error: 429 {\"error\":{\"message\":\"rate_limit_error\"}}'
nm r-brace "a 429 type key without the opening brace" 'API Error: 429 \"type\":\"rate_limit_error\"'
nm r-newline "a 429 body whose type key is on a second line" 'API Error: 429 {\n\"type\":\"rate_limit_error\"}'
nm p-switch-long "a model name longer than the sentence allows" 'You\u0027re out of usage credits. Run /usage-credits to keep using aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa or /model to switch models.'
check "exit 124 is timeout" "$(field "$FX/complete.jsonl" completion_status --exit-code 124)" "timeout"
check "no result object is error" "$(field "$FX/no-result.jsonl" completion_status --exit-code 1)" "error"
check "empty capture is error" "$(field /dev/null completion_status --exit-code 1)" "error"
check "tokens_total is input plus output plus cache write" "$(field "$FX/complete.jsonl" tokens_total)" "60"
check "multi-result tokens_total counts the whole run" "$(field "$FX/multi-result.jsonl" tokens_total)" "66"
check "multi-result tokens_in counts the whole run" "$(field "$FX/multi-result.jsonl" tokens_in)" "11"
check "multi-result tokens_out counts the whole run" "$(field "$FX/multi-result.jsonl" tokens_out)" "22"
check "multi-result tokens_cache_write counts the whole run" "$(field "$FX/multi-result.jsonl" tokens_cache_write)" "33"
check "multi-result tokens_cache_read counts the whole run" "$(field "$FX/multi-result.jsonl" tokens_cache_read)" "440"
check "multi-result num_turns counts the whole run" "$(field "$FX/multi-result.jsonl" num_turns)" "6"
check "multi-result duration_api_ms counts the whole run" "$(field "$FX/multi-result.jsonl" duration_api_ms)" "500"
check "without modelUsage tokens sum usage over every result" "$(field "$FX/multi-result-no-mu.jsonl" tokens_total)" "21"
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
