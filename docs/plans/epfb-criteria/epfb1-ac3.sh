#!/usr/bin/env bash
# epfb-1 AC1.3 (item e): the glossary's Escalation packet entry names the
# protocol heading "Durable escalation packet" as the same term; the reviewer
# and template headings are unchanged.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
entry=$(awk '/^\*\*Escalation packet\*\*:/{f=1;print;next} f&&/^\*\*[^*]+\*\*/{exit} f' CONTEXT.md | tr -s ' \n' ' ')
[ -n "$entry" ] || { echo "no Escalation packet entry"; exit 1; }
printf '%s' "$entry" | grep -qF "The protocol's own heading for it, **Durable escalation packet** (\`agents/reviewer.md\` and \`templates/persona-protocol.md\`), names this same term, not a second concept." \
  || { echo "alias sentence missing from the entry"; exit 1; }
grep -qF -- '- **Durable escalation packet**: in the **same action** that writes the marker,' agents/reviewer.md || { echo "reviewer heading changed"; exit 1; }
grep -qF '**Durable escalation packet.** In the **same action** that writes the marker,' templates/persona-protocol.md || { echo "template heading changed"; exit 1; }
