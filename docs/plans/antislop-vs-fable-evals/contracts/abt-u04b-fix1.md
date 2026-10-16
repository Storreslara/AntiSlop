Unit: abt-u04b

## Objective
eval/abtest/verify-checks.sh exits non-zero, prints "verify: <id> reference did not apply" and never prints "verify-checks: ok" when any patch of a reference series (or the single reference.patch) fails to apply or commit, and when the reference run reports a different number of required checks than the baseline; the glob sort is pinned to LC_ALL=C and the header comment names reference.d; nine new test rows prove it. One commit.

## Retrieval
GitHub issues: `gh issue view 592 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/verify-checks.sh` (anchor: line matching `# least one required check fails; after applying reference.patch every`)
- `eval/abtest/verify-checks.sh` (anchor: line matching `local fx="$1" repo="$2" p`)
- `eval/abtest/verify-checks.sh` (anchor: line matching `apply_reference "$fx" "$T/$id-b" || echo "verify: $id reference did not apply"`)
- `eval/abtest/verify-checks.sh` (anchor: line matching `printed no valid JSON checks`)
- `tests/abtest-checks.test.sh` (anchor: line matching `check "a check.sh with an uppercase required value is rejected" "$rc" "1"`)

## Ordered edits
1. command: `! grep -q "reference ran" eval/abtest/verify-checks.sh && grep -q "apply_reference" eval/abtest/verify-checks.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `# least one required check fails; after applying reference.patch every`
   indent: 0
   before:
~~~~
# least one required check fails; after applying reference.patch every
# required check passes; no check.sh names a fixture or run path. The patch is
# applied with --recount because a contract payload turns a context line that
# holds one space into an empty line.
~~~~
   after:
~~~~
# least one required check fails; after applying the reference (reference.patch,
# or every reference.d/*.patch in name order, one commit each) every patch
# applies and every required check passes; no check.sh names a fixture or run
# path. Patches are applied with --recount because a contract payload turns a
# context line that holds one space into an empty line.
~~~~
3. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `local fx="$1" repo="$2" p`
   before: `local fx="$1" repo="$2" p`
   after: `local fx="$1" repo="$2" p LC_ALL=C`
4. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `apply_reference "$fx" "$T/$id-b" || echo "verify: $id reference did not apply"`
   indent: 0
   before: `apply_reference "$fx" "$T/$id-b" || echo "verify: $id reference did not apply"`
   after:
~~~~
if ! apply_reference "$fx" "$T/$id-b"; then
    echo "verify: $id reference did not apply"; bad=1; continue
  fi
~~~~
5. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `printed no valid JSON checks`
   insert-after: `  [ "$ref_total" -eq "$base_total" ] || { echo "verify: $id reference ran $ref_total required checks, baseline $base_total"; bad=1; continue; }`
6. file: `tests/abtest-checks.test.sh`
   anchor: line matching `check "a check.sh with an uppercase required value is rejected" "$rc" "1"`
   indent: 0
   insert-after:
~~~~

cp -r "$SYN/fixtures/syn-series" "$T/fx/syn-half"
mkdir -p "$T/ck/syn-half"
grep -v two-commits "$SYN/checks/syn-series/check.sh" > "$T/ck/syn-half/check.sh"
cat > "$T/fx/syn-half/reference.d/02-extra.patch" << 'EOS'
--- a/missing.txt
+++ b/missing.txt
@@ -1 +1 @@
-x
+y
EOS
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-half 2>/dev/null)"; rc=$?
check "a series that stops applying midway is rejected" "$rc" "1"
has "the half-applied series is named" "$out" "syn-half reference did not apply"
has "a half-applied series never ends ok" "$out" "verify-checks: FAILED"

cp -r "$SYN/fixtures/syn-series" "$T/fx/syn-order"
mkdir -p "$T/ck/syn-order"
cat > "$T/fx/syn-order/reference.d/02-extra.patch" << 'EOS'
--- a/answer.txt
+++ b/answer.txt
@@ -1 +1 @@
-2
+3
EOS
cat > "$T/ck/syn-order/check.sh" << 'EOS'
#!/usr/bin/env bash
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check answer-is-three defect true 'grep -qx 3 answer.txt'
abt_check_scope scope-outside-allowed true
abt_emit
EOS
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-order 2>/dev/null)"; rc=$?
check "a series whose second patch needs the first applies in name order" "$rc" "0"
has "the ordered series passes every required check" "$out" "verify: syn-order baseline-required-failures=1/2 reference-required-failures=0/2"

cp -r "$SYN/fixtures/syn-ok" "$T/fx/syn-empty"
cp -r "$SYN/checks/syn-ok" "$T/ck/syn-empty"
mkdir "$T/fx/syn-empty/reference.d"
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-empty 2>/dev/null)"; rc=$?
check "an empty reference.d is rejected" "$rc" "1"
has "the empty series is named" "$out" "syn-empty reference did not apply"

cp -r "$SYN/fixtures/syn-series" "$T/fx/syn-count"
mkdir -p "$T/ck/syn-count"
cat > "$T/ck/syn-count/check.sh" << 'EOS'
#!/usr/bin/env bash
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check answer-is-two defect true 'grep -qx 2 answer.txt'
[ -f "$1/extra.txt" ] || abt_check extra-file-exists defect true 'test -f extra.txt'
abt_emit
EOS
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-count 2>/dev/null)"; rc=$?
check "a reference that runs fewer required checks than the baseline is rejected" "$rc" "1"
has "the check-count mismatch is named" "$out" "syn-count reference ran 1 required checks, baseline 2"
~~~~
7. command: `git add eval/abtest/verify-checks.sh tests/abtest-checks.test.sh && git commit -m "fix(abt-u04b): verify-checks.sh rejects a reference series that stops applying (#592)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/fixtures/lib.sh` (the fix is in verify-checks.sh and its test only)
- `tests/fixtures/abtest/verify/` (the existing synthetic fixtures stay as they are; the new rows build their fixtures in a temp dir)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/harness/`, `tests/validate.sh` (other units own them)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand; the design-doc reference.patch count is a separate reconcile)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh`
   exit: 0
   stdout: `All abtest-checks checks passed.`
   mutation: skip edit 4; the "stops applying midway" and "never ends ok" rows FAIL (verify prints ok, rc 0), so the script exits non-zero and the fragment is absent.
2. run: `bash tests/abtest-checks.test.sh | grep -cE '^ok   (a series that stops|the half-applied|a half-applied|a series whose second|the ordered|an empty reference|the empty series|a reference that runs fewer|the check-count)'`
   exit: 0
   stdout: `9`
   mutation: skip edit 4; two half-apply rows FAIL and stdout is 7. Skip edit 5; the two count rows FAIL and stdout is 7.
   proof: scratch run at 8a05ea48 with edits 2-6 applied: the full suite printed 35 passed, 0 failed; with the pre-fix verify-checks.sh and the new rows, 2 rows FAILed.
3. run: `ABT_FIXTURES_DIR=tests/fixtures/abtest/verify/fixtures ABT_CHECKS_ROOT=tests/fixtures/abtest/verify/checks bash eval/abtest/verify-checks.sh syn-series | tail -n 1`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: edit 5 with -eq changed to -ne; the line reads verify-checks: FAILED.
   proof: scratch run with that change printed "verify-checks: FAILED" for syn-ok.
4. run: `grep -c 'bad=1; continue' eval/abtest/verify-checks.sh`
   exit: 0
   stdout: `6`
   mutation: skip edit 4; stdout 5. Skip edit 5; stdout 5.
5. run: `grep -c 'reference ran' eval/abtest/verify-checks.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; stdout 0, exit 1.
6. run: `grep -cF 'p LC_ALL=C' eval/abtest/verify-checks.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; stdout 0, exit 1.
7. run: `sed -n 1,12p eval/abtest/verify-checks.sh | grep -c 'reference.d'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; stdout 0, exit 1.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/verify-checks.sh tests/abtest-checks.test.sh`
   mutation: skip edit 7 (the commit); the newest abt-u04b commit is the original feat commit and the list names its 7 files.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; the newest abt-u04b commit is the original, whose stdout is also 1, so this row alone does not prove edit 7 (criterion 8 does).
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/verify-checks.sh tests/abtest-checks.test.sh | grep -vcE "^[a-z]+\(abt-u04b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- eval/abtest tests/abtest-checks.test.sh tests/fixtures/abtest/verify`
   exit: 0
   stdout: empty
   mutation: skip edit 7; the edited files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criteria 1 and 2 are red-then-green: the "stops applying midway" and "never ends ok" rows and the two count rows FAIL at HEAD; the order and empty-series rows already pass and guard against regressions)
blast-radius: eval/abtest/verify-checks.sh:66
fix-of: 2026-10-16T21:03:39Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract states indent: 0 and is applied as written, with no stripping. Edits 3 and 4 are substring replacements: the matched text is replaced and the line's existing two leading spaces stay, so edit 4's first after-line starts at column 0 and its next two lines carry 4 and 2 spaces. Edit 5's inline payload is literal, including its two leading spaces. Empty payload lines stay empty.
audit: the whole of verify-checks.sh was re-read at 8a05ea48 for any path that prints a failure without setting bad. Found: line 66 (fixed by edit 4) and an unchecked reference check count (edit 5). Lines 54, 57, 62 and 70 set bad=1 and continue; line 25 exits 2; line 71 sets bad.
not-covered: the build.sh exit status is read through a pipe to tail; a build that exits non-zero after printing a stable last line is not rejected. Left as is (no such fixture; out of scope here).
locale-note: LC_ALL=C pins the glob order; the shell has no en_US locale installed, so no row can distinguish C order from locale order (criterion 6 only proves the text).
why: the FAIL showed a series that stops applying midway leaves a mixed tree, and verify-checks.sh certified it because line 66 only echoed.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u04b): verify-checks.sh rejects a reference series that stops applying (#592)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u04b (#592)
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
