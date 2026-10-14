#!/usr/bin/env bash
# lgc1-ac3.sh: the guard catches the ORIGINAL gh425 leak. T gets a copy of
# hooks/ and of tests/marker-write.test.sh with the f3dca44 fix reverted (its
# CLAUDE_PROJECT_DIR pins removed); the stub validate.sh runs that suite. The
# guard must exit 1 and name the four fixtures it leaks today (measured
# 2026-10-14: unitA.pass, unitB.fail, unitC.blocked, unitG.fail; the suite's
# set -e now stops at item12-1, before gh425 F3's spec2-unitC). A control tree with
# the unreverted suite must exit 0. Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
grep -q 'CLAUDE_PROJECT_DIR="\$proj" ' tests/marker-write.test.sh || { echo "marker-write.test.sh no longer carries the f3dca44 pin"; exit 1; }
for kind in reverted control; do
  t=$(mktree "$kind" 'bash tests/marker-write.test.sh')
  cp -r hooks "$t/hooks"
  if [ "$kind" = reverted ]; then
    sed -E 's/CLAUDE_PROJECT_DIR="\$g?proj" //' tests/marker-write.test.sh > "$t/tests/marker-write.test.sh"
  else
    cp tests/marker-write.test.sh "$t/tests/marker-write.test.sh"
  fi
  runguard "$t"
  if [ "$kind" = control ]; then
    [ "$RC" = 0 ] || { echo "control: guard exit $RC, want 0"; printf '%s\n' "$OUT"; exit 1; }
    continue
  fi
  [ "$RC" = 1 ] || { echo "reverted: guard exit $RC, want 1"; printf '%s\n' "$OUT"; exit 1; }
  for n in unitA.pass unitB.fail unitC.blocked unitG.fail; do
    case "$OUT" in *"$n"*) ;; *) echo "reverted: output does not name $n"; printf '%s\n' "$OUT"; exit 1;; esac
  done
done
