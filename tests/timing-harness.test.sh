#!/usr/bin/env bash
# Regression test for tests/lib/timing-harness.sh's assert_budget: the `--`
# argv separator was previously double-handled (assert_budget's own `shift 5`
# left it in `$@`, then a second `--` was prepended before calling
# measure_latencies), so the harness ran a program literally named `--` and
# never the real command, making every budget check unfalsifiable (see
# .claude/reviewed/spec2-unitA.fail). Proves the harness discriminates.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib/timing-harness.sh
fail=0

if assert_budget x 0.5 0.5 3 '{}' -- sleep 1 >/dev/null 2>&1; then
  echo "FAIL assert_budget did not fail a command that exceeds its budget"
  fail=1
else
  echo "OK   assert_budget fails a command that exceeds its budget"
fi

exit "$fail"
