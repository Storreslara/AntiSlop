#!/usr/bin/env bash
# vlg2-ac2.sh: lane isolation and the per-section leak check (item 2).
# (a) A section that writes the marker directory relative to the repository
#     root (cwd), via an explicit `git rev-parse --show-toplevel` root, or via
#     CLAUDE_PROJECT_DIR is a FAIL naming that section and the entry; so is
#     an overwrite of an existing entry and removal of the directory.
# (b) None of it reaches the source tree T: T's marker directory still holds
#     only old.pass, unchanged, and no section ever sees CLAUDE_PROJECT_DIR=T.
# (c) Git writes in a section (add, commit) never touch T's index or HEAD,
#     and no index.lock is left in T.
# (d) A "reviewer" writing into T's marker directory while the runner is in
#     flight does not FAIL the run.
# (e) The runner leaves nothing in TMPDIR.
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
sec() { printf 'echo\necho "== s%s =="\n%s\n' "$1" "$2"; }
ok() { sec "$1" "echo \"OK   s$1\""; }
untouched() { # <label> <T>
  local l; l=$(cd "$2/.claude/reviewed" && ls -A)
  [ "$l" = old.pass ] || { echo "$1: source marker dir now holds: $l"; exit 1; }
  grep -qx 'PASS old 2026-01-01T00:00:00Z commit: none criteria: none' "$2/.claude/reviewed/old.pass" \
    || { echo "$1: source old.pass content changed"; exit 1; }
  [ -z "$(ls -A "$2/tmp")" ] || { echo "$1: TMPDIR not cleaned: $(ls -A "$2/tmp")"; exit 1; }
}
leak() { # <label> <section-2-body> <substring>
  local t; t=$(ltree "$1" "$(ok 1; sec 2 "$2"; ok 3)"); runlanes "$t"
  expect "$1" 1 'FAIL section 2 changed' "$3" '!FAIL section 1 changed' '!FAIL section 3 changed' 'OK   s3'
  untouched "$1" "$t"
}
leak relpath  'printf x > .claude/reviewed/relA.pass'                                       relA.pass
leak toplevel 'printf x > "$(git rev-parse --show-toplevel)/.claude/reviewed/topB.fail"'  topB.fail
leak envvar   'printf x > "$CLAUDE_PROJECT_DIR/.claude/reviewed/envC.blocked"'             envC.blocked
leak overwrite 'sleep 1; printf "PASS old y\n" > .claude/reviewed/old.pass'                 old.pass
leak removal  'rm -rf .claude/reviewed'                                                     'directory itself is missing'

# (b) CLAUDE_PROJECT_DIR is the lane copy, never T.
t=$(ltree envcheck "$(sec 1 'echo "CPD=$CLAUDE_PROJECT_DIR PWD=$(pwd)"')"); runlanes "$t"
expect envcheck 0 '!CPD='"$t"' ' 'CPD='
cpd=$(printf '%s\n' "$OUT" | sed -n 's/^CPD=\([^ ]*\) PWD=\(.*\)$/\1/p'); pwd_=$(printf '%s\n' "$OUT" | sed -n 's/^CPD=[^ ]* PWD=\(.*\)$/\1/p')
[ -n "$cpd" ] && [ "$cpd" = "$pwd_" ] || { echo "envcheck: CLAUDE_PROJECT_DIR ($cpd) is not the section's cwd ($pwd_)"; exit 1; }

# (c) git writes stay in the lane.
g='git add -A >/dev/null 2>&1; git -c user.name=t -c user.email=t@t commit -qm lane --allow-empty || fail=1'
t=$(ltree gitw "$(sec 1 "$g"; sec 2 "$g"; sec 3 "$g"; sec 4 "$g")")
head0=$(git -C "$t" rev-parse HEAD); idx0=$(md5sum < "$t/.git/index")
runlanes "$t" --lanes 3
expect gitw 0
[ "$(git -C "$t" rev-parse HEAD)" = "$head0" ] || { echo "gitw: source HEAD moved"; exit 1; }
[ "$(md5sum < "$t/.git/index")" = "$idx0" ] || { echo "gitw: source index changed"; exit 1; }
[ ! -e "$t/.git/index.lock" ] || { echo "gitw: index.lock left in source"; exit 1; }

# (d) concurrent reviewer write into T during the run.
t=$(ltree concurrent "$(sec 1 'sleep 2; echo "OK   s1"'; sec 2 'sleep 2; echo "OK   s2"')")
( sleep 1; printf 'PASS gh999-1 x\n' > "$t/.claude/reviewed/gh999-1.pass"; rm -f "$t/.claude/reviewed/old.pass" ) &
runlanes "$t" --lanes 2; wait
expect concurrent 0 'All checks passed.' '!changed'
[ -z "$(ls -A "$t/tmp")" ] || { echo "concurrent: TMPDIR not cleaned"; exit 1; }
exit 0
