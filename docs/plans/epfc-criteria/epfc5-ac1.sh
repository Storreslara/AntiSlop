#!/usr/bin/env bash
# epfc-5 AC5.1 (note 5): the Escalation packet entry's alias sentence names
# templates/persona-protocol.md, and no longer says "and the template)".
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
entry=$(awk '/^\*\*Escalation packet\*\*:/{f=1;print;next} f&&/^\*\*[^*]+\*\*/{exit} f' CONTEXT.md | tr -s ' \n' ' ')
[ -n "$entry" ] || { echo "no Escalation packet entry"; exit 1; }
printf '%s' "$entry" | grep -qF "The protocol's own heading for it, **Durable escalation packet** (\`agents/reviewer.md\` and \`templates/persona-protocol.md\`), names this same term, not a second concept." \
  || { echo "alias sentence does not name templates/persona-protocol.md"; exit 1; }
printf '%s' "$entry" | grep -qF 'and the template)' && { echo "entry still says \"and the template)\""; exit 1; }
exit 0
