Unit: abt-u12b

## Objective
tests/abtest-runner.test.sh gains the guard rows for the abt-u12 runner: run directories are built under ABT_WORK outside the repo as standalone repositories, a work root under a CLAUDE.md is refused, an unverifiable fixture stops the runner before any usage, the exit-code normalisation, an outer timeout -k that ends a claude ignoring SIGTERM (recorded as a timeout, and no stub process left alive), a worktree-style run directory is refused, and a run id classified usage-limit three times stops the runner with exit 76. One commit.

## Retrieval
GitHub issues: `gh issue view 597 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `tests/abtest-runner.test.sh` (anchor: line matching `export ABT_RESULTS=`)

## Ordered edits
1. command: `test -f tests/abtest-runner.test.sh && test -f eval/abtest/run-matrix.sh && test -f eval/abtest/lib/rc.sh && grep -q check_work_root eval/abtest/run-matrix.sh && grep -q run_guarded eval/abtest/run-matrix.sh && ! grep -q hardening tests/abtest-runner.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `tests/abtest-runner.test.sh`
   anchor: line matching `export ABT_RESULTS=`
   indent: 0
   insert-after:
~~~~
. "$REPO_ROOT/eval/abtest/lib/rc.sh"
~~~~
3. file: `tests/abtest-runner.test.sh`
   anchor: line matching `the stray file shows in the diff`
   indent: 0
   insert-after:
~~~~

# --- hardening (abt-u12): run directories, required-check count, guards ---
rm -rf "$ABT_RESULTS" "$T/flog" "$T/work"
bash "$RUN" --pilot --evals $E > /dev/null
check "both arms and their version calls run in a directory under ABT_WORK, outside the repo" "$(grep -l "^PWD=$T/work/" "$T"/flog/env.* | wc -l | tr -d ' ')" "4"
check "no arm ran under the repo" "$(grep -l "^PWD=$REPO_ROOT/" "$T"/flog/env.* 2> /dev/null | grep -vc '^$')" "0"
check "a run directory is a standalone repository with its own .git directory" "$(test -d "$T/work/${E}_A_uniform_1/w/.git" && test -d "$T/work/${E}_B_uniform_1/w/.git" && echo yes)" "yes"
check "the run artifacts stay under ABT_RUNS" "$(test -s "$ABT_RUNS/${E}_B_uniform_1/summary.json" && echo yes)" "yes"
REQ="$(bash "$REPO_ROOT/eval/abtest/verify-checks.sh" $E | sed -n 's#^verify: .* reference-required-failures=0/\([0-9][0-9]*\)$#\1#p' | head -n1)"
check "verify-checks proves a positive required-check count for the eval" "$([ -n "$REQ" ] && [ "$REQ" -ge 1 ] && echo yes)" "yes"
check "every row carries exactly the required-check count verify-checks proved" "$(python3 -I -c 'import json,sys;print([sum(1 for c in json.loads(l)["checks"] if c["required"]) for l in open(sys.argv[1]) if l.strip()])' "$ABT_RESULTS")" "[$REQ, $REQ]"
check "an arm B row carries its process block" "$(col "$ABT_RESULTS" 2 process | grep -c "'units': [0-9]")" "1"

rm -rf "$T/flog"
rm -rf "$REPO_ROOT/eval/abtest/.runs/work-refused"
out="$(ABT_WORK="$REPO_ROOT/eval/abtest/.runs/work-refused" bash "$RUN" --pilot --evals $E 2>&1)"; rc=$?
check "a work root under a CLAUDE.md-bearing directory is refused with exit 2" "$rc" "2"
case "$out" in *"would be loaded into the arms"*) ok "the refusal names the CLAUDE.md problem" ;; *) bad "the refusal text was '$out'" ;; esac
check "a refused work root starts no claude" "$(test -e "$T/flog" && echo ran || echo none)" "none"
check "a refused work root creates no directory" "$(test -e "$REPO_ROOT/eval/abtest/.runs/work-refused" && echo made || echo none)" "none"

# A fixture whose checks print nothing useful must stop the runner before any usage is spent.
rm -rf "$ABT_RESULTS" "$T/flog" "$T/ck"
cp -r "$REPO_ROOT/eval/abtest/checks" "$T/ck"
printf '#!/usr/bin/env bash\necho "[]"\n' > "$T/ck/$E/check.sh"
out="$(ABT_CHECKS_ROOT="$T/ck" bash "$RUN" --pilot --evals $E 2>&1)"; rc=$?
check "an unverifiable fixture stops the runner with exit 1" "$rc" "1"
case "$out" in *"verify-checks.sh failed for $E"*) ok "the stop names the failed verification" ;; *) bad "the stop text was '$out'" ;; esac
check "an unverifiable fixture starts no claude" "$(test -e "$T/flog" && echo ran || echo none)" "none"
check "an unverifiable fixture writes no row" "$(test -e "$ABT_RESULTS" && echo wrote || echo none)" "none"

# exit-code normalisation
check "137 after the cap counts as the wall-clock cap" "$(abtest_normalize_rc 137 100 100)" "124"
check "137 well before the cap stays 137" "$(abtest_normalize_rc 137 5 100)" "137"
check "124 stays 124" "$(abtest_normalize_rc 124 1 100)" "124"
check "another code stays unchanged" "$(abtest_normalize_rc 1 100 100)" "1"
check "an unparsable elapsed time leaves 137 unchanged" "$(abtest_normalize_rc 137 '' 100)" "137"

# The outer guard ends a claude that ignores SIGTERM: every process here ignores TERM (BASH_ENV), so
# only the KILL after -k ends it, the guard exits 137, and the runner must still record a timeout.
printf '#!/usr/bin/env bash\nif [ "${1:-}" = --version ]; then echo stubborn-0; exit 0; fi\ntrap "" TERM\nfor i in $(seq 25); do sleep 1; done\n' > "$T/stubborn"
chmod +x "$T/stubborn"
rm -rf "$ABT_RESULTS"
start=$SECONDS
printf 'trap "" TERM\n' > "$T/ignore-term.sh"
BASH_ENV="$T/ignore-term.sh" ABTEST_CLAUDE="$T/stubborn" TIMEOUT_MIN=0.02 ABT_OUTER_GRACE_S=2 ABT_KILL_AFTER_S=1 bash "$RUN" --pilot --evals $E > /dev/null 2>&1
elapsed=$((SECONDS - start))
check "a claude that ignores SIGTERM is ended by the outer guard well before it would exit" "$([ "$elapsed" -lt 22 ] && echo fast || echo "slow:$elapsed")" "fast"
check "both KILLed runs are recorded as timeouts, not errors" "$(python3 -I -c 'import json,sys;print([json.loads(l)["completion_status"] for l in open(sys.argv[1]) if l.strip()])' "$ABT_RESULTS")" "['timeout', 'timeout']"
check "no stub process survives the runner" "$(pgrep -f "$T/stubborn" | wc -l | tr -d ' ')" "0"
pkill -f "$T/stubborn" 2> /dev/null || true

# A run directory that is not a standalone repository (a .git file, as git worktree makes) is refused.
# The altered build.sh converts only directories under /work/ (the runner's), so verify-checks still passes.
rm -rf "$ABT_RESULTS" "$T/flog" "$T/fxr"
cp -r "$REPO_ROOT/eval/abtest/fixtures" "$T/fxr"
cat > "$T/fxr/$E/build.sh" << EOS
#!/usr/bin/env bash
bash "$REPO_ROOT/eval/abtest/fixtures/$E/build.sh" "\$1" | tail -n1
case "\$1" in
  */work/*) mv "\$1/.git" "\$1/.gitdir"; echo 'gitdir: .gitdir' > "\$1/.git" ;;
esac
EOS
out="$(ABT_FIXTURES_DIR="$T/fxr" bash "$RUN" --pilot --evals $E 2>&1)"; rc=$?
check "a worktree-style run directory stops the runner with exit 1" "$rc" "1"
case "$out" in *"standalone clone"*) ok "the stop names the standalone-clone rule" ;; *) bad "the stop text was '$out'" ;; esac
check "a worktree-style run directory starts no claude" "$(test -e "$T/flog" && echo ran || echo none)" "none"

# A run id that keeps coming back as a usage limit stops the runner instead of looping.
rm -rf "$T/flog"
python3 -I - "$ABT_RESULTS" "$E" << 'PYEOF'
import json, sys

with open(sys.argv[1], "w") as f:
    for _ in range(3):
        f.write(json.dumps({"run_id": f"{sys.argv[2]}/A/uniform/1", "completion_status": "usage-limit"}) + "\n")
PYEOF
out="$(bash "$RUN" --pilot --evals $E 2>&1)"; rc=$?
check "three usage-limit rows for one run id stop the runner with exit 76" "$rc" "76"
~~~~
4. file: `tests/abtest-runner.test.sh`
   anchor: line matching `check "three usage-limit rows for one run id stop the runner with exit 76" "$rc" "76"`
   indent: 0
   insert-after:
~~~~
case "$out" in *"classified usage-limit 3 times"*) ok "the stop names the repeat count" ;; *) bad "the stop text was '$out'" ;; esac
check "a capped run id starts no claude" "$(test -e "$T/flog" && echo ran || echo none)" "none"
ABT_MAX_LIMIT_HITS=4 bash "$RUN" --pilot --evals $E > /dev/null; rc=$?
check "raising the cap lets the run go ahead" "$rc" "0"
check "the repeated run is appended after the three limit rows" "$(python3 -I -c 'import json,sys;print([json.loads(l)["completion_status"] for l in open(sys.argv[1]) if l.strip()])' "$ABT_RESULTS")" "['usage-limit', 'usage-limit', 'usage-limit', 'complete', 'complete']"
~~~~
5. command: `git add tests/abtest-runner.test.sh && git commit -m "test(abt-u12b): runner guards are proven fail-closed (outside run directory, work root, outer timeout, exit mapping, required count, repeat cap) (#597)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/run-matrix.sh` and `eval/abtest/lib/rc.sh` (unit abt-u12 owns them; a failing guard row is a defect to report, not to fix here)
- `eval/abtest/arms/`, `eval/abtest/lib/stream.py`, `eval/abtest/lib/make-row.py`, `eval/abtest/checks/`, `eval/abtest/fixtures/` (other units own them)
- `tests/fixtures/abtest/` (the fake claude and canned streams belong to earlier units)
- `tests/validate.sh` (the runner test is already registered by abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-runner.test.sh`
   exit: 0
   stdout: `All abtest-runner checks passed.`
   mutation: delete a guard row or break the behaviour it guards in run-matrix.sh; the matching row FAILs and the script exits non-zero.
   proof: mutation matrix, run in a scratch copy of the finished abt-u12 + abt-u12b change, each making bash tests/abtest-runner.test.sh exit non-zero: R1 delete the --expected-required argument; R2 build the run directory inside the artifacts directory; R3 delete the work-root ancestor check; R4 delete the outer timeout wrapper inside run_guarded; R5 delete the exit-code normalisation; R6 drop -k from the wrapper; R7 delete the usage-limit repeat cap; R8 replace the verified required-check count by the constant 4; R9 delete the standalone .git test; R11 stop passing --process to make-row; R12 check only the work root itself for CLAUDE.md.
2. run: `bash tests/abtest-runner.test.sh | grep -c '^ok'`
   exit: 0
   stdout: `95`
   mutation: skip edit 4 (the last part of the guard rows); four rows go missing and stdout is 91.
3. run: `bash tests/abtest-runner.test.sh | grep -c '^FAIL'`
   exit: 1
   stdout: `0`
   mutation: skip edit 2 (the rc.sh source line); the normalisation rows cannot call the function and FAIL, so stdout is above 0.
4. run: `bash tests/abtest-runner.test.sh | grep -c 'KILLed runs are recorded as timeouts, not errors\|stop the runner with exit 76\|names the standalone-clone rule\|outside the repo\|no stub process survives the runner'`
   exit: 0
   stdout: `5`
   mutation: delete the five named rows from the test; stdout is below 5.
   proof: scratch run: with one named row deleted the count printed 4 with exit 0.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `tests/abtest-runner.test.sh`
   mutation: skip edit 5 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; no unit commit exists and the exit is 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- tests/abtest-runner.test.sh | grep -vcE "^[a-z]+\(abt-u12b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
8. run: `git status --porcelain -- tests/abtest-runner.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 5; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-runner.test.sh (criterion 2 is the red-then-green check: the 31 guard rows do not exist at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 (the base rows pass at HEAD), criterion 3 (no FAIL line yet) and criterion 8 (the scoped clean-tree check) pass at HEAD by design; criterion 2 and the named rows of criterion 4 are the red-then-green checks.
depends-on: abt-u12 and its fix abt-u12-fix1 (run_guarded, acquire_lock and the 32 guard rows of the runner test) must have landed; edit 1 checks for them and STOPs otherwise.
extends-landed-code: every edit is an insertion anchored on a line of the abt-u12 test; nothing is rewritten.
fail-closed: each guard row compares an explicit expected value and a message, never only an exit code; the rows pkill their stubborn stub at the end and take about 20 seconds more than the base rows.
no-real-claude: no command in this contract runs the real claude CLI; the test sets ABTEST_CLAUDE to a fake or a stub and HOME to a temp directory.
commit-message: test(abt-u12b): runner guards are proven fail-closed (outside run directory, work root, outer timeout, exit mapping, required count, repeat cap) (#597)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u12b (#597)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
