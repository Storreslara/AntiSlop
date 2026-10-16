#!/usr/bin/env bash
# Tests the check conventions (checks/lib.sh, checks/scope.sh) and the
# non-vacuity verifier (verify-checks.sh) over synthetic fixtures.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY="$REPO_ROOT/eval/abtest/verify-checks.sh"
SCOPE="$REPO_ROOT/eval/abtest/checks/scope.sh"
SYN="$REPO_ROOT/tests/fixtures/abtest/verify"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing '$3' in '$2')" ;; esac; }

export ABT_FIXTURES_DIR="$SYN/fixtures" ABT_CHECKS_ROOT="$SYN/checks"

out="$(bash "$VERIFY" syn-ok)"; rc=$?
check "a non-vacuous fixture verifies" "$rc" "0"
has "verify reports the baseline failure and a clean reference" "$out" "verify: syn-ok baseline-required-failures=1/2 reference-required-failures=0/2"
has "verify ends ok" "$out" "verify-checks: ok"
out="$(bash "$VERIFY" syn-vacuous)"; rc=$?
check "a check that passes on the baseline is rejected" "$rc" "1"
has "the vacuous fixture reports no baseline failure" "$out" "baseline-required-failures=0/2"
out="$(bash "$VERIFY" syn-badref)"; rc=$?
check "a reference that does not satisfy a check is rejected" "$rc" "1"
has "the bad reference reports a reference failure" "$out" "reference-required-failures=1/2"
out="$(bash "$VERIFY" syn-series)"; rc=$?
check "a reference series applies one commit per patch" "$rc" "0"
has "the series reference passes every required check" "$out" "verify: syn-series baseline-required-failures=2/3 reference-required-failures=0/3"
out="$(bash "$VERIFY" --all)"; rc=$?
check "--all fails when any fixture fails" "$rc" "1"

mkdir -p "$T/fx" "$T/ck"
cp -r "$SYN/fixtures/syn-ok" "$T/fx/syn-path"
cp -r "$SYN/checks/syn-ok" "$T/ck/syn-path"
printf '# see fixtures/x\n' >> "$T/ck/syn-path/check.sh"
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-path)"; rc=$?
check "a check naming a fixture path is rejected" "$rc" "1"
has "the path rule is named" "$out" "names a fixture or run path"

cp -r "$SYN/fixtures/syn-ok" "$T/fx/syn-nondet"
cp -r "$SYN/checks/syn-ok" "$T/ck/syn-nondet"
printf 'date +%%s%%N > "$1/stamp.txt"\ncd "$1" && git add -A && git commit -q --amend -m baseline\ngit rev-parse HEAD\n' >> "$T/fx/syn-nondet/build.sh"
sed -i 's/^abt_fixture_baseline "\$1"$/abt_fixture_baseline "$1" >\/dev\/null/' "$T/fx/syn-nondet/build.sh"
out="$(ABT_FIXTURES_DIR="$T/fx" ABT_CHECKS_ROOT="$T/ck" bash "$VERIFY" syn-nondet)"; rc=$?
check "a nondeterministic build is rejected" "$rc" "1"
has "the build rule is named" "$out" "nondeterministic build"

out="$(ABT_FIXTURES_DIR="$T/none" ABT_CHECKS_ROOT="$T/none" bash "$VERIFY" absent)"; rc=$?
check "a missing fixture is rejected" "$rc" "1"

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

# lib.sh: run checks against a hand-built tree.
R="$T/repo"
ABT_REPO_ROOT="$REPO_ROOT" bash "$SYN/fixtures/syn-ok/build.sh" "$R" > "$T/sha"
BASE="$(tail -n1 "$T/sha")"
printf 'answer.txt\n' > "$T/allowed"
printf 'x' > "$R/package.json"
cat > "$T/lib-check.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
abt_init "$1" "$2" "$3" "$4"
abt_check restored-runner defect true 'grep -q syn package.json'
abt_check cannot-touch-tree defect false 'rm -f answer.txt'
abt_check sees-env process false 'test -n "$ABT_BASE" && test -d "$ABT_CHECKS_DIR"'
abt_emit
EOS
json="$(ABT_CHECKS_LIB="$REPO_ROOT/eval/abtest/checks/lib.sh" bash "$T/lib-check.sh" "$R" "$BASE" "$BASE" "$T/allowed")"
check "package.json is restored from the baseline inside the check" "$(printf '%s' "$json" | python3 -I -c 'import json,sys;print(json.load(sys.stdin)[0]["pass"])')" "True"
check "the agent tree survives a destructive check" "$(test -f "$R/answer.txt" && cat "$R/package.json")" "x"
check "the check environment is exported" "$(printf '%s' "$json" | python3 -I -c 'import json,sys;print(json.load(sys.stdin)[2]["pass"])')" "True"
cat > "$T/bad-kind.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
abt_init "$1" "$2" "$3" "$4"
abt_check x bogus true true
EOS
ABT_CHECKS_LIB="$REPO_ROOT/eval/abtest/checks/lib.sh" bash "$T/bad-kind.sh" "$R" "$BASE" "$BASE" "$T/allowed" > /dev/null 2>&1
check "an unknown kind exits 2" "$?" "2"

# scope.sh: only edits outside the allowed paths count; .claude and docs/plans never do.
S="$T/scope"
mkdir -p "$S" && git -C "$S" init -q -b main
printf 'a\n' > "$S/answer.txt"
git -C "$S" add -A && git -C "$S" -c user.name=t -c user.email=t@t.invalid commit -q -m start
START="$(git -C "$S" rev-parse HEAD)"
printf 'b\nc\n' >> "$S/answer.txt"
printf '1\n2\n3\n' > "$S/other.js"
mkdir -p "$S/.claude" "$S/docs/plans"
printf 'z\n' > "$S/.claude/x"
printf 'z\n' > "$S/docs/plans/p.md"
git -C "$S" add -A && git -C "$S" -c user.name=t -c user.email=t@t.invalid commit -q -m work
check "scope lines count only the outside edit" "$(bash "$SCOPE" "$S" "$START" "$T/allowed" lines)" "3"
check "scope files count only the outside file" "$(bash "$SCOPE" "$S" "$START" "$T/allowed" files)" "1"
printf 'answer.txt' > "$T/allowed-nonl"
check "scope lines honor a last allowed path with no trailing newline" "$(bash "$SCOPE" "$S" "$START" "$T/allowed-nonl" lines)" "3"
check "scope.sh rejects an unknown mode" "$(bash "$SCOPE" "$S" "$START" "$T/allowed" bogus >/dev/null 2>&1; echo $?)" "2"

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

echo "abtest-checks: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-checks checks passed."
exit "$fail"
