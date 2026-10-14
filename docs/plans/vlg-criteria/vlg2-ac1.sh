#!/usr/bin/env bash
# vlg2-ac1.sh: tests/validate-lanes.sh reports like tests/validate.sh. Stub
# suites of 5 sections; checks exit code, closing summary as the LAST line
# (printed exactly once, so the stub's own summary block is not run as part of
# the last section), every section's output in header order, abort and
# never-ran reporting (a section that exits before its end is "aborted",
# even with exit 1, which a check that merely failed never produces), and
# the --lanes argument contract.
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
sec() { printf 'echo\necho "== s%s =="\n%s\n' "$1" "${2:-echo \"OK   s$1\"}"; }
five() { sec 1 "$1"; sec 2 "$2"; sec 3 "$3"; sec 4 "$4"; sec 5 "$5"; }
last() { printf '%s\n' "$OUT" | grep -v '^[[:space:]]*$' | tail -n 1; }
inorder() { # every "== sN ==" present once, in ascending order
  local got; got=$(printf '%s\n' "$OUT" | grep -E '^== s[0-9]+ ==$' | tr -d '=s ' | tr '\n' ' ')
  [ "$got" = "1 2 3 4 5 " ] || { echo "$1: section order/count is '$got', want '1 2 3 4 5 '"; printf '%s\n' "$OUT"; exit 1; }
}
once() { # $2 occurs on exactly one line
  local n; n=$(printf '%s\n' "$OUT" | grep -cxF "$2")
  [ "$n" = 1 ] || { echo "$1: '$2' printed $n times, want 1"; printf '%s\n' "$OUT"; exit 1; }
}

t=$(ltree green "$(five)"); runlanes "$t" --lanes 3
expect green 0; inorder green; once green 'All checks passed.'
[ "$(last)" = 'All checks passed.' ] || { echo "green: last line is '$(last)'"; exit 1; }
printf '%s\n' "$OUT" | grep -q '^== lanes: 3, sections: 5,' || { echo "green: no '== lanes: 3, sections: 5,' line"; printf '%s\n' "$OUT"; exit 1; }

t=$(ltree red "$(five '' '' 'echo "FAIL s3"; fail=1')"); runlanes "$t"
expect red 1 'FAIL s3' 'OK   s4' '!All checks passed.'; inorder red; once red 'One or more checks FAILED.'
[ "$(last)" = 'One or more checks FAILED.' ] || { echo "red: last line is '$(last)'"; exit 1; }

t=$(ltree abort "$(five '' 'echo "half s2"; exit 1; echo "OK   s2 tail"')"); runlanes "$t" --lanes=2
expect abort 1 'half s2' 'FAIL section 2 aborted (exit 1)' '!OK   s2 tail' 'OK   s5'
t=$(ltree abort7 "$(five '' '' '' 'exit 7')"); runlanes "$t"
expect abort7 1 'FAIL section 4 aborted (exit 7)' 'OK   s5'

t=$(ltree unset "$(five '' 'echo "$undefined_var_from_nowhere"')"); runlanes "$t"
expect unset 1 'FAIL section 2 aborted (exit ' '!FAIL section 1' 'OK   s3'

t=$(ltree one "$(five)"); runlanes "$t" --lanes 1
expect one 0 '== lanes: 1, sections: 5,'; inorder one

for bad in 0 9 x ''; do
  t=$(ltree "bad$bad" "$(five)"); runlanes "$t" --lanes "$bad"
  expect "lanes=$bad" 2 '!All checks passed.'
done
t=$(ltree badflag "$(five)"); runlanes "$t" --frobnicate
expect badflag 2 'usage: bash tests/validate-lanes.sh [--lanes N]'

# A linked worktree (.git is a file) would share its index across lanes: refuse.
t=$(ltree linked "$(five)"); rm -rf "$t/.git"; printf 'gitdir: /nonexistent\n' > "$t/.git"; runlanes "$t"
expect linked 2 'is not a directory' '!All checks passed.'
exit 0
