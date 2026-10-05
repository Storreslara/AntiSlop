#!/usr/bin/env bash
# Sums token counts from an outcomeci usage.json; --cap <n> fails when total (input+output) exceeds n.
set -uo pipefail
cap=
if [ "${1:-}" = --cap ]; then
  [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo 'usage: token-usage.sh [--cap <n>] <usage.json>' >&2; exit 64; }
  cap="$2"; shift 2
fi
[ "$#" -eq 1 ] || { echo 'usage: token-usage.sh [--cap <n>] <usage.json>' >&2; exit 64; }
line="$(jq -er 'if (.records | type) == "array" then
  [.records[] | {i: (.input_tokens // 0), o: (.output_tokens // 0), r: (.cache_read_tokens // 0), w: (.cache_write_tokens // 0)}] as $r
  | "\($r | length) \($r | map(.i) | add // 0) \($r | map(.o) | add // 0) \($r | map(.r) | add // 0) \($r | map(.w) | add // 0)"
  else error("records not an array") end' "$1" 2>/dev/null)" || { echo 'token-usage: unreadable usage.json' >&2; exit 2; }
read -r n in out cr cw <<< "$line"
total=$((in + out))
printf 'records=%s input=%s output=%s cache_read=%s cache_write=%s total=%s\n' "$n" "$in" "$out" "$cr" "$cw" "$total"
if [ -n "$cap" ]; then { [ "$n" -gt 0 ] && [ "$total" -le "$cap" ]; } || exit 1; fi # CHECK:CAP
