#!/usr/bin/env bash
# epfc-3 AC3.1 (note 3): the cross-references suite passes and reports F5 OK,
# and the parseProtocolSections header comment records the non-goal.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
log=$(mktemp)
node tests/protocol-cross-references.test.js > "$log" 2>&1 || { grep '^FAIL' "$log" | cut -c1-120; exit 1; }
grep -q '^OK   F5 ' "$log" || { echo "F5 not OK"; exit 1; }
c=$(awk '/^function parseProtocolSections\(text\) \{/{print b; exit} /^\/\//{b=b substr($0,4) " "; next} {b=""}' bin/cli.js)
printf '%s' "$c" | tr -s ' ' | grep -qF "except a text that opens with a \`## \` line: it has no preamble, and the join adds a leading '\n'. That case is a non-goal" \
  || { echo "non-goal sentence missing from the parseProtocolSections comment"; exit 1; }
