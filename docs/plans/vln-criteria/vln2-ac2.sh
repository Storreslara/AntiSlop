#!/usr/bin/env bash
# vln2-ac2.sh: the cases vlg3-ac2's five mutants left unproven can go red.
# For each mutant below, a copy of tests/validate-lanes.test.sh runs against
# a copy of tests/validate-lanes.sh with ONE exact-string replacement
# applied; the test must exit 1 and print `FAIL (<id>)`. The unmutated pair
# must exit 0. Each replacement must match exactly once (else the runner text
# drifted from the plan: exit 1).
#   order    L1   sections are printed in reverse header order
#   gitshare L6   each lane copy's .git is a symlink to the source's .git
#   keepwork L9   the EXIT trap no longer removes the work directory
#   oldtrap  L10  the EXIT trap kills only the lane subshells (pre-vln-1 text)
#   noretry  L11  a tar create exit 1 is never retried
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
[ -f tests/validate-lanes.test.sh ] || { echo "tests/validate-lanes.test.sh missing"; exit 1; }
try() { # <label> <old> <new> <fail-id>   (label "none": no mutation, want exit 0)
  local d="$VLN_ROOT/m-$1" out rc
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
  [ "$rc" = 1 ] || { echo "$1: test exit $rc, want 1"; printf '%s\n' "$out" | grep '^FAIL'; exit 1; }
  printf '%s\n' "$out" | grep -qF "FAIL ($4)" || { echo "$1: test did not print FAIL ($4)"; printf '%s\n' "$out" | grep '^FAIL'; exit 1; }
}
try none '' '' ''
try order    'for i in $(seq 1 "$count"); do' 'for i in $(seq "$count" -1 1); do' L1
try gitshare 'rm -f "$l/.git/index.lock"' 'rm -f "$l/.git/index.lock"; mv "$l/.git" "$l/.git.x"; ln -s "$root/.git" "$l/.git"' L6
try keepwork 'rm -rf "$work"' 'true' L9
try oldtrap  'for p in $(jobs -p); do kill -TERM -- "-$p" 2>/dev/null; done; wait;' 'kill $(jobs -p) 2>/dev/null;' L10
try noretry  'if [ "$st" = "1 0" ] && [ "$try" -lt 3 ]; then' 'if false; then' L11
exit 0
