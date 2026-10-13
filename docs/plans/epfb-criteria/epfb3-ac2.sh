#!/usr/bin/env bash
# epfb-3 AC3.2 (item f, invariants): escapeHtml( occurs exactly 5 times, no table
# tag carries an attribute, and the test's ALLOWED_TAG allowlist is unchanged.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
M=bin/microworld-dashboard/markdown-lite.js
n=$(grep -o 'escapeHtml(' "$M" | wc -l)
[ "$n" -eq 5 ] || { echo "escapeHtml( count $n, want 5"; exit 1; }
! grep -qE '<(table|thead|tbody|tr|th|td) ' "$M" || { echo "attribute on a table tag"; exit 1; }
grep -qF 'const ALLOWED_TAG = /<\/?(?:h[1-6]|p|strong|em|code|pre|ul|ol|li|blockquote|table|thead|tbody|tr|th|td)>|<hr \/>|<br \/>|<a href="[^"<>]*" rel="noopener noreferrer" target="_blank">|<\/a>/g;' \
  tests/microworld/dashboard-markdown-lite.test.js || { echo "ALLOWED_TAG changed"; exit 1; }
