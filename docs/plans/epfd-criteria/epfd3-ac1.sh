#!/usr/bin/env bash
# epfd-3 AC3.1 (item 3): the parity suite passes, SF1 and EB1 are OK, and SF1
# calls the file's own splitFences (nothing is exported from bin/).
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
T=tests/adapter-protocol-parity.test.js
log=$(mktemp)
node "$T" > "$log" 2>&1 || { grep '^FAIL' "$log" | cut -c1-120; exit 1; }
for n in SF1 EB1; do grep -q "^OK   $n " "$log" || { echo "$n not OK"; exit 1; }; done
body=$(awk '/^check\(.SF1 /{f=1} f{print} f&&/^}\);$/{exit}' "$T")
printf '%s\n' "$body" | grep -q 'splitFences(' || { echo "SF1 does not call splitFences"; exit 1; }
grep -q "require(.*bin/" "$T" && { echo "the parity test now requires a bin/ module"; exit 1; }
exit 0
