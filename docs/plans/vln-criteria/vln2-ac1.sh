#!/usr/bin/env bash
# vln2-ac1.sh: tests/validate-lanes.test.sh passes against the committed
# runner, prints an `ok` line for each of L1-L8, L10 and L11, ends with its
# own success line, and its validate.sh section (exactly one section header
# names the lane runner, and exactly one line runs this test; the section
# count is not pinned, since other plans add sections) runs green through
# docs/plans/epf-criteria/lib.sh's vrun.
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
out=$(env -u CLAUDE_PROJECT_DIR bash tests/validate-lanes.test.sh 2>&1); rc=$?
[ "$rc" = 0 ] || { echo "test exit $rc, want 0"; printf '%s\n' "$out"; exit 1; }
for id in L1 L2 L3 L4 L5 L6 L7-0 L7-9 L7-x L8 L10 L11; do
  printf '%s\n' "$out" | grep -qF "ok   ($id) " || { echo "no ok line for $id"; printf '%s\n' "$out"; exit 1; }
done
last=$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -n 1)
[ "$last" = 'All validate-lanes cases passed.' ] || { echo "last line is: $last"; exit 1; }
n=$(grep -c '^echo "== .*opt-in parallel lane runner' tests/validate.sh)
[ "$n" = 1 ] || { echo "lane runner section headers: $n, want 1"; exit 1; }
n=$(grep -c '^if bash tests/validate-lanes\.test\.sh; then$' tests/validate.sh)
[ "$n" = 1 ] || { echo "validate.sh lines running the lane test: $n, want 1"; exit 1; }
. docs/plans/epf-criteria/lib.sh
vout=$(REVIEWED_DIR_LEAK_GUARD_NESTED=1 vrun 'opt-in parallel lane runner' 2>&1); vrc=$?
[ "$vrc" = 0 ] || { echo "vrun exit $vrc, want 0"; printf '%s\n' "$vout"; exit 1; }
printf '%s\n' "$vout" | grep -qx 'OK   tests/validate-lanes.test.sh' || { echo "vrun did not print the OK line"; printf '%s\n' "$vout"; exit 1; }
exit 0
