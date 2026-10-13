#!/usr/bin/env bash
# epf-6 AC6.3: the stale criterion in the 2026-10-01 plan is corrected and green.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
line=$(grep -F "for f in agents/orchestrator.md .claude/agents/orchestrator.md; do grep -q 'AskUserQuestion'" docs/plans/2026-10-01-in-session-escalation-decision.md)
[ -n "$line" ] || { echo "criterion line not found"; exit 1; }
echo "$line" | grep -qF 'erratum 2026-10-13 (epf-6)' || { echo "no erratum comment"; exit 1; }
bash -c "$line"
