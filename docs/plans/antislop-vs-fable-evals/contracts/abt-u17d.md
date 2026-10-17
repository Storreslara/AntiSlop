Unit: abt-u17d

## Objective
`eval/abtest/README.md` numbers its steps 1-7 with the canary probe as a real step 2 that says what to do on each probe outcome, and the two stale header comments of `eval/abtest/run-matrix.sh` match its real behaviour. No code line of `run-matrix.sh` changes.

## Retrieval
GitHub issues: `gh issue view 618 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`. Umbrella: `gh issue view 567 --repo Storreslara/AntiSlop`.

## Affected files
- `eval/abtest/README.md` (anchor: line matching `1b. Canary probe:`)
- `eval/abtest/run-matrix.sh` (anchor: line matching `print the plan (run / skip per run id) and exit; starts nothing`)

## Ordered edits
1. command: `grep -qF '1b. Canary probe:' eval/abtest/README.md && git diff --quiet HEAD -- eval/abtest/README.md eval/abtest/run-matrix.sh`
   expect: 0
2. file: `eval/abtest/README.md`
   anchor: line matching `1b. Canary probe:`
   before: `1b. Canary probe:`
   after: `2. Canary probe:`
3. file: `eval/abtest/README.md`
   anchor: line matching `directories and fails if either arm prints it. The runner does not enforce this order: read the exit code.`
   indent: 0
   before:
~~~~
directories and fails if either arm prints it. The runner does not enforce this order: read the exit code.
~~~~
   after:
~~~~
directories and fails if either arm prints it. The runner does not enforce this order: read the exit code.
   - Exit 1 with `A=not-run` or `B=not-run`: that arm did not finish. Read the summary under `eval/abtest/.runs/probe-canary/A` or `eval/abtest/.runs/probe-canary/B`, fix the cause and rerun the probe. Do not run the pilot.
   - Exit 1 with `A=FOUND` or `B=FOUND`: isolation is broken. Do not run the pilot; report it.
   - Exit 75: a usage limit was reached. Wait for the subscription window to reset and rerun the probe.
~~~~
4. file: `eval/abtest/README.md`
   anchor: line matching `2. Check the fixtures:`
   before: `2. Check the fixtures:`
   after: `3. Check the fixtures:`
5. file: `eval/abtest/README.md`
   anchor: line matching `3. Pilot, one run per arm per eval:`
   before: `3. Pilot, one run per arm per eval:`
   after: `4. Pilot, one run per arm per eval:`
6. file: `eval/abtest/README.md`
   anchor: line matching `4. Full pass, five reps:`
   before: `4. Full pass, five reps:`
   after: `5. Full pass, five reps:`
7. file: `eval/abtest/README.md`
   anchor: line matching `5. Score (the scorer does not create the report directory):`
   before: `5. Score (the scorer does not create the report directory):`
   after: `6. Score (the scorer does not create the report directory):`
8. file: `eval/abtest/README.md`
   anchor: line matching `6. Grade the E1 judgment item:`
   before: `6. Grade the E1 judgment item:`
   after: `7. Grade the E1 judgment item:`
9. file: `eval/abtest/run-matrix.sh`
   anchor: line matching `print the plan (run / skip per run id) and exit; starts nothing`
   before: `print the plan (run / skip per run id) and exit; starts nothing`
   after: `print the plan (run, skip or rerun (stale provenance) per run id) and exit; starts nothing`
10. file: `eval/abtest/run-matrix.sh`
    anchor: line matching `ABT_WORK (default $TMPDIR/antislop-abtest-work)`
    before: `ABT_WORK (default $TMPDIR/antislop-abtest-work)`
    after: `ABT_WORK (default ${TMPDIR:-/tmp}/antislop-abtest-work)`
11. command: `bash -n eval/abtest/run-matrix.sh`
    expect: 0
12. command: `git add eval/abtest/README.md eval/abtest/run-matrix.sh && git commit -m "docs(abt-u17d): number the canary step 2, say what to do on each probe outcome, fix two runner header comments (#618)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
    expect: 0

## Do NOT touch
- `CHANGELOG.md` (a scribe owns the close-out entries; this unit adds none)
- `docs/harness-glossary.md`
- `eval/abtest/score.py` and every other file under `eval/abtest/` except `README.md` and `run-matrix.sh`
- `tests/` (every test file, including `tests/validate.sh` and `tests/abtest-runner.test.sh`)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `grep -cE '^2\. Canary probe: .bash eval/abtest/run-matrix\.sh --probe-canary. must exit 0 before the pilot' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout `0`, exit 1.
2. run: `grep -c '^1b\.' eval/abtest/README.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 2; stdout `1`, exit 0.
3. run: `grep -oE '^[0-9]+\.' eval/abtest/README.md | paste -sd' '`
   exit: 0
   stdout: `1. 2. 3. 4. 5. 6. 7.`
   mutation: skip edit 8; the list ends `6. 6.`.
4. run: `grep -cE '^6\. Score .*: .mkdir -p eval/reports && python3 eval/abtest/score\.py ' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; stdout `0`, exit 1.
5. run: `grep -cF 'B=not-run' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; stdout `0`, exit 1.
6. run: `grep -cF 'isolation is broken. Do not run the pilot; report it.' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; stdout `0`, exit 1.
7. run: `grep -cF 'Exit 75: a usage limit was reached. Wait for the subscription window to reset and rerun the probe.' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; stdout `0`, exit 1.
8. run: `grep -cF 'ABT_WORK (default ${TMPDIR:-/tmp}/antislop-abtest-work)' eval/abtest/run-matrix.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; stdout `0`, exit 1.
9. run: `grep -cF 'ABT_WORK (default $TMPDIR/' eval/abtest/run-matrix.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 10; stdout `1`, exit 0.
10. run: `grep -cF '(run, skip or rerun (stale provenance) per run id)' eval/abtest/run-matrix.sh`
    exit: 0
    stdout: `1`
    mutation: skip edit 9; stdout `0`, exit 1.
11. run: `bash -n eval/abtest/run-matrix.sh`
    exit: 0
    stdout: empty
    mutation: delete the leading `#` of the `--dry-run` header line (line 9); bash -n reports a syntax error and exits 2.
    proof: scratch run: `sed -i '9s/^#//' eval/abtest/run-matrix.sh; bash -n eval/abtest/run-matrix.sh` exited 2.
12. run: `bash tests/abtest-runner.test.sh | tail -n 2 | grep -cE '[0-9]+ passed, 0 failed|All abtest-runner checks passed\.'`
    exit: 0
    stdout: `2`
    mutation: delete the leading `#` of the `--dry-run` header line (line 9); the runner no longer parses and the suite does not end with the pass lines.
    proof: scratch run with line 9 uncommented: the suite did not print `All abtest-runner checks passed.`.
13. run: `echo "$(grep -c 'exit 75' eval/abtest/README.md) $(grep -c 'exit 76' eval/abtest/README.md) $(grep -c 'ABT_WORK' eval/abtest/README.md) $(grep -c '^## ' eval/abtest/README.md)"`
    exit: 0
    stdout: `1 1 1 5`
    mutation: change the `Exit 75:` bullet of edit 3 to `exit 75:`; the first number is 2.
14. run: `echo "$(grep -cF 'rerun (stale provenance)' eval/abtest/README.md) $(grep -cF 'cannot read the holdout checks' eval/abtest/README.md) $(grep -c 'hidden check' eval/abtest/README.md)"`
    exit: 0
    stdout: `1 1 0`
    mutation: change the `isolation is broken` bullet of edit 3 to contain `hidden check`; the last number is 1.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
    exit: 0
    stdout: `eval/abtest/README.md eval/abtest/run-matrix.sh`
    mutation: skip edit 12 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
    exit: 0
    stdout: `1`
    mutation: skip edit 12; no unit commit exists and the exit is 3.
17. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/README.md eval/abtest/run-matrix.sh | grep -vcE '^[a-z]+\(abt-u17d\): '`
    exit: 1
    stdout: `0`
    mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
    proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
18. run: `git status --porcelain -- eval/abtest/README.md eval/abtest/run-matrix.sh`
    exit: 0
    stdout: empty
    mutation: skip edit 12; the two files stay modified and are listed.

## Pre-resolved context
tdd: no comment and prose edits only; criteria 1-10 are red before the edits and criterion 12 proves the runner suite stays green
blast-radius: eval/abtest/README.md:35
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every edit with the Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing. The three bullet lines of edit 3 keep their three leading spaces.
already-green: criteria 11, 13, 14 and 18 pass at HEAD by design (13 and 14 guard the abt-u17 and abt-u17c README greps; 11 and 12 guard the runner).
slow: criterion 12 runs the runner suite in about two minutes.
no-real-claude: nothing here runs the claude CLI.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry.
superseded-greps: the abt-u17c criteria 1 (`^1b\.`) and 2 (`^5\. Score`) are replaced by criteria 1 and 4 here; abt-u17c is landed and reviewed.
abt-u12d-interaction: abt-u12d (#617) edits `hits="$(limit_hits "$run_id")" || exit 1` and the line `# instead of repeating forever.` of run-matrix.sh; this unit edits header lines 9 and 27 only, so no anchor is shared and the two units may land in either order. abt-u12d's edit-1 command needs a clean tree for run-matrix.sh, so commit this unit before running it.
commit-message: docs(abt-u17d): number the canary step 2, say what to do on each probe outcome, fix two runner header comments (#618)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u17d (#618)
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
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
