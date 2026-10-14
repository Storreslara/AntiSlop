#!/usr/bin/env bash
# vlg1-ac2.sh: the guard sets ANTISLOP_VALIDATE_INNER=1 on its nested run, so
# validate.sh's skip-summary wrapper never appends lines after the closing
# summary. The stub imitates the real wrapper: without the variable it prints
# `Skipped checks: 0` AFTER the summary line. The guard is run standalone with
# the variable unset (as `bash tests/reviewed-dir-leak-guard.test.sh` from a
# shell would be), must exit 0, and must leave nothing in its TMPDIR.
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
t=$(gtree wrapper 'echo "All checks passed."
if [ -z "${ANTISLOP_VALIDATE_INNER:-}" ]; then echo; echo "Skipped checks: 0"; fi
exit 0')
runguard "$t"
expect wrapper 0 'OK   no suite wrote' '!did not finish'
left=$(ls -A "$t/tmp")
[ -z "$left" ] || { echo "TMPDIR not cleaned: $left"; exit 1; }
exit 0
