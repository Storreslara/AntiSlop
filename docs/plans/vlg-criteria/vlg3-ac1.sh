#!/usr/bin/env bash
# vlg3-ac1.sh: tests/validate-lanes.test.sh passes against the committed
# runner, its last line is its own success line, and validate.sh registers it
# as the LAST section (header text below), after which the section count is
# 116. The section itself runs green through docs/plans/epf-criteria/lib.sh's
# vrun. Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
out=$(env -u CLAUDE_PROJECT_DIR bash tests/validate-lanes.test.sh 2>&1); rc=$?
[ "$rc" = 0 ] || { echo "test exit $rc, want 0"; printf '%s\n' "$out"; exit 1; }
last=$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -n 1)
[ "$last" = 'All validate-lanes cases passed.' ] || { echo "last line is: $last"; exit 1; }
H='echo "== tests/validate-lanes.sh: opt-in parallel lane runner (Bash, vlg-3) =="'
[ "$(grep -c '^echo "== ' tests/validate.sh)" = 116 ] || { echo "section count is $(grep -c '^echo "== ' tests/validate.sh), want 116"; exit 1; }
[ "$(grep '^echo "== ' tests/validate.sh | tail -n 1)" = "$H" ] || { echo "last section header is not the vlg-3 header"; exit 1; }
. docs/plans/epf-criteria/lib.sh
vout=$(REVIEWED_DIR_LEAK_GUARD_NESTED=1 vrun 'opt-in parallel lane runner' 2>&1); vrc=$?
[ "$vrc" = 0 ] || { echo "vrun exit $vrc, want 0"; printf '%s\n' "$vout"; exit 1; }
printf '%s\n' "$vout" | grep -qx 'OK   tests/validate-lanes.test.sh' || { echo "vrun did not print the OK line"; printf '%s\n' "$vout"; exit 1; }
exit 0
