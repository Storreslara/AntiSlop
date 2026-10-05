#!/usr/bin/env bash
# Prints journal=<ok|absent|invalid> calls=<n> bad=<n>; exits 0 iff ok (or absent with --allow-absent).
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
allow_absent=0
[ "${1:-}" = "--allow-absent" ] && { allow_absent=1; shift; }
trial="${1:?usage: check-journal.sh [--allow-absent] <trial-dir> <run-id>}"
run="${2:?missing run-id}"
file="$trial/.outcomeci/.broker/$run/journal.json"

if [ ! -e "$file" ]; then
  printf 'journal=absent calls=0 bad=0\n'
  [ "$allow_absent" = 1 ]
  exit
fi

terminal='["confirmed","denied","unsent","uncertain"]'
bad_filter='[.calls[] | select((.status | type) != "string" or (.status as $s | $ok | index($s) | not))] | length'  # CHECK:STATUS

if counts="$(jq -rs --argjson ok "$terminal" \
  "if length == 1 and (.[0].calls | type) == \"object\" then .[0] | \"\\(.calls | length) \\($bad_filter)\" else error(\"not one object with calls object\") end" \
  "$file" 2>/dev/null)"; then
  read -r calls bad <<< "$counts"
else
  calls=0 bad=0 bad_json=1
fi

if [ -z "${bad_json:-}" ] && [ "$bad" -eq 0 ]; then
  printf 'journal=ok calls=%s bad=%s\n' "$calls" "$bad"
else
  printf 'journal=invalid calls=%s bad=%s\n' "$calls" "$bad"
  exit 1
fi
