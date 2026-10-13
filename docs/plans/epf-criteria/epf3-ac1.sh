#!/usr/bin/env bash
# epf-3 AC3.1: the new cases run and pass; T8 checks stderr.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
log=$(mktemp)
bash tests/packet-view-script.test.sh > "$log" 2>&1 || { grep '^FAIL' "$log"; exit 1; }
for c in 'T1b ' 'O1 ' 'O2 ' 'O3 ' 'O4 ' 'T8 '; do grep -q "^OK   $c" "$log" || { echo "not OK: $c"; exit 1; }; done
grep -q '^OK   T8 .*stderr empty' "$log" || { echo "T8 does not check stderr"; exit 1; }
