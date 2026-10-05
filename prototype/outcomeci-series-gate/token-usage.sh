#!/usr/bin/env bash
# Sums token counts from an outcomeci usage.json; --cap <n> fails when total (input+output) exceeds n.
set -uo pipefail
cap=
if [ "${1:-}" = --cap ]; then
  [[ "${2:-}" =~ ^[0-9]{1,15}$ ]] || { echo 'usage: token-usage.sh [--cap <n>] <usage.json>' >&2; exit 64; }
  cap="$2"; shift 2
fi
[ "$#" -eq 1 ] || { echo 'usage: token-usage.sh [--cap <n>] <usage.json>' >&2; exit 64; }
# Token fields must be non-negative integers (at most 2^53-1); totals are summed in jq, never by the shell.
line="$(jq -er 'def tok: (. // 0) | if type == "number" and . >= 0 and . == floor and . <= 9007199254740991
    then . else error("token field not a non-negative integer") end;
  if (.records | type) == "array" then
  [.records[] | {i: (.input_tokens | tok), o: (.output_tokens | tok), r: (.cache_read_tokens | tok), w: (.cache_write_tokens | tok)}] as $r
  | ($r | map(.i) | add // 0) as $in | ($r | map(.o) | add // 0) as $out
  | "\($r | length) \($in) \($out) \($r | map(.r) | add // 0) \($r | map(.w) | add // 0) \($in + $out)"
  else error("records not an array") end' "$1" 2>/dev/null)" || { echo 'token-usage: unreadable or invalid usage.json' >&2; exit 2; }
read -r n in out cr cw total <<< "$line"
printf 'records=%s input=%s output=%s cache_read=%s cache_write=%s total=%s\n' "$n" "$in" "$out" "$cr" "$cw" "$total"
if [ -n "$cap" ]; then { [ "$n" -gt 0 ] && [ "$total" -le "$cap" ]; } || exit 1; fi # CHECK:CAP
