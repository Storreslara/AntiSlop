Unit: abt-u04

## Objective
eval/abtest/verify-checks.sh fails a fixture whose check.sh prints no usable JSON (crash, `set -e` abort, or lib.sh exiting 2 on a bad kind or an uppercase `TRUE`) instead of printing "verify-checks: ok"; scope.sh honors a last allowed path with no trailing newline; three new test rows prove both. One commit.

## Retrieval
GitHub issues: `gh issue view 572 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/verify-checks.sh` (anchor: line matching `reference-required-failures=$ref_fail/$ref_total"`)
- `eval/abtest/checks/scope.sh` (anchor: line matching `while IFS= read -r p; do`)
- `tests/abtest-checks.test.sh` (anchor: line matching `check "a missing fixture is rejected" "$rc" "1"`)

## Ordered edits
1. command: `! grep -q "printed no valid JSON checks" eval/abtest/verify-checks.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `reference-required-failures=$ref_fail/$ref_total"`
   insert-after: `  [[ "$base_fail" =~ ^[0-9]+$ && "$base_total" =~ ^[0-9]+$ && "$ref_fail" =~ ^[0-9]+$ && "$ref_total" =~ ^[0-9]+$ ]] || { echo "verify: $id check.sh printed no valid JSON checks"; bad=1; continue; }`
3. file: `eval/abtest/checks/scope.sh`
   anchor: line matching `while IFS= read -r p; do`
   before: `while IFS= read -r p; do`
   after: `while IFS= read -r p || [ -n "$p" ]; do`
4. file: `tests/abtest-checks.test.sh`
   anchor: line matching `check "a missing fixture is rejected" "$rc" "1"`
   indent: 0
   insert-after:
~~~~

cp -r "$SYN/fixtures/syn-ok" "$T/fx/syn-silent"
mkdir -p "$T/ck/syn-silent"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/ck/syn-silent/check.sh"
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-silent 2>/dev/null)"; rc=$?
check "a check.sh that prints no JSON is rejected" "$rc" "1"
has "the silent check is named" "$out" "printed no valid JSON checks"
cp -r "$SYN/fixtures/syn-ok" "$T/fx/syn-upper"
mkdir -p "$T/ck/syn-upper"
printf '#!/usr/bin/env bash\n. "$ABT_CHECKS_LIB"\nabt_init "$1" "$2" "$3" "$4"\nabt_check x defect TRUE true\nabt_emit\n' > "$T/ck/syn-upper/check.sh"
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-upper 2>/dev/null)"; rc=$?
check "a check.sh with an uppercase required value is rejected" "$rc" "1"
~~~~
5. file: `tests/abtest-checks.test.sh`
   anchor: line matching `check "scope files count only the outside file"`
   indent: 0
   insert-after:
~~~~
printf 'answer.txt' > "$T/allowed-nonl"
check "scope lines honor a last allowed path with no trailing newline" "$(bash "$SCOPE" "$S" "$START" "$T/allowed-nonl" lines)" "3"
~~~~
6. command: `git add eval/abtest/verify-checks.sh eval/abtest/checks/scope.sh tests/abtest-checks.test.sh && git commit -m "fix(abt-u04): verify-checks.sh rejects a check.sh that prints no JSON (#572)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/lib.sh`, `eval/abtest/fixtures/lib.sh` (the fix is in verify-checks.sh, scope.sh and the test only)
- `tests/fixtures/abtest/verify/` (the existing synthetic fixtures stay as they are; the new rows build their fixtures in a temp dir)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/harness/`, `tests/validate.sh` (other units own them)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: skip edit 2; the silent and uppercase rows FAIL (verify prints ok, rc 0), the script exits non-zero and the fragment is absent.
2. run: `bash tests/abtest-checks.test.sh | grep -c -e '^ok   a check.sh' -e '^ok   scope lines honor'`
   exit: 0
   stdout: `3`
   mutation: skip edit 3; the scope row FAILs, so only 2 ok lines match and stdout is 2.
3. run: `ABT_FIXTURES_DIR=tests/fixtures/abtest/verify/fixtures ABT_CHECKS_ROOT=tests/fixtures/abtest/verify/checks bash eval/abtest/verify-checks.sh syn-ok`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: edit 2 with the guard regex changed to `^[a-z]+$`; the valid fixture is rejected and the fragment is absent.
   proof: scratch run with that regex on the finished change printed "verify-checks: FAILED".
4. run: `grep -c 'printed no valid JSON checks' eval/abtest/verify-checks.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout 0, exit 1.
5. run: `grep -cF 'read -r p || [ -n "$p" ]' eval/abtest/checks/scope.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; stdout 0, exit 1.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/scope.sh eval/abtest/verify-checks.sh tests/abtest-checks.test.sh`
   mutation: skip edit 6 (the commit); the newest abt-u04 commit is the original one and the list names its 17 files.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the newest abt-u04 commit is the original, whose stdout is also 1, so this row alone does not prove edit 6 (criterion 6 does).
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/verify-checks.sh eval/abtest/checks/scope.sh tests/abtest-checks.test.sh | grep -vcE "^[a-z]+\(abt-u04\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest tests/abtest-checks.test.sh tests/fixtures/abtest/verify`
   exit: 0
   stdout: empty
   mutation: skip edit 6; the edited files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criteria 1 and 2 are red-then-green: the three new rows FAIL at HEAD)
blast-radius: eval/abtest/verify-checks.sh:56
fix-of: 2026-10-16T20:52:08Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. Inline-code payloads are literal, including leading spaces.
why: the FAIL showed verify-checks.sh certifying a fixture whose check.sh printed no JSON; empty counts made every numeric test error, so bad stayed 0.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u04): verify-checks.sh rejects a check.sh that prints no JSON (#572)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u04 (#572)
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
