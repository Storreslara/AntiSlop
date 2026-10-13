#!/usr/bin/env bash
# epfc-1 AC1.1 (note 1): the markdown-lite suite passes and reports TB18 ok.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
log=$(mktemp)
node tests/microworld/dashboard-markdown-lite.test.js > "$log" 2>&1 || { grep '^  - ' "$log" | cut -c1-120; exit 1; }
awk 'p && /^  ✓ ok$/ {ok=1} {p = (index($0, "Test TB18 ") == 1)} END {exit !ok}' "$log" \
  || { echo "TB18 not ok"; exit 1; }
