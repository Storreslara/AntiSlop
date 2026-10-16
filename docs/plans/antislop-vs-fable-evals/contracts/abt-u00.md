Unit: abt-u00

## Objective
docs/plans/antislop-vs-fable-evals.md, the finalized design, is tracked in git by one docs commit with its text unchanged.

## Retrieval
GitHub issues: `gh issue view 568 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `docs/plans/antislop-vs-fable-evals.md` (anchor: line matching `# AntiSlop vs. bare Fable: a ten-eval comparison suite (design only)`)

## Ordered edits
1. command: `test -f docs/plans/antislop-vs-fable-evals.md && test -z "$(git ls-files -- docs/plans/antislop-vs-fable-evals.md)"`
   expect: 0
2. command: `git add docs/plans/antislop-vs-fable-evals.md && git commit -m "docs(abt-u00): commit the AntiSlop-vs-Fable eval design (#568)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `docs/plans/antislop-vs-fable-evals.md` (stage and commit it byte for byte; never edit its text)
- `docs/plans/antislop-vs-fable-evals/` (operator-decisions.md and the contract files are already committed; do not restage them)
- `eval/`, `tests/`, `agents/`, `templates/` (this unit changes no code)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump)

## Acceptance criteria
1. run: `git ls-files --error-unmatch docs/plans/antislop-vs-fable-evals.md`
   exit: 0
   stdout: `docs/plans/antislop-vs-fable-evals.md`
   mutation: skip edit 2 (the commit); the file stays untracked, git exits 1 and prints an error to stderr only.
2. run: `git log -1 --format=%s`
   exit: 0
   stdout: `docs(abt-u00): commit the AntiSlop-vs-Fable eval design (#568)`
   mutation: skip edit 2; the newest commit is another unit's and the subject differs.
3. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u00\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `docs/plans/antislop-vs-fable-evals.md`
   mutation: skip edit 2 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
4. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u00\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; no unit commit exists and the exit is 3.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u00\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- docs/plans/antislop-vs-fable-evals.md | grep -vcE "^[a-z]+\(abt-u00\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
6. run: `git status --porcelain -- docs/plans/antislop-vs-fable-evals.md`
   exit: 0
   stdout: empty
   mutation: skip edit 2; the new files stay untracked and are listed.

## Pre-resolved context
tdd: no docs-only commit of an existing file
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
staging: the commit command stages the one explicit path; if git status shows other untracked files, leave them alone.
commit-message: docs(abt-u00): commit the AntiSlop-vs-Fable eval design (#568)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u00 (#568)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
