#!/usr/bin/env bash
# epf-2 AC2.1: the skip token is spelled with an ASCII hyphen everywhere.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
for f in agents/reviewer.md templates/persona-protocol.md .claude/agents/reviewer.md .claude/persona-protocol.md CONTEXT.md; do
  [ "$(grep -c 'examples: none —' "$f")" -eq 0 ] || { echo "EM DASH left: $f"; exit 1; }
done
for f in agents/reviewer.md templates/persona-protocol.md .claude/agents/reviewer.md .claude/persona-protocol.md; do
  [ "$(grep -cF 'examples: none - <one-line reason>' "$f")" -ge 2 ] || { echo "token count <2: $f"; exit 1; }
done
grep -qF 'examples: none - <one-line reason>' CONTEXT.md || { echo "CONTEXT.md token"; exit 1; }
