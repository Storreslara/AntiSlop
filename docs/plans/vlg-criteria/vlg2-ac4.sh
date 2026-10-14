#!/usr/bin/env bash
# vlg2-ac4.sh: the runner on the REAL suite. `bash tests/validate-lanes.sh
# --lanes 3` in this checkout exits 0, ends with `All checks passed.`, reports
# every section of tests/validate.sh (count line), prints no "aborted",
# "never ran" or "changed" FAIL, and leaves this checkout's git index and HEAD
# as they were. Run with the Bash tool's timeout at 600000 ms; the measured
# wall time at 70458f7 is in the plan (Verification record).
# Prints one line `wall: <s>s` and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
n=$(grep -c '^echo "== ' tests/validate.sh)
head0=$(git rev-parse HEAD); idx0=$(md5sum < .git/index)
s=$(mono)
out=$(env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
  CLAUDE_PROJECT_DIR="$REPO" bash tests/validate-lanes.sh --lanes 3 2>&1); rc=$?
secs=$(awk -v a="$s" -v b="$(mono)" 'BEGIN { printf "%d", b - a }')
bad=$(printf '%s\n' "$out" | grep -E '^FAIL section [0-9]+ (aborted|never ran|changed)')
[ "$rc" = 0 ] || { echo "runner exit $rc, want 0"; printf '%s\n' "$out" | grep -E '^FAIL' | head -20; exit 1; }
[ -z "$bad" ] || { printf '%s\n' "$bad"; exit 1; }
printf '%s\n' "$out" | grep -q "^== lanes: 3, sections: $n, " || { echo "no '== lanes: 3, sections: $n,' line"; exit 1; }
[ "$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -n 1)" = 'All checks passed.' ] || { echo "last line is not 'All checks passed.'"; exit 1; }
[ "$(git rev-parse HEAD)" = "$head0" ] || { echo "HEAD moved during the run"; exit 1; }
[ "$(md5sum < .git/index)" = "$idx0" ] || { echo "git index changed during the run (another agent may have staged; re-run)"; exit 1; }
echo "wall: ${secs}s"
