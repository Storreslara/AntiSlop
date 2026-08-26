#!/usr/bin/env bash
# AC-A1: PostToolUse must return fast even when the edited file matches a
# slow watched suite in tests/watch-map.json (Unit A made the rerun
# asynchronous - "run and report" became "enqueue and return"). Invokes the
# real hooks/scripts/microworld-rerun.sh with canned stdin against this
# repo's OWN existing, committed watched files - no fixture, since the
# baselines below (211.96s / 158.89s / 115.85s, the pre-fix synchronous
# runtime of the very suites these paths are watched by, see
# tests/watch-map.json) are only meaningful against the real watch-map.
# Modifies no git-tracked file (microworld-audit.log and
# .microworld-results-reported are both gitignored).
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/lib/timing-harness.sh

export CLAUDE_PROJECT_DIR="$(pwd)"
fail=0
p50_budget=2.0
p99_budget=5.0
iterations=5

check() {
  # $1 = label, $2 = file_path
  local out rc=0
  out="$(assert_budget "$1" "$p50_budget" "$p99_budget" "$iterations" \
    "$(jq -n --arg fp "$2" '{tool_input: {file_path: $fp}}')" \
    -- bash hooks/scripts/microworld-rerun.sh)" || rc=$?
  echo "$out"
  if [ "$rc" = 0 ]; then
    echo "OK   AC-A1: $1"
  else
    echo "FAIL AC-A1: $1 exceeded its latency budget"
    fail=1
  fi
}

check "editing tests/human-decision-gate.test.sh" "tests/human-decision-gate.test.sh"
check "editing hooks/scripts/human-decision-gate.sh" "hooks/scripts/human-decision-gate.sh"
check "editing hooks/scripts/reviewed-path-gate.sh" "hooks/scripts/reviewed-path-gate.sh"

exit "$fail"
