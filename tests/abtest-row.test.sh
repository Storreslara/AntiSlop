#!/usr/bin/env bash
# Tests eval/abtest/lib/make-row.py over canned summaries and check arrays.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$REPO_ROOT/eval/abtest/lib/make-row.py"
FX="$REPO_ROOT/tests/fixtures/abtest/row"
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# row SUMMARY CHECKS ARM [extra flags]: print the row JSON.
row() {
  local s="$1" c="$2" arm="$3"
  shift 3
  python3 "$PY" --summary "$FX/$s" --checks "$FX/$c" --arm "$arm" --eval-id e01-ambiguous-tax --rep 3 \
    --started-at 2026-10-20T14:03:11Z --harness-commit h1 --cli-version 2.1.300 --fixture-commit f1 \
    --prompt-file "$FX/prompt.txt" --wall-clock-ms 4000 "$@"
}
# field JSON EXPR: evaluate a python expression over the row d.
field() { printf '%s' "$1" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1]))' "$2"; }

R="$(row summary-complete.json checks-pass.json A)"
check "run_id joins eval, arm, policy and rep" "$(field "$R" 'd["run_id"]')" "e01-ambiguous-tax/A/uniform/3"
check "clean complete run passes" "$(field "$R" 'd["run_pass"]')" "True"
check "pass rate is 1.0" "$(field "$R" 'd["holdout_pass_rate"]')" "1.0"
check "arm A process fields are null except gate_blocks 0" "$(field "$R" '[d["process"]["units"], d["process"]["gate_blocks"]]')" "[None, 0]"
check "prompt_sha is the sha256 of the prompt file" "$(field "$R" 'd["prompt_sha"]')" "$(sha256sum "$FX/prompt.txt" | cut -d' ' -f1)"
check "plugin fields are null for arm A" "$(field "$R" '[d["plugin_commit"], d["plugin_version"]]')" "[None, None]"
check "token columns are copied" "$(field "$R" '[d["tokens_total"], d["tokens_cache_read"]]')" "[60, 400]"
check "cost is carried for information" "$(field "$R" 'd["total_cost_usd"]')" "1.5"
check "schema_version is 1" "$(field "$R" 'd["schema_version"]')" "1"

R="$(row summary-complete.json checks-fail.json B --policy uniform --plugin-commit abc --plugin-version 0.31.181 --process "$FX/process-b.json")"
check "a failed required check fails the run" "$(field "$R" 'd["run_pass"]')" "False"
check "pass rate is a half" "$(field "$R" 'd["holdout_pass_rate"]')" "0.5"
check "a failed security check is an escaped defect" "$(field "$R" 'd["defects_escaped"]')" "1"
check "arm B process comes from the process file" "$(field "$R" '[d["process"]["units"], d["process"]["gate_blocks"]]')" "[3, 2]"
check "plugin fields are kept for arm B" "$(field "$R" '[d["plugin_commit"], d["plugin_version"]]')" "['abc', '0.31.181']"

R="$(row summary-stalled.json checks-pass.json B)"
check "a stall fails the run with every check passing" "$(field "$R" '[d["run_pass"], d["completion_status"]]')" "[False, 'stalled-human']"

R="$(row summary-limit.json checks-pass.json A)"
check "a usage-limit row is kept with its own status" "$(field "$R" '[d["run_pass"], d["completion_status"]]')" "[False, 'usage-limit']"

R="$(row summary-complete.json checks-optional.json A)"
check "no required checks gives a null pass rate" "$(field "$R" 'd["holdout_pass_rate"]')" "None"
check "an optional failed check does not fail the run" "$(field "$R" 'd["run_pass"]')" "True"

echo '{"completion_status":"budget"}' > "$FX/../row-bad.tmp"
python3 "$PY" --summary "$FX/../row-bad.tmp" --checks "$FX/checks-pass.json" --arm A --eval-id x --rep 1 --started-at t \
  --harness-commit h --cli-version c --fixture-commit f --prompt-file "$FX/prompt.txt" --wall-clock-ms 1 > /dev/null 2>&1
check "the retired budget status is rejected" "$?" "1"
rm -f "$FX/../row-bad.tmp"

echo "abtest-row: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-row checks passed."
exit "$fail"
