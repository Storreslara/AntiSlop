Unit: abt-u07

## Objective
eval/abtest/checks/e01-ambiguous-tax/assumptions.sh makes the required premise check assumptions-recorded pass only on an ASSUMPTIONS.md that states the rate is a percentage and that tax follows the discount; the plant glossary states that new functions never mutate their inputs; the fixture build neutralises the T1 description, fails closed on a dropped plant and on any antislop/eval/pilot/claude text; tests/abtest-checks.test.sh proves all of it with positive and negative samples. One commit.

## Retrieval
GitHub issues: `gh issue view 575 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/checks/e01-ambiguous-tax/assumptions.sh` (anchor: new file)
- `eval/abtest/checks/e01-ambiguous-tax/check.sh` (anchor: line matching `abt_check assumptions-recorded premise true`)
- `eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js` (anchor: line matching `for (const wrong of`)
- `eval/abtest/fixtures/e01-ambiguous-tax/build.sh` (anchor: line matching `cp -r "$HERE/plant/." "$dest/"`)
- `eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md` (anchor: line matching `_Avoid_: ratio, factor.`)
- `tests/abtest-checks.test.sh` (anchor: line matching `scope.sh rejects an unknown mode`)

## Ordered edits
1. command: `git merge-base --is-ancestor b61fe0a5 HEAD && test ! -e eval/abtest/checks/e01-ambiguous-tax/assumptions.sh && test "$(grep -cF 'abt_fixture_baseline "$dest"' eval/abtest/fixtures/e01-ambiguous-tax/build.sh)" = 1 && test "$(grep -cF 'wrong of' eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js)" = 1 && test "$(grep -cF 'abt_check assumptions-recorded premise true' eval/abtest/checks/e01-ambiguous-tax/check.sh)" = 1 && test "$(grep -cF 'scope.sh rejects an unknown mode' tests/abtest-checks.test.sh)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/checks/e01-ambiguous-tax/assumptions.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# E1 premise matcher. Usage: assumptions.sh ASSUMPTIONS_FILE
# Exit 0 only when the file records both resolved facts: the rate is a
# percentage, and tax is applied after the discount. Echoes of the signature
# (cartTotalWithTax, taxRate, discountPct) and the pre-discount wording are
# dropped first, so restating the prompt scores nothing. Every other outcome
# (missing, empty, unreadable, a crashed tool) exits non-zero.
set -uo pipefail
f="${1:-}"
[ -n "$f" ] && [ -f "$f" ] && [ -s "$f" ] || exit 1
t="$(tr '[:upper:]' '[:lower:]' < "$f" | tr '\n' ' ')" || exit 1
t="$(printf '%s' "$t" | sed -E 's/carttotalwithtax *\([^)]*\)//g; s/carttotalwithtax|taxrate|discountpct//g; s/\b(pre|non|un)-? ?discount(ed)?//g; s/before (the |any )?discount//g')" || exit 1
[ -n "${t//[[:space:]]/}" ] || exit 1
printf '%s' "$t" | LC_ALL=C grep -qE '(^|[^a-z])(percent(age)?s?|per cent)([^a-z]|$)|%' || exit 1
printf '%s' "$t" | LC_ALL=C grep -qE 'post[- ]?discount|\bdiscounted\b|after (applying |taking |subtracting )?(the |any |a )?discount|net of (the |any )?discount|reduced (price|total|subtotal|amount)|discount[a-z ,;]{0,30} (first|then (the |a )?tax|before (the )?tax)' || exit 1
exit 0
~~~~
3. file: `eval/abtest/checks/e01-ambiguous-tax/check.sh`
   anchor: line matching `abt_check assumptions-recorded premise true`
   before: `abt_check assumptions-recorded premise true 'test -f ASSUMPTIONS.md && grep -qiE "tax" ASSUMPTIONS.md && grep -qiE "percent|rate" ASSUMPTIONS.md'`
   after: `abt_check assumptions-recorded premise true 'bash "$ABT_CHECKS_DIR/assumptions.sh" ASSUMPTIONS.md'`
4. file: `eval/abtest/fixtures/e01-ambiguous-tax/build.sh`
   anchor: line matching `cp -r "$HERE/plant/." "$dest/"`
   indent: 0
   insert-after:
~~~~
# The template description names the eval and the claude CLI. This fixture
# replaces it, so neither arm can tell it is inside an eval.
sed -i 's|^\(  "description": \).*$|\1"Minimal fixture library with no external dependencies.",|' "$dest/package.json"
# Fail closed: the plant must have landed, and the tree must not name the eval.
need() { grep -qF -- "$2" "$dest/$1" 2> /dev/null || { echo "build: $1 lacks: $2" >&2; exit 1; }; }
need CONTEXT.md '**taxable amount**'
need CONTEXT.md 'never a fraction'
need CONTEXT.md 'never mutates its arguments'
need README.md 'all rates are percentages'
need package.json '"description": "Minimal fixture library with no external dependencies."'
need package.json '"test": "node --test"'
if grep -qiE 'antislop|eval|pilot|claude' "$dest/package.json" "$dest/README.md" "$dest/CONTEXT.md"; then
  echo "build: the built tree names the eval or the tool" >&2
  exit 1
fi
~~~~
5. file: `eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md`
   anchor: line matching `_Avoid_: ratio, factor.`
   indent: 0
   before:
~~~~
_Avoid_: ratio, factor.
~~~~
   after:
~~~~
_Avoid_: ratio, factor.

**pure helper**: a new pricing function never mutates its arguments; it works on copies. `applyDiscountPercent` is the one legacy exception and stays as it is.
~~~~
6. file: `eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js`
   anchor: line matching `for (const wrong of`
   indent: 0
   before:
~~~~
  assert.equal(total, 108);
  for (const wrong of [110, 120, 90.2]) assert.notEqual(total, wrong);
~~~~
   after:
~~~~
  assert.equal(total, 108);
~~~~
7. file: `tests/abtest-checks.test.sh`
   anchor: line matching `scope.sh rejects an unknown mode`
   indent: 0
   insert-after:
~~~~

# E1 (abt-u07): the premise matcher, the plant evidence and a neutral baseline.
E1FX="$REPO_ROOT/eval/abtest/fixtures/e01-ambiguous-tax"
E1CK="$REPO_ROOT/eval/abtest/checks/e01-ambiguous-tax"
mkdir -p "$T/e1"
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

# The build: a 40-hex sha, the same sha twice, the plant committed, no eval wording.
E1W="$T/e1/w"
E1BASE="$(bash "$E1FX/build.sh" "$E1W" 2> /dev/null | tail -n 1)"
check "the e01 build prints a 40-hex baseline sha" "$(printf '%s\n' "$E1BASE" | grep -cE '^[0-9a-f]{40}$')" "1"
check "two e01 builds agree on the baseline sha" "$(bash "$E1FX/build.sh" "$T/e1/w2" 2> /dev/null | tail -n 1)" "$E1BASE"
check "the baseline commits CONTEXT.md and README.md" "$(git -C "$E1W" ls-tree -r --name-only "$E1BASE" 2> /dev/null | grep -cE '^(CONTEXT|README)\.md$')" "2"
e1_in_base() { git -C "$E1W" show "$E1BASE:$1" 2> /dev/null | grep -cF -- "$2"; }
check "the baseline glossary defines the taxable amount" "$(e1_in_base CONTEXT.md '**taxable amount**')" "1"
check "the baseline glossary says rates are never fractions" "$(e1_in_base CONTEXT.md 'never a fraction')" "1"
check "the baseline glossary says new functions never mutate" "$(e1_in_base CONTEXT.md 'never mutates its arguments')" "1"
check "the baseline README says all rates are percentages" "$(e1_in_base README.md 'all rates are percentages')" "1"
check "the baseline package.json still names the library" "$(e1_in_base package.json '"name": "toy-lib"')" "1"
check "the baseline package.json still runs node --test" "$(git -C "$E1W" show "$E1BASE:package.json" 2> /dev/null | python3 -I -c 'import json,sys;p=json.load(sys.stdin);print(p["name"],p["scripts"]["test"])' 2> /dev/null)" "toy-lib node --test"
E1LEAK='antislop|eval|pilot|claude'
check "the leak pattern sees the template description (positive control)" "$(grep -ciE "$E1LEAK" "$REPO_ROOT/eval/fixtures/toy-lib-template/package.json")" "1"
check "the baseline names neither the eval nor the tool" "$(for f in package.json README.md CONTEXT.md; do git -C "$E1W" show "$E1BASE:$f" 2> /dev/null; done | grep -ciE "$E1LEAK")" "0"

# build.sh fails closed on a dropped plant, a plant missing the mutation line and a plant that names the tool.
E1BAD="$T/e1/fxbad/e01-ambiguous-tax"
mkdir -p "$T/e1/fxbad"
e1_badbuild() {
  rm -rf "$T/e1/fxbad" "$T/e1/wbad"
  mkdir -p "$T/e1/fxbad"
  cp -r "$E1FX" "$E1BAD"
  "$@"
  out="$(ABT_REPO_ROOT="$REPO_ROOT" bash "$E1BAD/build.sh" "$T/e1/wbad" 2> "$T/e1/bad.err")"; rc=$?
  if [ "$rc" -ne 0 ] && ! printf '%s\n' "$out" | grep -qE '^[0-9a-f]{40}$' && [ -s "$T/e1/bad.err" ]; then echo refused; else echo "rc=$rc"; fi
}
e1_drop_plant() { rm -rf "$E1BAD/plant"; mkdir "$E1BAD/plant"; }
e1_drop_mutation_line() { sed -i '/never mutates its arguments/d' "$E1BAD/plant/CONTEXT.md"; }
e1_name_the_tool() { printf 'Built for claude.\n' >> "$E1BAD/plant/README.md"; }
check "the unmodified copy builds (positive control)" "$(e1_badbuild true)" "rc=0"
check "build.sh refuses an empty plant" "$(e1_badbuild e1_drop_plant)" "refused"
check "build.sh refuses a glossary without the mutation line" "$(e1_badbuild e1_drop_mutation_line)" "refused"
check "build.sh refuses a README that names the tool" "$(e1_badbuild e1_name_the_tool)" "refused"

# check.sh: the reviewer repro now fails the premise check while the code checks stay green.
git -C "$E1W" apply --recount "$E1FX/reference.patch" && git -C "$E1W" add -A \
  && git -C "$E1W" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m reference
e1_pass() {
  local json
~~~~
8. file: `tests/abtest-checks.test.sh`
   anchor: line matching `  local json`
   indent: 0
   insert-after:
~~~~
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
9. command: `git add eval/abtest/checks/e01-ambiguous-tax/assumptions.sh eval/abtest/checks/e01-ambiguous-tax/check.sh eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md tests/abtest-checks.test.sh && git commit -m "fix(abt-u07): E1 premise check requires a recorded assumption, plant states no-mutation, baseline names no eval (#575)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/fixtures/` (template T1 stays untouched; the description is neutralised in this fixture build only)
- `eval/abtest/verify-checks.sh`, `eval/abtest/checks/lib.sh`, `eval/abtest/checks/scope.sh`, `eval/abtest/fixtures/lib.sh` (unit abt-u04 owns them; the scope.sh exemptions are watched in the pilot)
- `eval/abtest/fixtures/e01-ambiguous-tax/reference.patch`, `eval/abtest/fixtures/e01-ambiguous-tax/allowed-paths.txt`, `eval/abtest/fixtures/e01-ambiguous-tax/plant/README.md` (they stay as committed; the replay shows the reference still passes every required check)
- `eval/abtest/tasks/e01-ambiguous-tax.prompt.md` (the prompt is verbatim from the design; its sha256 is a criterion of the original unit)
- `eval/abtest/checks/e01-ambiguous-tax/characterisation.holdout.test.js` (unchanged)
- `tests/validate.sh` (merge-gate registration is unit abt-u17; this fix adds rows to the already-registered tests/abtest-checks.test.sh and no new tests/abtest-*.test.sh file, so the u17 count of eight suites holds)
- `eval/abtest/arms/`, `eval/abtest/lib/`, `eval/abtest/templates/`, `eval/harness/`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-checks.test.sh | tail -n 2 | paste -sd" "`
   exit: 0
   stdout: `abtest-checks: 80 passed, 0 failed All abtest-checks checks passed.`
   mutation: skip edit 2 (assumptions.sh); the premise rows FAIL, the summary counts differ and the passed line is absent.
2. run: `bash eval/abtest/verify-checks.sh e01-ambiguous-tax | paste -sd" "`
   exit: 0
   stdout: `verify: e01-ambiguous-tax baseline-required-failures=2/4 reference-required-failures=0/4 verify-checks: ok`
   mutation: skip edit 2; check.sh calls a missing script, the reference fails the premise check and the line reads reference-required-failures=1/4 verify-checks: FAILED.
3. run: `grep -c "never mutates its arguments" eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 5 (the plant line); stdout 0 and the exit is 1.
4. run: `D=$(mktemp -d); bash eval/abtest/fixtures/e01-ambiguous-tax/build.sh "$D/w" > /dev/null && git -C "$D/w" show HEAD:package.json HEAD:README.md HEAD:CONTEXT.md | grep -ciE "antislop|eval|pilot|claude"; r=$?; rm -rf "$D"; exit $r`
   exit: 1
   stdout: `0`
   mutation: skip edit 4 (build.sh); package.json keeps the template description and stdout is 1 with exit 0. A failed build prints nothing.
5. run: `ls eval/abtest/checks/e01-ambiguous-tax | paste -sd" "`
   exit: 0
   stdout: `assumptions.sh characterisation.holdout.test.js check.sh tax.holdout.test.js`
   mutation: skip edit 2; the listing lacks assumptions.sh.
6. run: `grep -c "assert.notEqual" eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js`
   exit: 1
   stdout: `0`
   mutation: skip edit 6; stdout 1 and the exit is 0.
7. run: `D=$(mktemp -d); printf "%s\n" "- Added a separate tax helper." > "$D/a.md"; bash eval/abtest/checks/e01-ambiguous-tax/assumptions.sh "$D/a.md"; r=$?; rm -rf "$D"; exit $r`
   exit: 1
   stdout: empty
   mutation: skip edit 2; bash cannot open the missing script and exits 127, not 1.
8. run: `D=$(mktemp -d); printf "%s\n" "- I assumed the 8 means 8 percent, applied to the discounted subtotal" > "$D/a.md"; bash eval/abtest/checks/e01-ambiguous-tax/assumptions.sh "$D/a.md"; r=$?; rm -rf "$D"; exit $r`
   exit: 0
   stdout: empty
   mutation: skip edit 2; the script is missing and the exit is 127.
9. run: `grep -c "assumptions.sh" eval/abtest/checks/e01-ambiguous-tax/check.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (check.sh); stdout 0 and the exit is 1.
10. run: `D=$(mktemp -d); mkdir -p "$D/fx"; cp -r eval/abtest/fixtures/e01-ambiguous-tax "$D/fx/"; rm -rf "$D/fx/e01-ambiguous-tax/plant"; mkdir "$D/fx/e01-ambiguous-tax/plant"; ABT_REPO_ROOT="$PWD" bash "$D/fx/e01-ambiguous-tax/build.sh" "$D/w" > /dev/null 2>&1; r=$?; rm -rf "$D"; exit $r`
   exit: 1
   stdout: empty
   mutation: skip edit 4; an empty plant builds without complaint and the exit is 0.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u07\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/checks/e01-ambiguous-tax/assumptions.sh eval/abtest/checks/e01-ambiguous-tax/check.sh eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md tests/abtest-checks.test.sh`
   mutation: skip edit 9 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u07\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -cE "^(fix\(abt-u07\): E1 premise check requires|Co-Authored-By: Claude .* <noreply@anthropic.com>$)"`
   exit: 0
   stdout: `2`
   mutation: skip edit 9; the newest abt-u07 commit is the original (subject feat(...)), so only the trailer line matches and stdout is 1.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u07\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/checks/e01-ambiguous-tax/assumptions.sh eval/abtest/checks/e01-ambiguous-tax/check.sh eval/abtest/checks/e01-ambiguous-tax/tax.holdout.test.js eval/abtest/fixtures/e01-ambiguous-tax/build.sh eval/abtest/fixtures/e01-ambiguous-tax/plant/CONTEXT.md tests/abtest-checks.test.sh | grep -vcE "^[a-z]+\(abt-u07\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
14. run: `git status --porcelain -- eval/abtest/checks/e01-ambiguous-tax eval/abtest/fixtures/e01-ambiguous-tax tests/abtest-checks.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 9; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-checks.test.sh (criterion 1 is red-then-green: the new rows FAIL at HEAD because assumptions.sh does not exist and the plant has no mutation line)
blast-radius: none
fix-of: 2026-10-16T22:45:51Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part. Inline-code payloads are literal. The before payloads are exact copies of the committed text: copy, do not retype.
why: the FAIL showed the required premise check assumptions-recorded passing on an ASSUMPTIONS.md that records no assumption, because the prompt's own parameter name taxRate matches both unanchored greps and "separate" contains "rate". The matcher now needs a word-bounded percent/percentage/per cent/% AND a post-discount statement, after dropping echoes of the signature and of pre-discount wording; a table of positive and negative samples in tests/abtest-checks.test.sh includes the reviewer's two repro strings (now FAIL) and genuine phrasings (PASS). It stays AntiSlop-agnostic and reads only ASSUMPTIONS.md.
folded-in: (a) the plant glossary gains a "pure helper" entry so the hidden "items not mutated" assertion is resolvable from repo evidence; it names applyDiscountPercent as the one legacy exception and says nothing about 108 or the discount/tax order. (b) build.sh replaces the T1 package.json description (it said antislop eval pilot and headless claude -p) in this fixture only and exits non-zero unless the plant lines are present and package.json, README.md and CONTEXT.md contain none of antislop, eval, pilot, claude; the tests prove build.sh refuses an empty plant, a glossary without the mutation line and a README that names the tool. (c) the redundant notEqual loop in tax.holdout.test.js is deleted; assert.equal(total, 108) already implies it.
counts: the required-check count stays 4 and verify-checks still prints baseline-required-failures=2/4 reference-required-failures=0/4, so nothing keyed to those numbers (units abt-u12, abt-u14, abt-u16, abt-u17, abt-u21a) shifts. The check names are unchanged. The checks directory gains assumptions.sh, so criterion 4 of the original unit (the directory listing) is superseded by criterion 5 here. The design section E1 premise command text differs from the shipped check by this fix; the plan document is not edited.
fail-closed-tests: every new row compares against a non-empty expected value and is paired with a presence check (a 40-hex sha, the committed plant lines, a package.json that still parses and runs node --test, a positive control that the leak pattern sees the template description, an unmodified copy that builds), so a crash, a missing file or an empty output reads as FAIL. The matcher exits 0 only on its final line and exits 1 for a missing, empty, blank or unreadable file and for a crashed tool.
not-covered: a statement that denies the fact (for example "the rate is not a percentage") still matches the keyword; the hidden code test, not this check, settles correctness. The scope.sh exemptions and the redundancy that the prompt already settles the tax order are left alone on purpose.
already-green: criterion 2 (verify-checks) passes at HEAD by design because the check count and the 2/4 baseline do not change; it is proven through its skip-edit mutation. Criterion 13 (the untagged-tail count) and criterion 14 (the scoped clean-tree check) pass at HEAD by design and turn red only when a later commit is untagged or the commit step is skipped.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u07): E1 premise check requires a recorded assumption, plant states no-mutation, baseline names no eval (#575)
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
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
