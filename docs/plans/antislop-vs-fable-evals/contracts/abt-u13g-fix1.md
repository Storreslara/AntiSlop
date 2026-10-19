Unit: abt-u13g

## Objective
Fix of the FAIL of abt-u13g (commit 0ccd30a6, issue #624, .claude/reviewed/abt-u13g.fail). The first pilot stalled 4 of 10 rows, not 5: three docs and the handoff note carry "5 of 10", OD-19 lists only E1 and E2 as completed (6 rows completed), and eval/abtest/README.md says `find /` is no longer refused although OD-19(d) leaves that unverified. Docs only: no code, no version bump.

## Retrieval
GitHub issues: `gh issue view 624 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Original contract: `docs/plans/antislop-vs-fable-evals/contracts/abt-u13g.md`; operator overrides: `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` (anchor: line matching `  Evidence (pilot 2026-10-18, eval/abtest/results.jsonl, runs under eval/abtest/.runs/): 5 of 10 rows were`)
- `docs/experiments/abtest-2026-10.md` (anchor: line matching `because the first pilot stalled 5 of 10 rows (E3 B, E4 B, E5 A and B) on permission denials for ordinary dev`)
- `eval/abtest/README.md` (anchor: line matching `   pilot (2026-10-18) stalled 5 of 10 rows on permission rules, and its 10 rows are superseded by the harness change`)
- `eval/abtest/README.md` second edit (anchor: line matching `   Since OD-19 both arms may run any shell command, so `find /` is no longer refused for lying outside the work`)
- `docs/plans/antislop-vs-fable-evals/handoff-task-master.md` (anchor: line matching `from the pilot: 5 of 10 rows stalled-human on permission_denied for ordinary dev commands`, and line matching `(5 of 10 rows stalled-human on permission_denied reasons`)

## Ordered edits
1. command: `python3 -I -c "import json;print(sum(json.loads(l)['completion_status']=='stalled-human' for l in open('eval/abtest/results.jsonl') if l.strip()))"`
   expect: 0
   stdout: `4`
   (The source of the count. If it prints anything but 4, STOP and report a spec gap.)
2. file: `docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   anchor: line matching `  Evidence (pilot 2026-10-18, eval/abtest/results.jsonl, runs under eval/abtest/.runs/): 5 of 10 rows were`
   indent: 0
   before:
~~~~
Evidence (pilot 2026-10-18, eval/abtest/results.jsonl, runs under eval/abtest/.runs/): 5 of 10 rows were
  `stalled-human` (E3 B, E4 B, E5 A and B; E1 and E2 completed), each with `permission_denied` system records on
~~~~
   after:
~~~~
Evidence (pilot 2026-10-18, eval/abtest/results.jsonl, runs under eval/abtest/.runs/): 4 of 10 rows were
  `stalled-human` (E3 B, E4 B, E5 A and B) and the other 6 completed (E1 A and B, E2 A and B, E3 A, E4 A); each
  stalled row has `permission_denied` system records on
~~~~
3. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `because the first pilot stalled 5 of 10 rows (E3 B, E4 B, E5 A and B) on permission denials for ordinary dev`
   indent: 0
   before: `because the first pilot stalled 5 of 10 rows (E3 B, E4 B, E5 A and B) on permission denials for ordinary dev`
   after: `because the first pilot stalled 4 of 10 rows (E3 B, E4 B, E5 A and B) on permission denials for ordinary dev`
4. file: `eval/abtest/README.md`
   anchor: line matching `   pilot (2026-10-18) stalled 5 of 10 rows on permission rules, and its 10 rows are superseded by the harness change`
   indent: 0
   before: `pilot (2026-10-18) stalled 5 of 10 rows on permission rules, and its 10 rows are superseded by the harness change`
   after: `pilot (2026-10-18) stalled 4 of 10 rows on permission rules, and its 10 rows are superseded by the harness change`
5. file: `eval/abtest/README.md`
   anchor: line matching `   Since OD-19 both arms may run any shell command, so `find /` is no longer refused for lying outside the work`
   indent: 0
   before:
~~~~
so `find /` is no longer refused for lying outside the work
~~~~
   after:
~~~~
so `find /` may no longer be refused for lying outside the work
~~~~
6. file: `docs/plans/antislop-vs-fable-evals/handoff-task-master.md`
   anchor: line matching `from the pilot: 5 of 10 rows stalled-human on permission_denied for ordinary dev commands`
   indent: 0
   before: `from the pilot: 5 of 10 rows stalled-human on permission_denied for ordinary dev commands`
   after: `from the pilot: 4 of 10 rows stalled-human on permission_denied for ordinary dev commands`
7. file: `docs/plans/antislop-vs-fable-evals/handoff-task-master.md`
   anchor: line matching `(5 of 10 rows stalled-human on permission_denied reasons`
   indent: 0
   before: `(5 of 10 rows stalled-human on permission_denied reasons`
   after: `(4 of 10 rows stalled-human on permission_denied reasons`
8. command: `git commit -m "fix(abt-u13g): the first pilot stalled 4 of 10 rows, OD-19 lists all 6 completed rows, README does not claim find / is refused (#624)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01YK99TBRAMRzztoenFf2Y9S" -- docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/handoff-task-master.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/README.md`
   expect: 0

## Do NOT touch
- `docs/plans/antislop-vs-fable-evals/contracts/abt-u13g.md` (the original contract stays as the record of what was dispatched)
- `eval/abtest/lib/stream.py`, `eval/abtest/arms/common.sh`, `tests/abtest-arms.test.sh` (code and tests are correct; this fix is docs only)
- `eval/abtest/results.jsonl`, `eval/abtest/.runs/` (the source of the count, read only)
- `CHANGELOG.md`, `docs/harness-glossary.md`, `.claude-plugin/plugin.json`, `package.json`, `agents/`, `templates/` (no version bump; a scribe owns the CHANGELOG entry)

## Acceptance criteria
1. run: `python3 -I -c "import json;print(sum(json.loads(l)['completion_status']=='stalled-human' for l in open('eval/abtest/results.jsonl') if l.strip()))"`
   exit: 0
   stdout: `4`
   mutation: append a stalled-human row to a scratch copy of eval/abtest/results.jsonl; stdout `5`. Passes at HEAD (the source of the count).
   proof: `git clone -q . scratch && cp scratch/eval/abtest/results.jsonl scratch/r.jsonl && tail -n 1 scratch/r.jsonl | sed 's/"completion_status": *"complete"/"completion_status": "stalled-human"/' >> scratch/r.jsonl`, then the run: with `r.jsonl` in place of `results.jsonl` in scratch
2. run: `cat docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md eval/abtest/README.md | /usr/bin/grep -cF '4 of 10 rows'`
   exit: 0
   stdout: `3`
   mutation: skip edit 4; stdout `2`.
3. run: `cat docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md eval/abtest/README.md docs/plans/antislop-vs-fable-evals/handoff-task-master.md | /usr/bin/grep -cF '5 of 10'`
   exit: 1
   stdout: `0`
   mutation: skip edit 3; exit 0, stdout `1`.
4. run: `/usr/bin/grep -rlF '5 of 10' docs eval --exclude-dir=contracts --exclude-dir=.runs`
   exit: 1
   stdout: `empty`
   mutation: skip edit 7; exit 0, stdout `docs/plans/antislop-vs-fable-evals/handoff-task-master.md`.
5. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF 'the other 6 completed (E1 A and B, E2 A and B, E3 A, E4 A)'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; exit 1, stdout `0`.
6. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'may no longer be refused for lying outside the work directory'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; exit 1, stdout `0`.
7. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'is no longer refused for lying outside'`
   exit: 1
   stdout: `0`
   mutation: skip edit 5; exit 0, stdout `1`.
8. run: `set -o pipefail; bash tests/abtest-arms.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-arms checks passed.`
   mutation: in a scratch copy, change the line `    --allowedTools Bash \` in eval/abtest/arms/common.sh to `    --allowedTools 'Bash(ls *)' \`; the suite fails. Passes at HEAD (docs-only regression guard).
   proof: `git clone -q . scratch && sed -i "s/^    --allowedTools Bash \\\\$/    --allowedTools 'Bash(ls *)' \\\\/" scratch/eval/abtest/arms/common.sh && (cd scratch && bash tests/abtest-arms.test.sh | tail -n 1)` prints a line other than `All abtest-arms checks passed.`
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13g\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/handoff-task-master.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/README.md`
   mutation: skip edit 8 (the commit); the newest unit commit is 0ccd30a6 and the file list is the five files of the original commit.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13g\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: drop the Co-Authored-By `-m` argument from edit 8; exit 1, stdout `0`.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13g\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/handoff-task-master.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/README.md | grep -vcE "^[a-z]+\(abt-u13g\): "`
   exit: 1
   stdout: `0`
   mutation: skip edit 8; no new unit commit exists and the run lists the earlier commits' state unchanged (exit 1, stdout `0` at the old end commit, so this is a regression guard).

## Pre-resolved context
tdd: no docs-only text fix; criteria 2 to 7 are red at HEAD and green after, criterion 8 is a regression guard
blast-radius: docs/plans/antislop-vs-fable-evals/operator-decisions.md:197 docs/experiments/abtest-2026-10.md:38 eval/abtest/README.md:55 eval/abtest/README.md:41 docs/plans/antislop-vs-fable-evals/handoff-task-master.md:44 docs/plans/antislop-vs-fable-evals/handoff-task-master.md:121 (grep-derived; no code reads these lines)
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it. Write every file with the Edit tool, not a Bash heredoc.
decision: no SPEC-GAP. The count of stalled-human rows in the first pilot is 4 (e03 B, e04 B, e05 A, e05 B); 6 completed (e01 A and B, e02 A and B, e03 A, e04 A). The wrong "5 of 10" came from the dispatch brief of abt-u13g. The sentence about `find /` in eval/abtest/README.md is softened because OD-19(d) lists the effect of Bash allow on the parser checks as unverified. The superseded original contract keeps "5 of 10" as a record and is excluded from criterion 4 by --exclude-dir=contracts.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry.
commit-message: fix(abt-u13g): the first pilot stalled 4 of 10 rows, OD-19 lists all 6 completed rows, README does not claim find / is refused (#624)
trailers: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> and Claude-Session: https://claude.ai/code/session_01YK99TBRAMRzztoenFf2Y9S, as two more -m arguments
fix-of: 2026-10-19T04:34:39Z
diagnosis: none
review-packet:
~~~
unit: abt-u13g (#624)
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
