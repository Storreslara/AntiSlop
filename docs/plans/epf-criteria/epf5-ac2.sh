#!/usr/bin/env bash
# epf-5 AC5.2: F1, F2 and F3 run and pass; F3 covers both templates.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
log=$(mktemp)
node tests/protocol-cross-references.test.js > "$log" 2>&1 || { grep '^FAIL' "$log"; exit 1; }
for n in F1 F2 F3; do grep -q "^OK   $n " "$log" || { echo "$n not OK"; exit 1; }; done
grep '^OK   F3 ' "$log" | grep -q 'persona-protocol-slim.md' || { echo "F3 omits slim"; exit 1; }
