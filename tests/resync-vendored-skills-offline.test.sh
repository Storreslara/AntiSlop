#!/usr/bin/env bash
# Offline checks for scripts/resync-vendored-skills.sh (unit sfu-5). The --check
# run needs the network; these read only the script's own FILES table and the
# tree, so a renamed or deleted local copy fails here without a fetch.
set -uo pipefail
cd "$(dirname "$0")/.."
SCRIPT="${RESYNC_SCRIPT:-scripts/resync-vendored-skills.sh}"
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

# lov-3: every tracked file under a skill's drift-tracked root has a FILES row, and
# each row's upstream path ends in the same skill-relative path as its local copy.
root_of() { case " $FORKED " in *" $1 "*) echo "docs/archive/skills/$1/" ;; *) echo "skills/$1/" ;; esac; }
for s in $order; do
  root="$(root_of "$s")"
  want_files="$(git ls-files -- "$root" | sort | tr '\n' ' ')"
  have_files="$(printf '%s\n' "$rows" | awk -F: -v s="$s" '$1 == s {print $3}' | sort | tr '\n' ' ')"
  [ "$want_files" = "$have_files" ] && ok "$s: FILES rows cover every tracked file under $root" || no "$s: FILES rows '$have_files' differ from the tracked files '$want_files' under $root"
done
while IFS=: read -r skill type local upstream extra; do
  [ -n "$skill" ] || continue
  rel="${local#"$(root_of "$skill")"}"
  case "$upstream" in */"$skill/$rel") ok "$skill $rel: upstream path names the same file" ;; *) no "$skill $rel: upstream path '$upstream' does not end in $skill/$rel" ;; esac
done <<< "$rows"

# lo2-2 self-test: mutated copies of the resync script, one planted defect each, that the checks
# above must reject. Skipped in the child runs (RESYNC_SELFTEST is set there), so it never recurses.
if [ -z "${RESYNC_SELFTEST:-}" ]; then
  st="$(mktemp -d)"
  st_case() { # <label> <sed expression> <fragment the child's output must contain>
    sed "$2" "$SCRIPT" > "$st/resync.sh"
    if cmp -s "$SCRIPT" "$st/resync.sh"; then no "($1) sed matched nothing"; return; fi
    st_out="$(RESYNC_SELFTEST=1 RESYNC_SCRIPT="$st/resync.sh" bash "$0" 2>&1)"
    st_rc=$?
    case "$st_out" in
      *"$3"*) if [ "$st_rc" = 1 ]; then ok "($1) rejected: $3"; else no "($1) exit $st_rc, want 1"; fi ;;
      *) no "($1) no output line contains: $3" ;;
    esac
  }
  st_case dropped-row '/^tdd:doc:docs\/archive\/skills\/tdd\/mocking.md:/d' "tdd: FILES rows"
  st_case upstream-typo 's#engineering/tdd/mocking.md$#engineering/tdd/mockng.md#' "upstream path 'skills/engineering/tdd/mockng.md' does not end in tdd/mocking.md"
  st_case unknown-type 's#^handoff:fm-noflag:#handoff:fmx:#' "handoff row type 'fmx' unknown"
  st_case untracked-local 's#^handoff:fm-noflag:skills/handoff/SKILL.md:#handoff:fm-noflag:skills/handoff/SKILLX.md:#' "skills/handoff/SKILLX.md is not tracked"
  st_case order-mismatch 's#^SKILL_ORDER="grilling #SKILL_ORDER="#' "differ from SKILL_ORDER"
  rm -rf "$st"
fi

[ "$fail" -eq 0 ] && echo "resync-vendored-skills-offline: ok" || echo "resync-vendored-skills-offline: FAIL"
exit "$fail"
