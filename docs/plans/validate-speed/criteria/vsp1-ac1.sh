#!/usr/bin/env bash
# vsp-1 AC1.1: `bash tests/validate.sh` runs its sections through the lane runner by default;
# --serial and ANTISLOP_VALIDATE_SERIAL=1 keep the serial run; ANTISLOP_VALIDATE_LANES sets the
# lane count; the default lane count is min(6, nproc); exit codes, quiet mode and its Counts
# line are unchanged. Stub-suite throwaway trees only: about 20 s.
. "$(dirname "$0")/lib.sh"

# Each stub section prints the directory it ran in, so a lane copy is distinguishable from the tree.
body="$(vsp_sec 1 'echo "OK   s1 cwd=$(pwd -P)"')
$(vsp_sec 2)
$(vsp_sec 3)"
t="$(vsp_tree green "$body")" || exit 99
tp="$(cd "$t" && pwd -P)"

vsp_run "$t" -- --verbose
vsp_check A1 "default run goes through the lane runner and passes" 0 "== lanes: " "All checks passed." "OK   s3"
case "$OUT" in *"cwd=$tp"$'\n'*|*"cwd=$tp") vsp_assert A2 "default run executes sections in a lane copy, not the tree" 1 "section ran in $tp" ;;
  *) vsp_assert A2 "default run executes sections in a lane copy, not the tree" 0 ;; esac

vsp_run "$t" -- --serial --verbose
vsp_check A3 "--serial runs serially in the tree" 0 "!== lanes: " "cwd=$tp" "All checks passed."

vsp_run "$t" ANTISLOP_VALIDATE_SERIAL=1 -- --verbose
vsp_check A4 "ANTISLOP_VALIDATE_SERIAL=1 runs serially in the tree" 0 "!== lanes: " "cwd=$tp"

vsp_run "$t" ANTISLOP_VALIDATE_LANES=2 -- --verbose
vsp_check A5 "ANTISLOP_VALIDATE_LANES=2 runs 2 lanes" 0 "== lanes: 2, sections: 3,"

n="$(nproc 2>/dev/null || echo 1)"; [ "$n" -gt 6 ] && n=6; [ "$n" -lt 1 ] && n=1
vsp_run "$t" -- --verbose
vsp_check A6 "default lane count is min(6, nproc) = $n" 0 "== lanes: $n, sections: 3,"

# Quiet mode (no --verbose) still ends with the Counts and Full log lines.
vsp_run "$t" --
vsp_check A7 "quiet default run prints Counts and Full log" 0 "Counts: OK=" "Full log: "

# A failing section fails the default run and the serial run alike.
r="$(vsp_tree red "$(vsp_sec 1)
$(vsp_sec 2 'echo "FAIL s2"; fail=1')")" || exit 99
vsp_run "$r" -- --verbose
vsp_check A8 "a failing section makes the default run exit 1" 1 "FAIL s2" "One or more checks FAILED."
vsp_run "$r" --
vsp_check A9 "quiet default run counts the FAIL" 1 "FAIL=1"
vsp_run "$r" -- --serial
vsp_check A10 "a failing section makes the serial run exit 1" 1 "FAIL s2"

# Parallelism: six 2-second sections finish well under the 12 s a serial run needs.
p="$(vsp_tree par "$(for i in 1 2 3 4 5 6; do vsp_sec "$i" 'sleep 2; echo "OK   s"'; done)")" || exit 99
vsp_run "$p" ANTISLOP_VALIDATE_LANES=6 --
vsp_assert A11 "six 2 s sections in 6 lanes take <= 8 s (took ${SECS} s, exit $RC)" \
  "$(awk -v s="$SECS" -v rc="$RC" 'BEGIN{print (s <= 8 && rc == 0) ? 0 : 1}')"

vsp_done
