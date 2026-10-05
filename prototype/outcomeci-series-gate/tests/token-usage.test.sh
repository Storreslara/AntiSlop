#!/usr/bin/env bash
# Exercises token-usage.sh against inline fixtures, plus a cap-check mutant.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="${TOKEN_USAGE_BIN:-$here/../token-usage.sh}"
failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); }

# ucase <name> <want-rc> <want-out|-> <bin> <args...>; want-out '-' skips the stdout check
ucase() {
  local name="$1" want_rc="$2" want="$3" b="$4" out rc
  shift 4
  out="$(bash "$b" "$@" 2>/dev/null)"; rc=$?
  [ "$rc" -eq "$want_rc" ] || fail "$name" "rc=$rc, want $want_rc"
  [ "$want" = - ] || [ "$out" = "$want" ] || fail "$name" "out '$out' != '$want'"
}

u1='{"records":[{"input_tokens":100,"output_tokens":20,"cache_read_tokens":5,"cache_write_tokens":1},{"input_tokens":50,"output_tokens":10,"cache_read_tokens":0,"cache_write_tokens":0}]}'
printf '%s\n' "$u1" > "$work/u1.json"
printf '%s\n' '{"records":[]}' > "$work/empty.json"
printf '%s\n' '{not json' > "$work/bad.json"
printf '%s\n' '{"records":{}}' > "$work/obj.json"
printf '%s\n' '{"records":[{"input_tokens":7}]}' > "$work/u9.json"

want1='records=2 input=150 output=30 cache_read=5 cache_write=1 total=180'
ucase U1-sum 0 "$want1" "$bin" "$work/u1.json"
ucase U2-cap-equal 0 "$want1" "$bin" --cap 180 "$work/u1.json"
ucase U3-cap-over 1 "$want1" "$bin" --cap 179 "$work/u1.json"
ucase U4a-empty-capped 1 - "$bin" --cap 10 "$work/empty.json"
ucase U4b-empty-uncapped 0 'records=0 input=0 output=0 cache_read=0 cache_write=0 total=0' "$bin" "$work/empty.json"
ucase U5-malformed 2 - "$bin" "$work/bad.json"
ucase U6-records-object 2 - "$bin" "$work/obj.json"
ucase U7-missing-file 2 - "$bin" "$work/nope.json"
ucase U8-no-arg 64 - "$bin"
ucase U9-missing-field 0 'records=1 input=7 output=0 cache_read=0 cache_write=0 total=7' "$bin" "$work/u9.json"

# Mutant: neutralise the cap check; U3 must then fail.
mut="$work/mut-token-usage.sh"
sed '/# CHECK:CAP/s/.*/:/' "$bin" > "$mut"
if cmp -s "$bin" "$mut"; then
  fail M1-cap-mutant "no # CHECK:CAP line found to mutate"
else
  before=$failures
  ucase U3-mutant 1 "$want1" "$mut" --cap 179 "$work/u1.json" >/dev/null
  if [ "$failures" -eq "$before" ]; then fail M1-cap-mutant "mutant survived U3"; else failures=$before; fi
fi

printf 'failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
