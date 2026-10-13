#!/usr/bin/env bash
# epf-2 AC2.3: every layout-anchor line is 80 bytes or less in all four sources.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
for f in agents/reviewer.md templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc; do
  n=$(grep -F -e 'blockquote line' -e '| Where | What to check |' -e 'lines under its heading' -e '**After:**' -e '**Before:**' -e 'no wrapped paragraph longer than two lines' -e 'most one consequence line' "$f" | LC_ALL=C awk 'length($0)>80' | wc -l)
  [ "$n" -eq 0 ] || { echo "$f: $n anchor line(s) over 80 columns"; exit 1; }
done
