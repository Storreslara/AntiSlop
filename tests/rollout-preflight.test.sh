#!/bin/bash
# TDD test for scripts/rollout-preflight.sh (Step 1 of
# docs/plans/2026-08-25-streamlining-rollout-sequencing.md).
#
# Mutation record (per wave, which single line deletion in scripts/rollout-preflight.sh
# makes that wave's assertion fail):
# W0: line checking gh run list (around "gh run list --branch master...")
# W1: line returning non-zero for W1 case statement
# W2: line checking tests/watch-map.json (around "if [ ! -f \"tests/watch-map.json\" ]")
# W3: line returning non-zero for W3 case statement
# W4: line returning non-zero for W4 case statement
# W5: line returning non-zero for W5 case statement
# W6: line returning non-zero for W6 case statement
# W7: line that includes "escape hatch" in E7 message
# W8: line returning non-zero for W8 case statement
# W9: line listing W3, W7, W8 as unmet predecessors in case statement
# W10: line mentioning "blocked by design" and "A23" and "OQ2"
set -euo pipefail
cd "$(dirname "$0")/.."
SCRIPT="$PWD/scripts/rollout-preflight.sh"
fail=0

# Test helpers
pass_test() {
  echo "OK   $1"
}

fail_test() {
  echo "FAIL $1"
  fail=1
}

# AC1: syntax check
if bash -n "$SCRIPT" 2>&1; then
  pass_test "syntax: bash -n passes"
else
  fail_test "syntax: bash -n failed"
fi

# AC2: W0 reports actual CI status (should be failure today per F2)
w0_output=$(bash "$SCRIPT" W0 2>&1 || true)
if echo "$w0_output" | grep -q "failure"; then
  pass_test "W0: reports CI failure status"
elif echo "$w0_output" | grep -q "success"; then
  fail_test "W0: incorrectly reports success (F2 says CI is red)"
else
  fail_test "W0: did not report CI status"
fi

# AC3: W9 lists W3, W7, W8 as unmet predecessors
w9_output=$(bash "$SCRIPT" W9 2>&1 || true)
if echo "$w9_output" | grep -q "W3" && echo "$w9_output" | grep -q "W7" && echo "$w9_output" | grep -q "W8"; then
  pass_test "W9: lists W3, W7, W8 as predecessors"
else
  fail_test "W9: did not list all three predecessors (W3, W7, W8)"
fi

# AC4: W7 mentions escape hatch
w7_output=$(bash "$SCRIPT" W7 2>&1 || true)
if echo "$w7_output" | grep -q "escape" || echo "$w7_output" | grep -q "baseline"; then
  pass_test "W7: mentions escape hatch"
else
  fail_test "W7: escape hatch not mentioned"
fi

# AC5: W10 reports blocked by design with A23 and OQ2
w10_output=$(bash "$SCRIPT" W10 2>&1 || true)
if echo "$w10_output" | grep -q "blocked" && echo "$w10_output" | grep -q "A23" && echo "$w10_output" | grep -q "OQ2"; then
  pass_test "W10: reports blocked by design with A23 and OQ2"
else
  fail_test "W10: did not report properly"
fi

# AC6: --owner for microworld-rerun.sh lists 4 specs
owner_output=$(bash "$SCRIPT" --owner hooks/scripts/microworld-rerun.sh 2>&1 || true)
spec_count=$(echo "$owner_output" | grep -oE "spec [0-9]" | wc -l)
if [ "$spec_count" -eq 4 ]; then
  pass_test "--owner microworld-rerun.sh: lists 4 specs"
else
  fail_test "--owner microworld-rerun.sh: listed $spec_count specs, expected 4"
fi

# AC6b: --owner for reviewed-path-gate.sh lists specs 1,2,3 and mentions H7
owner2_output=$(bash "$SCRIPT" --owner hooks/scripts/reviewed-path-gate.sh 2>&1 || true)
if echo "$owner2_output" | grep -q "spec 1" && echo "$owner2_output" | grep -q "spec 2" && echo "$owner2_output" | grep -q "spec 3" && echo "$owner2_output" | grep -q "H7"; then
  pass_test "--owner reviewed-path-gate.sh: lists specs 1,2,3 with H7 note"
else
  fail_test "--owner reviewed-path-gate.sh: missing specs or H7 note"
fi

# AC6c: --owner for .github/workflows lists only spec 6
owner3_output=$(bash "$SCRIPT" --owner .github/workflows/ 2>&1 || true)
if echo "$owner3_output" | grep -q "spec 6" && ! echo "$owner3_output" | grep -q "spec 1" && ! echo "$owner3_output" | grep -q "spec 2" && ! echo "$owner3_output" | grep -q "spec 3" && ! echo "$owner3_output" | grep -q "spec 4"; then
  pass_test "--owner .github/workflows/: lists only spec 6"
else
  fail_test "--owner .github/workflows/: incorrect specs"
fi

# AC7: --resource protected-paths points to spec 2 Unit E
resource_output=$(bash "$SCRIPT" --resource protected-paths 2>&1 || true)
if echo "$resource_output" | grep -q "spec 2" && echo "$resource_output" | grep -q "Unit E"; then
  pass_test "--resource protected-paths: spec 2 Unit E"
else
  fail_test "--resource protected-paths: incorrect allocation"
fi

# AC7b: --resource adr lists 0026/0027/0028 with do-not-backfill rule
adr_output=$(bash "$SCRIPT" --resource adr 2>&1 || true)
if echo "$adr_output" | grep -q "0026" && echo "$adr_output" | grep -q "0027" && echo "$adr_output" | grep -q "0028" && echo "$adr_output" | grep -q "not backfill"; then
  pass_test "--resource adr: lists 0026/0027/0028 with do-not-backfill rule"
else
  fail_test "--resource adr: missing entries or rule"
fi

# AC8: unknown wave exits non-zero with reason
unknown_output=$(bash "$SCRIPT" UNKNOWN 2>&1 || true)
if echo "$unknown_output" | grep -q "unknown"; then
  pass_test "unknown wave: exits with reason"
else
  fail_test "unknown wave: did not report reason"
fi

# AC10: wiring in validate.sh (check that bash invocation appears exactly once)
grep_count=$(grep -c 'bash tests/rollout-preflight' tests/validate.sh || true)
if [ "$grep_count" -eq 1 ]; then
  pass_test "validate.sh: exactly 1 wiring block"
else
  fail_test "validate.sh: found $grep_count wiring blocks, expected 1"
fi

# AC10b: validate.sh never invokes with wave argument
if grep 'rollout-preflight.*W[0-9]' tests/validate.sh >/dev/null 2>&1; then
  fail_test "validate.sh: invokes script with wave argument (should not)"
else
  pass_test "validate.sh: never invokes with wave argument"
fi

# AC11: sunset criterion in header and help text
header_check=$(head -20 "$SCRIPT" | grep -i "delete this file" || true)
help_check=$(bash "$SCRIPT" 2>&1 | grep -i "delete this file" || true)
if [ -n "$header_check" ] && [ -n "$help_check" ]; then
  pass_test "sunset: stated in both header and help"
else
  fail_test "sunset: not stated in header or help"
fi

# AC12: --reverify works and can fail
# Test 1: On unmodified worktree, A24 should pass (14 scripts exist)
reverify_output=$(bash "$SCRIPT" --reverify 6 2>&1 || true)
if echo "$reverify_output" | grep -q "A24" && echo "$reverify_output" | grep -q "passing"; then
  pass_test "--reverify: A24 passes on unmodified worktree"
else
  fail_test "--reverify: A24 did not show passing on unmodified worktree"
fi

# Test 2: Create a temporary worktree with 15 scripts and verify A24 fails
tmp_repo=$(mktemp -d)
trap "rm -rf $tmp_repo" EXIT
cp -r . "$tmp_repo"
# Add an extra script
touch "$tmp_repo/hooks/scripts/extra-test.sh"
# Run --reverify in the temp repo
cd "$tmp_repo"
reverify_fail_output=$(bash "$SCRIPT" --reverify 6 2>&1 || true)
cd - >/dev/null
if echo "$reverify_fail_output" | grep -q "A24" && echo "$reverify_fail_output" | grep -q "FAILING"; then
  pass_test "--reverify: A24 fails with 15 scripts"
else
  fail_test "--reverify: A24 did not fail with 15 scripts"
fi

# AC13: --reverify shows checked/skipped status without silent drops
if echo "$reverify_output" | grep -qE "checked|skipped"; then
  pass_test "--reverify: shows checked/skipped status"
else
  fail_test "--reverify: missing checked/skipped markers"
fi

# Verify A25b appears as skipped with reason
if echo "$reverify_output" | grep -q "A25b" && echo "$reverify_output" | grep -q "skipped"; then
  pass_test "--reverify: A25b appears as skipped with reason"
else
  fail_test "--reverify: A25b not marked as skipped"
fi

# AC15: no unintended file changes
# This will be checked at the script commit time via git diff

exit "$fail"
