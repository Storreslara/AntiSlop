#!/usr/bin/env bash
# epfb-3 AC3.1 (item f): the markdown-lite suite passes and reports TB11-TB17
# and VM1 ok.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
log=$(mktemp)
node tests/microworld/dashboard-markdown-lite.test.js > "$log" 2>&1 || { grep '^  - ' "$log" | cut -c1-120; exit 1; }
for n in TB11 TB12 TB13 TB14 TB15 TB16 TB17 VM1; do
  awk -v n="$n" 'p && /^  ✓ ok$/ {ok=1} {p = (index($0, "Test " n " ") == 1)} END {exit !ok}' "$log" \
    || { echo "$n not ok"; exit 1; }
done
