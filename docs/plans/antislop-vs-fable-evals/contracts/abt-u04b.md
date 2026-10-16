Unit: abt-u04b

## Objective
eval/abtest/verify-checks.sh applies a fixture's reference.d/*.patch series one commit per patch (and still applies a single reference.patch as one commit); a syn-series synthetic fixture and two test rows prove it; tests/abtest-checks.test.sh still passes. One commit.

## Retrieval
GitHub issues: `gh issue view 592 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/verify-checks.sh` (anchor: line matching `bad=0`)
- `tests/abtest-checks.test.sh` (anchor: line matching `has "the bad reference reports a reference failure"`)
- `tests/fixtures/abtest/verify/fixtures/syn-series/build.sh` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-series/allowed-paths.txt` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/01-answer.patch` (anchor: new file)
- `tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/02-extra.patch` (anchor: new file)
- `tests/fixtures/abtest/verify/checks/syn-series/check.sh` (anchor: new file)

## Ordered edits
1. command: `grep -q "apply --recount" eval/abtest/verify-checks.sh && ! grep -q "reference.d" eval/abtest/verify-checks.sh && test -f tests/abtest-checks.test.sh && test ! -e tests/fixtures/abtest/verify/fixtures/syn-series && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `bad=0`
   indent: 0
   insert-after:
~~~~

# apply_reference FIXTURE_DIR REPO: apply reference.patch as one commit, or every
# reference.d/*.patch in name order as one commit each (for evals whose checks
# count commits). Patches go in with --recount because a contract payload turns
# a context line that holds one space into an empty line.
apply_reference() {
  local fx="$1" repo="$2" p
  local -a patches
  if [ -d "$fx/reference.d" ]; then patches=("$fx"/reference.d/*.patch); else patches=("$fx/reference.patch"); fi
  for p in "${patches[@]}"; do
    git -C "$repo" apply --recount "$p" && git -C "$repo" add -A \
      && git -C "$repo" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m reference || return 1
  done
}
~~~~
3. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `if [ ! -f "$fx/build.sh" ]`
   before: `  if [ ! -f "$fx/build.sh" ] || [ ! -f "$ck/check.sh" ] || [ ! -f "$fx/reference.patch" ] || [ ! -f "$fx/allowed-paths.txt" ]; then`
   after: `  if [ ! -f "$fx/build.sh" ] || [ ! -f "$ck/check.sh" ] || { [ ! -f "$fx/reference.patch" ] && [ ! -d "$fx/reference.d" ]; } || [ ! -f "$fx/allowed-paths.txt" ]; then`
4. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `echo "verify: $id missing build.sh`
   before: `    echo "verify: $id missing build.sh, check.sh, reference.patch or allowed-paths.txt"; bad=1; continue`
   after: `    echo "verify: $id missing build.sh, check.sh, reference.patch (or reference.d) or allowed-paths.txt"; bad=1; continue`
5. file: `eval/abtest/verify-checks.sh`
   anchor: line matching `git -C "$T/$id-b" apply --recount "$fx/reference.patch"`
   indent: 0
   before:
~~~~
  git -C "$T/$id-b" apply --recount "$fx/reference.patch" && git -C "$T/$id-b" add -A \
    && git -C "$T/$id-b" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m reference
~~~~
   after:
~~~~
  apply_reference "$fx" "$T/$id-b" || echo "verify: $id reference did not apply"
~~~~
6. file: `tests/fixtures/abtest/verify/fixtures/syn-series/build.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
set -euo pipefail
. "$ABT_REPO_ROOT/eval/abtest/fixtures/lib.sh"
mkdir -p "$1"
printf '1\n' > "$1/answer.txt"
printf '{"name":"syn","scripts":{"test":"true"}}\n' > "$1/package.json"
abt_fixture_baseline "$1"
~~~~
7. file: `tests/fixtures/abtest/verify/fixtures/syn-series/allowed-paths.txt`
   anchor: new file
   indent: 0
   insert-after:
~~~~
answer.txt
extra.txt
~~~~
8. file: `tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/01-answer.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
--- a/answer.txt
+++ b/answer.txt
@@ -1 +1 @@
-1
+2
~~~~
9. file: `tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/02-extra.patch`
   anchor: new file
   indent: 0
   insert-after:
~~~~
--- /dev/null
+++ b/extra.txt
@@ -0,0 +1 @@
+extra
~~~~
10. file: `tests/fixtures/abtest/verify/checks/syn-series/check.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
. "${ABT_CHECKS_LIB:-$(dirname "$0")/../lib.sh}"
abt_init "$1" "$2" "$3" "$4"
abt_check answer-is-two defect true 'grep -qx 2 answer.txt'
abt_check two-commits process true '[ "$(git rev-list --count "$ABT_START..HEAD")" -ge 2 ]'
abt_check_scope scope-outside-allowed true
abt_emit
~~~~
11. file: `tests/abtest-checks.test.sh`
   anchor: line matching `has "the bad reference reports a reference failure" "$out" "reference-required-failures=1/2"`
   indent: 0
   insert-after:
~~~~
out="$(bash "$VERIFY" syn-series)"; rc=$?
check "a reference series applies one commit per patch" "$rc" "0"
has "the series reference passes every required check" "$out" "verify: syn-series baseline-required-failures=2/3 reference-required-failures=0/3"
~~~~
12. command: `git add eval/abtest/verify-checks.sh tests/abtest-checks.test.sh tests/fixtures/abtest/verify/fixtures/syn-series/build.sh tests/fixtures/abtest/verify/fixtures/syn-series/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/01-answer.patch tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/02-extra.patch tests/fixtures/abtest/verify/checks/syn-series/check.sh && git commit -m "feat(abt-u04b): verify-checks.sh applies a reference.d patch series (#592)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/fixtures/lib.sh` (extend verify-checks.sh and its test only)
- `tests/fixtures/abtest/verify/fixtures/syn-ok`, `tests/fixtures/abtest/verify/fixtures/syn-vacuous`, `tests/fixtures/abtest/verify/fixtures/syn-badref` and their `checks` (the existing synthetic fixtures stay as they are)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/harness/`, `tests/validate.sh` (other units own them)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh | grep -c '^ok   .*series'`
   exit: 0
   stdout: `2`
   mutation: skip edit 5 (the call to apply_reference); the two series rows FAIL, so no ok line mentions the series and stdout is 0.
2. run: `ABT_FIXTURES_DIR=tests/fixtures/abtest/verify/fixtures ABT_CHECKS_ROOT=tests/fixtures/abtest/verify/checks bash eval/abtest/verify-checks.sh syn-series`
   exit: 0
   stdout: `reference-required-failures=0/3`
   mutation: skip edit 9 (the second reference patch); only one reference commit lands, the two-commits check fails and the fragment reads 1/3.
3. run: `ABT_FIXTURES_DIR=tests/fixtures/abtest/verify/fixtures ABT_CHECKS_ROOT=tests/fixtures/abtest/verify/checks bash eval/abtest/verify-checks.sh syn-ok`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: skip edit 2 (the function); the call finds no apply_reference, verify cannot apply the reference and prints FAILED.
4. run: `grep -c 'reference.d' eval/abtest/verify-checks.sh`
   exit: 0
   stdout: `5`
   mutation: skip edit 2 (the function); the count is lower.
5. run: `grep -c 'apply_reference' eval/abtest/verify-checks.sh`
   exit: 0
   stdout: `3`
   mutation: skip edit 5 (the call); the comment and the definition remain and stdout is 2.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/verify-checks.sh tests/abtest-checks.test.sh tests/fixtures/abtest/verify/checks/syn-series/check.sh tests/fixtures/abtest/verify/fixtures/syn-series/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-series/build.sh tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/01-answer.patch tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/02-extra.patch`
   mutation: skip edit 12 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 12; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u04b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/verify-checks.sh tests/abtest-checks.test.sh tests/fixtures/abtest/verify/fixtures/syn-series/build.sh tests/fixtures/abtest/verify/fixtures/syn-series/allowed-paths.txt tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/01-answer.patch tests/fixtures/abtest/verify/fixtures/syn-series/reference.d/02-extra.patch tests/fixtures/abtest/verify/checks/syn-series/check.sh | grep -vcE "^[a-z]+\(abt-u04b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest/verify-checks.sh tests/abtest-checks.test.sh tests/fixtures/abtest/verify/fixtures/syn-series tests/fixtures/abtest/verify/checks/syn-series`
   exit: 0
   stdout: empty
   mutation: skip edit 12; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criteria 1 and 2 are the red-then-green checks: the series fixture and its rows do not exist at HEAD)
blast-radius: eval/abtest/verify-checks.sh:42
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 3 (the single-patch fixture) and criterion 9 (the scoped clean-tree check) pass at HEAD by design; criterion 3 turns red only if the edit breaks the single-patch path, criterion 9 only when the commit step is skipped.
extends-landed-code: abt-u04 is already on master (commit 1136ef08). This unit adds to it with insertions and small replacements anchored on the lines that exist there; it never rewrites a file.
why: E5 (abt-u11, abt-u11b) needs reference.d, a patch series applied one commit per patch, so its four-commits check can be proven non-vacuous.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: feat(abt-u04b): verify-checks.sh applies a reference.d patch series (#592)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
