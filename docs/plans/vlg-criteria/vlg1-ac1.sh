#!/usr/bin/env bash
# vlg1-ac1.sh: the leak guard FAILs a nested run that did not reach
# validate.sh's own closing summary, and does NOT fail a nested run that
# finished with failing checks (the outer run reports those itself).
# A run "finished" iff (exit 0 and last non-blank line `All checks passed.`)
# or (exit 1 and last non-blank line `One or more checks FAILED.`).
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
LEAK='printf "PASS unitZ x\n" > "$CLAUDE_PROJECT_DIR/.claude/reviewed/unitZ.pass"'
OK='OK   no suite wrote'
NF='did not finish'

case_() { # <label> <stub-body> <want-rc> <substring>...
  local label="$1" body="$2" t; shift 2
  t=$(gtree "$label" "$body"); runguard "$t"; expect "$label" "$@"
}
case_ clean      'echo "== a =="; echo "All checks passed."; exit 0'                 0 "$OK" "!$NF" '!NOTE'
case_ trailing   'echo "All checks passed."; echo; echo "   "; exit 0'               0 "$OK"
case_ red        'echo "FAIL x"; echo "One or more checks FAILED."; exit 1'           0 "$OK" 'NOTE the nested validate.sh run reported failing checks' "!$NF"
case_ abort3     'echo "== a =="; exit 3'                                             1 "$NF (exit 3; last line: == a ==)" "!$OK"
case_ abort0     'echo "== a =="; exit 0'                                             1 "$NF (exit 0" "!$OK"
case_ abort1     'echo "== a =="; exit 1'                                             1 "$NF (exit 1" "!$OK"
case_ silent     'exit 0'                                                             1 "$NF (exit 0; last line: (no output))"
case_ mismatch1  'echo "All checks passed."; exit 1'                                  1 "$NF (exit 1; last line: All checks passed.)"
case_ mismatch0  'echo "One or more checks FAILED."; exit 0'                          1 "$NF (exit 0"
case_ signal     'echo "== a =="; kill -TERM $$'                                      1 "$NF (exit 143"
case_ leakabort  "$LEAK; exit 2"                                                      1 "$NF (exit 2" 'unitZ.pass' "!$OK"
case_ leakred    "$LEAK; echo 'One or more checks FAILED.'; exit 1"                   1 'unitZ.pass' 'NOTE' "!$OK"
case_ leakclean  "$LEAK; echo 'All checks passed.'; exit 0"                           1 'unitZ.pass' "!$NF" "!$OK"
exit 0
