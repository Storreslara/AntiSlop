#!/usr/bin/env bash
# epfb-2 AC2.1 (item d): the parity test passes and reports EB1 and EB2 OK.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
log=$(mktemp)
node tests/adapter-protocol-parity.test.js > "$log" 2>&1 || { grep '^FAIL' "$log" | cut -c1-120; exit 1; }
for n in EB1 EB2; do grep -q "^OK   $n " "$log" || { echo "$n not OK"; exit 1; }; done
