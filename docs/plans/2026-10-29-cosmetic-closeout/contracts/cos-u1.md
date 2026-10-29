Unit: cos-u1

## Objective
Correct the two criteria of `docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md` that no longer match the tree: criterion 1 expects `ac=6` (the suite prints `ac=11` since tg-u2-fix1 added five cases), and criterion 6 checks `<first tg-u2 commit>^..HEAD`, which turns red as soon as a later unit (cos-u3) touches `agents/`. Afterwards `bin/review-precheck.sh` run with `--contract tg-u2.md --fix-contract tg-u2-fix1.md` and the baseline at HEAD prints `result=pass`. Criterion 2 is still correct and stays byte-identical.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-cosmetic-closeout.md` (Step 1, Context row 5, Open Question 1). This file is the contract of record.

## Affected files
- `docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md` (anchors: the line `   stdout: \`fails=0 ac=6 rc=0\``, and the line starting `6. run: \`bash -c 'b=$(git log --format=%H --grep="(tg-u2): "`)

These are the only paths in scope.

## Ordered edits
Use the Edit tool for both edits, never a Bash heredoc. Both were applied by spec-master in a scratch clone of ab174935, where every criterion below behaved as stated.

1. file: `docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md`
   anchor: line matching `   stdout: \`fails=0 ac=6 rc=0\``
   indent: 3
   before (the whole line; it occurs once):
~~~
   stdout: `fails=0 ac=6 rc=0`
~~~
   after (two lines; the `mutation:` line that follows stays as it is):
~~~
   stdout: `fails=0 ac=11 rc=0`
   amended 2026-10-29 (cos-u1): the expected count was `ac=6` when this contract was written; `contracts/tg-u2-fix1.md` added five (ac) cases, so the suite now prints `ac=11`, the same value as tg-u2-fix1.md criterion 1. The counts in the mutation line below are the original ones, against the six cases of this contract.
~~~

2. file: `docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md`
   anchor: line starting `6. run: \`bash -c 'b=$(git log --format=%H --grep="(tg-u2): "`
   indent: 0
   before:
~~~
6. run: `bash -c 'b=$(git log --format=%H --grep="(tg-u2): " | tail -1); [ -n "$b" ] || { echo no-commits; exit 1; }; bash hooks/scripts/version-stamp-check.sh "$b^..HEAD" | cut -d" " -f1-4'`
   exit: 0
   stdout: `version-stamp-check: ok touched: no`
   mutation: editing `agents/reviewer.md` in a `(tg-u2): ` commit prints `touched: yes` (with `violation`).
~~~
   after:
~~~
6. run: `bash -c 'cs=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(tg-u2\): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do bash hooks/scripts/version-stamp-check.sh "$c^..$c" | cut -d" " -f1-4; done | sort -u'`
   exit: 0
   stdout: `version-stamp-check: ok touched: no`
   amended 2026-10-29 (cos-u1): the original command checked `<first tg-u2 commit>^..HEAD`, so any later commit that touches `agents/*.md` (a different unit's) turned it red; it now checks each `(tg-u2): ` commit against its own parent, as tg-u2-fix1.md criterion 7 does.
   mutation: editing `agents/reviewer.md` in a `(tg-u2): ` commit adds a `version-stamp-check: violation touched: yes` line (or `ok touched: yes` with a bump), so the output is no longer the one line above.
~~~

3. command: `git add docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md && git commit -m "docs(cos-u1): tg-u2 contract criteria 1 and 6 match the tree after tg-u2-fix1"`
   expect: 0
   Run `git status --short` first; if any other tracked file is modified, leave it unstaged and report it.

## Do NOT touch
- `docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2-fix1.md`, `tg-u1.md`, `tg-u1-fix1.md` and the plan `docs/plans/2026-10-29-precheck-and-scope-gate-fixes.md`
- criterion 2 and every other line of `tg-u2.md` outside the two anchors
- `hooks/` (every hook and gate, `hooks/scripts/writer-scope-gate.sh` included), `bin/`, `tests/`, `.claude/`
- `eval/refutation-replay/labels.tsv`, `corpus.jsonl`, `report.jsonl`

## Acceptance criteria
1. run: `bash -c 'P=docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts; bash bin/review-precheck.sh cos-u1-check "$(git rev-parse HEAD)" --contract $P/tg-u2.md --fix-contract $P/tg-u2-fix1.md | head -n1 | cut -d" " -f2'`
   exit: 0
   stdout: `result=pass`
   mutation: with tg-u2.md as at ab174935 (no edit 1) the packet has `criterion 1: fail stdout want=fails=0 ac=6 rc=0 got=fails=0 ac=11 rc=0` and stdout is `result=fail` (spec-master ran it). With edit 1 but not edit 2, the same check run after cos-u3's commit prints `result=fail` from criterion 6. Run after the commit: the precheck reads the contract at the baseline commit.
2. run: `bash -c 'f=docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md; a=$(git show ab174935:$f | sed -n "/^2\. run:/,/^3\. run:/p" | md5sum | cut -c1-32); b=$(sed -n "/^2\. run:/,/^3\. run:/p" $f | md5sum | cut -c1-32); [ "$a" = "$b" ] && echo same || echo differ'`
   exit: 0
   stdout: `same`
   mutation: changing criterion 2's `stdout: \`4\`` prints `differ`.
3. run: `bash -c 'cs=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(cos-u1\): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxF docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: committing an edit to `tg-u2-fix1.md` under a `(cos-u1): ` subject prints `1`.
4. run: `bash -c 'f=docs/plans/2026-10-29-precheck-and-scope-gate-fixes/contracts/tg-u2.md; echo "ac11=$(grep -c "^   stdout: \`fails=0 ac=11 rc=0\`$" $f) ac6=$(grep -c "^   stdout: \`fails=0 ac=6 rc=0\`$" $f) amended=$(grep -c "^   amended 2026-10-29 (cos-u1): " $f)"'`
   exit: 0
   stdout: `ac11=1 ac6=0 amended=2`
   mutation: skipping edit 2 prints `amended=1`.
5. run: `bash -c 'git status --porcelain --untracked-files=no -- docs/plans/2026-10-29-precheck-and-scope-gate-fixes | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: leaving edit 2 uncommitted prints `1`.

## Pre-resolved context
- tdd: no. This edits a contract file; criterion 1 is the red/green check (red at ab174935, green after edit 1).
- blast-radius: `bin/review-precheck.sh` reads the contract only through `us_section`/`crit_items`; an `amended ...` line indented by three spaces between `stdout:` and `mutation:` is ignored by `crit_items` (it reads only `N. run:`, `exit:` and `stdout:` lines). Measured: with both edits the packet reads criteria 1-6 and 8 `pass` and criterion 7 `deferred long`.
- commit-message: docs(cos-u1): tg-u2 contract criteria 1 and 6 match the tree after tg-u2-fix1
- The precheck can never pass over tg-u2's own review range (baseline 0e0a2141): it reads `--contract` as the baseline commit holds it (`bin/review-precheck.sh:5-7`) and already prints `contract: changed-since-baseline` for the 1c827e9b amendment. This unit makes it pass with the baseline at its own commit (plan Open Question 1).
- Criterion 1 writes `.claude/bookkeeping/cos-u1-check.precheck` (gitignored, `.gitignore:40`); the id `cos-u1-check` keeps the reviewer's own `cos-u1.precheck` untouched.
- `docs/plans/` is exempt from `writer-scope-gate.sh`; the precheck's scope check also excludes it.

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If a `before` block is not found exactly once, stop and report the current text. If the Edit tool is unavailable (`exists but is not enabled in this context`), use a `python3` heredoc that asserts the old text occurs exactly once before replacing it. If criterion 1 prints `result=fail`, report the failing packet lines verbatim; do not edit any other criterion to make it pass.
