Unit: abt-u13e

## Objective
The shared allow set of both arms no longer holds `Bash(uniq *)`, the find and sort deny rules in `eval/abtest/arms/common.sh` are anchored so `sort log-old.txt` and `find . -name x-ok.txt` are not denied while the write forms still are, OD-17(a) to (c) and the pre-registration amendment say exactly that (no claim of "no write permission"), and `tests/abtest-arms.test.sh` goes from 92 to 117 rows. `eval/abtest/lib/stream.py` is untouched. One commit.

## Retrieval
GitHub issues: `gh issue view 622 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/arms/common.sh` (anchor: line matching `    'Bash(sort *)' 'Bash(uniq *)' 'Bash(echo *)' 'Bash(pwd *)' 'Bash(diff *)' 'Bash(stat *)' \`)
- `tests/abtest-arms.test.sh` (anchor: line matching `check "the shared allowed tools number 19" "$(wc -l < "$T/allowA" | tr -d ' ')" "19"`)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` (anchor: line matching `  (a) The set: `+"`Bash(npm test)`"+`, `+"`Bash(npm run *)`"+` and `+"`Bash(git *)`"+` as before, plus `+"`Bash(<command> *)`"+` for grep, ls,`)
- `docs/experiments/abtest-2026-10.md` (anchor: line matching `Amendment 2026-10-18 (OD-17, before the first run): both arms get the same read-only Bash allow rules in addition`)

## Ordered edits
1. command: `test -f eval/abtest/arms/common.sh && test -f tests/abtest-arms.test.sh && /usr/bin/grep -qF "'Bash(uniq *)'" eval/abtest/arms/common.sh && ! /usr/bin/grep -q 'abt-u13e' docs/plans/antislop-vs-fable-evals/operator-decisions.md && /usr/bin/grep -qF 'elif asks > 0 or denials > 0 or escalated > 0:' eval/abtest/lib/stream.py && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/arms/common.sh`
   anchor: line matching `    'Bash(sort *)' 'Bash(uniq *)' 'Bash(cut *)' 'Bash(echo *)' 'Bash(pwd *)' 'Bash(diff *)' 'Bash(stat *)' \`
   indent: 0
   before:
~~~~
    'Bash(sort *)' 'Bash(uniq *)' 'Bash(cut *)' 'Bash(echo *)' 'Bash(pwd *)' 'Bash(diff *)' 'Bash(stat *)' \
~~~~
   after:
~~~~
    'Bash(sort *)' 'Bash(cut *)' 'Bash(echo *)' 'Bash(pwd *)' 'Bash(diff *)' 'Bash(stat *)' \
~~~~
3. file: `eval/abtest/arms/common.sh`
   anchor: line matching `  # before allow rules, so these win, as do the harness-root rules below.`
   indent: 0
   before:
~~~~
  # The read-only allows (OD-17) must not reach a form that writes or runs another command. Deny rules are checked
  # before allow rules, so these win, as do the harness-root rules below.
  printf '%s\n' 'Bash(find *-exec*)' 'Bash(find *-ok*)' 'Bash(find *-delete*)' 'Bash(find *-fprint*)' 'Bash(find *-fls*)' 'Bash(sort *-o*)'
~~~~
   after:
~~~~
  # The read-only allows (OD-17) must not reach a form that writes or runs another command. Deny rules are checked
  # before allow rules, so these win, as do the harness-root rules below. Each is anchored to a space or to the start
  # of the arguments, because a rule matches the command text with * for any text: Bash(find *-ok*) would also deny
  # find . -name '*-ok*', and Bash(sort *-o*) would deny sort log-old.txt. The no-path forms cover find -delete.
  printf '%s\n' 'Bash(find * -exec*)' 'Bash(find * -ok*)' 'Bash(find * -delete*)' 'Bash(find * -fprint*)' 'Bash(find * -fls*)'
  printf '%s\n' 'Bash(find -exec*)' 'Bash(find -ok*)' 'Bash(find -delete*)' 'Bash(find -fprint*)' 'Bash(find -fls*)'
  printf '%s\n' 'Bash(sort -o*)' 'Bash(sort * -o*)' 'Bash(sort --output*)' 'Bash(sort * --output*)'
  printf '%s\n' 'Bash(sort --compress-program*)' 'Bash(sort * --compress-program*)'
~~~~
4. file: `tests/abtest-arms.test.sh`
   anchor: line matching `check "the shared allowed tools number 19" "$(wc -l < "$T/allowA" | tr -d ' ')" "19"`
   indent: 0
   before:
~~~~
check "the shared allowed tools number 19" "$(wc -l < "$T/allowA" | tr -d ' ')" "19"
~~~~
   after:
~~~~
check "the shared allowed tools number 18" "$(wc -l < "$T/allowA" | tr -d ' ')" "18"
~~~~
5. file: `tests/abtest-arms.test.sh`
   anchor: line matching `for c in grep ls find cat head tail wc sort uniq cut echo pwd diff stat basename dirname; do`
   indent: 0
   before:
~~~~
for c in grep ls find cat head tail wc sort uniq cut echo pwd diff stat basename dirname; do
~~~~
   after:
~~~~
for c in grep ls find cat head tail wc sort cut echo pwd diff stat basename dirname; do
~~~~
6. file: `tests/abtest-arms.test.sh`
   anchor: line matching `  check "arm $a denies the write-capable forms of find and sort"`
   indent: 0
   before:
~~~~
for a in A B; do
  check "arm $a denies the write-capable forms of find and sort" "$(grep -cxF -e 'Bash(find *-exec*)' -e 'Bash(find *-ok*)' -e 'Bash(find *-delete*)' -e 'Bash(find *-fprint*)' -e 'Bash(find *-fls*)' -e 'Bash(sort *-o*)' "$T/argv$a")" "6"
done
~~~~
   after:
~~~~
check "the shared allowed tools do not hold uniq (uniq IN OUT writes OUT)" "$(grep -c '^Bash(uniq ' "$T/allowA")" "0"
deny_of() { awk '/^--disallowedTools$/ {f = 1; next} /^--/ {f = 0} f' "$1"; }
deny_of "$T/argvA" > "$T/denyA"
deny_of "$T/argvB" > "$T/denyB"
check "both arms pass the same --disallowedTools values" "$(cmp -s "$T/denyA" "$T/denyB" && echo same || echo differ)" "same"
check "the find and sort deny rules number 16" "$(grep -cE '^Bash\((find|sort) ' "$T/denyA")" "16"
check "no find or sort deny rule starts with an unanchored star-dash" "$(grep -cE '^Bash\((find|sort) \*-' "$T/denyA")" "0"
# A rule is modelled as a shell glob: * is any text, spaces and nothing included (OD-17(c); the matcher itself is not run).
hits() {
  local r n=0
  while IFS= read -r r; do
    case "$r" in
      'Bash(find '* | 'Bash(sort '*)
        r="${r#Bash(}"
        r="${r%)}"
        case "$1" in $r) n=$((n + 1)) ;; esac
        ;;
    esac
  done < "$T/denyA"
  echo "$n"
}
for cmd in "sort log-old.txt" "sort -u a.txt" "sort a.txt b.txt" "find . -name x-ok.txt" "find . -name '*-ok*'" "find . -name '*-exec*' -type f" "find src -type f" "find . -name x-delete.txt"; do
  check "no find or sort deny rule matches the read $cmd" "$(hits "$cmd")" "0"
done
for cmd in "find . -exec rm {} ;" "find -exec rm {} ;" "find . -name x -execdir rm {} ;" "find . -ok rm {} ;" "find -okdir rm {} ;" "find . -delete" "find -delete" "find . -fprint out.txt" "find . -fprintf out.txt %p" "find . -fls out.txt" "sort -o out.txt in.txt" "sort in.txt -o out.txt" "sort -oout.txt in.txt" "sort --output=out.txt in.txt" "sort in.txt --output out.txt" "sort --compress-program=sh in.txt"; do
  check "a find or sort deny rule matches the write form $cmd" "$([ "$(hits "$cmd")" -ge 1 ] && echo matched || echo missed)" "matched"
done
~~~~
7. file: `docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   anchor: line matching `  (a) The set: `
   indent: 0
   before:
~~~~
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
~~~~
   after:
~~~~
  (a) The set: `Bash(npm test)`, `Bash(npm run *)` and `Bash(git *)` as before, plus `Bash(<command> *)` for grep, ls,
  find, cat, head, tail, wc, sort, cut, echo, pwd, diff, stat, basename and dirname (15 commands, 18 rules in all).
  `uniq` is not in the set because the form uniq IN OUT writes OUT; `sort -u` replaces it. Claude Code matches a
  compound command (`|`, `;`, `&&`, `||`) one subcommand at a time and each needs its own allow rule, so every
  command of such a pipeline has a rule.
  (b) What the set can and cannot write. Not added: rm, mv, cp, chmod, chown, ln, sed, awk, tee, touch, mkdir, uniq,
  curl, wget, ssh, any network command, any interpreter or shell. By their documented options the 15 added commands
  write no file, except `find` (-fprint, -fprintf, -fprint0, -fls and -delete write or delete; -exec, -execdir, -ok
  and -okdir run another command) and `sort` (-o and --output write the named file; --compress-program runs a
  program), and the deny rules in (c) name those forms. They name them by their usual spelling only: `sort` with
  combined short flags ending in o (for example `sort -uo OUT IN`) or with a quoted flag (`sort "-o" OUT IN`) is
  matched by no rule, so `sort` can still write a file named on its command line; this is residual risk of the kind
  OD-16(d) states, and a deny rule is not a security boundary around a program. A redirect or a tee target is checked
  by Claude Code against its Edit rules, so a redirect into the worktree stays governed by `--permission-mode
  acceptEdits` as before. Two allows already in place write far more than this decision does and are unchanged:
  `Bash(git *)` and `Bash(npm run *)` can write outside the worktree (for example `git -C DIR ...`,
  `git clone URL DIR`, or an npm script).
  (c) Deny rules are checked before allow rules, so `--disallowedTools` carries 16 find and sort rules. Claude Code
  matches a rule against the command text with `*` standing for any text, spaces included, so `Bash(find *-ok*)` would
  also deny `find . -name '*-ok*'` and `Bash(sort *-o*)` would deny `sort log-old.txt`. The rules are anchored to a
  space or to the start of the arguments instead: `Bash(find * -exec*)`, `Bash(find * -ok*)`,
  `Bash(find * -delete*)`, `Bash(find * -fprint*)`, `Bash(find * -fls*)`, the same five without the path word
  (`Bash(find -exec*)` and so on, because the docs do not say that a `*` inside a pattern can match nothing),
  `Bash(sort -o*)`, `Bash(sort * -o*)`, `Bash(sort --output*)`, `Bash(sort * --output*)`,
  `Bash(sort --compress-program*)` and `Bash(sort * --compress-program*)`. The tests model a rule as a shell glob
  and check that `sort log-old.txt` and `find . -name x-ok.txt` match none of them and that the write forms match at
  least one. Verified: the wildcard and compound-command rules quoted from the permissions page (read 2026-10-18).
  Not verified: that Claude Code's matcher agrees with a shell glob on every input; no test runs the real matcher.
  The OD-16 rules for the harness root (Read, Edit and `Bash(*<root>*)`) still win over every allow. A command that
  the rules cannot name, such as a shell that never names the path, is the residual risk stated in OD-16(d).
~~~~
8. file: `docs/experiments/abtest-2026-10.md`
   anchor: line matching `Amendment 2026-10-18 (OD-17, before the first run): both arms get the same read-only Bash allow rules in addition`
   indent: 0
   before:
~~~~
Amendment 2026-10-18 (OD-17, before the first run): both arms get the same read-only Bash allow rules in addition
to `Bash(npm test)`, `Bash(npm run *)` and `Bash(git *)`: grep, ls, find, cat, head, tail, wc, sort, uniq, cut, echo,
pwd, diff, stat, basename and dirname, with deny rules for find -exec, -ok, -delete, -fprint, -fls and for sort -o.
~~~~
   after:
~~~~
Amendment 2026-10-18 (OD-17, before the first run): both arms get the same read-only Bash allow rules in addition
to `Bash(npm test)`, `Bash(npm run *)` and `Bash(git *)`: grep, ls, find, cat, head, tail, wc, sort, cut, echo,
pwd, diff, stat, basename and dirname, with deny rules for the write and run forms of find (-exec, -execdir, -ok,
-okdir, -delete, -fprint, -fls) and of sort (-o, --output, --compress-program). Correction 2026-10-18 (OD-17,
abt-u13e, before the first run): `uniq` is not allowed (uniq IN OUT writes OUT), and the deny rules are anchored
so that a file name or pattern that merely contains -ok or -old is not denied.
~~~~
9. command: `set -o pipefail; bash tests/abtest-arms.test.sh | tail -n 1`
   expect: 0
   stdout: `All abtest-arms checks passed.`
10. command: `git add eval/abtest/arms/common.sh tests/abtest-arms.test.sh docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md && git commit -m "fix(abt-u13e): uniq leaves the shared allow set and the find and sort deny rules are anchored so a harmless read is not denied (OD-17) (#622)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_01YK99TBRAMRzztoenFf2Y9S"`
   expect: 0

## Do NOT touch
- `eval/abtest/lib/stream.py` (the stalled-human rule: any AskUserQuestion, permission denial or escalation marker; spec 4.1, OD-3, OD-13 bind it)
- `eval/abtest/run-matrix.sh` and `tests/abtest-probe.test.sh` (the probe is not edited here; re-running it is the operator's step)
- `eval/abtest/README.md`, `docs/plans/antislop-vs-fable-evals.md` (the design stays as written; OD-17 overrides its flag lines)
- `tests/abtest-stream.test.sh`, `tests/fixtures/abtest/` (the fake claude is unchanged), `tests/validate.sh`, `CHANGELOG.md`, `docs/harness-glossary.md`
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)

## Acceptance criteria
1. run: `/usr/bin/grep -cF "'Bash(uniq *)'" eval/abtest/arms/common.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 2; exit 0 and stdout `1`.
2. run: `/usr/bin/grep -cF "'Bash(find * -exec*)'" eval/abtest/arms/common.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; exit 1 and stdout `0`.
3. run: `/usr/bin/grep -cF "'Bash(sort *-o*)'" eval/abtest/arms/common.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 3; exit 0 and stdout `1`.
4. run: `set -o pipefail; bash tests/abtest-arms.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-arms checks passed.`
   mutation: in a scratch clone delete `'Bash(sort -o*)' ` from eval/abtest/arms/common.sh; the deny-count row and a write-form row FAIL and the suite exits with a non-zero code (its FAIL count, never a fixed 1).
   proof: `S=$(mktemp -d) && [ -d "${S:-}" ] && git clone -q . "$S/c" && cd "$S/c" && python3 -c "p='eval/abtest/arms/common.sh';s=open(p).read();open(p,'w').write(s.replace(\"'Bash(sort -o*)' \",''))" && bash tests/abtest-arms.test.sh | tail -n 1`
5. run: `set -o pipefail; bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^ok '`
   exit: 0
   stdout: `117`
   mutation: skip edit 6; the new rows do not exist and stdout is `89`.
6. run: `bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^FAIL'`
   exit: 1
   stdout: `0`
   mutation: add `'Bash(rm *)'` to the allow list in a scratch clone; the no-write row and the count row FAIL and stdout is at least `1`.
   proof: `S=$(mktemp -d) && [ -d "${S:-}" ] && git clone -q . "$S/c" && cd "$S/c" && python3 -c "p='eval/abtest/arms/common.sh';s=open(p).read();open(p,'w').write(s.replace(\"'Bash(dirname *)' \",\"'Bash(dirname *)' 'Bash(rm *)' \"))" && bash tests/abtest-arms.test.sh | /usr/bin/grep -c '^FAIL'`
7. run: `bash tests/abtest-arms.test.sh | /usr/bin/grep -cF 'ok   no find or sort deny rule matches the read sort log-old.txt'`
   exit: 0
   stdout: `1`
   mutation: in a scratch clone put the unanchored rule `'Bash(sort *-o*)'` back in place of `'Bash(sort -o*)'`; that row FAILs, so this count is `0` with exit 1.
   proof: `S=$(mktemp -d) && [ -d "${S:-}" ] && git clone -q . "$S/c" && cd "$S/c" && python3 -c "p='eval/abtest/arms/common.sh';s=open(p).read();open(p,'w').write(s.replace(\"'Bash(sort -o*)'\",\"'Bash(sort *-o*)'\"))" && bash tests/abtest-arms.test.sh | /usr/bin/grep -cF 'ok   no find or sort deny rule matches the read sort log-old.txt'`
8. run: `bash tests/abtest-arms.test.sh | /usr/bin/grep -c "^ok   no find or sort deny rule matches the read find . -name .[*]-ok[*].$"`
   exit: 0
   stdout: `1`
   mutation: in a scratch clone put the unanchored rule `'Bash(find *-ok*)'` in place of `'Bash(find * -ok*)'`; that row FAILs, so this count is `0` with exit 1.
   proof: `S=$(mktemp -d) && [ -d "${S:-}" ] && git clone -q . "$S/c" && cd "$S/c" && python3 -c "p='eval/abtest/arms/common.sh';s=open(p).read();open(p,'w').write(s.replace(\"'Bash(find * -ok*)'\",\"'Bash(find *-ok*)'\"))" && bash tests/abtest-arms.test.sh | /usr/bin/grep -c "^ok   no find or sort deny rule matches the read find . -name .[*]-ok[*].$"`
9. run: `cat docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr '\n' ' ' | tr -s ' ' | /usr/bin/grep -cF "this decision adds no write permission"`
   exit: 1
   stdout: `0`
   mutation: skip edit 7; the old sentence stays, exit 0 and stdout `1`.
10. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF "can write outside the worktree (for example"`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; stdout `0`.
11. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF "sort -uo OUT IN"`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; stdout `0`.
12. run: `tr '\n' ' ' < docs/plans/antislop-vs-fable-evals/operator-decisions.md | tr -s ' ' | /usr/bin/grep -cF "uniq IN OUT writes OUT"`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; stdout `0`.
13. run: `cat docs/plans/antislop-vs-fable-evals/operator-decisions.md docs/experiments/abtest-2026-10.md | /usr/bin/grep -c 'sort, uniq, cut'`
   exit: 1
   stdout: `0`
   mutation: skip edit 7 or edit 8; the old list stays, exit 0 and stdout is at least `1`.
14. run: `tr '\n' ' ' < docs/experiments/abtest-2026-10.md | tr -s ' ' | /usr/bin/grep -cF "Correction 2026-10-18 (OD-17, abt-u13e, before the first run)"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; stdout `0`.
15. run: `/usr/bin/grep -c 'probe-isolation' tests/abtest-arms.test.sh`
   exit: 1
   stdout: `0`
   mutation: add a line running `run-matrix.sh --probe-isolation` to tests/abtest-arms.test.sh; stdout `1` (re-running the probe is the operator's step, never a test; the suite runs the fake claude only).
16. run: `/usr/bin/grep -cF 'elif asks > 0 or denials > 0 or escalated > 0:' eval/abtest/lib/stream.py`
   exit: 0
   stdout: `1`
   mutation: delete `denials > 0 or ` from that line of eval/abtest/lib/stream.py; stdout `0`.
17. run: `set -o pipefail; bash tests/abtest-stream.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-stream checks passed.`
   mutation: delete `denials > 0 or ` from eval/abtest/lib/stream.py; the denied-capture rows FAIL and the suite exits with a non-zero code.
18. run: `set -o pipefail; bash tests/abtest-runner.test.sh | tail -n 1`
   exit: 0
   stdout: `All abtest-runner checks passed.`
   mutation: add a stray `fi` line to eval/abtest/run-matrix.sh; the runner suite exits with a non-zero code.
19. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13e\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md eval/abtest/arms/common.sh tests/abtest-arms.test.sh`
   mutation: skip edit 10 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
20. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13e\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; no unit commit exists and the exit is 3.
21. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u13e\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/arms/common.sh tests/abtest-arms.test.sh docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md | grep -vcE "^[a-z]+\(abt-u13e\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: a later untagged commit is counted by grep -v, so stdout is 1; with no later commit the count prints 0 (exit 1).
22. run: `git status --porcelain -- eval/abtest/arms/common.sh tests/abtest-arms.test.sh docs/experiments/abtest-2026-10.md docs/plans/antislop-vs-fable-evals/operator-decisions.md`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the four files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-arms.test.sh (criteria 1 to 5 and 7 to 8 are red-then-green: the 25 net new rows and the anchored deny lines do not exist at HEAD)
blast-radius: eval/abtest/arms/common.sh:22 eval/abtest/arms/common.sh:50 eval/abtest/arms/arm-a.sh eval/abtest/arms/arm-b.sh tests/abtest-arms.test.sh:129 tests/abtest-arms.test.sh:135 (grep-derived; both arm scripts build their command from abtest_common_flags and abtest_deny_flags and add nothing, and no other test or script names the allowed or the deny rules; eval/harness/run.sh keeps its own older copy, which is not an abtest arm)
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 of the contract file, keeps its own leading spaces, and states indent: 0; strip nothing; empty payload lines stay empty.
ordering: this unit follows abt-u13d (#621, closed, commit 2840cff5) and edits the same four files; it blocks the pilot abt-u19 (#589).
docs-checked: Claude Code permissions page (https://code.claude.com/docs/en/permissions, read 2026-10-18, via claude-code-guide): "A `*` in a Bash rule matches any text, including spaces"; a trailing ` *` with a space before it also matches the bare command, only when it is the rule's only wildcard; "`Bash(ls*)` has no space, so it matches `lsof` too"; rules match the raw command text after compound splitting and wrapper stripping, and a quoted form (`git 'push'`) is not normalized; deny and ask rules apply when any subcommand matches; the page says a deny or ask rule "isn't a security boundary around the program".
verified-by-test: the find and sort rules as written, modelled as shell globs (the 8 read forms match none, the 16 write forms match at least one); both arms carry identical allow and deny values; `uniq` is absent.
unverified: (1) that Claude Code's matcher equals a shell glob on every input; the docs do not say a mid-pattern `*` can match nothing, so the no-path forms (`find -exec*`, `sort -o*`) are listed separately and a literal reading of `find * -exec*` does not match `find -exec ls`; (2) a flag spelled `sort -uo OUT IN`, `sort "-o" OUT IN` or `sort -o'ut' IN` is matched by no rule (residual risk, now stated in OD-17(b)); (3) whether the widened set removes the denial seen in the probe (OD-17(e)); (4) that the 15 added commands write no file by their documented options is from the man pages, not measured.
probe-rerun-checklist: (a note for the operator, not a test, and nothing here runs it) after this unit lands, re-run `run-matrix.sh --probe-isolation --probe-model uniform` and expect no `probe-detail: ... denied` line for: a bare `sort | head`; an `echo` command; and the probe's own `grep -v ':0$' | head -50; echo ---; ls` pipeline. A `sort | head` or an `echo` that is denied means the matcher disagrees with the glob model above and the deny rules need a second look before the pilot.
not-stamped: no agents/*.md or templates/ file is touched, so there is no version bump and no CHANGELOG entry.
commit-message: fix(abt-u13e): uniq leaves the shared allow set and the find and sort deny rules are anchored so a harmless read is not denied (OD-17) (#622)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YK99TBRAMRzztoenFf2Y9S
diagnosis: none
review-packet:
~~~
unit: abt-u13e (#622)
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
criterion 19: <FILL: exit and stdout>
criterion 20: <FILL: exit and stdout>
criterion 21: <FILL: exit and stdout>
criterion 22: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
