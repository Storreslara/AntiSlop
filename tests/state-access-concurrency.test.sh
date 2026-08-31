#!/usr/bin/env bash
# Concurrency test (A20).
# Genuinely dispatches two units concurrently through the real hook scripts'
# per-unit stamp evaluation, exercising the ADR-0016 deadlock fix: a single
# global watermark used to block ALL review-join stamps on the LEAST-ready
# unit; per-unit stamps must let a satisfied unit proceed regardless of a
# sibling that is still in flight.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' > "$dir/.claude/persona-config.json"
  echo "$dir"
}

reviewer_payload() {
  # $1 = unit id -> a PreToolUse(Agent) dispatch targeting the reviewer
  jq -n --arg p "Unit: $1"$'\n\nReview this commit.' \
    '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:"orchestrator",tool_input:{subagent_type:"reviewer",prompt:$p}}'
}

dir="$(make_project concurrent)"
unit1="unit-001"
unit2="unit-002"

# (a) genuinely PARALLEL dispatch: two real reviewer-route-gate.sh invocations,
# one per unit, launched as background jobs against the SAME project dir -
# proves per-unit keying doesn't corrupt or collide under concurrent writes.
rc1=0; rc2=0
(printf '%s' "$(reviewer_payload "$unit1")" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/reviewer-route-gate.sh) &
pid1=$!
(printf '%s' "$(reviewer_payload "$unit2")" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/reviewer-route-gate.sh) &
pid2=$!
wait "$pid1" || rc1=$?
wait "$pid2" || rc2=$?

if [ "$rc1" = 0 ] && [ "$rc2" = 0 ] \
   && [ -f "$dir/.claude/.review-join.$unit1" ] && [ -f "$dir/.claude/.review-join.$unit2" ] \
   && grep -q "unit=$unit1" "$dir/.claude/.review-join.$unit1" \
   && grep -q "unit=$unit2" "$dir/.claude/.review-join.$unit2"; then
  pass "concurrency: two real concurrent reviewer-route-gate.sh dispatches each wrote their own stamp intact"
else
  bad "concurrency: concurrent dispatch corrupted or lost a stamp (rc1=$rc1 rc2=$rc2)"
fi

# (b) unit1 finishes (a fresh PASS marker lands); unit2 is still in flight
# (no marker yet). The real ADR-0016 regression: a global watermark would
# block THIS reviewer SubagentStop entirely because not every dispatched
# unit is ready. Per-unit stamps must let unit1 proceed without waiting on
# unit2 - no deadlock.
printf 'PASS %s 2026-08-27T10:00:00Z commit: abc1234 criteria: true\n' "$unit1" \
  > "$dir/.claude/reviewed/${unit1}.pass"

reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?

if [ "$rc" = 0 ] \
   && [ ! -f "$dir/.claude/.review-join.$unit1" ] \
   && [ -f "$dir/.claude/.review-join.$unit2" ] \
   && grep -q "join-consumed=$unit1" "$dir/.claude/review-audit.log"; then
  pass "concurrency: unit1's satisfied stamp is consumed and the reviewer proceeds (exit 0) without waiting on unit2 - no ADR-0016 deadlock"
else
  bad "concurrency: reviewer SubagentStop deadlocked or mishandled the in-flight sibling unit (rc=$rc)"
fi

exit "$fail"
