Unit: abt-u03b

## Objective
make-row.py requires --expected-required N and exits 1 with a named stderr message unless exactly N checks have required true (so an empty or all-optional array never yields a row); it rejects non-boolean or missing required/pass, a non-integer exit and a pass that disagrees with exit, an unreadable checks file, and an Arm B row without --process; tests/abtest-row.test.sh gains a rejection row per rule, a full-summary budget row asserting stderr, escaped-defect and pass-rate rows, and a mktemp temp directory with a trap. One commit.

## Retrieval
GitHub issues: `gh issue view 594 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/lib/make-row.py` (anchor: line matching `def load(path):`)
- `tests/abtest-row.test.sh` (anchor: line matching `row() {`)

## Ordered edits
1. command: `test -f eval/abtest/lib/make-row.py && test -f tests/abtest-row.test.sh && ! grep -q expected-required eval/abtest/lib/make-row.py && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/make-row.py`
   anchor: line matching `def load(path):`
   indent: 0
   before:
~~~~
def load(path):
    with open(path) as f:
        return json.load(f)
~~~~
   after:
~~~~
def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        fail(f"cannot read {path}: {e}")

def fail(msg):
    raise SystemExit(f"make-row: {msg}")


def validate_checks(checks, expected):
    """Fail closed: a checks array that is not exactly what the verified fixture produces never yields a row."""
    if expected < 1:
        fail("--expected-required must be at least 1")
    if not isinstance(checks, list):
        fail("checks must be a JSON array")
    for i, c in enumerate(checks):
        where = f"check {i}"
        if not isinstance(c, dict):
            fail(f"{where} is not an object")
        for key in ("required", "pass"):
            if key not in c:
                fail(f"{where} lacks '{key}'")
            if not isinstance(c[key], bool):
                fail(f"{where}: '{key}' must be a boolean")
        if "exit" in c:
            if isinstance(c["exit"], bool) or not isinstance(c["exit"], int):
                fail(f"{where}: 'exit' must be an integer")
            if c["pass"] != (c["exit"] == 0):
                fail(f"{where}: pass disagrees with exit")
    found = sum(1 for c in checks if c["required"])
    if found != expected:
        fail(f"expected {expected} required checks, found {found}")
~~~~
3. file: `eval/abtest/lib/make-row.py`
   anchor: line matching `    checks = load(a.checks)`
   indent: 0
   before:
~~~~
    checks = load(a.checks)
~~~~
   after:
~~~~
    checks = load(a.checks)
    validate_checks(checks, a.expected_required)
    if a.arm == "B" and not a.process:
        fail("arm B needs --process")
~~~~
4. file: `eval/abtest/lib/make-row.py`
   anchor: line matching `    p.add_argument("--wall-clock-ms", type=int, required=True)`
   indent: 0
   insert-after:
~~~~
    p.add_argument("--expected-required", type=int, required=True)
~~~~
5. file: `tests/abtest-row.test.sh`
   anchor: line matching `FX="$REPO_ROOT/tests/fixtures/abtest/row"`
   indent: 0
   insert-after:
~~~~
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
~~~~
6. file: `tests/abtest-row.test.sh`
   anchor: line matching `row() {`
   indent: 0
   before:
~~~~
row() {
  local s="$1" c="$2" arm="$3"
  shift 3
  python3 "$PY" --summary "$FX/$s" --checks "$FX/$c" --arm "$arm" --eval-id e01-ambiguous-tax --rep 3 \
    --started-at 2026-10-20T14:03:11Z --harness-commit h1 --cli-version 2.1.300 --fixture-commit f1 \
    --prompt-file "$FX/prompt.txt" --wall-clock-ms 4000 "$@"
}
~~~~
   after:
~~~~
row() {
  local s="$1" c="$2" arm="$3" ck
  shift 3
  case "$c" in /*) ck="$c" ;; *) ck="$FX/$c" ;; esac
  python3 "$PY" --summary "$FX/$s" --checks "$ck" --arm "$arm" --eval-id e01-ambiguous-tax --rep 3 \
    --started-at 2026-10-20T14:03:11Z --harness-commit h1 --cli-version 2.1.300 --fixture-commit f1 \
    --prompt-file "$FX/prompt.txt" --wall-clock-ms 4000 --expected-required 2 "$@"
}
~~~~
7. file: `tests/abtest-row.test.sh`
   anchor: line matching `R="$(row summary-stalled.json checks-pass.json B)"`
   before: `R="$(row summary-stalled.json checks-pass.json B)"`
   after: `R="$(row summary-stalled.json checks-pass.json B --process "$FX/process-b.json")"`
8. file: `tests/abtest-row.test.sh`
   anchor: line matching `R="$(row summary-complete.json checks-optional.json A)"`
   indent: 0
   before:
~~~~
R="$(row summary-complete.json checks-optional.json A)"
check "no required checks gives a null pass rate" "$(field "$R" 'd["holdout_pass_rate"]')" "None"
check "an optional failed check does not fail the run" "$(field "$R" 'd["run_pass"]')" "True"

echo '{"completion_status":"budget"}' > "$FX/../row-bad.tmp"
python3 "$PY" --summary "$FX/../row-bad.tmp" --checks "$FX/checks-pass.json" --arm A --eval-id x --rep 1 --started-at t \
  --harness-commit h --cli-version c --fixture-commit f --prompt-file "$FX/prompt.txt" --wall-clock-ms 1 > /dev/null 2>&1
check "the retired budget status is rejected" "$?" "1"
rm -f "$FX/../row-bad.tmp"
~~~~
   after:
~~~~
# Hardening (abt-u03b): rejections, the budget status, escaped defects, the pass rate.
~~~~
9. file: `tests/abtest-row.test.sh`
   anchor: line matching `# Hardening (abt-u03b): rejections, the budget status, escaped defects, the pass rate.`
   indent: 0
   insert-after:
~~~~
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
~~~~
10. command: `git add eval/abtest/lib/make-row.py tests/abtest-row.test.sh && git commit -m "feat(abt-u03b): make-row fails closed on a wrong required-check count and malformed checks (#594)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `tests/fixtures/abtest/row/` (the fixtures stay as landed; new inputs are written to a temp directory by the test)
- `eval/abtest/lib/stream.py`, `eval/abtest/score.py`, `eval/abtest/lib/blind.py` (other units own them)
- `eval/abtest/run-matrix.sh` (abt-u12 passes the new option; it is not edited here)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-row.test.sh`
   exit: 0
   stdout: `All abtest-row checks passed.`
   mutation: skip edit 2 (the validation function); every rejection row FAILs, the script exits non-zero and the fragment is absent.
   proof: mutation matrix, run in a scratch copy of the finished change, each making bash tests/abtest-row.test.sh exit non-zero: M1 delete the found-versus-expected comparison; M2 delete the expected-below-one test; M3 delete the required bool test; M4 delete the required presence test; M5 delete the pass bool test; M6 delete the pass-versus-exit test; M7 delete the exit integer test; M8 delete the arm B process test; M9 count every failed check as an escaped defect; M10 compute the pass rate over all checks; M11 add budget to STATUSES; M12 delete the status test; M13 delete the array test; M14 restore the bare load().
2. run: `bash tests/abtest-row.test.sh | grep -c 'rejected$'`
   exit: 0
   stdout: `14`
   mutation: skip edit 3 (the validate call); the rejection rows FAIL and the count of ok lines drops below 14.
3. run: `python3 -I eval/abtest/lib/make-row.py --summary tests/fixtures/abtest/row/summary-complete.json --checks tests/fixtures/abtest/row/checks-optional.json --arm A --eval-id x --rep 1 --started-at t --harness-commit h --cli-version c --fixture-commit f --prompt-file tests/fixtures/abtest/row/prompt.txt --wall-clock-ms 1 --expected-required 2 2>&1 | tail -n 1`
   exit: 0
   stdout: `make-row: expected 2 required checks, found 0`
   mutation: skip edit 3; a row is printed instead and the last line is JSON.
4. run: `python3 -I eval/abtest/lib/make-row.py --summary tests/fixtures/abtest/row/summary-complete.json --checks tests/fixtures/abtest/row/checks-pass.json --arm A --eval-id x --rep 1 --started-at t --harness-commit h --cli-version c --fixture-commit f --prompt-file tests/fixtures/abtest/row/prompt.txt --wall-clock-ms 1 2>&1 | tail -n 1`
   exit: 0
   stdout: `make-row.py: error: the following arguments are required: --expected-required`
   mutation: skip edit 4 (the new option); the option no longer exists, argparse errors on it or a row is printed, so the fragment is absent.
5. run: `python3 -I eval/abtest/lib/make-row.py --summary tests/fixtures/abtest/row/summary-complete.json --checks tests/fixtures/abtest/row/checks-pass.json --arm A --eval-id x --rep 1 --started-at t --harness-commit h --cli-version c --fixture-commit f --prompt-file tests/fixtures/abtest/row/prompt.txt --wall-clock-ms 1 --expected-required 0 2>&1 | tail -n 1`
   exit: 0
   stdout: `make-row: --expected-required must be at least 1`
   mutation: skip edit 2; the function is gone and python prints a traceback ending in NameError.
6. run: `grep -c 'mktemp' tests/abtest-row.test.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 5 (the temp directory); stdout 0 and the exit is 1.
7. run: `grep -c "row-bad.tmp" tests/abtest-row.test.sh`
   exit: 1
   stdout: `0`
   mutation: put the old row-bad.tmp redirect back into the test; stdout 1 and the exit is 0.
   proof: scratch run: the unmodified test at ee5e61db prints 1 for this grep; the finished file prints 0 with exit 1.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u03b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/lib/make-row.py tests/abtest-row.test.sh`
   mutation: skip edit 10 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u03b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; no unit commit exists and the exit is 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u03b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/make-row.py tests/abtest-row.test.sh | grep -vcE "^[a-z]+\(abt-u03b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- eval/abtest/lib/make-row.py tests/abtest-row.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-row.test.sh (criteria 1-5 are the red-then-green checks; the new rows and option do not exist at HEAD)
blast-radius: eval/abtest/lib/make-row.py:36
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 (the whole suite passes at HEAD; criteria 2 to 6 are the red-then-green checks) and criterion 11 (the scoped clean-tree check) pass at HEAD by design; the last turns red only when the commit step is skipped.
extends-landed-code: abt-u03 is on master (commit ee5e61db). Every edit here is an insertion or a small replacement anchored on lines that exist there; no file is rewritten.
fail-closed: every new check in the test must go red on a crash, an empty output or a missing file. Do not weaken a rejection row into an exit-code-only assertion; each must also see its message on stderr and no traceback.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: feat(abt-u03b): make-row fails closed on a wrong required-check count and malformed checks (#594)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u03b (#594)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
