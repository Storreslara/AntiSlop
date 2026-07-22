#!/usr/bin/env bash
# Fixture-driven test for the reviewer-SubagentStop branch of
# hooks/scripts/stop-gate.sh keeping pending-review flags standing while a
# .claude/reviewed/*.blocked marker is active, plus assertions that
# reviewer-route-gate.sh and task-gate.sh need NO change. Canned hook-input
# JSON piped to each script - no real claude/agent dependency.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  # $1 = case name -> echoes a fresh project dir seeded with persona-config.json
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
    > "$dir/.claude/persona-config.json"
  echo "$dir"
}

reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'

# (a) reviewer SubagentStop WITH an active .blocked marker -> flag kept + audit
dir="$(make_project blocked)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
printf 'BLOCKED task-a 2026-07-22T00:00:00Z missing: constraint X\n' \
  > "$dir/.claude/reviewed/task-a.blocked"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
if [ "$rc" = 0 ] && [ -f "$dir/.claude/.pending-review.lp-1" ] \
   && grep -q 'verdict=blocked flags-kept' "$dir/.claude/review-audit.log"; then
  echo "OK   (a) active .blocked marker keeps pending-review flag standing + audit logged"
else
  echo "FAIL (a) flag removed or 'verdict=blocked flags-kept' audit line missing (rc=$rc)"
  fail=1
fi

# (b) reviewer SubagentStop WITHOUT any .blocked marker -> flag removed (existing behavior)
dir="$(make_project cleared)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-1" ] \
   && grep -q 'cleared-by=reviewer' "$dir/.claude/review-audit.log"; then
  echo "OK   (b) no .blocked marker -> flag cleared (existing behavior preserved)"
else
  echo "FAIL (b) flag not cleared or 'cleared-by=reviewer' audit line missing (rc=$rc)"
  fail=1
fi

# (c) with a flag standing, dispatching the next gated unit is still blocked (exit 2)
dir="$(make_project route)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' '{"agent_type":"orchestrator","tool_input":{"subagent_type":"lead-programmer"}}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/reviewer-route-gate.sh || rc=$?
if [ "$rc" = 2 ]; then
  echo "OK   (c) reviewer-route-gate.sh still blocks next gated dispatch while a flag stands"
else
  echo "FAIL (c) expected exit 2 from reviewer-route-gate.sh, got rc=$rc"
  fail=1
fi

# (d) a .blocked marker does not satisfy task-gate.sh's marker_valid()
dir="$(make_project taskgate)"
printf 'BLOCKED blk-1 2026-07-22T00:00:00Z missing: constraint Y\n' \
  > "$dir/.claude/reviewed/blk-1.blocked"
rc=0
printf '%s' '{"task":{"subject":"impl: blk-1 do the thing","id":"blk-1"}}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/task-gate.sh || rc=$?
audit="$dir/.claude/review-audit.log"
if [ ! -f "$audit" ] || ! grep -q 'task=blk-1 marker-accepted' "$audit"; then
  echo "OK   (d) .blocked marker is not accepted as a valid PASS by task-gate.sh"
else
  echo "FAIL (d) task-gate.sh accepted a .blocked marker as a valid PASS"
  fail=1
fi

exit "$fail"
