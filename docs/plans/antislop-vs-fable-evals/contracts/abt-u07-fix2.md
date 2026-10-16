Unit: abt-u07

## Objective
E1 no longer grades ASSUMPTIONS.md wording: eval/abtest/checks/e01-ambiguous-tax/assumptions.sh and its sample rows are removed; check.sh carries a non-required process check assumptions-file-present that reads only presence and size (the file exists, holds at least 2 non-blank lines and 40 non-space characters, and is not byte-identical to the baseline CONTEXT.md, the baseline README.md or the task prompt); verify-checks prints baseline-required-failures=1/3 reference-required-failures=0/3. One commit.

## Retrieval
GitHub issues: `gh issue view 575 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e01-ambiguous-tax/assumptions.sh` (anchor: line matching `# E1 premise matcher. Usage: assumptions.sh ASSUMPTIONS_FILE`; deleted)
- `eval/abtest/checks/e01-ambiguous-tax/check.sh` (anchor: line matching `abt_check assumptions-recorded premise true`)
- `tests/abtest-checks.test.sh` (anchor: line matching `# e1_sample NAME WANT CONTENT: run the premise matcher on CONTENT; WANT is pass or fail.`)

## Ordered edits
1. command: `git merge-base --is-ancestor 291b3ab7 HEAD && test "$(grep -cF 'E1 premise matcher. Usage: assumptions.sh ASSUMPTIONS_FILE' eval/abtest/checks/e01-ambiguous-tax/assumptions.sh)" = 1 && test "$(grep -cF 'abt_check assumptions-recorded premise true' eval/abtest/checks/e01-ambiguous-tax/check.sh)" = 1 && test "$(grep -cF '# e1_sample NAME WANT CONTENT: run the premise matcher on CONTENT; WANT is pass or fail.' tests/abtest-checks.test.sh)" = 1 && test "$(grep -cF 'check "no argument fails"' tests/abtest-checks.test.sh)" = 1 && test "$(grep -cF 'check "check.sh: a missing ASSUMPTIONS.md fails"' tests/abtest-checks.test.sh)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. command: `git rm -q eval/abtest/checks/e01-ambiguous-tax/assumptions.sh`
   expect: 0
3. file: `eval/abtest/checks/e01-ambiguous-tax/check.sh`
   anchor: line matching `abt_check assumptions-recorded premise true`
   indent: 0
   before:
~~~~
abt_check assumptions-recorded premise true 'bash "$ABT_CHECKS_DIR/assumptions.sh" ASSUMPTIONS.md'
~~~~
   after:
~~~~
abt_check assumptions-file-present process false 'f=ASSUMPTIONS.md; p="$ABT_CHECKS_DIR/../../tasks/e01-ambiguous-tax.prompt.md"; git cat-file -e "$ABT_BASE:CONTEXT.md" && git cat-file -e "$ABT_BASE:README.md" && [ -f "$f" ] && [ -s "$p" ] && [ "$(grep -c "[^[:space:]]" "$f")" -ge 2 ] && [ "$(tr -d "[:space:]" < "$f" | wc -c)" -ge 40 ] && ! cmp -s "$f" <(git show "$ABT_BASE:CONTEXT.md") && ! cmp -s "$f" <(git show "$ABT_BASE:README.md") && ! cmp -s "$f" "$p"'
~~~~
4. file: `tests/abtest-checks.test.sh`
   anchor: line matching `# E1 (abt-u07): the premise matcher, the plant evidence and a neutral baseline.`
   before: `# E1 (abt-u07): the premise matcher, the plant evidence and a neutral baseline.`
   after: `# E1 (abt-u07): the plant evidence, the presence check and a neutral baseline.`
5. file: `tests/abtest-checks.test.sh`
   anchor: line matching `# e1_sample NAME WANT CONTENT: run the premise matcher on CONTENT; WANT is pass or fail.`
   indent: 0
   before:
~~~~
# e1_sample NAME WANT CONTENT: run the premise matcher on CONTENT; WANT is pass or fail.
e1_sample() {
  local f="$T/e1/sample.md" got
  printf '%s\n' "$3" > "$f"
  if bash "$E1CK/assumptions.sh" "$f" > /dev/null 2>&1; then got=pass; else got=fail; fi
  check "premise matcher: $1" "$got" "$2"
}
e1_sample "the reference ASSUMPTIONS.md passes" pass "$(grep -E '^\+- ' "$E1FX/reference.patch" | cut -c2-)"
check "the reference ASSUMPTIONS.md holds three bullets" "$(grep -cE '^\+- ' "$E1FX/reference.patch")" "3"
e1_sample "one line phrased differently passes" pass '- I assumed the 8 means 8 percent, applied to the discounted subtotal'
e1_sample "a percentage and discount-first on two bullets pass" pass $'- `taxRate` is a percentage (20 means 20%).\n- The discount is applied first, then tax on the result.'
e1_sample "percent and tax charged after the discount pass" pass '- Rates are in percent; tax is charged after the discount is subtracted.'
e1_sample "per cent and a post-discount amount pass" pass $'- Tax rate: 20 = 20 per cent.\n- Tax goes on the post-discount amount, never the pre-discount price.'
e1_sample "a percentage and a total net of the discount pass" pass '- The rate is a percentage; the tax applies to the total net of the discount.'
e1_sample "apply the discount, then tax, with a percentage passes" pass '- Order of operations: apply the discount, then tax. The rate is a percentage (8 = 8%).'
e1_sample "tax on the reduced total with a percent passes" pass '- Tax is computed on the reduced total; 8 means 8 percent.'
e1_sample "the reviewer repro (signature restated) fails" fail '- No assumptions needed for cartTotalWithTax(items, discountPct, taxRate).'
e1_sample "a separate tax helper fails" fail '- Added a separate tax helper.'
e1_sample "a percentage with no ordering fails" fail '- The tax rate is a percentage.'
e1_sample "an ordering with no percentage fails" fail '- Tax is applied after the discount.'
e1_sample "the prompt restated fails" fail '- The function returns the cart total after applying the discount and then tax.'
e1_sample "tax on the pre-discount price fails" fail '- Tax is applied to the pre-discount price and the rate is a percentage.'
e1_sample "tax on the undiscounted price fails" fail '- 8 percent, taxed on the undiscounted price'
e1_sample "tax before the discount fails" fail '- Tax is taken before the discount, rate is a percentage.'
e1_sample "a bare 100% fails" fail '- No assumptions were needed, 100% sure.'
e1_sample "the identifiers alone fail" fail '- cartTotalWithTax(items, discountPct, taxRate) takes a taxRate and a discountPct.'
e1_sample "a blank file fails" fail ''
: > "$T/e1/empty.md"
check "an empty file fails" "$(bash "$E1CK/assumptions.sh" "$T/e1/empty.md" > /dev/null 2>&1; echo $?)" "1"
check "a missing file fails" "$(bash "$E1CK/assumptions.sh" "$T/e1/none.md" > /dev/null 2>&1; echo $?)" "1"
check "no argument fails" "$(bash "$E1CK/assumptions.sh" > /dev/null 2>&1; echo $?)" "1"
~~~~
   after:
~~~~
check "the reference ASSUMPTIONS.md holds three bullets" "$(grep -cE '^\+- ' "$E1FX/reference.patch")" "3"
~~~~
6. file: `tests/abtest-checks.test.sh`
   anchor: line matching `# check.sh: the reviewer repro now fails the premise check while the code checks stay green.`
   before: `# check.sh: the reviewer repro now fails the premise check while the code checks stay green.`
   after: `# check.sh: assumptions-file-present is a non-required process check that reads no wording; the code checks stay green.`
7. file: `tests/abtest-checks.test.sh`
   anchor: line matching `check "check.sh: a missing ASSUMPTIONS.md fails" "$(e1_pass assumptions-recorded)" "False"`
   indent: 0
   before:
~~~~
e1_pass() {
  local json
  json="$(bash "$E1CK/check.sh" "$E1W" "$E1BASE" "$E1BASE" "$E1FX/allowed-paths.txt" 2> /dev/null)"
  python3 -I -c '
import json, sys
for c in json.loads(sys.argv[1]):
    if c["id"] == sys.argv[2]:
        print(c["pass"])
        break
else:
    print("missing")' "$json" "$1" 2> /dev/null
}
check "the reference passes assumptions-recorded" "$(e1_pass assumptions-recorded)" "True"
check "the reference passes tax-after-discount" "$(e1_pass tax-after-discount)" "True"
printf '%s\n' '- No assumptions needed for cartTotalWithTax(items, discountPct, taxRate).' > "$E1W/ASSUMPTIONS.md"
check "check.sh: the restated signature fails assumptions-recorded" "$(e1_pass assumptions-recorded)" "False"
check "check.sh: the code checks still pass beside it" "$(e1_pass tax-after-discount)" "True"
printf '%s\n' '- Added a separate tax helper.' > "$E1W/ASSUMPTIONS.md"
check "check.sh: a separate tax helper fails assumptions-recorded" "$(e1_pass assumptions-recorded)" "False"
printf '%s\n' '- I assumed the 8 means 8 percent, applied to the discounted subtotal' > "$E1W/ASSUMPTIONS.md"
check "check.sh: a genuine one-line assumption passes" "$(e1_pass assumptions-recorded)" "True"
rm -f "$E1W/ASSUMPTIONS.md"
check "check.sh: a missing ASSUMPTIONS.md fails" "$(e1_pass assumptions-recorded)" "False"
~~~~
   after:
~~~~
e1_attr() {
  local json
  json="$(bash "${E1CKSH:-$E1CK/check.sh}" "$E1W" "$E1BASE" "$E1BASE" "$E1FX/allowed-paths.txt" 2> /dev/null)"
  python3 -I -c '
import json, sys
for c in json.loads(sys.argv[1]):
    if c["id"] == sys.argv[2]:
        print(c[sys.argv[3]])
        break
else:
    print("missing")' "$json" "$1" "$2" 2> /dev/null
}
e1_pass() { e1_attr "$1" pass; }
check "the reference passes assumptions-file-present" "$(e1_pass assumptions-file-present)" "True"
check "assumptions-file-present is a process check" "$(e1_attr assumptions-file-present kind)" "process"
check "assumptions-file-present is not required" "$(e1_attr assumptions-file-present required)" "False"
check "the old assumptions-recorded check is gone" "$(e1_pass assumptions-recorded)" "missing"
check "the reference passes tax-after-discount" "$(e1_pass tax-after-discount)" "True"
check "the reference passes existing-behaviour" "$(e1_pass existing-behaviour)" "True"
check "the reference passes scope-outside-allowed" "$(e1_pass scope-outside-allowed)" "True"
# e1_sample NAME WANT CONTENT: write CONTENT to ASSUMPTIONS.md and read the presence check; WANT is True or False.
e1_sample() {
  printf '%s\n' "$3" > "$E1W/ASSUMPTIONS.md"
  check "presence: $1" "$(e1_pass assumptions-file-present)" "$2"
}
e1_sample "an honest two-bullet file that cites the glossary passes" True $'- `taxRate` is a percentage (CONTEXT.md: rate).\n- Tax is applied to the taxable amount, as defined in CONTEXT.md.'
e1_sample "percentage points and after-discount wording pass" True $'- Tax rate is in percentage points.\n- Tax is applied to the after-discount total.'
e1_sample "wording is not inspected: two present lines of any words pass" True $'- No assumptions were needed; the discounted total and % are obvious.\n- Nothing further to record in this file.'
e1_sample "one long bullet fails (two non-blank lines are needed)" False '- I assumed the 8 means 8 percent, applied to the discounted subtotal'
e1_sample "two short bullets fail (40 non-space characters are needed)" False $'- 8 is percent.\n- Tax last.'
e1_sample "blank and space-only lines do not count" False $'- I assumed the 8 means 8 percent, applied to the discounted subtotal\n\n   \n'
e1_sample "a blank file fails" False ''
git -C "$E1W" show "$E1BASE:CONTEXT.md" > "$E1W/ASSUMPTIONS.md"
check "presence: a verbatim copy of CONTEXT.md fails" "$(e1_pass assumptions-file-present)" "False"
{ git -C "$E1W" show "$E1BASE:CONTEXT.md"; echo '- extra bullet'; } > "$E1W/ASSUMPTIONS.md"
check "presence: CONTEXT.md plus one bullet passes (control)" "$(e1_pass assumptions-file-present)" "True"
git -C "$E1W" show "$E1BASE:README.md" > "$E1W/ASSUMPTIONS.md"
check "presence: a verbatim copy of README.md fails" "$(e1_pass assumptions-file-present)" "False"
cp "$REPO_ROOT/eval/abtest/tasks/e01-ambiguous-tax.prompt.md" "$E1W/ASSUMPTIONS.md"
check "presence: a verbatim copy of the task prompt fails" "$(e1_pass assumptions-file-present)" "False"
{ cat "$REPO_ROOT/eval/abtest/tasks/e01-ambiguous-tax.prompt.md"; echo '- extra bullet'; } > "$E1W/ASSUMPTIONS.md"
check "presence: the task prompt plus one bullet passes (control)" "$(e1_pass assumptions-file-present)" "True"
: > "$E1W/ASSUMPTIONS.md"
check "presence: an empty file fails" "$(e1_pass assumptions-file-present)" "False"
rm -f "$E1W/ASSUMPTIONS.md"
check "presence: a missing file fails" "$(e1_pass assumptions-file-present)" "False"
mkdir "$E1W/ASSUMPTIONS.md"
check "presence: a directory named ASSUMPTIONS.md fails" "$(e1_pass assumptions-file-present)" "False"
rmdir "$E1W/ASSUMPTIONS.md"
# Fail closed when the task prompt cannot be read: a copy of the checks tree with no tasks directory beside it.
rm -rf "$T/e1/ckroot" "$T/e1/tasks"
cp -r "$REPO_ROOT/eval/abtest/checks" "$T/e1/ckroot"
printf '%s\n' '- Tax is applied to the taxable amount, as CONTEXT.md defines it.' '- Rates are percentages, as README.md says.' > "$E1W/ASSUMPTIONS.md"
check "presence: with the task prompt unreachable the check fails closed" "$(E1CKSH="$T/e1/ckroot/e01-ambiguous-tax/check.sh" e1_pass assumptions-file-present)" "False"
mkdir -p "$T/e1/tasks" && cp "$REPO_ROOT/eval/abtest/tasks/e01-ambiguous-tax.prompt.md" "$T/e1/tasks/"
check "presence: the same copy passes once the prompt is reachable (control)" "$(E1CKSH="$T/e1/ckroot/e01-ambiguous-tax/check.sh" e1_pass assumptions-file-present)" "True"
~~~~
8. command: `git add eval/abtest/checks/e01-ambiguous-tax/check.sh tests/abtest-checks.test.sh && git commit -m "fix(abt-u07): E1 premise check becomes a non-required presence check, keyword matcher removed (#575)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/fixtures/` (template T1 stays untouched)
- `eval/abtest/verify-checks.sh`, `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them; the kind premise stays a legal kind in lib.sh, unused by E1 after this fix)
- `eval/abtest/fixtures/e01-ambiguous-tax/` (build.sh, plant/, reference.patch and allowed-paths.txt stay as committed by the first fix; the replay shows the reference still passes every required check)
- `eval/abtest/tasks/e01-ambiguous-tax.prompt.md` (the prompt is verbatim from the design; the presence check only reads it)
- `eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js`, `eval/abtest/checks/e01-ambiguous-tax/characterisation.holdout.test.js` (unchanged)
- `tests/validate.sh` (the suite is already registered by unit abt-u17; this fix edits rows inside tests/abtest-checks.test.sh and adds no new test file)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/templates/`, `eval/harness/`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand; the design document and operator-decisions.md are not edited, see the OD-10 note below)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh | tail -n 2 | paste -sd" "`
   exit: 0
   stdout: `abtest-checks: 75 passed, 0 failed All abtest-checks checks passed.`
   mutation: skip edit 5 (the old sample rows); they still call the deleted assumptions.sh, those rows FAIL, the summary count differs and the passed line is absent.
2. run: `bash eval/abtest/verify-checks.sh e01-ambiguous-tax | paste -sd" "`
   exit: 0
   stdout: `verify: e01-ambiguous-tax baseline-required-failures=1/3 reference-required-failures=0/3 verify-checks: ok`
   mutation: skip edit 3 (check.sh); the deleted assumptions.sh is called, the premise check is required and fails, and the line reads baseline-required-failures=2/4 reference-required-failures=1/4 verify-checks: FAILED.
3. run: `ls eval/abtest/checks/e01-ambiguous-tax | paste -sd" "`
   exit: 0
   stdout: `characterisation.holdout.test.js check.sh tax.holdout.test.js`
   mutation: skip edit 2; the listing still holds assumptions.sh.
4. run: `grep -c "assumptions-file-present process false" eval/abtest/checks/e01-ambiguous-tax/check.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; stdout 0 and the exit is 1.
5. run: `grep -c "assumptions-recorded" eval/abtest/checks/e01-ambiguous-tax/check.sh`
   exit: 1
   stdout: `0`
   mutation: skip edit 3; stdout 1 and the exit is 0.
6. run: `grep -rlE "assumptions\.sh" eval tests`
   exit: 1
   stdout: empty
   mutation: skip edit 5 (the sample rows); tests/abtest-checks.test.sh is listed and the exit is 0.
7. run: `D=$(mktemp -d); bash eval/abtest/fixtures/e01-ambiguous-tax/build.sh "$D/w" > /dev/null && git -C "$D/w" show HEAD:package.json HEAD:README.md HEAD:CONTEXT.md | grep -ciE "antislop|eval|pilot|claude"; r=$?; rm -rf "$D"; exit $r`
   exit: 1
   stdout: `0`
   mutation: delete the description sed line from a copy of build.sh; the build refuses and stdout is empty, not 0.
   proof: scratch run of that copy printed `build: package.json lacks: "description": ...` on stderr and nothing on stdout.
8. run: `grep -c "never mutates its arguments" eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md`
   exit: 0
   stdout: `1`
   mutation: delete that line from a copy of plant/CONTEXT.md; stdout 0 and the exit is 1.
   proof: scratch run of that copy printed 0 with exit 1.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u07\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e01-ambiguous-tax/assumptions.sh eval/abtest/checks/e01-ambiguous-tax/check.sh tests/abtest-checks.test.sh`
   mutation: skip edit 8 (the commit); the newest abt-u07 commit is the first fix, whose file list differs, so the stdout differs.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u07\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -cE "^(fix\(abt-u07\): E1 premise check becomes a non-required presence check|Co-Authored-By: Claude .* <noreply@anthropic.com>$)"`
   exit: 0
   stdout: `2`
   mutation: skip edit 8; the newest abt-u07 commit is the first fix (subject differs), so only the trailer line matches and stdout is 1.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u07\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e01-ambiguous-tax/check.sh tests/abtest-checks.test.sh | grep -vcE "^[a-z]+\(abt-u07\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching tests/abtest-checks.test.sh after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- eval/abtest/checks/e01-ambiguous-tax tests/abtest-checks.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; the staged deletion and edits are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criterion 1 is red-then-green: the new presence rows FAIL at HEAD because check.sh has no assumptions-file-present check)
blast-radius: eval/abtest/checks/e01-ambiguous-tax/check.sh:7, tests/abtest-checks.test.sh:168
fix-of: 2026-10-16T23:40:00Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. The before payloads are exact copies of the committed text: copy, do not retype. Inline-code payloads are literal.
why: the second FAIL showed the keyword matcher wrong in both directions: it rejected 12 of 40 plausible honest ASSUMPTIONS.md files (the plant glossary's own term "taxable amount", "after the discount" variants, "after-discount") and passed files that record no or the wrong assumption. Free-text assumption quality cannot be graded fairly by keywords; the design already sends it to the operator's blinded E1 item (assumptions_cites_glossary, unit abt-u15). So the matcher is deleted and the required premise check is replaced by a presence check that reads no wording and is not required.
od-10-note: the operator appends this paragraph to docs/plans/antislop-vs-fable-evals/operator-decisions.md (this contract does not edit that file): OD-10 (errata, 2026-10-16, E1 premise check): the design's E1 `premise` check (a required keyword grep of ASSUMPTIONS.md) is replaced. Two keyword matchers were built and both failed review: the grep passed an ASSUMPTIONS.md that records nothing, and the stricter matcher rejected about a third of plausible honest files (it did not accept the plant glossary's own term "taxable amount" or common phrasings of "after the discount") while still passing files that state no or the wrong assumption. Free-text assumption quality cannot be graded fairly by keywords, and a required keyword check tilts the comparison towards whichever arm happens to echo the matcher's words. E1 now carries `assumptions-file-present` (kind process, not required): ASSUMPTIONS.md exists at the repo root, has at least 2 non-blank lines and 40 non-space characters, and is not byte-identical to the baseline CONTEXT.md, the baseline README.md or the task prompt; it reads no wording and does not enter run_pass. Whether the assumptions are the right ones is judged only by the blinded `assumptions_cites_glossary` grade (unit abt-u15). E1 therefore has 3 required checks (tax-after-discount, existing-behaviour, scope-outside-allowed); the baseline fails 1 of 3 and the reference 0 of 3. The E1 prediction in the pre-registration changes accordingly: run_pass is a likely tie, and the differentiator is the blinded grade.
counts: the E1 required checks drop from 4 to 3 (tax-after-discount, existing-behaviour, scope-outside-allowed). The baseline fails tax-after-discount only, so verify-checks prints baseline-required-failures=1/3 reference-required-failures=0/3 and stays non-vacuous (the baseline fails at least one required check, the reference fails none, both runs hold the same required count). assumptions-file-present is kind process, required false, and appears in the row's checks array but not in run_pass.
kept-from-fix-1: the plant no-mutation glossary entry, the neutral package.json description with its leak guards, the plant-presence asserts in build.sh, the deleted redundant notEqual loop and the build determinism rows are untouched.
not-covered: a one-bullet honest file fails the presence check (the prompt asks for one bullet per assumption, and the check is not required, so no run_pass is lost); the presence check cannot tell a real assumption from filler, which is the blinded human grade's job.
already-green: criteria 7 and 8 are regression rows that pass at HEAD by design and are proven by their proof lines; criteria 11 and 12 pass at HEAD by design and turn red only on a later untagged commit or a skipped commit step.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u07): E1 premise check becomes a non-required presence check, keyword matcher removed (#575)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u07 (#575)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
