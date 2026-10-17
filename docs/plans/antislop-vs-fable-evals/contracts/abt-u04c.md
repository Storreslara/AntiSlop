Unit: abt-u04c

## Objective
The header of eval/abtest/checks/lib.sh lists ABT_SNAPSHOT beside ABT_WT, ABT_BASE, ABT_START and ABT_CHECKS_DIR, and the E5 build script is committed mode 755 like the other four build scripts; the checks test still passes. One commit.

## Retrieval
GitHub issues: `gh issue view 614 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/lib.sh` (anchor: line matching `directory holding the holdout files). Exit 0 means the check passed.`)
- `eval/abtest/fixtures/e05-tags-feature/build.sh` (anchor: line matching `abt_fixture_baseline "$dest"`)

## Ordered edits
1. command: `grep -c ABT_SNAPSHOT eval/abtest/checks/lib.sh | grep -qx 0 && test ! -x eval/abtest/fixtures/e05-tags-feature/build.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/checks/lib.sh`
   anchor: line matching `directory holding the holdout files). Exit 0 means the check passed.`
   indent: 0
   insert-after:
~~~~
# The runner also exports ABT_SNAPSHOT, the number of commits its dirty-tree snapshot added ahead of
# the arm's own work (0 when unset); the E5 commit-count check subtracts it from its commit count.
~~~~
3. command: `chmod +x eval/abtest/fixtures/e05-tags-feature/build.sh`
   expect: 0
4. command: `git add eval/abtest/checks/lib.sh eval/abtest/fixtures/e05-tags-feature/build.sh && git commit -m "chore(abt-u04c): the checks library header lists ABT_SNAPSHOT and the E5 build script is executable (#614)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/e05-tags-feature/` (abt-u11c owns check.sh and its mode)
- `docs/harness-glossary.md` and `CONTEXT.md` (the glossary sentence is corrected in the close-out commit)
- `tests/abtest-checks.test.sh` and `eval/abtest/verify-checks.sh` (no behaviour changes here)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `grep -c ABT_SNAPSHOT eval/abtest/checks/lib.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout 0 and the exit is 1.
2. run: `bash -n eval/abtest/checks/lib.sh && bash tests/abtest-checks.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: insert the two header lines without their leading # (the text breaks the sourced file); bash -n exits 2 and nothing prints.
   proof: scratch run in a clone with the finished change and the # removed from the second inserted line: bash -n printed a syntax error and exited 2.
3. run: `git ls-files -s eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e02-preview-mutation/build.sh eval/abtest/fixtures/e03-rename-query/build.sh eval/abtest/fixtures/e04-search-injection/build.sh eval/abtest/fixtures/e05-tags-feature/build.sh | grep -c '^100755'`
   exit: 0
   stdout: `5`
   mutation: skip edit 4 (the commit); the index still holds 100644 for the E5 script and stdout is 4.
4. run: `test -x eval/abtest/fixtures/e05-tags-feature/build.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 3; the script is mode 644 and nothing prints.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/lib.sh eval/abtest/fixtures/e05-tags-feature/build.sh`
   mutation: skip edit 4 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; no unit commit exists and the exit is 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04c\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/lib.sh eval/abtest/fixtures/e05-tags-feature/build.sh | grep -vcE "^[a-z]+\(abt-u04c\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
8. run: `git status --porcelain -- eval/abtest/checks/lib.sh eval/abtest/fixtures/e05-tags-feature`
   exit: 0
   stdout: empty
   mutation: skip edit 4; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no a comment and a file mode; criteria 1 and 4 are red at HEAD
blast-radius: eval/abtest/checks/e05-tags-feature/check.sh:13
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: the scoped clean-tree check (the last criterion) passes at HEAD by design; criterion 2 passes at HEAD (the library works today) and only turns red when the inserted text is not a comment.
glossary: docs/harness-glossary.md says the library "does not yet list" ABT_SNAPSHOT; that sentence is stale after this unit and is corrected in the close-out glossary commit, not here (this unit edits no docs).
check-sh-mode: eval/abtest/checks/e05-tags-feature/check.sh is made executable by abt-u11c (it edits that file); do not touch it here.
no-real-claude: nothing here runs the claude CLI.
commit-message: chore(abt-u04c): the checks library header lists ABT_SNAPSHOT and the E5 build script is executable (#614)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u04c (#614)
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
