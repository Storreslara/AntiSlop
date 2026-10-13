#!/usr/bin/env bash
# epf-1 AC1.1 + AC1.2: the no-fold and no-decide rules, in source and mirror.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
for f in agents/orchestrator.md .claude/agents/orchestrator.md; do
  t=$(tr -s ' \n' ' ' < "$f")
  echo "$t" | grep -qF 'A marker with no `---` fold line' || { echo "MISSING fold rule: $f"; exit 1; }
  echo "$t" | grep -qF 'print the whole marker verbatim instead, with no pointer line' || { echo "MISSING whole-marker rule: $f"; exit 1; }
  echo "$t" | grep -qF 'When the marker has no `decide: ` line, Q1'"'"'s description is exactly `How should this escalation be resolved?`' || { echo "MISSING generic Q1: $f"; exit 1; }
  echo "$t" | grep -qF 'Q1'"'"'s description is the text after `decide: ` on the card, verbatim' || { echo "LOST card Q1 rule: $f"; exit 1; }
done
