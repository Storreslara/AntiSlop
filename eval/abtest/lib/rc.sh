#!/usr/bin/env bash
# Exit-code helpers for run-matrix.sh. Sourced, never run.

# abtest_normalize_rc RC ELAPSED_S CAP_S: print the exit code stream.py should see.
# 124 stays 124. 137 (a process the outer timeout had to KILL) counts as the wall-clock
# cap only when the run lasted at least 90 percent of the cap; any other code, and any
# input that does not parse, is printed unchanged.
abtest_normalize_rc() {
  local rc="$1" elapsed="$2" cap="$3"
  if [ "$rc" = 137 ] && python3 -I -c 'import sys;sys.exit(0 if float(sys.argv[1]) >= 0.9 * float(sys.argv[2]) else 1)' "$elapsed" "$cap" 2> /dev/null; then
    echo 124
  else
    echo "$rc"
  fi
}
