#!/usr/bin/env bash
# Usage: skr-glossary.sh <retired-skill>...
# For CONTEXT.md and docs/harness-glossary.md: every glossary entry (a line
# starting with **...**: up to the next such line) that names a retired skill
# must also contain the string docs/archive/skills/ somewhere in the entry,
# so glossary prose about a retired skill always points at its archived copy.
# Lines before the first entry heading count as one preamble entry.
# Exit 0 iff that holds for every named skill.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
[ "$#" -gt 0 ] || { echo "usage: $0 <skill>..." >&2; exit 2; }
bad=0
for name in "$@"; do
  for f in CONTEXT.md docs/harness-glossary.md; do
    out="$(awk -v n="$name" -v f="$f" '
      function flush() { if (hit && !arch) printf "%s:%d: entry names %s without an archive pointer\n", f, start, n; hit=0; arch=0 }
      BEGIN { start=1 }
      /^\*\*[^*].*\*\*:/ { flush(); start=NR }
      {
        line=$0
        if (match(line, "(^|[^a-z0-9-])" n "([^a-z0-9-]|$)")) hit=1
        if (index(line, "docs/archive/skills/")) arch=1
      }
      END { flush() }' "$f")"
    if [ -n "$out" ]; then echo "$out"; bad=1; fi
  done
  [ "$bad" -eq 0 ] && echo "skr-glossary: $name ok"
done
[ "$bad" -eq 0 ]
