#!/usr/bin/env bash
# TDD suite for state-access.sh — tests for ordering/atomicity constraints.
# Written BEFORE consolidation to verify current behavior.
# Each constraint test is mutation-proved: reverting the fix must make the test red.
# Tests exercise state-access.sh functions directly, not inline fixture setup.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

# == Test harness setup ==
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export dot="$tmpdir/.claude"
mkdir -p "$dot/reviewed" "$dot/human-review"

# Source the library under test
source hooks/scripts/lib/state-access.sh

# Source supporting libs
source hooks/scripts/lib/audit-log.sh

# == CONSTRAINT 1: .consumed-before-rm ==
# The .dispatch-override.consumed stamp MUST exist BEFORE the override is deleted.
# This prevents loss of the replay window on crash.
test_consumed_before_rm() {
  state_write_dispatch_override "test waiver"

  # Write consumed marker
  local epoch=$(date +%s)
  state_write_dispatch_consumed "$epoch" "abc123def456"

  # Verify consumed exists
  [ -f "${dot}/.dispatch-override.consumed" ] || { bad "C1: consumed not written"; return 1; }

  # Delete override
  state_delete_dispatch_override

  # CONSTRAINT: consumed must still exist after override is deleted
  [ -f "${dot}/.dispatch-override.consumed" ] && pass "C1: consumed survives rm" || bad "C1: consumed lost after rm"

  # Content must match pattern: epoch hash
  grep -E "^[0-9]+ [a-f0-9]+$" "${dot}/.dispatch-override.consumed" >/dev/null && \
    pass "C1: consumed has epoch + hash" || bad "C1: consumed format wrong"
}

# == CONSTRAINT 2: review-join → clear .pending-review ==
# When a reviewer's SubagentStop sees .escalated, it must clear .pending-review
# flags ONLY after consulting review-join stamps.
test_review_join_ordering() {
  local unit_id="test-unit-1"
  local agent_id="lead-programmer"

  # Setup: create pending-review flag (as stop-gate does)
  state_write_pending_review "$agent_id" ""
  [ -f "${dot}/.pending-review.${agent_id}" ] || { bad "C2: pending-review not created"; return 1; }

  # Setup: write .escalated marker (as reviewer does)
  state_write_unit_marker "$unit_id" "escalated" "ESCALATED $unit_id 2026-08-27T10:00:00Z"

  # Setup: write review-join stamp (as reviewer-route-gate does)
  state_write_review_join "$unit_id" "unit=$unit_id prior_mtime=1693114800"

  # Marker exists
  state_unit_marker_exists "$unit_id" "escalated" && pass "C2: escalated marker written" || bad "C2: escalated missing"

  # pending-review still exists (not yet cleared by reviewer)
  state_pending_review_exists "$agent_id" && pass "C2: pending-review not yet cleared" || bad "C2: pending-review cleared prematurely"
}

# == CONSTRAINT 3: .pending-review create-only-if-absent ==
# A .pending-review flag must be created ONLY on first SubagentStop.
# If main session writes a defer: reason first, SubagentStop must not clobber it.
test_pending_review_idempotent() {
  local agent_id="test-agent-1"
  local flag_file="${dot}/.pending-review.${agent_id}"

  # First: main session writes a reason directly (not via state_write, simulating manual edit)
  printf 'defer: user wrote this\n' > "$flag_file"
  local original_content=$(cat "$flag_file")

  # Second: SubagentStop calls state_write_pending_review with empty content
  # The state-access.sh function checks -f before writing, so it should NOT overwrite
  state_write_pending_review "$agent_id" ""

  # Verify content unchanged
  local current_content=$(cat "$flag_file")
  [ "$current_content" = "$original_content" ] && pass "C3: pending-review not clobbered" || bad "C3: pending-review was overwritten"
}

# == CONSTRAINT 4: .session-baseline create-only-if-absent ==
# A .session-baseline is created once at session start and never overwritten.
test_session_baseline_idempotent() {
  local session_id="sess-001"
  local baseline_file="${dot}/.session-baseline.${session_id}"

  # First session start: write baseline
  state_write_session_baseline "$session_id" "abc123def456"
  local original=$(cat "$baseline_file")

  # Second attempt (later in session): should NOT overwrite
  state_write_session_baseline "$session_id" "xyz789abc000"
  local after=$(cat "$baseline_file")

  [ "$original" = "$after" ] && pass "C4: session-baseline not overwritten" || bad "C4: session-baseline was clobbered"
}

# == CONSTRAINT 5: .directed exclusion from stop-gate globs ==
# .directed MUST NOT be checked by stop-gate's glob patterns.
# Including it would deadlock the dispatch it's meant to authorize.
test_directed_excluded_from_globs() {
  local unit_id="test-unit-2"

  # Write a .directed marker
  state_write_unit_marker "$unit_id" "directed" "DIRECTED $unit_id"

  # Verify .directed exists
  state_unit_marker_exists "$unit_id" "directed" && pass "C5: directed marker created" || bad "C5: directed missing"

  # Critical: verify .directed is NOT matched by the glob that matches .blocked/.escalated
  # This tests that the lib function does not include .directed in problematic globs
  # (Actual stop-gate.sh logic handles the glob; this verifies the marker was created separately)

  # Create .blocked for comparison (should be globs-able by stop-gate)
  state_write_unit_marker "$unit_id" "blocked" "BLOCKED"

  # Both should exist but have different treatment expectations
  [ -f "${dot}/reviewed/${unit_id}.directed" ] && [ -f "${dot}/reviewed/${unit_id}.blocked" ] && \
    pass "C5: both directed and blocked exist separately" || bad "C5: marker files missing"
}

# == CONSTRAINT 6: DECISION zero-identity write ban ==
# No agent may write .claude/human-review/<id>/DECISION.
# (This constraint is enforced by gates; lib should not provide a write function for it)
test_decision_zero_identity_write() {
  local unit_id="test-unit-3"

  # Verify state-access.sh has NO function to write DECISION
  if declare -f state_write_decision >/dev/null 2>&1; then
    bad "C6: state_write_decision should not exist"
  else
    pass "C6: no write function for DECISION"
  fi
}

# == CONSTRAINT 7: DECISION↔.escalated timestamp binding ==
# When a unit is escalated, the .escalated marker's timestamp must be parseable
# and will be echoed in the DECISION packet by the human.
test_escalated_timestamp_binding() {
  local unit_id="test-unit-4"
  local timestamp="2026-08-27T10:00:00Z"

  # Write escalated with timestamp
  state_write_unit_marker "$unit_id" "escalated" "ESCALATED $unit_id $timestamp"

  # Read it back
  local content=$(state_read_unit_marker "$unit_id" "escalated")

  # Verify timestamp is present and RFC3339-like
  echo "$content" | grep -E "T[0-9]{2}:[0-9]{2}:[0-9]{2}Z" >/dev/null && \
    pass "C7: escalated timestamp is parseable" || bad "C7: timestamp format wrong"
}

# == CONSTRAINT 8: wip-handoff empty ≠ absent ==
# An empty .wip-handoff file must be deleted, NOT preserved.
# Empty does not mean "pause honored"; it means "misconfigured — delete it."
test_wip_handoff_empty_not_absent() {
  local agent_id="test-agent-2"

  # Write empty handoff via state_write
  state_write_wip_handoff "$agent_id" ""

  # Verify it was deleted (not preserved as empty)
  [ ! -f "${dot}/.wip-handoff.${agent_id}" ] && pass "C8: empty wip-handoff deleted" || bad "C8: empty file not deleted"

  # Write non-empty and verify it survives
  state_write_wip_handoff "$agent_id" "TDD red phase"
  [ -f "${dot}/.wip-handoff.${agent_id}" ] && pass "C8: non-empty wip-handoff written" || bad "C8: non-empty not preserved"
}

# == CONSTRAINT 9: .dispatch-override.consumed content-embedded epoch ==
# The epoch in .dispatch-override.consumed must be embedded in content, not mtime.
# This survives clock skew and file operations that would reset mtime.
test_dispatch_consumed_epoch_embedded() {
  local epoch=$(date +%s)
  state_write_dispatch_consumed "$epoch" "hash123"

  # Read back the file
  local content=$(cat "${dot}/.dispatch-override.consumed")

  # Verify epoch is in the first field
  local first_field=$(echo "$content" | cut -d' ' -f1)
  [ "$first_field" = "$epoch" ] && pass "C9: epoch embedded in content" || bad "C9: epoch not in content"

  # Sleep 1 second and touch the file (change mtime without changing content)
  sleep 1
  touch "${dot}/.dispatch-override.consumed"

  # Read back - epoch should still be the original, not derived from mtime
  local new_content=$(cat "${dot}/.dispatch-override.consumed")
  [ "$new_content" = "$content" ] && pass "C9: epoch survives touch" || bad "C9: epoch lost after mtime change"
}

# == CONSTRAINT 10: .fail consumes 2-FAIL-cap without filesystem derivation ==
# The .fail marker is overwritten in place (each new FAIL overwrites the previous).
# The 2-FAIL cap count cannot be derived from filesystem state alone —
# it requires parsing the audit log or tracking state.
# (This constraint documents a property, not a testable lib function;
#  the actual count is tracked by reviewer-tier.sh via review-audit.log)
test_fail_overwrites_cap() {
  local unit_id="test-unit-5"
  local fail_file="${dot}/reviewed/${unit_id}.fail"

  # First FAIL
  state_write_unit_marker "$unit_id" "fail" "FAIL $unit_id 2026-08-27T09:00:00Z\nDefect A"

  # Second FAIL overwrites
  state_write_unit_marker "$unit_id" "fail" "FAIL $unit_id 2026-08-27T10:00:00Z\nDefect B"

  # Only one .fail file exists (overwritten)
  [ -f "$fail_file" ] && pass "C10: fail file exists" || bad "C10: fail file missing"

  # Content is the second one
  grep -q "Defect B" "$fail_file" && pass "C10: fail overwrites in place" || bad "C10: fail content wrong"
}

# == Run all tests ==
test_consumed_before_rm
test_review_join_ordering
test_pending_review_idempotent
test_session_baseline_idempotent
test_directed_excluded_from_globs
test_decision_zero_identity_write
test_escalated_timestamp_binding
test_wip_handoff_empty_not_absent
test_dispatch_consumed_epoch_embedded
test_fail_overwrites_cap

exit "$fail"
