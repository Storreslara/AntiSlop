#!/usr/bin/env bash
# vln1-ac2.sh: a lane copy whose tar create side exits 1 (GNU tar: a file
# changed while it was read) is copied again, at most 3 attempts in all; any
# other tar failure is not retried. A `tar` wrapper first on PATH runs the real
# tar, counts create calls in T/creates, and replaces the create side's exit
# status for the first <n> creates. Cases (--lanes 1, two stub sections):
#   once:   status 1 once -> exit 0, `All checks passed.`, the retry NOTE, 2 creates.
#   always: status 1 always -> exit 1, `FAIL lane 1: could not copy the checkout (tar exits: 1 0)`, 3 creates.
#   hard:   status 2 always -> exit 1, `... (tar exits: 2 0)`, 1 create (no retry).
# Each case also wants T/tmp empty afterwards.
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# case_ <label> <status> <n> : build the tree, install the wrapper, run.
case_() {
  local t
  t=$(ltree "$1" "$(sec 1; sec 2)") || exit 1
  echo 0 > "$t/creates"
  { printf '#!/usr/bin/env bash\n'
    printf 'case " $* " in\n'
    printf '  *" -cf "*) n=$(( $(cat %q) + 1 )); echo "$n" > %q\n' "$t/creates" "$t/creates"
    printf '    %q "$@"; s=$?; [ "$n" -le %s ] && exit %s; exit "$s" ;;\n' "$REAL_TAR" "$3" "$2"
    printf 'esac\nexec %q "$@"\n' "$REAL_TAR"; } > "$t/bin/tar"
  chmod +x "$t/bin/tar"
  runlanes "$t" --lanes 1
  T=$t
}
creates() { [ "$(cat "$T/creates")" = "$2" ] || { echo "$1: tar create ran $(cat "$T/creates") times, want $2"; printf '%s\n' "$OUT"; exit 1; }; }

case_ once 1 1
expect once 0 'All checks passed.' 'NOTE lane 1: a file changed during copy attempt 1; copying again' 'OK   s1' 'OK   s2' '!FAIL'
creates once 2; tmpclean once "$T"

case_ always 1 99
expect always 1 'FAIL lane 1: could not copy the checkout (tar exits: 1 0)' 'NOTE lane 1: a file changed during copy attempt 2; copying again' '!All checks passed.'
creates always 3; tmpclean always "$T"

case_ hard 2 99
expect hard 1 'FAIL lane 1: could not copy the checkout (tar exits: 2 0)' '!NOTE lane 1' '!All checks passed.'
creates hard 1; tmpclean hard "$T"
exit 0
