#!/usr/bin/env bash
# vlg3-ac2.sh: tests/validate-lanes.test.sh is not vacuous. For each mutant
# below, a copy of the test runs against a copy of tests/validate-lanes.sh
# with ONE exact-string replacement applied; the test must exit 1 and print
# the named FAIL id. The unmutated pair must exit 0. Each replacement must
# match exactly once (else the runner text drifted from the plan: exit 1).
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
[ -f tests/validate-lanes.test.sh ] || { echo "tests/validate-lanes.test.sh missing"; exit 1; }
try() { # <label> <old> <new> <fail-id>   (label "none": no mutation, want exit 0)
  local d="$VLG_ROOT/m-$1" out rc
  mkdir -p "$d/tests"
  cp tests/validate-lanes.test.sh "$d/tests/"
  python3 - "$REPO/tests/validate-lanes.sh" "$d/tests/validate-lanes.sh" "$2" "$3" <<'PY' || exit 1
import sys
src, dst, old, new = sys.argv[1:]
s = open(src).read()
if old:
    n = s.count(old)
    if n != 1:
        print(f"mutant anchor matched {n} times: {old!r}")
        sys.exit(1)
    s = s.replace(old, new)
open(dst, 'w').write(s)
PY
  out=$(env -u CLAUDE_PROJECT_DIR bash "$d/tests/validate-lanes.test.sh" 2>&1); rc=$?
  if [ "$1" = none ]; then
    [ "$rc" = 0 ] || { echo "unmutated: test exit $rc, want 0"; printf '%s\n' "$out"; exit 1; }
    return
  fi
  [ "$rc" = 1 ] || { echo "$1: test exit $rc, want 1"; exit 1; }
  printf '%s\n' "$out" | grep -q "^FAIL ($4)" || { echo "$1: test did not print FAIL ($4)"; printf '%s\n' "$out" | grep '^FAIL'; exit 1; }
}
try none '' '' ''
try leakflag   '      echo 1 > "$work/leak/$i"' '      :' L4
try envroot    'CLAUDE_PROJECT_DIR="$l" REVIEWED_DIR_LEAK_GUARD_NESTED=1' 'CLAUDE_PROJECT_DIR="$root" REVIEWED_DIR_LEAK_GUARD_NESTED=1' L5
try abortmsg   '[ -f "$work/rc/$i" ] || echo "FAIL section $i aborted (exit $rc)" >> "$work/out/$i"' ':' L3
try lanes9     '  [1-8]) ;;' '  [1-9]) ;;' L7-9
try linked     'if [ ! -d "$root/.git" ]; then' 'if false; then' L8
exit 0
