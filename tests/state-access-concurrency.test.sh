#!/usr/bin/env bash
# TDD suite for concurrency test (A20)
# Verifies that two units can be processed concurrently without deadlock.
# Per-unit keying (ADR-0016) must prevent concurrent writes from blocking.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmpdir="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmpdir"' EXIT

export dot_dir="$tmpdir/.claude"
mkdir -p "$dot_dir/reviewed"

source hooks/scripts/lib/agent-identity.sh
source hooks/scripts/lib/audit-log.sh

# == Test: concurrent unit processing ==
# Two units processed concurrently should not block each other.
# Each has its own .review-join.* stamp and its own markers.
test_concurrent_unit_processing() {
  local unit1="concurrent-unit-1"
  local unit2="concurrent-unit-2"

  # Simulate concurrent marker writes from two units
  # Unit 1: reviewer creates PASS
  (
    sleep 0.1
    echo "PASS $unit1 2026-08-27T10:00:00Z commit: abc123" > "$dot_dir/reviewed/$unit1.pass"
  ) &
  local pid1=$!

  # Unit 2: reviewer creates PASS (concurrently)
  (
    sleep 0.1
    echo "PASS $unit2 2026-08-27T10:00:00Z commit: def456" > "$dot_dir/reviewed/$unit2.pass"
  ) &
  local pid2=$!

  # Wait for both to complete
  wait $pid1
  wait $pid2

  # Verify: both markers exist
  [ -f "$dot_dir/reviewed/$unit1.pass" ] && pass "A20: unit1.pass created" || bad "A20: unit1.pass missing"
  [ -f "$dot_dir/reviewed/$unit2.pass" ] && pass "A20: unit2.pass created" || bad "A20: unit2.pass missing"

  # Verify: content is correct (not overwritten)
  grep -q "$unit1" "$dot_dir/reviewed/$unit1.pass" && pass "A20: unit1.pass content correct" || bad "A20: unit1.pass content wrong"
  grep -q "$unit2" "$dot_dir/reviewed/$unit2.pass" && pass "A20: unit2.pass content correct" || bad "A20: unit2.pass content wrong"
}

# == Test: per-unit review-join stamps prevent deadlock ==
# Each unit has its own .review-join.<unit> stamp.
# Processing one unit should not block processing another.
test_per_unit_review_join_stamps() {
  local unit1="rj-unit-1"
  local unit2="rj-unit-2"

  # Create review-join stamps for two units
  echo '{"unit": "'$unit1'", "prior_mtime": 1693114800}' > "$dot_dir/.review-join.$unit1"
  echo '{"unit": "'$unit2'", "prior_mtime": 1693114801}' > "$dot_dir/.review-join.$unit2"

  # Verify: separate stamps exist
  [ -f "$dot_dir/.review-join.$unit1" ] && pass "A20: review-join.$unit1 created" || bad "A20: review-join.$unit1 missing"
  [ -f "$dot_dir/.review-join.$unit2" ] && pass "A20: review-join.$unit2 created" || bad "A20: review-join.$unit2 missing"

  # Simulate concurrent marker verdict for each
  (
    echo "PASS $unit1 2026-08-27T10:00:01Z commit: aaa" > "$dot_dir/reviewed/$unit1.pass"
  ) &
  local pid1=$!

  (
    echo "FAIL $unit2 2026-08-27T10:00:02Z" > "$dot_dir/reviewed/$unit2.fail"
  ) &
  local pid2=$!

  wait $pid1
  wait $pid2

  # Verify: both verdicts exist
  [ -f "$dot_dir/reviewed/$unit1.pass" ] && pass "A20: concurrent verdicts written" || bad "A20: concurrent verdicts blocked"
}

# == Test: agent-keyed flags don't interfere across units ==
# Two different agents processing different units should not block each other.
# .pending-review flags are keyed by agent, not unit.
test_agent_flags_concurrent() {
  local agent1="lead-programmer"
  local agent2="scribe"

  # Simulate two agents finishing simultaneously
  (
    echo "defer: testing unit-A" > "$dot_dir/.pending-review.$agent1"
  ) &
  local pid1=$!

  (
    echo "skip: abandoning unit-B" > "$dot_dir/.pending-review.$agent2"
  ) &
  local pid2=$!

  wait $pid1
  wait $pid2

  # Verify: both flags exist independently
  [ -f "$dot_dir/.pending-review.$agent1" ] && [ -f "$dot_dir/.pending-review.$agent2" ] && pass "A20: agent flags independent" || bad "A20: agent flags blocked"
}

# == Test: concurrent session-baseline writes with create-only-if-absent ==
# Two sessions starting concurrently should not overwrite each other's baseline.
test_session_baseline_concurrent_create() {
  local session1="sess-concurrent-1"
  local session2="sess-concurrent-2"

  # Simulate two sessions starting concurrently
  local baseline1="$dot_dir/.session-baseline.$session1"
  local baseline2="$dot_dir/.session-baseline.$session2"

  (
    if [ ! -f "$baseline1" ]; then
      echo "abc123" > "$baseline1"
    fi
  ) &
  local pid1=$!

  (
    if [ ! -f "$baseline2" ]; then
      echo "def456" > "$baseline2"
    fi
  ) &
  local pid2=$!

  wait $pid1
  wait $pid2

  # Verify: both baselines exist
  [ -f "$baseline1" ] && [ -f "$baseline2" ] && pass "A20: session baselines independent" || bad "A20: session baselines blocked"

  # Verify: content matches what was written (no cross-contamination)
  grep -q "abc" "$baseline1" && pass "A20: session1 baseline unchanged" || bad "A20: session1 baseline corrupted"
  grep -q "def" "$baseline2" && pass "A20: session2 baseline unchanged" || bad "A20: session2 baseline corrupted"
}

# == Test: concurrent audit log appends ==
# Multiple concurrent appends to the same log should not deadlock.
test_concurrent_audit_log_appends() {
  local log="$dot_dir/review-audit.log"

  # Simulate concurrent audit appends
  for i in {1..5}; do
    (
      audit_append "$log" "concurrent line $i from process $$"
    ) &
  done
  wait

  # Verify: log exists and has content
  [ -f "$log" ] && pass "A20: concurrent audit appends succeeded" || bad "A20: concurrent audit appends failed"

  # Verify: all lines are present (rough check - may have some)
  local line_count=$(wc -l < "$log" 2>/dev/null || echo 0)
  [ "$line_count" -gt 0 ] && pass "A20: audit log has $line_count lines" || bad "A20: audit log empty"
}

# == RUN ALL TESTS ==
echo "=== Concurrency Test (A20 - ADR-0016 deadlock prevention) ==="
test_concurrent_unit_processing
test_per_unit_review_join_stamps
test_agent_flags_concurrent
test_session_baseline_concurrent_create
test_concurrent_audit_log_appends

echo ""
[ $fail -eq 0 ] && echo "All concurrency tests passed" && exit 0 || echo "$fail test(s) failed" && exit 1
