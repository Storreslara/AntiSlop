#!/usr/bin/env bash
# vlg2-ac3.sh: lanes really run in parallel. Six sections that each sleep 2 s:
# --lanes 3 must finish in at most 8 s (ideal 4 s plus copy overhead) and
# --lanes 1 in at least 11 s (monotonic clock; ideal 12 s). Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
body=$(for i in 1 2 3 4 5 6; do printf 'echo\necho "== s%s =="\nsleep 2\necho "OK   s%s"\n' "$i" "$i"; done)
t=$(ltree par "$body"); runlanes "$t" --lanes 3
expect par 0 'OK   s6'
[ "$SECS" -le 8 ] || { echo "par: --lanes 3 took ${SECS}s, want <= 8"; exit 1; }
t=$(ltree ser "$body"); runlanes "$t" --lanes 1
expect ser 0 'OK   s6'
[ "$SECS" -ge 11 ] || { echo "ser: --lanes 1 took ${SECS}s, want >= 11"; exit 1; }
exit 0
