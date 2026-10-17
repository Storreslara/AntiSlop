Unit: abt-u08b

## Objective
The E2 package.json description reads "Minimal library with no external dependencies." (the word fixture is gone from what an arm can read, as in E1), build.sh fails closed if package.json ever names the eval, the tool or a fixture, and verify-checks still proves E2 (2/4 baseline failures, 0/4 on the reference). One commit.

## Retrieval
GitHub issues: `gh issue view 610 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/fixtures/e02-preview-mutation/build.sh` (anchor: line matching `Minimal fixture library with no external dependencies.",|`)

## Ordered edits
1. command: `grep -c 'Minimal fixture library' eval/abtest/fixtures/e02-preview-mutation/build.sh | grep -qx 2 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/fixtures/e02-preview-mutation/build.sh`
   anchor: line matching `Minimal fixture library with no external dependencies.",|`
   before: `sed -i 's|^\(  "description": \).*$|\1"Minimal fixture library with no external dependencies.",|' "$dest/package.json"`
   after: `sed -i 's|^\(  "description": \).*$|\1"Minimal library with no external dependencies.",|' "$dest/package.json"`
3. file: `eval/abtest/fixtures/e02-preview-mutation/build.sh`
   anchor: line matching `Minimal fixture library with no external dependencies."'`
   before: `grep -qF '"description": "Minimal fixture library with no external dependencies."' "$dest/package.json" || { echo "build: package.json description was not replaced" >&2; exit 1; }`
   after: `grep -qF '"description": "Minimal library with no external dependencies."' "$dest/package.json" || { echo "build: package.json description was not replaced" >&2; exit 1; }`
4. file: `eval/abtest/fixtures/e02-preview-mutation/build.sh`
   anchor: line matching `package.json description was not replaced`
   indent: 0
   insert-after:
~~~~
# The leak guard reads the history for the word fixture but not package.json, so check the file here.
if grep -qiE 'antislop|eval|pilot|claude|fixture' "$dest/package.json"; then
  echo "build: package.json names the eval or the tool" >&2
  exit 1
fi
~~~~
5. command: `git add eval/abtest/fixtures/e02-preview-mutation/build.sh && git commit -m "fix(abt-u08b): the E2 package description no longer says fixture (#610)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/fixtures/lib.sh` (the leak guard keeps scanning the history for fixture, not package.json; E2 checks its own description here)
- `eval/abtest/fixtures/e02-preview-mutation/plant/`, `reference.patch` and `allowed-paths.txt` (the plant and the reference do not change)
- `eval/abtest/checks/` and `eval/fixtures/toy-lib-template/` (the checks and the template stay as they are)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `D=$(mktemp -d); bash eval/abtest/fixtures/e02-preview-mutation/build.sh "$D/w" > /dev/null; grep -rilw fixture "$D/w" --exclude-dir=.git | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip edit 2 (the sed line); the guard stops the build, the copied package.json still holds the word and stdout is 1.
2. run: `D=$(mktemp -d); cp -r eval/abtest/fixtures/e02-preview-mutation "$D/fx"; sed -i 's/Minimal library/Minimal fixture library/g' "$D/fx/build.sh"; ABT_REPO_ROOT="$PWD" bash "$D/fx/build.sh" "$D/w" 2>&1 | tail -n 1`
   exit: 0
   stdout: `build: package.json names the eval or the tool`
   mutation: skip edit 4 (the guard); the copy with the word builds and the last line is a commit sha.
3. run: `grep -c 'Minimal library with no external dependencies' eval/abtest/fixtures/e02-preview-mutation/build.sh`
   exit: 0
   stdout: `2`
   mutation: skip edit 2; stdout 1.
4. run: `bash eval/abtest/verify-checks.sh e02-preview-mutation`
   exit: 0
   stdout: `verify: e02-preview-mutation baseline-required-failures=2/4 reference-required-failures=0/4`
   mutation: skip edit 3 (the grep line); the build stops on its own check, verify prints a nondeterministic-build line and exits 1.
5. run: `bash eval/abtest/verify-checks.sh --all | tail -n 1`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: skip edit 3; the E2 build fails, the last line reads verify-checks: FAILED.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u08b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/fixtures/e02-preview-mutation/build.sh`
   mutation: skip edit 5 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u08b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u08b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/fixtures/e02-preview-mutation/build.sh | grep -vcE "^[a-z]+\(abt-u08b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest/fixtures/e02-preview-mutation`
   exit: 0
   stdout: empty
   mutation: skip edit 5; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no a build-script text edit; criteria 1 and 2 are red at HEAD and are the red-then-green check
blast-radius: eval/abtest/fixtures/e02-preview-mutation/build.sh:14
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criteria 4 and 5 pass at HEAD (the fixture builds today) and turn red only when an edit is skipped; criterion 9 (the scoped clean-tree check) passes at HEAD by design.
baseline-sha: the E2 baseline commit sha changes with the description; nothing in the repository pins it (checked: no file holds the old sha), and verify-checks compares two fresh builds, not a stored sha.
no-real-claude: nothing here runs the claude CLI.
commit-message: fix(abt-u08b): the E2 package description no longer says fixture (#610)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u08b (#610)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
