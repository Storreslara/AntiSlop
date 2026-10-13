#!/usr/bin/env bash
# epf-1 AC1.7: epa invariants kept: the viewer test, epa AC4.5, and the
# corrected epa AC4.6 (the epf-6 form, with F and L of epa-4).
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
bash tests/packet-view-script.test.sh >/dev/null 2>&1 || { echo "packet-view-script.test.sh failed"; exit 1; }
grep -qF 'Full record (criteria, notes): .claude/reviewed/<task-id>.escalated, same text in the packet'"'"'s PACKET.md' agents/orchestrator.md || { echo "AC4.5 pointer"; exit 1; }
o=$(tr -s ' \n' ' ' < agents/orchestrator.md)
echo "$o" | grep -qF 'lines 1 through the `---` fold line' || { echo "AC4.5 fold"; exit 1; }
echo "$o" | grep -qF 'Never summarize the record' || { echo "AC4.5 summarize"; exit 1; }
echo "$o" | grep -qF 'the text after `decide: ` on the card, verbatim' || { echo "AC4.5 decide"; exit 1; }
echo "$o" | grep -qF 'sh .claude/human-review/<task-id>/view.sh' || { echo "AC4.5 view.sh"; exit 1; }
for f in agents/reviewer.md templates/persona-protocol.md; do tr -s ' \n' ' ' < $f | grep -qiF 'byte-identical' || { echo "AC4.5 byte-identical: $f"; exit 1; }; done
grep -qF 'Full record (criteria, notes)' .claude/agents/orchestrator.md || { echo "AC4.5 mirror pointer"; exit 1; }
F=$(uF epa-4); L=$(uL epa-4); [ -n "$F" ] && [ -n "$L" ] || { echo "no epa-4 commits"; exit 1; }
a=$(mktemp); b=$(mktemp)
[ "$(git diff -U0 "$F^" "$L" -- agents/reviewer.md templates/persona-protocol.md adapters/ | grep -cE '^[-+].*ESCALATE-TO-HUMAN <task-id> <UTC ISO-8601 timestamp> trigger:')" -eq 0 ] || { echo "AC4.6 line 1 changed"; exit 1; }
git show "$F^:agents/orchestrator.md" | awk '/^6\. Make the \*\*prompt-confirmed/,/^7\. /' > "$a"
awk '/^6\. Make the \*\*prompt-confirmed/,/^7\. /' agents/orchestrator.md > "$b"
[ -s "$a" ] && cmp -s "$a" "$b" || { echo "AC4.6 step 6 changed"; exit 1; }
