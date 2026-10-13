#!/usr/bin/env bash
# epf-1 AC1.3: the template sentence; "pastes" gone; the epa AC1.4 count kept.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
for f in templates/persona-protocol.md .claude/persona-protocol.md; do
  t=$(tr -s ' \n' ' ' < "$f")
  echo "$t" | grep -qF 'prints marker lines 1 through the `---` fold line verbatim in chat (the whole marker when it has no fold line)' || { echo "MISSING: $f"; exit 1; }
  echo "$t" | grep -qF 'reproduces `CHANGES.md` and `EXAMPLES.md` verbatim as its own message text' || { echo "MISSING reproduces: $f"; exit 1; }
  ! echo "$t" | grep -qF 'pastes `CHANGES.md`' || { echo "STALE pastes: $f"; exit 1; }
  [ "$(echo "$t" | grep -oF 'as its own message text, outside any code fence' | wc -l)" -eq 1 ] || { echo "count: $f"; exit 1; }
done
