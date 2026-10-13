#!/usr/bin/env bash
# epfb-1 AC1.2 (item c): reviewer.md names the "Resolving a standing escalation"
# bullet, which follows the pointer, instead of "the bullet after next".
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
for f in agents/reviewer.md .claude/agents/reviewer.md; do
  t=$(tr -s ' \n' ' ' < "$f")
  ! printf '%s' "$t" | grep -qF 'bullet after next' || { echo "stale pointer: $f"; exit 1; }
  printf '%s' "$t" | grep -qF 'resolves it, per the "Resolving a standing escalation" bullet below.' \
    || { echo "pointer missing: $f"; exit 1; }
  p=$(grep -n 'resolves it, per the "Resolving a standing' "$f" | head -1 | cut -d: -f1)
  q=$(grep -n '^- \*\*Resolving a standing escalation (transcription, never re-review)\*\*:' "$f" | head -1 | cut -d: -f1)
  [ -n "$p" ] && [ -n "$q" ] && [ "$q" -gt "$p" ] || { echo "target bullet not below the pointer: $f"; exit 1; }
done
