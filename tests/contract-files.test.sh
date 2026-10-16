#!/usr/bin/env bash
# AC3.1 (ptr-u3a): a contract file and the plan that embeds the same contract give
# the same contract-guard line and the same contract-score result. Exit 0: every
# case passed; 1: a case FAILed.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT
failures=0
checked=0
plans="docs/plans/2026-10-14-validate-lanes-followups-2.md docs/plans/2026-10-14-skills-audit-leftovers-2.md"

# extract <plan> <dir>: write the interior of each top-level fenced block whose first
# interior line is `Unit: <id>` to <dir>/<id>.md (the block rule of bin/contract-guard.js).
extract() {
  awk -v dir="$2" '
    function runof(t) {
      if (match(t, /^`+/) && RLENGTH >= 3) return substr(t, 1, RLENGTH)
      if (match(t, /^~+/) && RLENGTH >= 3) return substr(t, 1, RLENGTH)
      return ""
    }
    { t = $0; sub(/^[ \t]+/, "", t); r = runof(t); sub(/[ \t]+$/, "", t) }
    open == "" { if (r != "") { open = r; n = 0; buf = "" }; next }
    t == open {
      if (n > 0 && first ~ /^Unit: [A-Za-z0-9][A-Za-z0-9._#-]*$/) {
        f = dir "/" substr(first, 7) ".md"; printf "%s", buf > f; close(f)
      }
      open = ""; next
    }
    { n++; if (n == 1) first = $0; buf = buf $0 "\n" }
  ' "$1"
}
shape_of() { if /usr/bin/grep -qxF '## Glossary edits' "$1"; then echo scribe; else echo lead; fi; }
ok() { echo "OK   $1"; }
bad() { echo "FAIL $1"; failures=$((failures + 1)); }

first_file=""
for plan in $plans; do
  d="$T/$(basename "$plan" .md)"
  mkdir -p "$d"
  extract "$plan" "$d"
  found=0
  for f in "$d"/*.md; do
    [ -e "$f" ] || continue
    found=$((found + 1)); checked=$((checked + 1))
    id="$(basename "$f" .md)"; shape="$(shape_of "$f")"
    [ -n "$first_file" ] || [ "$shape" != lead ] || first_file="$f"
    a="$(node bin/contract-guard.js "$f" --unit="$id" --shape="$shape" | head -1)"
    b="$(node bin/contract-guard.js "$plan" --unit="$id" --shape="$shape" | head -1)"
    if [ -n "$a" ] && [ "$a" = "$b" ]; then ok "$id guard line equal: $a"; else bad "$id guard lines differ: [$a] [$b]"; fi
    s1="$(node bin/contract-score.js --rubric=v2 --shape="$shape" "$f")"
    s2="$(node bin/contract-score.js --rubric=v2 --shape="$shape" - < "$f")"
    if [ -n "$s1" ] && [ "$s1" = "$s2" ]; then ok "$id score equal (file vs stdin)"; else bad "$id scores differ"; fi
  done
  [ "$found" -gt 0 ] && ok "$plan: $found contract(s) extracted" || bad "$plan: no contract extracted"
done

# Mutation: a stray fence line after line 1 hides the headings, so the guard line must differ.
if [ -n "$first_file" ]; then
  id="$(basename "$first_file" .md)"
  { head -1 "$first_file"; printf '%s\n' '```'; tail -n +2 "$first_file"; } > "$T/mutant.md"
  m="$(node bin/contract-guard.js "$T/mutant.md" --unit="$id" | head -1)"
  g="$(node bin/contract-guard.js "$first_file" --unit="$id" | head -1)"
  if [ "$m" != "$g" ]; then ok "stray fence changes the guard line: $m"; else bad "stray fence left the guard line unchanged"; fi
else
  bad "no lead contract to mutate"
fi

if [ "$failures" -eq 0 ]; then echo "All contract-files checks passed ($checked contracts)."; else echo "$failures contract-files check(s) failed."; fi
[ "$failures" -eq 0 ]
