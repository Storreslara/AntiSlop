#!/usr/bin/env bash
# epf-2 AC2.4: probes added (each tagged // epf-2), old probes kept, parity green.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
T=tests/adapter-protocol-parity.test.js
node "$T" >/dev/null || { echo "parity test failed"; exit 1; }
for p in "'**After:**'" "'### <n>. <one-phrase title>'" "'one \`>\` blockquote line'" "'\`run.sh\` and \`view.sh\` commands'"; do
  grep -F -- "$p" "$T" | grep -qF '// epf-2' || { echo "probe missing or untagged: $p"; exit 1; }
done
B=$(uF epf-2); [ -n "$B" ] || B=HEAD
git show "$B^:$T" | sed -n '/^const ESCALATION_PROBES/,/^];/p' | grep -oE "^  '[^']+'" | while read -r p; do
  grep -qF -- "$p" "$T" || { echo "LOST $p"; exit 1; }
done || exit 1
