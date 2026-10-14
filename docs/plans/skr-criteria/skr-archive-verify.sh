#!/usr/bin/env bash
# Usage: skr-archive-verify.sh <skill>...
# Reads docs/archive/skills/README.md rows of the form
#   | <skill> | <origin dir> | <archived-from sha> | <disposition> | <successor> |
# and, for every row (not only the named ones), checks that
# docs/archive/skills/<skill>/ holds exactly the files git had under
# <origin dir> at <sha>, byte-identical. Each named <skill> must have a row.
# Exit 0 iff all of that holds.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
IDX=docs/archive/skills/README.md
[ -f "$IDX" ] || { echo "skr-archive-verify: no $IDX"; exit 1; }

rows="$(grep -E '^\| *[a-z0-9-]+ *\| *[^|]+ *\| *[0-9a-f]{7,40} *\|' "$IDX" || true)"
bad=0
for want in "$@"; do
  printf '%s\n' "$rows" | grep -qE "^\| *$want *\|" || { echo "MISSING row: $want"; bad=1; }
done

while IFS='|' read -r _ skill origin sha disp succ _; do
  skill="$(echo "$skill" | xargs)"; origin="$(echo "$origin" | xargs)"; sha="$(echo "$sha" | xargs)"
  [ -n "$skill" ] || continue
  origin="${origin%/}"
  dest="docs/archive/skills/$skill"
  files="$(git ls-tree -r --name-only "$sha" -- "$origin/" 2>/dev/null)"
  rowbad=0
  if [ -z "$files" ]; then echo "BAD $skill: nothing at $sha:$origin/"; bad=1; continue; fi
  want_n="$(printf '%s\n' "$files" | wc -l)"
  have_n="$(find "$dest" -type f 2>/dev/null | wc -l)"
  [ "$want_n" = "$have_n" ] || { echo "BAD $skill: $have_n files in $dest, $want_n at $sha:$origin"; bad=1; rowbad=1; }
  while IFS= read -r f; do
    rel="${f#"$origin"/}"
    if ! git show "$sha:$f" | cmp -s - "$dest/$rel"; then
      echo "BAD $skill: $dest/$rel differs from $sha:$f"; bad=1; rowbad=1
    fi
  done <<< "$files"
  [ "$rowbad" -eq 0 ] && echo "ok  $skill ($want_n files from $sha:$origin)"
done <<< "$rows"
[ "$bad" -eq 0 ]
