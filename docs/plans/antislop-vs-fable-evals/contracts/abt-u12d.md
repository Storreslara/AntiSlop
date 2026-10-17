Unit: abt-u12d

## Objective
`eval/abtest/run-matrix.sh` checks the usage-limit cap before it moves a stale row to the superseded file, so a run id at the cap keeps its row and the runner exits 76 without touching the results; `tests/abtest-runner.test.sh` proves it.

## Retrieval
GitHub issues: `gh issue view 617 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`. Umbrella: `gh issue view 567 --repo Storreslara/AntiSlop`.

## Affected files
- `eval/abtest/run-matrix.sh` (anchor: line matching `hits="$(limit_hits "$run_id")" || exit 1`)
- `tests/abtest-runner.test.sh` (anchor: line matching `check "a usage-limit row of the same run id stays when the stale row is superseded"`)

## Ordered edits
1. command: `grep -qF 'hits="$(limit_hits "$run_id")" || exit 1' eval/abtest/run-matrix.sh && git diff --quiet HEAD -- eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   expect: 0
2. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `hits="$(limit_hits "$run_id")" || exit 1`
   indent: 0
   before:
~~~~
      if [ "$st" -eq 2 ]; then
        supersede_run "$run_id" || exit 1
        echo "run-matrix: $run_id had a row from another harness, plugin or prompt; moved to $SUPERSEDED"
      fi
      hits="$(limit_hits "$run_id")" || exit 1
      if [ "$hits" -ge "$MAX_LIMIT_HITS" ]; then
        echo "run-matrix: $run_id was classified usage-limit $hits times; read $RUNS/${run_id//\//_}/stream.jsonl before retrying (raise ABT_MAX_LIMIT_HITS to try again)" >&2
        exit 76
      fi
~~~~
   after:
~~~~
      hits="$(limit_hits "$run_id")" || exit 1
      if [ "$hits" -ge "$MAX_LIMIT_HITS" ]; then
        echo "run-matrix: $run_id was classified usage-limit $hits times; read $RUNS/${run_id//\//_}/stream.jsonl before retrying (raise ABT_MAX_LIMIT_HITS to try again)" >&2
        exit 76
      fi
      if [ "$st" -eq 2 ]; then
        supersede_run "$run_id" || exit 1
        echo "run-matrix: $run_id had a row from another harness, plugin or prompt; moved to $SUPERSEDED"
      fi
~~~~
3. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `# instead of repeating forever.`
   insert-after: `# The cap is checked before a stale row is moved, so a capped run id keeps its row.`
4. file: `tests/abtest-runner.test.sh`
   anchor: line matching `check "a usage-limit row of the same run id stays when the stale row is superseded"`
   indent: 0
   insert-after:
~~~~
fresh
restamp "$E/A/uniform/1" harness_commit stale
python3 -I - "$ABT_RESULTS" "$E" << 'PYEOF'
import json, sys

with open(sys.argv[1], "a") as f:
    for _ in range(3):
        f.write(json.dumps({"run_id": f"{sys.argv[2]}/A/uniform/1", "completion_status": "usage-limit"}) + "\n")
PYEOF
held="$(cksum < "$ABT_RESULTS")"
rm -rf "$T/flog"
bash "$RUN" --pilot --evals $E > /dev/null 2>&1; rc=$?
check "capped stale row: the runner stops with exit 76" "$rc" "76"
check "capped stale row: the results file is unchanged" "$(cksum < "$ABT_RESULTS")" "$held"
check "capped stale row: no superseded file is made" "$(test -e "$SUP" && echo made || echo none)" "none"
check "capped stale row: no claude is started" "$(test -e "$T/flog" && echo ran || echo none)" "none"
~~~~
5. command: `git add eval/abtest/run-matrix.sh tests/abtest-runner.test.sh && git commit -m "fix(abt-u12d): check the usage-limit cap before a stale row is moved (#617)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `CHANGELOG.md` (a scribe owns the close-out entries; this unit adds none)
- `docs/harness-glossary.md`
- `eval/abtest/README.md`, `eval/abtest/score.py` and every other file under `eval/abtest/` except `run-matrix.sh`
- `tests/validate.sh`, `tests/validate-lanes.sh` and every test other than `tests/abtest-runner.test.sh`
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-runner.test.sh | grep -c '^ok   capped stale row: '`
   exit: 0
   stdout: `4`
   mutation: skip edit 2 (the reorder); the results-file and exit rows FAIL, so stdout is 2.
   proof: scratch run with edit 4 applied and edit 2 skipped: the exit stays 76 but the stale row was moved, so the unchanged-results and no-superseded rows FAIL.
2. run: `bash tests/abtest-runner.test.sh | tail -n 2 | paste -sd' '`
   exit: 0
   stdout: `abtest-runner: 126 passed, 0 failed All abtest-runner checks passed.`
   mutation: skip edit 4 (the test rows); the summary reads 122 passed.
3. run: `awk '/hits="\$\(limit_hits/{h=NR} /supersede_run "\$run_id"/{s=NR} END{print (h>0 && s>h) ? "cap-first" : "supersede-first"}' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `cap-first`
   mutation: skip edit 2; stdout `supersede-first`.
4. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   mutation: skip edit 5 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; no unit commit exists and the exit is 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u12d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/run-matrix.sh tests/abtest-runner.test.sh | grep -vcE '^[a-z]+\(abt-u12d\): '`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
7. run: `git status --porcelain -- eval/abtest/run-matrix.sh tests/abtest-runner.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 5; the two files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-runner.test.sh (criterion 1 is the red-then-green check: the four `capped stale row:` rows do not exist at HEAD and two of them FAIL without edit 2)
blast-radius: eval/abtest/run-matrix.sh:593
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every edit with the Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract states indent: 0; strip nothing; empty payload lines stay empty.
already-green: the scoped clean-tree check (criterion 7) passes at HEAD by design.
slow: criteria 1 and 2 each run the suite, about 140 seconds each; do not shorten it.
foreground-only: run the suite in the foreground; a shell background job ignores SIGINT and the two `SIGINT` rows then FAIL (an artifact, not a defect of this unit).
why-safe: `limit_hits` counts only usage-limit rows and `supersede_run` moves only non-usage-limit rows, so the count is the same before and after a move; running the cap check first changes nothing else.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump.
commit-message: fix(abt-u12d): check the usage-limit cap before a stale row is moved (#617)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u12d (#617)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
