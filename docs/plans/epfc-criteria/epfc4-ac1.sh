#!/usr/bin/env bash
# epfc-4 AC4.1 (note 4): the parity test passes, EB1 and EB2 are OK, and EB1
# reads the prose/fence split (splitFences) rather than the whole text.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
log=$(mktemp)
node tests/adapter-protocol-parity.test.js > "$log" 2>&1 || { grep '^FAIL' "$log" | cut -c1-120; exit 1; }
for n in EB1 EB2; do grep -q "^OK   $n " "$log" || { echo "$n not OK"; exit 1; }; done
body=$(awk '/^check\(.EB1 /{f=1} f{print} f&&/^}\);$/{exit}' tests/adapter-protocol-parity.test.js)
printf '%s\n' "$body" | grep -q 'splitFences(' || { echo "EB1 does not call splitFences"; exit 1; }
printf '%s\n' "$body" | grep -q "t\.includes('examples: none - <one-line reason>')" && { echo "EB1 still has the whole-text positive check"; exit 1; }
exit 0
