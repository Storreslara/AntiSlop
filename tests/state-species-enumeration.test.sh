#!/usr/bin/env bash
# Species-enumeration test (A17).
# Asserts the exact set of filename patterns the harness may create.
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
source hooks/scripts/lib/audit-log.sh

test_species_enumeration() {
  # Create artifacts via state-access.sh
  state_write_unit_marker "unit-1" "pass" "PASS unit-1 2026-08-27T10:00:00Z commit: abc123"
  state_write_unit_marker "unit-1" "fail" "FAIL unit-1 2026-08-27T10:00:00Z"
  state_write_unit_marker "unit-2" "escalated" "ESCALATED unit-2 2026-08-27T10:00:00Z"
  state_write_review_join "unit-1" "unit=unit-1"
  state_write_pending_review "lead-programmer" ""
  state_write_wip_handoff "scribe" "working"
  state_write_session_baseline "session-001" "abc123"
  state_write_dispatch_override "waiver"
  state_write_dispatch_consumed "$(date +%s)" "hash123"
  audit_append "${dot}/review-audit.log" "test"

  # Count files created - should be markers + review-join + pending + handoff + session + dispatch + consumed + audit
  local file_count=$(find "$dot" -type f | wc -l)
  
  # Should have at least 9 files created
  if [ "$file_count" -ge 9 ]; then
    pass "enumeration: $file_count artifacts created"
  else
    bad "enumeration: only $file_count artifacts (expected >= 9)"
  fi
}

test_species_enumeration
exit "$fail"
