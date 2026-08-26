#!/usr/bin/env bash
# Reusable latency-measurement harness (docs/plans/2026-08-25-agent-throughput-
# performance-dampeners.md "Measurement harness"): invokes a REAL hook with
# canned stdin, reports p50/p99 over N iterations. Sourced by budget tests
# (e.g. tests/hook-latency-budget.test.sh for AC-A1); never executed directly.
set -euo pipefail

# measure_latencies <iterations> <json-input> -- <cmd...>
# Prints one elapsed-seconds float per line (invocation order, unsorted).
measure_latencies() {
  local iterations="$1" json_input="$2"; shift 2
  [ "${1:-}" = "--" ] && shift
  local i start_ns end_ns
  for ((i = 0; i < iterations; i++)); do
    start_ns="$(date +%s%N)"
    printf '%s' "$json_input" | "$@" >/dev/null 2>&1 || true
    end_ns="$(date +%s%N)"
    awk -v ns="$((end_ns - start_ns))" 'BEGIN { printf "%.3f\n", ns / 1000000000 }'
  done
}

# percentile <p> - reads sorted-ascending latency lines from stdin
percentile() {
  local p="$1" n idx
  local -a vals=()
  while IFS= read -r line; do vals+=("$line"); done
  n="${#vals[@]}"
  [ "$n" -gt 0 ] || { echo 0; return; }
  idx=$(( (p * n + 99) / 100 ))
  [ "$idx" -lt 1 ] && idx=1
  [ "$idx" -gt "$n" ] && idx="$n"
  echo "${vals[$((idx - 1))]}"
}

# assert_budget <label> <p50_budget_s> <p99_budget_s> <iterations> <json-input> -- <cmd...>
# Prints a measurement line; returns non-zero if either budget is exceeded.
assert_budget() {
  local label="$1" p50_budget="$2" p99_budget="$3" iterations="$4" json_input="$5"; shift 5
  local sorted p50 p99 ok=0
  sorted="$(measure_latencies "$iterations" "$json_input" -- "$@" | sort -n)"
  p50="$(printf '%s\n' "$sorted" | percentile 50)"
  p99="$(printf '%s\n' "$sorted" | percentile 99)"
  echo "${label}: p50=${p50}s p99=${p99}s (budget p50<=${p50_budget}s p99<=${p99_budget}s, n=${iterations})"
  awk -v v="$p50" -v b="$p50_budget" 'BEGIN{exit !(v>b)}' && ok=1
  awk -v v="$p99" -v b="$p99_budget" 'BEGIN{exit !(v>b)}' && ok=1
  return "$ok"
}
