#!/usr/bin/env bash
# epf-1 AC1.6: steps 1-5 fit in 80 bytes per line; the pointer literal stays on one line.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
n=$(LC_ALL=C awk '/^1\. Print the marker/{f=1} /^6\. Make the/{f=0} f && length($0)>80 && index($0,"Full record (criteria, notes)")==0' agents/orchestrator.md | wc -l)
[ "$n" -eq 0 ] || { echo "$n over-80 lines in steps 1-5"; exit 1; }
grep -F 'Full record (criteria, notes): ' agents/orchestrator.md | grep -qF 'PACKET.md`.' || { echo "pointer literal split"; exit 1; }
