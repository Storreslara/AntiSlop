#!/usr/bin/env bash
# Capability-regression fixture test (A22).
# With humanReviewMode: "all" in a fixture, verify the escalation path still
# works end to end by driving the REAL hooks (not writing+grepping the
# test's own fixture text, which would notice nothing if the capability
# rotted away entirely).
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

fixture_dot="$fixture_dir/.claude"
unit_id="fixture-test-unit"
escalated_ts="2026-08-27T10:00:00Z"
mkdir -p "$fixture_dot/reviewed" "$fixture_dot/human-review/${unit_id}"

cat > "$fixture_dot/persona-config.json" << 'CFGEOF'
{
  "gatedAgents": ["lead-programmer"],
  "humanReviewMode": "all",
  "markerCommitCheck": { "mode": "on" },
  "dispatchHygiene": { "mode": "on" },
  "testAndLintCommand": "true",
  "pluginVersion": "0.13.15",
  "fileHashes": {}
}
CFGEOF

printf 'ESCALATE-TO-HUMAN %s %s trigger: capability-regression-test microworld: none\n' "$unit_id" "$escalated_ts" \
  > "$fixture_dot/reviewed/${unit_id}.escalated"
printf 'lead-programmer flag\n' > "$fixture_dot/.pending-review.lp-1"

test_escalation_path() {
  # (1) real stop-gate.sh reviewer SubagentStop: an .escalated marker must
  # log verdict=escalated AND keep pending-review flags standing (unlike a
  # clean SubagentStop, which would clear them).
  local reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'
  local rc=0
  printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$fixture_dir" bash hooks/scripts/stop-gate.sh || rc=$?
  if [ "$rc" = 0 ] && [ -f "$fixture_dot/.pending-review.lp-1" ] \
     && grep -q 'verdict=escalated flags-kept' "$fixture_dot/review-audit.log"; then
    pass "capability: real stop-gate.sh logs the escalation and keeps flags standing"
  else
    bad "capability: stop-gate.sh did not produce the escalated verdict/flags-kept artifacts (rc=$rc)"
  fi
}

test_escalation_path
exit "$fail"
