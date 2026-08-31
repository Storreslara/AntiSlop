#!/usr/bin/env bash
# Concurrency test (A20).
# Verifies per-unit keying: two units dispatched concurrently do not block each other.
# This exercises the ADR-0016 deadlock fix.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export dot="$tmpdir/.claude"
mkdir -p "$dot/reviewed" "$dot/human-review"

source hooks/scripts/lib/state-access.sh

test_concurrency_no_deadlock() {
  local unit1="unit-001"
  local unit2="unit-002"
  
  # Simulate two units being processed concurrently
  # Each writes its own .review-join stamp
  state_write_review_join "$unit1" "unit=$unit1"
  state_write_review_join "$unit2" "unit=$unit2"
  
  # Each writes its own markers
  state_write_unit_marker "$unit1" "pass" "PASS $unit1"
  state_write_unit_marker "$unit2" "pass" "PASS $unit2"
  
  # Both should exist independently (no global lock/watermark blocking the second)
  if [ -f "$dot/.review-join.$unit1" ] && [ -f "$dot/.review-join.$unit2" ]; then
    pass "concurrency: both units have review-join stamps"
  else
    bad "concurrency: review-join stamps not independent"
  fi
  
  if [ -f "$dot/reviewed/$unit1.pass" ] && [ -f "$dot/reviewed/$unit2.pass" ]; then
    pass "concurrency: both units have pass markers"
  else
    bad "concurrency: pass markers not independent"
  fi
  
  # Key property: clearing one unit does not affect the other
  # (in real stop-gate, this is per-unit cleanup)
  state_delete_review_join "$unit1"
  
  if [ ! -f "$dot/.review-join.$unit1" ] && [ -f "$dot/.review-join.$unit2" ]; then
    pass "concurrency: per-unit cleanup works"
  else
    bad "concurrency: cleanup affected wrong unit"
  fi
}

test_concurrency_no_deadlock
exit "$fail"
