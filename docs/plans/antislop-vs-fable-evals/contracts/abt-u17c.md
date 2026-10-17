Unit: abt-u17c

## Objective
The operator README tells the operator to run the canary probe before the pilot, creates `eval/reports/` before scoring, and states the real `ABT_WORK` default, the `rerun (stale provenance)` dry-run line and the term "holdout checks"; `eval/abtest/results.superseded.jsonl` is git-ignored; the two `git commit --amend` lines of `tests/abtest-checks.test.sh` carry their own git identity, so the suite passes with an empty HOME and in CI.

## Retrieval
GitHub issues: `gh issue view 616 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`. Umbrella: `gh issue view 567 --repo Storreslara/AntiSlop`.

## Affected files
- `eval/abtest/README.md` (anchor: line matching `reply that merely mentions rate limits cannot be mistaken for a limit hit.`)
- `.gitignore` (anchor: line matching `eval/abtest/results.jsonl`)
- `tests/abtest-checks.test.sh` (anchor: line matching `lgrepo m4 "initial import"`)

## Ordered edits
1. command: `grep -qF 'reply that merely mentions rate limits cannot be mistaken for a limit hit.' eval/abtest/README.md && test ! -e eval/reports && ! git check-ignore -q eval/abtest/results.superseded.jsonl && git diff --quiet HEAD -- eval/abtest/README.md .gitignore tests/abtest-checks.test.sh`
   expect: 0
2. file: `eval/abtest/README.md`
   anchor: line matching `reply that merely mentions rate limits cannot be mistaken for a limit hit.`
   indent: 0
   insert-after:
~~~~
1b. Canary probe: `bash eval/abtest/run-matrix.sh --probe-canary` must exit 0 before the pilot (OD-16(c) in
   `docs/plans/antislop-vs-fable-evals/operator-decisions.md`). It plants a random token in the checks and fixtures
   directories and fails if either arm prints it. The runner does not enforce this order: read the exit code.
~~~~
3. file: `eval/abtest/README.md`
   anchor: line matching `5. Score: `
   indent: 0
   before:
~~~~
5. Score: `python3 eval/abtest/score.py eval/abtest/results.jsonl --out-json eval/reports/abtest-<date>.json --out-md eval/reports/abtest-<date>.md`.
~~~~
   after:
~~~~
5. Score (the scorer does not create the report directory): `mkdir -p eval/reports && python3 eval/abtest/score.py eval/abtest/results.jsonl --out-json eval/reports/abtest-<date>.json --out-md eval/reports/abtest-<date>.md`.
~~~~
4. file: `eval/abtest/README.md`
   anchor: line matching `(default `/tmp/antislop-abtest-work`)`
   indent: 0
   before:
~~~~
Each run is built as a standalone repository under `ABT_WORK` (default `/tmp/antislop-abtest-work`),
~~~~
   after:
~~~~
Each run is built as a standalone repository under `ABT_WORK` (default `${TMPDIR:-/tmp}/antislop-abtest-work`),
~~~~
5. file: `eval/abtest/README.md`
   anchor: line matching `--dry-run` prints the plan`
   indent: 0
   before:
~~~~
`usage-limit`, so only the unfinished runs repeat. `--dry-run` prints the plan (`run` or `skip` per run).
~~~~
   after:
~~~~
`usage-limit`, so only the unfinished runs repeat. `--dry-run` prints the plan (`run`, `skip` or `rerun (stale provenance)` per run).
~~~~
6. file: `eval/abtest/README.md`
   anchor: line matching `**Residual risk (OD-16).** The arms cannot read the hidden checks`
   indent: 0
   before:
~~~~
**Residual risk (OD-16).** The arms cannot read the hidden checks or the reference solutions by the ordinary
~~~~
   after:
~~~~
**Residual risk (OD-16).** The arms cannot read the holdout checks or the reference solutions by the ordinary
~~~~
7. file: `eval/abtest/README.md`
   anchor: line matching `- `results.jsonl` and `.runs/` are git-ignored.`
   indent: 0
   before:
~~~~
- `results.jsonl` and `.runs/` are git-ignored.
~~~~
   after:
~~~~
- `results.jsonl`, `results.superseded.jsonl` and `.runs/` are git-ignored.
~~~~
8. file: `.gitignore`
   anchor: line matching `eval/abtest/results.jsonl`
   insert-after: `eval/abtest/results.superseded.jsonl`
9. file: `tests/abtest-checks.test.sh`
   anchor: line matching `lgrepo m4 "initial import"`
   indent: 0
   before:
~~~~
lgrepo m4 "initial import"
git -C "$T/lg/hist" commit -q --amend -m "initial import" -m "the plant is here"
~~~~
   after:
~~~~
lgrepo m4 "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --amend -m "initial import" -m "the plant is here"
~~~~
10. file: `tests/abtest-checks.test.sh`
   anchor: line matching `lgrepo od "initial import"`
   indent: 0
   before:
~~~~
lgrepo od "initial import"
git -C "$T/lg/hist" commit -q --amend -m "initial import" -m "the plant is here"
~~~~
   after:
~~~~
lgrepo od "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --amend -m "initial import" -m "the plant is here"
~~~~
11. command: `git add eval/abtest/README.md .gitignore tests/abtest-checks.test.sh && git commit -m "docs(abt-u17c): canary step, report directory and README wording, ignore the superseded file, git identity in the leak-guard tests (#616)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `CHANGELOG.md` (a scribe edits it for the abt-u17 close-out; this unit adds no entry)
- `docs/harness-glossary.md`
- `eval/abtest/run-matrix.sh`, `eval/abtest/score.py` and every other file under `eval/abtest/` except `README.md`
- `tests/validate.sh`, `tests/validate-lanes.sh` and every test other than `tests/abtest-checks.test.sh`
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `grep -cE '^1b\. Canary probe: .bash eval/abtest/run-matrix\.sh --probe-canary. must exit 0 before the pilot' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout `0`, exit 1.
2. run: `grep -cE '^5\. Score .*: .mkdir -p eval/reports && python3 eval/abtest/score\.py ' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; stdout `0`, exit 1.
3. run: `git check-ignore -q eval/abtest/results.superseded.jsonl`
   exit: 0
   stdout: empty
   mutation: skip edit 8; exit 1.
4. run: `grep -cF '${TMPDIR:-/tmp}/antislop-abtest-work' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; stdout `0`, exit 1.
5. run: `grep -cF 'rerun (stale provenance)' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; stdout `0`, exit 1.
6. run: `grep -cF 'cannot read the holdout checks' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; stdout `0`, exit 1.
7. run: `grep -c 'hidden check' eval/abtest/README.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 6; stdout `1`, exit 0.
8. run: `D=$(mktemp -d); env HOME="$D" GIT_CONFIG_NOSYSTEM=1 bash tests/abtest-checks.test.sh | tail -n 2 | paste -sd' '`
   exit: 0
   stdout: `abtest-checks: 231 passed, 0 failed All abtest-checks checks passed.`
   mutation: skip edits 9 and 10; the two amend rows FAIL and the summary reads 229 passed, 2 failed.
   proof: scratch run at HEAD with an empty HOME printed `abtest-checks: 229 passed, 2 failed` (rc 2).
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `.gitignore eval/abtest/README.md tests/abtest-checks.test.sh`
   mutation: skip edit 11 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 11; no unit commit exists and the exit is 3.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/README.md .gitignore tests/abtest-checks.test.sh | grep -vcE '^[a-z]+\(abt-u17c\): '`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- eval/abtest/README.md .gitignore tests/abtest-checks.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 11; the three files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criterion 8 is the red-then-green check: the suite reports 229 passed, 2 failed with an empty HOME before edits 9 and 10)
blast-radius: eval/abtest/README.md:34
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every edit with the Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing.
already-green: criterion 7 and the scoped clean-tree check (criterion 12) pass or fail the expected way at HEAD by design: criterion 7 prints 1 (red) at HEAD; criterion 12 prints nothing.
slow: criterion 8 runs the suite in about 25 seconds.
no-real-claude: nothing here runs the claude CLI.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry; a scribe owns the abt-u17 close-out entries.
follow-ups-not-in-this-unit: the usage-limit cap check order in run-matrix.sh is abt-u12d (#617); adding abtest-runner to the heavy list of tests/validate-lanes.sh is left out because its effect on lane balance cannot be proved by a small check.
commit-message: docs(abt-u17c): canary step, report directory and README wording, ignore the superseded file, git identity in the leak-guard tests (#616)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u17c (#616)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
