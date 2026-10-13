#!/usr/bin/env bash
# epfd-2 AC2.1 (item 2): the cross-references suite passes, F5 is OK, and F5
# also pins a text made of a bare `## ` line.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
T=tests/protocol-cross-references.test.js
log=$(mktemp)
node "$T" > "$log" 2>&1 || { grep '^FAIL' "$log" | cut -c1-120; exit 1; }
grep -q '^OK   F5 ' "$log" || { echo "F5 not OK"; exit 1; }
body=$(awk '/^check\(.F5 /{f=1} f{print} f&&/^}\);$/{exit}' "$T")
printf '%s\n' "$body" | grep -qF "cli.parseProtocolSections('## ')" || { echo "F5 has no bare ## input"; exit 1; }
exit 0
