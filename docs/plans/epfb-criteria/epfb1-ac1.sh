#!/usr/bin/env bash
# epfb-1 AC1.1 (item b): the prompt-confirmed decision write paragraph fits in
# 80 bytes per line in the template and its mirror; the epf-1 sentence survives.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
  grep -q '^\*\*The prompt-confirmed decision write\.\*\* ' "$f" || { echo "heading lost: $f"; exit 1; }
  n=$(LC_ALL=C awk '/^\*\*The prompt-confirmed decision write\.\*\*/{f=1} f&&/^$/{f=0} f&&length($0)>80' "$f" | wc -l)
  [ "$n" -eq 0 ] || { echo "$n over-80 lines: $f"; exit 1; }
done
bash "$D/../epf-criteria/epf1-ac3.sh" >/dev/null || { echo "epf-1 sentence changed"; exit 1; }
