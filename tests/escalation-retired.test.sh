#!/usr/bin/env bash
# Escalation machinery is retired from prose; the reviewer's optional needs-human note replaces it.
set -u
cd "$(dirname "$0")/.."
mode="${1:-}"
[ "$mode" = prose ] || { echo "usage: escalation-retired.test.sh prose" >&2; exit 2; }
fail=0
# each pattern is assembled from pieces so this file never spells one whole
pats=(
  "[Ee][Ss][Cc][Aa][Ll][Aa][Tt][Ee]-[Tt][Oo]""-[Hh][Uu][Mm][Aa][Nn]"
  "\\.escal""ated\\b"
  "human-re""view/"
  "(/DEC""ISION|\`DEC""ISION\`|DEC""ISION file|DEC""ISION <task-id>)"
  "escalation""-card"
  "heavy""-trigger"
  "human-decision""-gate"
  "decision-gate"" denial"
  "Fourth"" verdict"
  "[Ee]scalation"" packet"
)
for p in "${pats[@]}"; do
  if hits=$(git grep -nE -e "$p" -- agents templates commands skills adapters ':!adapters/*/hooks/**'); then
    printf '%s\n' "$hits"; fail=1
  fi
done
for f in agents/reviewer.md agents/orchestrator.md; do
  grep -q 'needs-human:' "$f" || { echo "missing needs-human: in $f"; fail=1; }
done
exit "$fail"
