#!/usr/bin/env bash
# epf-1 AC1.4: glossary entries (entry-scoped) and the wiki sentence.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
entry() { awk -v h="$1" 'f&&/^\*\*/{exit} index($0,h)==1{f=1;next} f' CONTEXT.md | tr -s ' \n' ' '; }
entry '**fold line**:' | grep -qF 'A marker with no fold line is printed whole' || { echo "fold line entry"; exit 1; }
entry '**escalation card**:' | grep -qF 'a fixed generic question when the marker has no `decide:` line' || { echo "escalation card entry"; exit 1; }
sed -n '76,90p' .claude/wiki/architecture.md | tr -s ' \n' ' ' | grep -qF 'a marker with no fold is printed whole' || { echo "wiki"; exit 1; }
