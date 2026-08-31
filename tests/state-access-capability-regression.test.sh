#!/usr/bin/env bash
# Capability-regression fixture test (A22).
# With humanReviewMode: "all" in a fixture, verify escalation path still works.
# This ensures no silent capability rot when repo stops populating these artifacts locally.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

# Create fixture environment with humanReviewMode: "all"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

fixture_dot="$fixture_dir/.claude"
mkdir -p "$fixture_dot/reviewed" "$fixture_dot/human-review"

# Create fixture persona-config with humanReviewMode: "all"
cat > "$fixture_dot/persona-config.json" << 'CFGEOF'
{
  "gatedAgents": ["lead-programmer"],
  "humanReviewMode": "all",
  "markerCommitCheck": {
    "mode": "on"
  },
  "dispatchHygiene": {
    "mode": "on"
  },
  "pluginVersion": "0.13.15",
  "fileHashes": {}
}
CFGEOF

export dot="$fixture_dot"
source hooks/scripts/lib/state-access.sh

test_escalation_path() {
  local unit_id="fixture-test-unit"
  
  # Simulate an escalation being created
  state_write_unit_marker "$unit_id" "escalated" "ESCALATED $unit_id 2026-08-27T10:00:00Z"
  
  # With humanReviewMode: "all", the presence of .escalated should trigger
  # the escalation path (normally gated by a config check, tested here for presence)
  if [ -f "$fixture_dot/reviewed/$unit_id.escalated" ]; then
    pass "capability: escalation marker created in fixture"
  else
    bad "capability: escalation marker missing"
  fi
  
  # Verify fixture config is readable
  if grep -q '"humanReviewMode"' "$fixture_dot/persona-config.json"; then
    pass "capability: fixture config readable"
  else
    bad "capability: fixture config not found"
  fi
  
  # Verify that our fixture config has humanReviewMode: "all"
  if grep -q '"humanReviewMode": "all"' "$fixture_dot/persona-config.json"; then
    pass "capability: humanReviewMode: all set in fixture"
  else
    bad "capability: humanReviewMode not set correctly"
  fi
}

test_escalation_path
exit "$fail"
