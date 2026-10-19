Unit: abt-u13j

## Objective
`operator-decisions.md` holds OD-21 (the answer key is unreadable to the arm while it runs, restored on every exit path, fail closed, deny rules best effort, the canary probe checks the lock), `docs/experiments/abtest-2026-10.md` carries the dated amendment, and `eval/abtest/README.md` carries a note; all three state that this change moves `harness_commit`, so none of the rows made before it counts toward the full run and they are superseded and repeated under OD-14, and that the earlier pilots' evidence of nothing leaked rests on a keyword scan only. Prose only; no code, no test.

## Retrieval
GitHub issues: `gh issue view 627 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` (anchor: line matching `  pilot are superseded under OD-14 by this harness change and the pilot repeats them.`)
- `docs/experiments/abtest-2026-10.md` (anchor: line matching `superseded by this harness change (OD-14) and will be repeated. Stall detection is unchanged.`)
- `eval/abtest/README.md` (anchor: line matching `rule on a `sed` of an agent file) is not covered; if the pilot still stalls on it, report it.`)

## Ordered edits
1. command: `test -f eval/abtest/arms/common.sh && /usr/bin/grep -qF -e 'abtest_lock_secrets' eval/abtest/arms/common.sh && ! /usr/bin/grep -qF -e 'OD-21' docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   expect: 0

2. file: `docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   anchor: line matching `  pilot are superseded under OD-14 by this harness change and the pilot repeats them.`
   indent: 0
   insert-after:
~~~~
- OD-21 (2026-10-19, the answer key is made unreadable to the arm while it runs; binding operator decision, option 1, from the canary probe after OD-20)
  Evidence (eval/abtest/.runs/probe-canary/A/stream.jsonl and B/stream.jsonl, run on 2026-10-19 after OD-19 and OD-20):
  the probe returned FOUND for both arms. Each arm ran `find / -name '*holdout*' -o -name 'reference.patch' -o -name
  'canary-*'`, which listed paths under the WSL alias /mnt/wslg/distro/home/sebas/AntiSlop/..., then printed the token with
  `grep -H '^ABT-CANARY'` through xargs from eval/abtest/checks/e01-ambiguous-tax/canary-holdout.txt and
  eval/abtest/fixtures/e01-ambiguous-tax/canary-reference.patch. The deny rules of OD-16 match only the literal absolute
  root, so an alias spelling, a glob, a relative path or an xargs route bypasses them; this is the residual risk OD-19 named.
  (a) The rule. While an arm process runs, run-matrix.sh sets every file and directory under the harness secrets to mode
  000: eval/abtest/checks and the fixtures directory (eval/abtest/fixtures, or ABT_FIXTURES_DIR). The reference solutions,
  the hidden tests and the canary files all live under these two, and ABT_LOCK_PATHS (colon-separated) replaces the
  list. The lock is on the inode, so a symlink, a glob, a relative path, an xargs route and the /mnt/wslg alias get
  permission denied alike. It is taken inside run_guarded, which every arm start goes through (a run, the isolation probe
  and the canary probe), after the work tree, the plugin copy inputs and the fixture build are done.
  (b) Restore. The original modes are recorded in a manifest under ABT_WORK and put back after the arm exits and before
  anything is scored, on every exit path: normal, wall-clock timeout, arm failure, usage-limit exit 75 and 76, and SIGINT,
  SIGTERM and SIGHUP (the EXIT trap). SIGKILL of the runner cannot be trapped: the manifest then stays, and the next runner
  restores it before it starts anything.
  (c) Fail closed. If the lock cannot be taken, or a mode cannot be restored, the runner aborts with exit 1 and a message
  naming the path; no arm is started on a failed lock. Root is refused, because mode 000 does not stop root.
  (d) Deny rules, best effort. Both arms also get deny rules for chmod, chattr, setfacl, install, mv, cp and ln on the names
  abtest/checks, abtest/fixtures, holdout, reference.patch and canary-. The same user can still change a mode through a
  path built in a variable, so the lock is not proof; the canary probe stays the check. It now also prints
  `probe: canary-lock covered=yes restored=yes`, fails if a canary file lies outside the lock, and fails if it is
  unreadable after the restore. While the lock holds, a read of a canary file by an arm gets permission denied.
  (e) Fingerprint. A row carries `harness_commit`, `plugin_commit` and `prompt_sha`, and the runner counts a run id done
  only when all three match the current checkout (OD-14(b)). This change moves `harness_commit`, so none of the rows made
  before this change counts toward the full run: the runner moves them to results.superseded.jsonl and repeats them. The
  rows of the pilots before this change were made with the answer key readable; that no arm read it is evidence only by
  keyword scan of the streams, not by prevention, and it does not carry over.
  (f) Not changed. hooks/, lib/stream.py, the scorer, Arm B's plugin copy and OD-19's allow list. The operator re-runs, in
  order, `run-matrix.sh --probe-isolation`, `run-matrix.sh --probe-canary` and `run-matrix.sh --pilot`; a canary `FOUND`
  after this change blocks everything.
~~~~

3. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `superseded by this harness change (OD-14) and will be repeated. Stall detection is unchanged.`
   indent: 0
   insert-after:
~~~~
Amendment 2026-10-19 (OD-21, before the first full run): the answer key is made unreadable to the arm while it runs.
After OD-19 and OD-20 the canary probe returned FOUND for both arms: each ran `find /` for the hidden-test and
reference names, which listed paths under the WSL alias `/mnt/wslg/distro/...`, and read the token through `xargs`, an
alias spelling that the deny rules (which match the literal absolute root only) do not catch. Now `run-matrix.sh` sets
`eval/abtest/checks` and the fixtures directory to mode 000 for the duration of each arm run and restores the modes
before scoring on every exit path (normal, timeout, error, usage limit, signal); a failed lock or restore aborts the
run and names the path. Both arms also get deny rules for `chmod`, `chattr`, `setfacl`, `install`, `mv`, `cp` and `ln` on
those names. The same user could still change a mode through a path built in a variable, so the canary probe stays the
check and a `FOUND` blocks everything. Nothing in the task, the checks, the scoring or the arm settings changes. A
row is current only when `harness_commit`, `plugin_commit` and `prompt_sha` match (OD-14), and this change moves
`harness_commit`, so none of the rows made before it counts toward the full run: they are superseded and will be
repeated. Those rows were made with the answer key readable, and that no arm read it is evidence only by keyword scan of
the streams.
~~~~

4. file: `eval/abtest/README.md`
   anchor: line matching `rule on a `sed` of an agent file) is not covered; if the pilot still stalls on it, report it.`
   indent: 0
   insert-after:
~~~~
Since OD-21 the harness secrets are locked while an arm runs: `run-matrix.sh` sets every file and directory under
`eval/abtest/checks` and the fixtures directory to mode 000 just before each arm process starts (a run, the isolation
probe and the canary probe) and restores the recorded modes when the arm has exited, before anything is scored, on every
exit path including a timeout, an arm failure, exit 75 or 76 and SIGINT, SIGTERM or SIGHUP. The lock is on the inode, so a
symlink, a glob, a relative path, an `xargs` route and the `/mnt/wslg/distro/...` alias are denied alike.
`ABT_LOCK_PATHS` (colon-separated) replaces the default list. If the lock or the restore fails, the runner exits 1 and
names the path; if a runner was killed with SIGKILL, the manifest `$ABT_WORK/.secrets-lock.manifest` stays and the next
runner restores it first. The same user could still change a mode through a path built in a variable, which is why the
canary probe stays the check: it prints `probe: canary-lock covered=yes restored=yes`, and a `FOUND` blocks everything.
A row counts only with the current `harness_commit` (OD-14), so every row made before OD-21 is superseded and repeats:
run steps 1, 2 and 4 again, in that order.
~~~~

5. command: `git commit -m "docs(abt-u13j): OD-21 records the answer-key lock, the pre-registration and the README carry the dated amendment, every earlier row is superseded (#627)" -- docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md eval/abtest/README.md`
   expect: 0
   trailers: before running it, add one more `-m` argument for the Co-Authored-By trailer and one for the Claude-Session trailer, both taken from the session attribution; the paths after `--` stay explicit and no `git add` runs.

## Do NOT touch
- `eval/abtest/arms/common.sh`, `eval/abtest/run-matrix.sh` (the mechanism landed in abt-u13i; this unit writes prose only)
- `tests/` (no test changes; abt-u13i registered `tests/abtest-lock.test.sh`)
- `hooks/`, `eval/abtest/lib/stream.py`, `eval/abtest/checks/`, `eval/abtest/fixtures/` (unchanged)
- `eval/abtest/results.jsonl`, `eval/abtest/results.superseded.jsonl`, `eval/abtest/.runs/` (run output; the pilot is repeated by the operator, not edited)
- `docs/plans/antislop-vs-fable-evals.md`, `docs/harness-glossary.md`, `CHANGELOG.md` (the design stays as written; a scribe owns the CHANGELOG entry and any glossary close-out)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)

## Acceptance criteria
1. run: `/usr/bin/grep -c '^- OD-21 (2026-10-19, the answer key is made unreadable to the arm while it runs' docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; exit 1, stdout `0`.

2. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF 'the probe returned FOUND for both arms'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; exit 1, stdout `0`.

3. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF 'so none of the rows made before this change counts toward the full run'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; exit 1, stdout `0`.

4. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF 'is evidence only by keyword scan of the streams, not by prevention'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; exit 1, stdout `0`.

5. run: `/usr/bin/grep -c '^Amendment 2026-10-19 (OD-21, before the first full run): the answer key is made unreadable to the arm while it runs' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; exit 1, stdout `0`.

6. run: `tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | /usr/bin/grep -cF 'none of the rows made before it counts toward the full run'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; exit 1, stdout `0`.

7. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'Since OD-21 the harness secrets are locked while an arm runs'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; exit 1, stdout `0`.

8. run: `tr '\n' ' ' < eval/abtest/README.md | tr -s ' ' | /usr/bin/grep -cF 'every row made before OD-21 is superseded and repeats'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; exit 1, stdout `0`.

9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13j\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/README.md`
   mutation: skip edit 5 (the commit); exit 3, stdout `no-unit-commit`.

10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13j\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5 (the commit); exit 3, stdout `no-unit-commit`.

11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13j\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md eval/abtest/README.md | grep -vcE "^[a-z]+\(abt-u13j\): "`
   exit: 1
   stdout: `0`
   mutation: skip edit 5 (the commit); a later commit `docs: tail` touching docs/plans/antislop-vs-fable-evals/operator-decisions.md without the unit scope prints 1; before the commit, exit 3, stdout `no-unit-commit`.

## Pre-resolved context
tdd: no prose-only edits to three markdown files; the criteria are grep counts
blast-radius: docs/plans/antislop-vs-fable-evals/operator-decisions.md:263 docs/experiments/abtest-2026-10.md:53 eval/abtest/README.md:110 (the last line of OD-20, the last line of the OD-20 amendment and the last line of the README; each insert goes after it)
payload-indent: every fenced payload in this contract starts at column 0 of the contract file, keeps its own leading spaces, and states indent: 0; empty payload lines stay empty.
decision: no SPEC-GAP. Fingerprint, checked 2026-10-19 in eval/abtest/run-matrix.sh: current_prov and done_run compare harness_commit (git rev-parse HEAD of this checkout), plugin_commit (Arm B) and prompt_sha with the row; any mismatch is stale, the run is repeated and the old row is moved to results.superseded.jsonl, which the scorer never reads (OD-14). So no pilot row survives a commit of abt-u13i, and the rows keep no standing as rep 1 of the full run. Their evidence that nothing leaked rests on a keyword scan of the streams, not on prevention.
requires: abt-u13i has landed (the prose names run_guarded, ABT_LOCK_PATHS and the canary-lock line it added).
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry; a scribe close-out owns the CHANGELOG entry.
commit-message: docs(abt-u13j): OD-21 records the answer-key lock, the pre-registration and the README carry the dated amendment, every earlier row is superseded (#627)
trailers: use the Co-Authored-By and Claude-Session trailers from the session attribution (criterion 10 greps the Co-Authored-By line)
diagnosis: none
review-packet:
~~~
unit: abt-u13j (#627)
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
