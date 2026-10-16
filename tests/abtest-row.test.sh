#!/usr/bin/env bash
# Tests eval/abtest/lib/make-row.py over canned summaries and check arrays.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="$REPO_ROOT/eval/abtest/lib/make-row.py"
FX="$REPO_ROOT/tests/fixtures/abtest/row"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# row SUMMARY CHECKS ARM [extra flags]: print the row JSON.
row() {
  local s="$1" c="$2" arm="$3" ck
  shift 3
  case "$c" in /*) ck="$c" ;; *) ck="$FX/$c" ;; esac
  python3 "$PY" --summary "$FX/$s" --checks "$ck" --arm "$arm" --eval-id e01-ambiguous-tax --rep 3 \
    --started-at 2026-10-20T14:03:11Z --harness-commit h1 --cli-version 2.1.300 --fixture-commit f1 \
    --prompt-file "$FX/prompt.txt" --wall-clock-ms 4000 --expected-required 2 "$@"
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

R="$(row summary-stalled.json checks-pass.json B --process "$FX/process-b.json")"
check "a stall fails the run with every check passing" "$(field "$R" '[d["run_pass"], d["completion_status"]]')" "[False, 'stalled-human']"

R="$(row summary-limit.json checks-pass.json A)"
check "a usage-limit row is kept with its own status" "$(field "$R" '[d["run_pass"], d["completion_status"]]')" "[False, 'usage-limit']"

# Hardening (abt-u03b): rejections, the budget status, escaped defects, the pass rate.
# Every rejection must print no row, exit exactly 1 and name its reason on stderr; a crash
# with a traceback or an empty stderr does not count.
rejects() {
  local name="$1" want="$2" out err rc
  shift 2
  out="$("$@" 2> "$T/err")"
  rc=$?
  err="$(cat "$T/err")"
  if [ "$rc" -eq 1 ] && [ -z "$out" ] && [[ "$err" == *"$want"* ]] && [[ "$err" != *Traceback* ]]; then
    ok "$name"
  else
    bad "$name (rc=$rc out='$out' err='$err')"
  fi
}
# cj NAME JSON: write a checks array to $T/NAME.json and print its path.
cj() { printf '%s\n' "$2" > "$T/$1.json"; printf '%s' "$T/$1.json"; }
OK1='{"id":"a","kind":"defect","required":true,"exit":0,"pass":true}'
OK2='{"id":"b","kind":"scope","required":true,"exit":0,"pass":true}'

rejects "an empty checks array is rejected" "expected 2 required checks, found 0" row summary-complete.json "$(cj empty '[]')" A
rejects "an all-optional checks array is rejected" "expected 2 required checks, found 0" row summary-complete.json checks-optional.json A
rejects "zero expected required checks is rejected" "--expected-required must be at least 1" row summary-complete.json checks-pass.json A --expected-required 0
rejects "too few required checks is rejected" "expected 3 required checks, found 2" row summary-complete.json checks-pass.json A --expected-required 3
rejects "too many required checks is rejected" "expected 1 required checks, found 2" row summary-complete.json checks-pass.json A --expected-required 1
rejects "a string required value is rejected" "'required' must be a boolean" row summary-complete.json "$(cj strreq "[{\"id\":\"a\",\"kind\":\"defect\",\"required\":\"true\",\"pass\":true},$OK2]")" A
rejects "a missing required key is rejected" "lacks 'required'" row summary-complete.json "$(cj noreq "[{\"id\":\"a\",\"kind\":\"defect\",\"pass\":true},$OK2]")" A
rejects "a string pass value is rejected" "'pass' must be a boolean" row summary-complete.json "$(cj strpass "[{\"id\":\"a\",\"kind\":\"defect\",\"required\":true,\"pass\":\"false\"},$OK2]")" A
rejects "pass true with a failing exit is rejected" "pass disagrees with exit" row summary-complete.json "$(cj liepass "[{\"id\":\"a\",\"kind\":\"defect\",\"required\":true,\"exit\":1,\"pass\":true},$OK2]")" A
rejects "pass false with a zero exit is rejected" "pass disagrees with exit" row summary-complete.json "$(cj liefail "[{\"id\":\"a\",\"kind\":\"defect\",\"required\":true,\"exit\":0,\"pass\":false},$OK2]")" A
rejects "a string exit value is rejected" "'exit' must be an integer" row summary-complete.json "$(cj strexit "[{\"id\":\"a\",\"kind\":\"defect\",\"required\":true,\"exit\":\"0\",\"pass\":true},$OK2]")" A
rejects "a checks file that is not an array is rejected" "checks must be a JSON array" row summary-complete.json "$(cj notarray '{"a":1}')" A
rejects "an arm B row without --process is rejected" "arm B needs --process" row summary-complete.json checks-pass.json B
rejects "a missing checks file is rejected" "No such file" row summary-complete.json "$T/absent.json" A

# The retired budget status, with a FULL summary so only the status can be the cause.
sed 's/"completion_status":"complete"/"completion_status":"budget"/' "$FX/summary-complete.json" > "$T/summary-budget.json"
check "the budget summary differs from the complete one only in the status" "$(diff "$FX/summary-complete.json" "$T/summary-budget.json" | grep -c '^[<>]')" "2"
check "the budget summary still carries every token key" "$(grep -o 'tokens_[a-z_]*' "$T/summary-budget.json" | sort -u | paste -sd' ')" "tokens_cache_read tokens_cache_write tokens_in tokens_out tokens_total"
out="$(python3 "$PY" --summary "$T/summary-budget.json" --checks "$FX/checks-pass.json" --arm A --eval-id x --rep 1 --started-at t \
  --harness-commit h --cli-version c --fixture-commit f --prompt-file "$FX/prompt.txt" --wall-clock-ms 1 --expected-required 2 2> "$T/err")"; rc=$?
check "the retired budget status exits 1" "$rc" "1"
check "the retired budget status prints no row" "$out" ""
check "the retired budget status is named on stderr" "$(cat "$T/err")" "make-row: unknown completion_status 'budget'"

# defects_escaped counts failed defect and security checks, required or not, and no other kind.
MIX="[{\"id\":\"d\",\"kind\":\"defect\",\"required\":true,\"exit\":1,\"pass\":false},{\"id\":\"s\",\"kind\":\"security\",\"required\":false,\"exit\":1,\"pass\":false},{\"id\":\"c\",\"kind\":\"scope\",\"required\":true,\"exit\":1,\"pass\":false},{\"id\":\"p\",\"kind\":\"process\",\"required\":false,\"exit\":1,\"pass\":false},{\"id\":\"o\",\"kind\":\"docs\",\"required\":false,\"exit\":1,\"pass\":false},{\"id\":\"g\",\"kind\":\"defect\",\"required\":false,\"exit\":0,\"pass\":true}]"
R="$(row summary-complete.json "$(cj mix "$MIX")" A)"
check "only failed defect and security checks count as escaped defects" "$(field "$R" 'd["defects_escaped"]')" "2"
check "a run with failed required checks does not pass" "$(field "$R" 'd["run_pass"]')" "False"

# The pass rate is over required checks only, and optional failures never fail the run.
RATE="[{\"id\":\"r1\",\"kind\":\"defect\",\"required\":true,\"exit\":0,\"pass\":true},{\"id\":\"r2\",\"kind\":\"defect\",\"required\":true,\"exit\":1,\"pass\":false},{\"id\":\"o1\",\"kind\":\"docs\",\"required\":false,\"exit\":0,\"pass\":true},{\"id\":\"o2\",\"kind\":\"docs\",\"required\":false,\"exit\":0,\"pass\":true}]"
R="$(row summary-complete.json "$(cj rate "$RATE")" A)"
check "the pass rate counts required checks only" "$(field "$R" 'd["holdout_pass_rate"]')" "0.5"
OPT="[$OK1,$OK2,{\"id\":\"o\",\"kind\":\"docs\",\"required\":false,\"exit\":1,\"pass\":false}]"
R="$(row summary-complete.json "$(cj opt "$OPT")" A)"
check "a failed optional check does not fail the run" "$(field "$R" 'd["run_pass"]')" "True"
check "a failed optional docs check is not an escaped defect" "$(field "$R" 'd["defects_escaped"]')" "0"
R="$(row summary-complete.json checks-pass.json B --process "$FX/process-b.json")"
check "an arm B row with a process file is accepted" "$(field "$R" 'd["process"]["units"]')" "3"

echo "abtest-row: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-row checks passed."
exit "$fail"
