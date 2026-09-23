#!/bin/bash
# TDD test for scripts/rollout-preflight.sh (Step 1 of
# docs/plans/2026-08-25-streamlining-rollout-sequencing.md).
#
# Mutation record (per wave, which single line deletion in scripts/rollout-preflight.sh
# makes that wave's assertion fail):
# W0: line checking gh run list (around "gh run list --branch master...")
# W1: line defining WAVE_OWNER_SPECS[W1] (spec 3's owner mapping)
# W2: line defining EDGES[E2] (the W1 -> W2 edge)
# W3: line defining EDGES[E3] (the W1,W2 -> W3 edge)
# W4: line defining EDGES[E4] (the W1 -> W4 edge)
# W5: line defining EDGES[E5] (the W3,W4 -> W5 edge)
# W6: line defining EDGES[E6] (the W5 -> W6 edge)
# W7: line defining EDGES[E7] (carries the "escape hatch" phrase)
# W8: line defining EDGES[E1] (the W0 -> W8 edge)
# W9: line defining EDGES[E7] (the W7 -> W9 edge)
# W10: line mentioning "blocked by design" and "A23" and "OQ2"
# W1 (no-reverify-support): line REVERIFY_IMPLEMENTED[6]="reverify_spec6"
#   (deleting it makes reverify_supported() report unsupported for every
#   spec including 6, which the W9-unchanged assertion below also catches)
# W9 (unchanged wording): same line as above, from the other direction --
#   a hardcoded no-reverify-support message unconditional on the spec number
#   would trip this assertion for spec 6 even though W1's assertion above
#   would still pass, so the two together close the vacuous-pass gap
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

# AC2: W0 reproduces the live `validate` workflow conclusion rather than
# asserting a fixed value -- CI's actual conclusion moves over time (it was
# `failure` when this spec was written, and may be `success` later).
live_conclusion=$(gh run list --branch master --workflow validate --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "unknown")
w0_output=$(bash "$SCRIPT" W0 2>&1 || true)
if echo "$w0_output" | grep -q "$live_conclusion"; then
  pass_test "W0: reports live CI conclusion ($live_conclusion)"
else
  fail_test "W0: did not report live CI conclusion ($live_conclusion)"
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

# W1: lists spec 3 (no predecessors; owner is data-driven)
w1_output=$(bash "$SCRIPT" W1 2>&1 || true)
if echo "$w1_output" | grep -q "spec 3"; then
  pass_test "W1: names spec 3 as owner"
else
  fail_test "W1: did not name spec 3 as owner"
fi

# NEW: W1 is owned by spec 3, which has no --reverify implementation. The
# gate must say so distinctly and must never print unmet-on-staleness for a
# spec it cannot actually re-verify.
if echo "$w1_output" | grep -q "no-reverify-support" && echo "$w1_output" | grep -q "spec 3" && ! echo "$w1_output" | grep -q "unmet-on-staleness"; then
  pass_test "W1: reports no-reverify-support for spec 3, not unmet-on-staleness"
else
  fail_test "W1: did not report no-reverify-support distinctly for spec 3"
fi

# W2: lists W1 as unmet predecessor
w2_output=$(bash "$SCRIPT" W2 2>&1 || true)
if echo "$w2_output" | grep -q "W1"; then
  pass_test "W2: lists W1 as predecessor"
else
  fail_test "W2: did not list W1 as predecessor"
fi

# W3: lists W1 and W2 as unmet predecessors
w3_output=$(bash "$SCRIPT" W3 2>&1 || true)
if echo "$w3_output" | grep -q "W1" && echo "$w3_output" | grep -q "W2"; then
  pass_test "W3: lists W1, W2 as predecessors"
else
  fail_test "W3: did not list W1, W2 as predecessors"
fi

# W4: lists W1 as unmet predecessor
w4_output=$(bash "$SCRIPT" W4 2>&1 || true)
if echo "$w4_output" | grep -q "W1"; then
  pass_test "W4: lists W1 as predecessor"
else
  fail_test "W4: did not list W1 as predecessor"
fi

# W5: lists W3 and W4 as unmet predecessors
w5_output=$(bash "$SCRIPT" W5 2>&1 || true)
if echo "$w5_output" | grep -q "W3" && echo "$w5_output" | grep -q "W4"; then
  pass_test "W5: lists W3, W4 as predecessors"
else
  fail_test "W5: did not list W3, W4 as predecessors"
fi

# W6: lists W5 as unmet predecessor
w6_output=$(bash "$SCRIPT" W6 2>&1 || true)
if echo "$w6_output" | grep -q "W5"; then
  pass_test "W6: lists W5 as predecessor"
else
  fail_test "W6: did not list W5 as predecessor"
fi

# W8: lists W0 and W2 as unmet predecessors
w8_output=$(bash "$SCRIPT" W8 2>&1 || true)
if echo "$w8_output" | grep -q "W0" && echo "$w8_output" | grep -q "W2"; then
  pass_test "W8: lists W0, W2 as predecessors"
else
  fail_test "W8: did not list W0, W2 as predecessors"
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

# --owner defect-5 regression: previously-false-negative/mislabeled paths
owner4_output=$(bash "$SCRIPT" --owner bin/cli.js 2>&1)
owner4_exit=$?
if [ "$owner4_exit" -eq 0 ] && echo "$owner4_output" | grep -q "spec 3"; then
  pass_test "--owner bin/cli.js: lists spec 3, exit 0"
else
  fail_test "--owner bin/cli.js: false negative or non-zero exit"
fi

owner5_output=$(bash "$SCRIPT" --owner .claude/persona-config.json 2>&1)
owner5_exit=$?
if [ "$owner5_exit" -eq 0 ] && echo "$owner5_output" | grep -q "spec 1" && echo "$owner5_output" | grep -q "spec 2" && echo "$owner5_output" | grep -q "spec 3" && echo "$owner5_output" | grep -q "spec 6"; then
  pass_test "--owner .claude/persona-config.json: lists specs 1,2,3,6, exit 0"
else
  fail_test "--owner .claude/persona-config.json: missing claimants or non-zero exit"
fi

owner6_output=$(bash "$SCRIPT" --owner hooks/scripts/protected-paths.sh 2>&1)
owner6_exit=$?
if [ "$owner6_exit" -eq 0 ] && echo "$owner6_output" | grep -q "spec 1" && echo "$owner6_output" | grep -q "spec 2" && echo "$owner6_output" | grep -q "spec 3"; then
  pass_test "--owner hooks/scripts/protected-paths.sh: lists specs 1,2,3, exit 0"
else
  fail_test "--owner hooks/scripts/protected-paths.sh: missing claimants or non-zero exit"
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

# AC10: wiring in validate.sh -- the actual criterion command, exactly 1 hit
grep_count=$(grep -c 'rollout-preflight' tests/validate.sh || true)
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
# Test 1: A24 is a documented skip (the Phase 2 disablement-flip unit its
# diff-filter=D criterion is scoped to doesn't exist yet), not a live script
# count -- see rollout-a24-remechanize-1's investigation note in
# reverify_spec6().
reverify_output=$(bash "$SCRIPT" --reverify 6 2>&1 || true)
if echo "$reverify_output" | grep -q "skipped: A24" && echo "$reverify_output" | grep -q "flip unit"; then
  pass_test "--reverify: A24 reports skipped with flip-unit reason"
else
  fail_test "--reverify: A24 did not report skipped with the flip-unit reason"
fi

# Test 2: adding a hooks/scripts/*.sh file must not change A24's report --
# this is the treadmill-ending property (no count left to bump).
tmp_repo=$(mktemp -d)
trap "rm -rf $tmp_repo" EXIT
cp -r . "$tmp_repo"
touch "$tmp_repo/hooks/scripts/extra-test.sh"
cd "$tmp_repo"
reverify_extra_output=$(bash "$SCRIPT" --reverify 6 2>&1 || true)
cd - >/dev/null
if [ "$reverify_output" = "$reverify_extra_output" ]; then
  pass_test "--reverify: A24 output unchanged after adding a hooks/scripts/*.sh file"
else
  fail_test "--reverify: A24 output changed after adding a hooks/scripts/*.sh file (treadmill not fixed)"
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

# AC14: the staleness gate is wired to sibling amendments. Reuse tmp_repo (its
# spec 6 doc has the same content/mtime as this tree at copy time) so touching
# it here never mutates a real project file. Order matters: --reverify 6 was
# just run above, so spec 6's reverify stamp is fresh and W9 starts "green"
# (no staleness line) before the touch flips it to unmet-on-staleness.
sibling_in_tmp="$tmp_repo/docs/plans/2026-08-25-ci-shaped-review-architecture-d.md"
w9_before_touch=$(cd "$tmp_repo" && bash "$SCRIPT" W9 2>&1 || true)
sleep 1
touch "$sibling_in_tmp"
w9_after_touch=$(cd "$tmp_repo" && bash "$SCRIPT" W9 2>&1 || true)
if [ "$w9_before_touch" != "$w9_after_touch" ] && echo "$w9_after_touch" | grep -q "unmet-on-staleness"; then
  pass_test "AC14: W9 report flips to unmet-on-staleness after sibling spec amendment"
else
  fail_test "AC14: W9 report did not flip on sibling spec amendment"
fi

# NEW: spec 6 has a real --reverify implementation, so its staleness wording
# must stay exactly unmet-on-staleness -- it must never be downgraded to the
# new no-reverify-support phrase.
if echo "$w9_after_touch" | grep -q "unmet-on-staleness -- spec 6" && ! echo "$w9_after_touch" | grep -q "no-reverify-support"; then
  pass_test "W9: spec 6 staleness wording unchanged (no-reverify-support not applied)"
else
  fail_test "W9: spec 6 staleness wording changed unexpectedly"
fi

# AC15: no unintended file changes
# This will be checked at the script commit time via git diff

exit "$fail"
