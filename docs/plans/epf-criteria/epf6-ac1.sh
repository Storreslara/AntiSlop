#!/usr/bin/env bash
# epf-6 AC6.1: each corrected run line of the 2026-10-12 plan is green.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
P=docs/plans/2026-10-12-escalation-packet-aesthetics.md
runac() {
  local cmd; cmd=$(awk -v id="- **$1** " 'index($0,id)==1{f=1;next} f&&/^  - run: `/{sub(/^  - run: `/,""); sub(/`$/,""); print; exit}' "$P")
  [ -n "$cmd" ] || { echo "$1: no run line"; return 1; }
  local f l; f=$(uF "$2"); l=$(uL "$2")
  [ -n "$f" ] && [ -n "$l" ] || { echo "$1: no $2 commits"; return 1; }
  F="$f" L="$l" bash -c "$cmd" >/dev/null 2>&1 || { echo "$1 exits non-zero"; return 1; }
}
runac AC1.3 epa-1 && runac AC2.2 epa-2 && runac AC2.3 epa-2 && runac AC3.2 epa-3 && runac AC3.3 epa-3 && runac AC4.4 epa-4 && runac AC4.6 epa-4
