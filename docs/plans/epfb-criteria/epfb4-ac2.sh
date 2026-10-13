#!/usr/bin/env bash
# epfb-4 AC4.2 (item g): the cross-reference test passes with F1-F4 OK.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
log=$(mktemp)
node tests/protocol-cross-references.test.js > "$log" 2>&1 || { grep '^FAIL' "$log" | cut -c1-120; exit 1; }
for n in F1 F2 F3 F4; do grep -q "^OK   $n " "$log" || { echo "$n not OK"; exit 1; }; done
