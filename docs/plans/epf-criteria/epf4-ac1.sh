#!/usr/bin/env bash
# epf-4 AC4.1: TB1-TB10 and the table XSS contexts run and pass.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
T=tests/microworld/dashboard-markdown-lite.test.js; log=$(mktemp)
node "$T" > "$log" 2>&1 || { grep -B1 '✗' "$log" | head -20; exit 1; }
for n in 1 2 3 4 5 6 7 8 9 10; do
  awk -v n="TB$n " 'index($0,"Test " n)==1{getline nx; ok=(nx=="  ✓ ok"); found=1} END{exit !(found&&ok)}' "$log" || { echo "TB$n missing or not ok"; exit 1; }
done
for ctx in 'table header cell' 'table body cell'; do
  [ "$(grep -c "^Test U1-C3c adjacency payload [1-5] in $ctx\.\.\.\$" "$log")" -eq 5 ] || { echo "adjacency not run in: $ctx"; exit 1; }
done
grep -qF '|table|thead|tbody|tr|th|td)>' "$T" || { echo "ALLOWED_TAG not extended exactly"; exit 1; }
