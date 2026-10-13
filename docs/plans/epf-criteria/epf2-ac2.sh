#!/usr/bin/env bash
# epf-2 AC2.2: the card no longer orphans the "same action" paragraph.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  nxt=$(awk 'f&&NF{print;exit} /^<!-- escalated-card:end -->$/{f=1}' "$f")
  case "$nxt" in '- **Durable escalation packet**: in the **same action** that writes the marker,'*) : ;;
    *) echo "line after card in $f: $nxt"; exit 1 ;; esac
  [ "$(grep -c '^In the \*\*same action\*\*' "$f")" -eq 0 ] || { echo "column-0 paragraph left: $f"; exit 1; }
done
