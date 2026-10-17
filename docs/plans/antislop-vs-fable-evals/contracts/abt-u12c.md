Unit: abt-u12c

## Objective
run-matrix.sh treats a run id as done only when a non-usage-limit row for it has the current harness commit, the current plugin commit (arm B; arm A none) and the current prompt hash; otherwise it repeats the run, moves the stale row to results.superseded.jsonl (ABT_SUPERSEDED) so the scorer never sees it, and a dry run plans it as rerun; tests/abtest-runner.test.sh gains the proof rows (a stale row of each kind is repeated, a matching one is skipped, arm A with no plugin commit works, usage-limit rows are untouched); the suite goes from 95 to 122 rows. One commit.

## Retrieval
GitHub issues: `gh issue view 606 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/run-matrix.sh` (anchor: line matching `# done_run RUN_ID: success when a non-usage-limit row exists for it.`)
- `tests/abtest-runner.test.sh` (anchor: line matching `check "zero reps exits 2" "$?" "2"`)

## Ordered edits
1. command: `test -f eval/abtest/run-matrix.sh && test -f tests/abtest-runner.test.sh && grep -q check_work_root eval/abtest/run-matrix.sh && grep -q run_guarded eval/abtest/run-matrix.sh && grep -q abtest_plugin_copy eval/abtest/arms/common.sh && ! grep -q current_prov eval/abtest/run-matrix.sh && grep -q "OD-14" docs/plans/antislop-vs-fable-evals/operator-decisions.md && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `# Resume: a run id is done once a row exists for it whose completion_status is`
   indent: 0
   before:
~~~~
# Resume: a run id is done once a row exists for it whose completion_status is
# not usage-limit; a usage-limit row is kept, the runner stops with exit 75, and
# the next invocation repeats that run.
~~~~
   after:
~~~~
# Resume: a run id is done once a non-usage-limit row exists for it that carries the same harness commit,
# plugin commit (arm B; an arm A row must carry none) and prompt hash as this checkout and config (OD-14).
# A row of another provenance is stale: it is moved to ABT_SUPERSEDED (default results.superseded.jsonl beside
# the results file, never read by the scorer) and the run is repeated. A usage-limit row is kept, the runner
# stops with exit 75, and the next invocation repeats that run.
~~~~
3. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `#      ABT_OUTER_GRACE_S (default 120), ABT_KILL_AFTER_S (default 30), ABT_MAX_LIMIT_HITS (default 3).`
   indent: 0
   insert-after:
~~~~
#      ABT_SUPERSEDED (default results.superseded.jsonl beside ABT_RESULTS; stale rows are moved there).
~~~~
4. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `RESULTS="${ABT_RESULTS:-$HERE/results.jsonl}"`
   indent: 0
   insert-after:
~~~~
SUPERSEDED="${ABT_SUPERSEDED:-$(dirname "$RESULTS")/results.superseded.jsonl}"
~~~~
5. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `# done_run RUN_ID: success when a non-usage-limit row exists for it.`
   indent: 0
   before:
~~~~
# done_run RUN_ID: success when a non-usage-limit row exists for it.
done_run() {
  [ -f "$RESULTS" ] || return 1
  python3 -I - "$RESULTS" "$1" <<'PYEOF'
import json, sys

path, run_id = sys.argv[1:3]
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        if row.get("run_id") == run_id and row.get("completion_status") != "usage-limit":
            sys.exit(0)
sys.exit(1)
PYEOF
}
~~~~
   after:
~~~~
# current_prov ARM EV: three lines, the provenance a row written now would carry: the harness commit, the plugin
# commit (null for arm A) and the prompt hash.
current_prov() {
  local arm="$1" ev="$2" pf="$HERE/tasks/$2.prompt.md"
  git -C "$ABT_REPO_ROOT" rev-parse HEAD 2> /dev/null || echo unknown
  if [ "$arm" = B ]; then git -C "$PLUGIN_ROOT" rev-parse HEAD 2> /dev/null || echo null; else echo null; fi
  if [ -f "$pf" ]; then sha256sum "$pf" | cut -d' ' -f1; else echo missing; fi
}

# done_run RUN_ID ARM EV: 0 when a non-usage-limit row exists for the run id with the current provenance (skip it),
# 2 when such a row exists with another provenance (stale: repeat the run), 1 when there is none.
done_run() {
  [ -f "$RESULTS" ] || return 1
  local cur
  cur="$(current_prov "$2" "$3")"
  python3 -I - "$RESULTS" "$1" "$cur" <<'PYEOF'
import json, sys

path, run_id, cur = sys.argv[1:4]
harness, plugin, prompt = cur.split("\n")
want = {"harness_commit": harness, "plugin_commit": None if plugin == "null" else plugin, "prompt_sha": prompt}
state = 1
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        if row.get("run_id") == run_id and row.get("completion_status") != "usage-limit":
            if all(row.get(k) == v for k, v in want.items()):
                sys.exit(0)
            state = 2
sys.exit(state)
PYEOF
}

# supersede_run RUN_ID: move the stale non-usage-limit row(s) of the run id from the results file to SUPERSEDED,
# which the scorer never reads. Usage-limit rows stay where they are.
supersede_run() {
  python3 -I - "$RESULTS" "$SUPERSEDED" "$1" <<'PYEOF'
import json, os, sys

path, dest, run_id = sys.argv[1:4]
keep, moved = [], []
with open(path) as f:
    for line in f:
        s = line.strip()
        if not s:
            continue
        row = json.loads(s)
        stale = row.get("run_id") == run_id and row.get("completion_status") != "usage-limit"
        (moved if stale else keep).append(s)
if not moved:
    sys.exit(1)
with open(dest, "a") as f:
    for s in moved:
        f.write(s + "\n")
tmp = path + ".tmp"
with open(tmp, "w") as f:
    for s in keep:
        f.write(s + "\n")
os.replace(tmp, path)
PYEOF
}
~~~~
6. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `      if done_run "$run_id"; then`
   indent: 0
   before:
~~~~
      if done_run "$run_id"; then
        skipped=$((skipped + 1))
        [ "$DRY" -eq 1 ] && echo "plan: $run_id skip"
        continue
      fi
      if [ "$DRY" -eq 1 ]; then echo "plan: $run_id run"; continue; fi
~~~~
   after:
~~~~
      done_run "$run_id" "$arm" "$ev"; st=$?
      if [ "$st" -eq 0 ]; then
        skipped=$((skipped + 1))
        [ "$DRY" -eq 1 ] && echo "plan: $run_id skip"
        continue
      fi
      if [ "$DRY" -eq 1 ]; then
        if [ "$st" -eq 2 ]; then echo "plan: $run_id rerun (stale provenance)"; else echo "plan: $run_id run"; fi
        continue
      fi
      if [ "$st" -eq 2 ]; then
        supersede_run "$run_id" || exit 1
        echo "run-matrix: $run_id had a row from another harness, plugin or prompt; moved to $SUPERSEDED"
      fi
~~~~
7. file: `tests/abtest-runner.test.sh`
   anchor: line matching `check "zero reps exits 2" "$?" "2"`
   indent: 0
   insert-after:
~~~~
# --- provenance (abt-u12c, OD-14): a row from another harness, plugin or prompt is repeated, never reused ---
SUP="$T/results.superseded.jsonl"
restamp() {
  python3 -I - "$ABT_RESULTS" "$1" "$2" "$3" << 'PYEOF'
import json, sys

path, run_id, key, value = sys.argv[1:5]
rows = [json.loads(l) for l in open(path) if l.strip()]
for r in rows:
    if r["run_id"] == run_id:
        r[key] = None if value == "null" else value
with open(path, "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
PYEOF
}
fresh() { rm -rf "$ABT_RESULTS" "$SUP" "$T/flog" "$T/work"; bash "$RUN" --pilot --evals $E > /dev/null; }
fresh
out="$(bash "$RUN" --pilot --evals $E)"
has "rows with the current provenance are skipped, arm A included" "$out" "runs=0 skipped=2"
check "a skipped pilot leaves no superseded file" "$(test -e "$SUP" && echo made || echo none)" "none"
restamp "$E/A/uniform/1" harness_commit stale
out="$(bash "$RUN" --pilot --evals $E --dry-run)"
has "a stale harness commit is planned as a rerun" "$out" "plan: $E/A/uniform/1 rerun (stale provenance)"
has "a matching row next to it is still skipped" "$out" "plan: $E/B/uniform/1 skip"
check "a dry run moves nothing" "$(test -e "$SUP" && echo made || echo none)|$(col "$ABT_RESULTS" 1 harness_commit)" "none|stale"
out="$(bash "$RUN" --pilot --evals $E)"
has "the stale row is repeated and the matching one skipped" "$out" "runs=1 skipped=1"
has "the move is announced" "$out" "had a row from another harness, plugin or prompt"
check "the repeated row carries the current harness commit" "$(col "$ABT_RESULTS" 2 harness_commit)" "$(git -C "$REPO_ROOT" rev-parse HEAD)"
check "the results file holds one row per run id" "$(ids "$ABT_RESULTS")" "$E/B/uniform/1 $E/A/uniform/1"
check "the stale row is kept in the superseded file" "$(ids "$SUP")|$(col "$SUP" 1 harness_commit)" "$E/A/uniform/1|stale"
check "the scorer's validator accepts the results file" "$(python3 -I "$REPO_ROOT/eval/abtest/score.py" --validate-rows "$ABT_RESULTS" | tail -n1)" "rows ok: 2"
out="$(bash "$RUN" --pilot --evals $E)"
has "a second resume skips both runs again" "$out" "runs=0 skipped=2"
fresh
restamp "$E/B/uniform/1" plugin_commit stale
out="$(bash "$RUN" --pilot --evals $E)"
has "a stale plugin commit repeats arm B only" "$out" "runs=1 skipped=1"
check "arm B was repeated and its stale row superseded" "$(ids "$SUP")|$(col "$ABT_RESULTS" 2 plugin_commit | grep -cE '^[0-9a-f]{40}$')" "$E/B/uniform/1|1"
fresh
restamp "$E/A/uniform/1" prompt_sha stale
out="$(bash "$RUN" --pilot --evals $E)"
has "a stale prompt hash repeats the run" "$out" "runs=1 skipped=1"
check "the stale prompt row is superseded" "$(ids "$SUP")" "$E/A/uniform/1"
fresh
restamp "$E/A/uniform/1" plugin_commit abc
out="$(bash "$RUN" --pilot --evals $E)"
has "a plugin commit on an arm A row is stale" "$out" "runs=1 skipped=1"
check "arm A is repeated with no plugin commit" "$(col "$ABT_RESULTS" 2 plugin_commit)" "None"
fresh
restamp "$E/B/uniform/1" plugin_commit null
out="$(bash "$RUN" --pilot --evals $E)"
has "no plugin commit on an arm B row is stale" "$out" "runs=1 skipped=1"
fresh
restamp "$E/A/uniform/1" completion_status usage-limit
restamp "$E/A/uniform/1" harness_commit stale
out="$(bash "$RUN" --pilot --evals $E)"
has "a usage-limit row is repeated without being superseded" "$out" "runs=1 skipped=1"
check "the usage-limit row stays in the results file" "$(ids "$ABT_RESULTS")" "$E/A/uniform/1 $E/B/uniform/1 $E/A/uniform/1"
check "a usage-limit row creates no superseded file" "$(test -e "$SUP" && echo made || echo none)" "none"
fresh
python3 -I - "$ABT_RESULTS" "$E/A/uniform/1" << 'PYEOF'
import json, sys

path, rid = sys.argv[1:3]
rows = [json.loads(l) for l in open(path) if l.strip()]
a = next(r for r in rows if r["run_id"] == rid)
lim = dict(a, completion_status="usage-limit", run_pass=False)
a["harness_commit"] = "stale"
with open(path, "w") as f:
    for r in [lim] + rows:
        f.write(json.dumps(r) + "\n")
PYEOF
bash "$RUN" --pilot --evals $E > /dev/null
check "a usage-limit row of the same run id stays when the stale row is superseded" "$(ids "$ABT_RESULTS")|$(ids "$SUP")|$(col "$SUP" 1 completion_status)" "$E/A/uniform/1 $E/B/uniform/1 $E/A/uniform/1|$E/A/uniform/1|complete"
~~~~
8. file: `tests/abtest-runner.test.sh`
   anchor: line matching `check "a usage-limit row of the same run id stays when the stale row is superseded" "$(ids "$ABT_RESULTS")|$(ids "$SUP")|$(col "$SUP" 1 completion_status)" "$E/A/uniform/1 $E/B/uniform/1 $E/A/uniform/1|$E/A/uniform/1|complete"`
   indent: 0
   insert-after:
~~~~
fresh
restamp "$E/A/uniform/1" harness_commit stale
ABT_SUPERSEDED="$T/elsewhere.jsonl" bash "$RUN" --pilot --evals $E > /dev/null
check "ABT_SUPERSEDED chooses the file for the stale rows" "$(ids "$T/elsewhere.jsonl")|$(test -e "$SUP" && echo made || echo none)" "$E/A/uniform/1|none"
~~~~
9. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$RUNS/config"`
   before: `  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$RUNS/config"`
   after: `  [ -n "${ABTEST_CONFIG_DIR:-}" ] || ABTEST_CONFIG_DIR="$WORK/config"`
10. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `PLUGIN_ROOT="${ABT_PLUGIN_ROOT:-$ABT_REPO_ROOT}"`
   indent: 0
   insert-after:
~~~~
# The arms may not read the results or the runs (OD-16): the arm scripts turn these paths into deny rules.
export ABTEST_DENY_PATHS="$RESULTS:$RUNS${ABTEST_DENY_PATHS:+:$ABTEST_DENY_PATHS}"
~~~~
11. file: `tests/abtest-runner.test.sh`
   anchor: line matching `check "ABT_SUPERSEDED chooses the file for the stale rows"`
   indent: 0
   insert-after:
~~~~
fresh
check "the config dir is made under the work root, not under the runs directory" "$(test -d "$ABT_WORK/config" && test ! -e "$ABT_RUNS/config" && echo work)" "work"
tr '\0' '\n' < "$T/flog/argv.1" > "$T/argv-first"
TP="$(cd "$T" && pwd -P)"
check "the arms are denied Read of the runs directory" "$(grep -cxF "Read(/$TP/runs/**)" "$T/argv-first")" "1"
check "the arms are denied Read of the results file" "$(grep -cxF "Read(/$TP/results.jsonl)" "$T/argv-first")" "1"
~~~~
12. command: `git add eval/abtest/run-matrix.sh tests/abtest-runner.test.sh && git commit -m "fix(abt-u12c): a resume repeats a run whose row has another harness, plugin or prompt and moves the stale row aside (#606)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/score.py` and `tests/abtest-score.test.sh` (the scorer side of OD-14 is abt-u14b)
- `eval/abtest/arms/`, `eval/abtest/lib/` (the arm scripts, make-row.py and rc.sh are other units)
- `eval/abtest/checks/`, `eval/abtest/fixtures/` (no fixture or check changes)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` and the rest of `docs/plans/` (OD-14 is already written; never edit a plan by hand)

## Acceptance criteria
1. run: `bash tests/abtest-runner.test.sh`
   exit: 0
   stdout: `All abtest-runner checks passed.`
   mutation: skip edit 5 (the provenance test of done_run); the provenance rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix of 19 single edits to the finished run-matrix.sh, run in a scratch copy, each making bash tests/abtest-runner.test.sh exit non-zero: R1 to R3 stop comparing the harness commit, the plugin commit or the prompt hash; R4 make arm A want a plugin commit; R5 stop mapping the null plugin to none; R6 treat a usage-limit row as done; R7 stop reporting a stale row; R8 accept any one matching field; R9 hide the rerun in a dry run; R10 skip the supersede call; R11 keep the stale row in the results file; R12 supersede usage-limit rows too; R13 write nothing to the superseded file; R14 drop the other rows; R15 ignore ABT_SUPERSEDED; R16 and R17 read not-found or stale as done; R18 drop the announcement; R21 read a missing results file as done. Two edits are not claimed because the tests cannot tell them apart when this unit lands: taking the prompt hash from another eval's prompt (only the E1 fixture exists) and taking the plugin commit from the harness checkout (the tests use one checkout for both)
2. run: `bash tests/abtest-runner.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `122`
   mutation: skip edit 5; the provenance rows FAIL and the count drops below 122.
3. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   a stale harness commit is planned as a rerun'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6 (the loop that plans and supersedes); the dry run prints run instead of rerun, the row prints FAIL and the count is 0 (exit 1).
4. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   the stale row is kept in the superseded file'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; nothing is moved, the superseded file is missing, the row prints FAIL and the count is 0 (exit 1).
5. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   the scorer.s validator accepts the results file'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the stale row stays beside the new one, the validator reports a duplicate run_id and the count is 0 (exit 1).
6. run: `grep -c '^SUPERSEDED=' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; the variable is absent, stdout 0 and the exit is 1.
7. run: `grep -c '^supersede_run()' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the function is absent, stdout 0 and the exit is 1.
8. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   a usage-limit row of the same run id stays when the stale row is superseded'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the stale row is never moved, the results file keeps both rows of the run id, the row prints FAIL and the count is 0 (exit 1).
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   mutation: skip edit 12 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 12; no unit commit exists and the exit is 3.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/run-matrix.sh tests/abtest-runner.test.sh | grep -vcE "^[a-z]+\(abt-u12c\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 12; the new files stay untracked and are listed.
13. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   the config dir is made under the work root'`
   exit: 0
   stdout: `1`
   mutation: skip edit 9 (the config dir line); the runner still makes the config dir under the runs directory, the row prints FAIL and the count is 0 (exit 1).
14. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   the arms are denied Read of'`
   exit: 0
   stdout: `2`
   mutation: skip edit 10 (the export of ABTEST_DENY_PATHS); the arms get no extra deny paths, the rows print FAIL and the count is 0 (exit 1).

## Pre-resolved context
tdd: yes tests/abtest-runner.test.sh (criteria 2 to 8 are the red-then-green checks: the provenance rows and functions do not exist at HEAD)
blast-radius: eval/abtest/run-matrix.sh:78, eval/abtest/run-matrix.sh:275, eval/abtest/run-matrix.sh:90
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 passes at HEAD only before the new rows exist, and criterion 12 (the scoped clean-tree check) passes at HEAD by design; criteria 2 to 8 fail at HEAD.
extends-landed-code: abt-u12, its fix abt-u12-fix1 and abt-u12b must have landed (edit 1 checks check_work_root and run_guarded and STOPs otherwise); every anchor and replaced block is taken from the tree after both. done_run, the resume comment, the Env comment and the loop are replaced; one variable and the proof rows are inserted.
od-14: PROVENANCE (operator decision). A pilot row counts as rep 1 and a resume skips run ids already done, so a harness, plugin or prompt fix after the pilot would mix pre-fix rep 1 with post-fix reps 2 to 5. A run id is now done only if a non-usage-limit row for it has the same harness_commit (git rev-parse HEAD of this checkout), plugin_commit (git rev-parse HEAD of ABT_PLUGIN_ROOT for arm B; arm A must carry none, null) and prompt_sha (sha256 of the eval prompt file) as now. Otherwise the run is repeated and the stale row is moved to results.superseded.jsonl (ABT_SUPERSEDED), so the scorer, which reads only results.jsonl, never sees it and run ids stay unique. A usage-limit row is never superseded and never counts as done. A dry run only reports plan: <run id> rerun (stale provenance).
not-checked: fixture_commit is not compared here (the scorer compares it; a fixture change changes the baseline sha, which the fixture build already fixes), and a dirty working tree is not detected; the harness commit is the checkout HEAD.
fail-closed: every row compares an explicit expected value; a crash or empty output reads as FAILURE. A move that cannot write exits 1 before any run starts.
no-real-claude: no command in this contract runs the real claude CLI; the rows use the fake claude of abt-u12.
commit-message: fix(abt-u12c): a resume repeats a run whose row has another harness, plugin or prompt and moves the stale row aside (#606)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u12c (#606)
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
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
