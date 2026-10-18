Unit: abt-u13d

## Objective
Both arms run with the same wider `--allowedTools` set of read-only commands (OD-17), so a correct run is not scored `stalled-human` for a benign piped read: `eval/abtest/arms/common.sh` allows 16 more `Bash(<command> *)` rules and denies the write-capable forms of `find` and `sort`; `tests/abtest-arms.test.sh` goes from 69 to 92 rows; OD-17 is recorded in `operator-decisions.md` and the pre-registration carries a dated amendment. `eval/abtest/lib/stream.py` is untouched. One commit.

## Retrieval
GitHub issues: `gh issue view 621 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/arms/common.sh` (anchor: line matching `    --allowedTools 'Bash(npm test)' 'Bash(npm run *)' 'Bash(git *)' \`)
- `tests/abtest-arms.test.sh` (anchor: line matching `mkrepo "$T/wa4"`)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` (anchor: line matching `  a shell could still search the filesystem; the measures are defence in depth and the canary is a probe, not a proof.`)
- `docs/experiments/abtest-2026-10.md` (anchor: line matching `the checkout; the measures are defence in depth, not a proof.`)

## Ordered edits
1. command: `test -f eval/abtest/arms/common.sh && test -f tests/abtest-arms.test.sh && ! /usr/bin/grep -qF "'Bash(grep *)'" eval/abtest/arms/common.sh && ! /usr/bin/grep -q '^- OD-17' docs/plans/antislop-vs-fable-evals/operator-decisions.md && /usr/bin/grep -qF 'elif asks > 0 or denials > 0 or escalated > 0:' eval/abtest/lib/stream.py && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/arms/common.sh`
   anchor: line matching `    --allowedTools 'Bash(npm test)' 'Bash(npm run *)' 'Bash(git *)' \`
   indent: 0
   before:
~~~~
    --allowedTools 'Bash(npm test)' 'Bash(npm run *)' 'Bash(git *)' \
~~~~
   after:
~~~~
    --allowedTools 'Bash(npm test)' 'Bash(npm run *)' 'Bash(git *)' \
    'Bash(grep *)' 'Bash(ls *)' 'Bash(find *)' 'Bash(cat *)' 'Bash(head *)' 'Bash(tail *)' 'Bash(wc *)' \
    'Bash(sort *)' 'Bash(uniq *)' 'Bash(cut *)' 'Bash(echo *)' 'Bash(pwd *)' 'Bash(diff *)' 'Bash(stat *)' \
    'Bash(basename *)' 'Bash(dirname *)' \
~~~~
3. file: `eval/abtest/arms/common.sh`
   anchor: line matching `  printf '%s\n' --disallowedTools`
   indent: 0
   insert-after:
~~~~
  # The read-only allows (OD-17) must not reach a form that writes or runs another command. Deny rules are checked
  # before allow rules, so these win, as do the harness-root rules below.
  printf '%s\n' 'Bash(find *-exec*)' 'Bash(find *-ok*)' 'Bash(find *-delete*)' 'Bash(find *-fprint*)' 'Bash(find *-fls*)' 'Bash(sort *-o*)'
~~~~
4. file: `tests/abtest-arms.test.sh`
   anchor: line matching `mkrepo "$T/wa4"`
   indent: 0
   before:
~~~~
mkrepo "$T/wa4"
~~~~
   after:
~~~~
# --- shared read-only allows (abt-u13d, OD-17): identical in both arms, nothing that writes, deny rules still win ---
allow_of() { awk '/^--allowedTools$/ {f = 1; next} /^--/ {f = 0} f' "$1"; }
allow_of "$T/argvA" > "$T/allowA"
allow_of "$T/argvB" > "$T/allowB"
check "both arms pass the same --allowedTools values" "$(cmp -s "$T/allowA" "$T/allowB" && echo same || echo differ)" "same"
check "the shared allowed tools number 19" "$(wc -l < "$T/allowA" | tr -d ' ')" "19"
check "the shared allowed tools keep the original three" "$(grep -cxE 'Bash\(npm test\)|Bash\(npm run \*\)|Bash\(git \*\)' "$T/allowA")" "3"
for c in grep ls find cat head tail wc sort uniq cut echo pwd diff stat basename dirname; do
  check "the shared allowed tools hold Bash($c *) in both arms" "$(grep -cxF "Bash($c *)" "$T/allowA")|$(grep -cxF "Bash($c *)" "$T/allowB")" "1|1"
done
check "no allowed tool names a command that writes, deletes, fetches or runs another" "$(grep -cE '^Bash\((rm|mv|cp|chmod|chown|ln|tee|sed|awk|dd|curl|wget|ssh|scp|nc|xargs|tar|touch|mkdir|sh|bash|env|eval|sudo|node|python3?) ' "$T/allowA")" "0"
check "no deny rule rides the allow list" "$(grep -c "$REPO_PHYS" "$T/allowA")" "0"
for a in A B; do
  check "arm $a denies the write-capable forms of find and sort" "$(grep -cxF -e 'Bash(find *-exec*)' -e 'Bash(find *-ok*)' -e 'Bash(find *-delete*)' -e 'Bash(find *-fprint*)' -e 'Bash(find *-fls*)' -e 'Bash(sort *-o*)' "$T/argv$a")" "6"
done
mkrepo "$T/wa4"
~~~~
5. file: `docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   anchor: line matching `  a shell could still search the filesystem; the measures are defence in depth and the canary is a probe, not a proof.`
   indent: 0
   insert-after:
~~~~
- OD-17 (2026-10-18, shared allowed tools; binding operator decision from the first real isolation probe; amends the
  design's flag lines 36 and 322)
  The shared `--allowedTools` set is widened identically in both arms with read-only commands, so a correct run is
  not scored `stalled-human` for a benign piped read. Evidence (probe 2026-10-18, `run-matrix.sh --probe-isolation
  --probe-model uniform`): the Arm B explorer subagent ran `grep ... | grep -v ':0$' | head -50; echo ---; ls ...`;
  the stream held a `permission_denied` record with reason `subcommandResults`, so Arm B answered correctly and was
  classified `stalled-human` (spec 4.1, OD-3, OD-13).
  (a) The set: `Bash(npm test)`, `Bash(npm run *)` and `Bash(git *)` as before, plus `Bash(<command> *)` for grep, ls,
  find, cat, head, tail, wc, sort, uniq, cut, echo, pwd, diff, stat, basename and dirname. Claude Code matches a
  compound command (`|`, `;`, `&&`, `||`) one subcommand at a time and each needs its own allow rule, so every
  command of such a pipeline has a rule.
  (b) Not added: rm, mv, cp, chmod, chown, ln, sed, awk, tee, touch, mkdir, curl, wget, ssh, any network command, any
  interpreter or shell. A redirect or a tee target is checked by Claude Code against its Edit rules, so a redirect
  into the worktree stays governed by `--permission-mode acceptEdits` exactly as before; this decision adds no write
  permission.
  (c) Deny rules are checked before allow rules, so `--disallowedTools` also carries `Bash(find *-exec*)`,
  `Bash(find *-ok*)`, `Bash(find *-delete*)`, `Bash(find *-fprint*)`, `Bash(find *-fls*)` and `Bash(sort *-o*)`, and
  the OD-16 rules for the harness root (Read, Edit and `Bash(*<root>*)`) still win over every allow. A command that
  the rules cannot name, such as a shell that never names the path, is the residual risk stated in OD-16(d).
  (d) Stall detection in lib/stream.py is unchanged: any permission denial or ask is still `stalled-human`, and a
  command outside the set is still a stall. `--probe-model uniform` stays report-only (abt-u13c).
  (e) Whether the widening removes the denial seen in the probe is confirmed only by re-running the probe; that is
  the operator's step, and no test spends usage for it. The pre-registration is amended before the first run.
~~~~
6. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `the checkout; the measures are defence in depth, not a proof.`
   indent: 0
   insert-after:
~~~~
Amendment 2026-10-18 (OD-17, before the first run): both arms get the same read-only Bash allow rules in addition
to `Bash(npm test)`, `Bash(npm run *)` and `Bash(git *)`: grep, ls, find, cat, head, tail, wc, sort, uniq, cut, echo,
pwd, diff, stat, basename and dirname, with deny rules for find -exec, -ok, -delete, -fprint, -fls and for sort -o.
Stall detection is unchanged: any permission denial or ask is still `stalled-human`.
~~~~
7. command: `set -o pipefail; bash tests/abtest-arms.test.sh | tail -n 1`
   expect: 0
   stdout: `All abtest-arms checks passed.`
8. command: `git add eval/abtest/arms/common.sh tests/abtest-arms.test.sh docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md && git commit -m "feat(abt-u13d): both arms allow the same read-only commands so a benign piped read is not a stall (OD-17) (#621)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/lib/stream.py` (the stalled-human rule: any AskUserQuestion, permission denial or escalation marker; spec 4.1, OD-3, OD-13 bind it)
- `eval/abtest/run-matrix.sh` and `tests/abtest-probe.test.sh` (abt-u13c owns them; this unit runs after it and does not edit them)
- `eval/abtest/README.md` (it lists no flag, criterion 12 proves it; nothing to change), `docs/plans/antislop-vs-fable-evals.md` (the design stays as written; OD-17 overrides its flag lines)
- `tests/abtest-stream.test.sh`, `tests/fixtures/abtest/` (the fake claude is unchanged), `tests/validate.sh`, `CHANGELOG.md`, `docs/harness-glossary.md`
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)

## Acceptance criteria
1. run: `/usr/bin/grep -cF "'Bash(basename *)' 'Bash(dirname *)'" eval/abtest/arms/common.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout `0`.
2. run: `/usr/bin/grep -cF "'Bash(find *-exec*)'" eval/abtest/arms/common.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; stdout `0`.
3. run: `set -o pipefail; bash tests/abtest-arms.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-arms checks passed.`
   mutation: in a scratch clone delete `'Bash(grep *)' ` from eval/abtest/arms/common.sh; two rows FAIL and the suite exits 1.
   proof: `S=$(mktemp -d) && [ -d "${S:-}" ] && git clone -q . "$S/c" && cd "$S/c" && python3 -c "p='eval/abtest/arms/common.sh';s=open(p).read();open(p,'w').write(s.replace(\"'Bash(grep *)' \",''))" && bash tests/abtest-arms.test.sh | tail -n 1`
4. run: `set -o pipefail; bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^ok '`
   exit: 0
   stdout: `92`
   mutation: skip edit 4; stdout `69`.
5. run: `bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^FAIL'`
   exit: 1
   stdout: `0`
   mutation: add `'Bash(rm *)'` to the allow list in a scratch clone; the no-write row FAILs and stdout is at least `1`.
   proof: `S=$(mktemp -d) && [ -d "${S:-}" ] && git clone -q . "$S/c" && cd "$S/c" && python3 -c "p='eval/abtest/arms/common.sh';s=open(p).read();open(p,'w').write(s.replace(\"'Bash(dirname *)' \",\"'Bash(dirname *)' 'Bash(rm *)' \"))" && bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^FAIL'`
6. run: `/usr/bin/grep -c '^- OD-17 (2026-10-18' docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; stdout `0`.
7. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF "Stall detection in lib/stream.py is unchanged"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; stdout `0`.
8. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF 'subcommandResults'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; stdout `0`.
9. run: `/usr/bin/grep -c '^Amendment 2026-10-18 (OD-17, before the first run)' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; stdout `0`.
10. run: `/usr/bin/grep -c 'probe-isolation' tests/abtest-arms.test.sh`
    exit: 1
    stdout: `0`
    mutation: add a line running `run-matrix.sh --probe-isolation` to tests/abtest-arms.test.sh; stdout `1` (re-running the probe is the operator's step, OD-17(e), never a test; the suite runs the fake claude only).
11. run: `/usr/bin/grep -cF 'elif asks > 0 or denials > 0 or escalated > 0:' eval/abtest/lib/stream.py`
    exit: 0
    stdout: `1`
    mutation: delete `denials > 0 or ` from that line of eval/abtest/lib/stream.py; stdout `0`.
12. run: `/usr/bin/grep -c 'allowedTools' eval/abtest/README.md`
    exit: 1
    stdout: `0`
    mutation: add the word allowedTools to the README; stdout `1`, which says the README now lists a flag and this unit must name it.
13. run: `set -o pipefail; bash tests/abtest-stream.test.sh | tail -n 1`
    exit: 0
    stdout: `All abtest-stream checks passed.`
    mutation: delete `denials > 0 or ` from eval/abtest/lib/stream.py; the denied-capture rows FAIL.
14. run: `set -o pipefail; bash tests/abtest-runner.test.sh | tail -n 1`
    exit: 0
    stdout: `All abtest-runner checks passed.`
    mutation: add a stray `fi` line to eval/abtest/run-matrix.sh; the runner suite exits non-zero.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
    exit: 0
    stdout: `docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/arms/common.sh tests/abtest-arms.test.sh`
    mutation: skip edit 8 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
    exit: 0
    stdout: `1`
    mutation: skip edit 8; no unit commit exists and the exit is 3.
17. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13d\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/arms/common.sh tests/abtest-arms.test.sh docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md | grep -vcE "^[a-z]+\(abt-u13d\): "`
    exit: 1
    stdout: `0`
    mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
    proof: a later untagged commit is counted by grep -v, so stdout is 1; with no later commit the count prints 0 (exit 1).
18. run: `git status --porcelain -- eval/abtest/arms/common.sh tests/abtest-arms.test.sh docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md`
    exit: 0
    stdout: empty
    mutation: skip edit 8; the four files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-arms.test.sh (criteria 1 to 4 are red-then-green: the 23 new rows and the new allow and deny lines do not exist at HEAD)
blast-radius: eval/abtest/arms/common.sh:20 eval/abtest/arms/common.sh:44 eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh tests/abtest-arms.test.sh:78 tests/abtest-arms.test.sh:95 (grep-derived; both arm scripts build their command from abtest_common_flags and abtest_deny_flags and add nothing, and no other test or script names the allowed set; eval/harness/run.sh keeps its own older copy, which is not an abtest arm)
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 of the contract file, keeps its own leading spaces, and states indent: 0; strip nothing; empty payload lines stay empty.
ordering: this unit follows abt-u13c (#620), by the operator's ruling, so that the re-run probe reports stall signals by name; the two units share no file. Both block the pilot abt-u19 (#589).
docs-checked: Claude Code permissions page (read 2026-10-18): a rule must match each subcommand independently; deny and ask apply when any subcommand matches; rules are evaluated deny, then ask, then allow; a `*` matches any text including spaces; a redirect or tee target is checked against Edit rules, not the base command's allow rule; ls, cat, echo, pwd, head, tail, grep, find, wc, diff, stat are a built-in read-only set that needs no prompt, which the page does not tie to headless mode, so the explicit rules do not rely on it; the page documents no negation for Bash rules, so find and sort write forms are excluded by deny rules.
unverified: whether `Bash(<command> *)` also matches the bare command with no argument, and whether the widened set removes the denial seen in the probe, are not measured by any test; the operator's probe re-run is the check (OD-17(e)).
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry.
commit-message: feat(abt-u13d): both arms allow the same read-only commands so a benign piped read is not a stall (OD-17) (#621)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u13d (#621)
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
