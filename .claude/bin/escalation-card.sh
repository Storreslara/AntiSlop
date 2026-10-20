#!/usr/bin/env bash
# Defect history for "At the 2-FAIL cap" (ptr-u9). Usage: bin/escalation-card.sh <unit-id> [project-dir]
# Per FAIL block: header, tier line, first defect line; then commit subjects carrying
# (<unit-id>). It never prints the options (they stay in agents/orchestrator.md), writes
# nothing and exits 0.
set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

unit="${1:-}"
project_dir="${2:-.}"
dot="${project_dir}/.claude"

. "$repo_root/hooks/scripts/lib/state-access.sh"
set +e

if [ -z "$unit" ] || ! unit_id_valid "$unit"; then
  echo "escalation-card: no valid unit id"
  exit 0
fi

marker="$(unit_id_marker_path "$unit" fail)"
echo "escalation-card: $unit"
if [ -f "$marker" ]; then
  awk -v id="$unit" '
    $0 ~ "^FAIL " id " " { print; state = 1; next }
    state == 1 && /^tier: / { print; state = 2; next }
    state >= 1 && NF > 0 { print "  " $0; state = 0 }
  ' "$marker"
else
  echo "(no FAIL record)"
fi
echo "fix-attempt commits:"
(cd "$project_dir" && git log --format='%h %s' --grep="($unit)" 2>/dev/null) | head -40
exit 0
