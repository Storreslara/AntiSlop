#!/usr/bin/env bash
# Offline checks for scripts/resync-vendored-skills.sh (unit sfu-5). The --check
# run needs the network; these read only the script's own FILES table and the
# tree, so a renamed or deleted local copy fails here without a fetch.
set -uo pipefail
cd "$(dirname "$0")/.."
SCRIPT=scripts/resync-vendored-skills.sh
FORKED="grilling tdd diagnosing-bugs improve-codebase-architecture"
fail=0
ok() { echo "OK   $1"; }
no() { echo "FAIL $1"; fail=1; }

rows="$(sed -n '/^FILES="$/,/^"$/p' "$SCRIPT" | sed '1d;$d')"
order="$(sed -n 's/^SKILL_ORDER="\(.*\)"$/\1/p' "$SCRIPT")"
[ -n "$rows" ] || no "FILES table not found in $SCRIPT"
[ -n "$order" ] || no "SKILL_ORDER not found in $SCRIPT"

while IFS=: read -r skill type local upstream extra; do
  [ -n "$skill" ] || continue
  [ -z "$extra" ] || no "$skill row has more than four fields"
  case "$type" in fm|fm-noflag|doc|raw) ;; *) no "$skill row type '$type' unknown" ;; esac
  if git ls-files --error-unmatch -- "$local" >/dev/null 2>&1; then ok "$skill $local is tracked"; else no "$skill $local is not tracked"; fi
  case "$upstream" in skills/*/"${skill}"/*) ;; *) no "$skill upstream path '$upstream' is not under skills/<group>/$skill/" ;; esac
  case " $FORKED " in
    *" $skill "*) want="docs/archive/skills/$skill/" ;;
    *) want="skills/$skill/" ;;
  esac
  case "$local" in "$want"*) ;; *) no "$skill local path '$local' is not under $want" ;; esac
done <<< "$rows"

in_files="$(printf '%s\n' "$rows" | cut -d: -f1 | sort -u | tr '\n' ' ')"
in_order="$(printf '%s\n' $order | sort -u | tr '\n' ' ')"
[ "$in_files" = "$in_order" ] && ok "FILES and SKILL_ORDER name the same skills" || no "FILES skills '$in_files' differ from SKILL_ORDER '$in_order'"
n="$(printf '%s\n' $order | wc -l | tr -d ' ')"
[ "$n" = 7 ] && ok "7 drift-tracked skills" || no "SKILL_ORDER has $n skills, the runbook and NOTICES say 7"
grep -q 'vendors 7 skills' docs/maintenance/resync-vendored-skills.md && ok "runbook says 7" || no "runbook does not say 'vendors 7 skills'"
for s in $FORKED; do
  grep -q "^<!-- Derived from mattpocock/skills " "skills/$s/SKILL.md" && ok "skills/$s/SKILL.md has a Derived from header" || no "skills/$s/SKILL.md lacks a Derived from header"
done

[ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok" || echo "resync-vendored-skills-offline: FAIL"
exit "$fail"
