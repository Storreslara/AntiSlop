#!/usr/bin/env bash
# Tests the check conventions (checks/lib.sh, checks/scope.sh) and the
# non-vacuity verifier (verify-checks.sh) over synthetic fixtures.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY="$REPO_ROOT/eval/abtest/verify-checks.sh"
SCOPE="$REPO_ROOT/eval/abtest/checks/scope.sh"
SYN="$REPO_ROOT/tests/fixtures/abtest/verify"
T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }
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

# E1 (abt-u07): the plant evidence, the presence check and a neutral baseline.
E1FX="$REPO_ROOT/eval/abtest/fixtures/e01-ambiguous-tax"
E1CK="$REPO_ROOT/eval/abtest/checks/e01-ambiguous-tax"
mkdir -p "$T/e1"
check "the reference ASSUMPTIONS.md holds three bullets" "$(grep -cE '^\+- ' "$E1FX/reference.patch")" "3"

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

# check.sh: assumptions-file-present is a non-required process check that reads no wording; the code checks stay green.
git -C "$E1W" apply --recount "$E1FX/reference.patch" && git -C "$E1W" add -A \
  && git -C "$E1W" -c user.name=abtest -c user.email=abtest@example.invalid commit -q -m reference
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

# --- leak guard (abt-u05c): fixtures/lib.sh abt_leak_guard scans the built baseline tree ---
lg() { ( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_leak_guard "$1" ) 2>&1; echo "rc=$?"; }
lgcase() {
  local name="$1" dir="$2" rc="$3" text="$4" out
  out="$(lg "$dir")"
  if [ -z "$text" ]; then
    [ "$out" = "rc=$rc" ] && ok "$name" || bad "$name (got '$out')"
  else
    [[ "$out" == *"$text"* && "$out" == *"rc=$rc" ]] && ok "$name" || bad "$name (got '$out')"
  fi
}
lgmk() { mkdir -p "$T/lg/$1/$(dirname "$2")" && printf '%s\n' "$3" > "$T/lg/$1/$2" || bad "setup: could not write lg/$1/$2"; }
lgmk clean package.json '{"name":"x","description":"Zero-dependency notes service."}'
lgmk clean README.md 'We evaluate options. Retrieval, medieval and copilot are fine. See CLAUDE.md for conventions.'
lgmk clean CLAUDE.md 'Run npm test. CLAUDE.md is this file.'
lgmk clean docs/adr/0001-x.md 'An in-memory store.'
lgcase "leak guard: a clean tree passes (positive control)" "$T/lg/clean" 0 ""
for spec in "package.json|{\"description\":\"for the antislop comparison suite\"}|'antislop'" "README.md|the eval harness|'eval'" "CONTEXT.md|a pilot run|'pilot'" \
            "docs/adr/0002-y.md|the persona files|'persona'" "CLAUDE.md|Ask Claude for help|'Claude'" "README.md|a holdout test|'holdout'" \
            "CONTEXT.md|the hidden check passes|'hidden check'" "docs/wiki/a/b.md|AntiSlop notes|'AntiSlop'"; do
  IFS='|' read -r f c w <<< "$spec"
  rm -rf "$T/lg/leak"; cp -r "$T/lg/clean" "$T/lg/leak"; lgmk leak "$f" "$c"
  lgcase "leak guard: $f naming $w is refused" "$T/lg/leak" 1 "$f names the eval or the tool ($w)"
done
lgcase "leak guard: a missing directory is refused" "$T/lg/absent" 1 "is not a directory"
rm -rf "$T/lg/real"; mkdir -p "$T/lg/real"; cp -r "$REPO_ROOT/eval/abtest/templates/notes-svc/." "$T/lg/real/"
lgcase "leak guard: the real T2 template tree passes" "$T/lg/real" 0 ""
check "the T2 package.json description is neutral" "$(grep -c '"description": "Zero-dependency notes service."' "$T/lg/real/package.json")" "1"
sed -i 's|^  "description": .*$|  "description": "Zero-dependency notes service for the antislop comparison evals. Network-free on purpose.",|' "$T/lg/real/package.json"
lgcase "leak guard: the old T2 description is refused (the real leak)" "$T/lg/real" 1 "package.json names the eval or the tool ('antislop')"
rm -rf "$T/lg/mk"; mkdir -p "$T/lg/mk"; printf '{"description":"an eval harness"}\n' > "$T/lg/mk/package.json"
out="$( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/mk" 2>&1 )"; rc=$?
check "abt_fixture_baseline refuses a leaking tree" "$rc" "1"
check "the refused baseline made no repository" "$(test -d "$T/lg/mk/.git" && echo made || echo none)" "none"
rm -rf "$T/lg/ok"; mkdir -p "$T/lg/ok"; printf '{"description":"notes"}\n' > "$T/lg/ok/package.json"
sha="$( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/ok" )"; rc=$?
check "abt_fixture_baseline still commits a clean tree" "$rc|$(printf '%s' "$sha" | tail -n1 | grep -cE '^[0-9a-f]{40}$')" "0|1"
ABT_REPO_ROOT="$REPO_ROOT" bash "$REPO_ROOT/eval/abtest/fixtures/e01-ambiguous-tax/build.sh" "$T/lg/e01" > "$T/lg/e01.out" 2> "$T/lg/e01.err"; rc=$?
sha="$(tail -n1 "$T/lg/e01.out")"
check "the E1 build, with its own guard, still builds under the lib guard" "$rc|$(printf '%s' "$sha" | grep -cE '^[0-9a-f]{40}$')" "0|1"
# --- neutral baseline identity and git-history scan (abt-u05d) ---
# A failing tool must fail the guard: each case puts a fake tool first on PATH that exits non-zero.
FK="$T/fake"; mkdir -p "$FK"
lgfake() {
  local tool="$1" body="$2" dir="$3"
  printf '#!/bin/sh\n%s\n' "$body" > "$FK/$tool"; chmod +x "$FK/$tool"
  ( PATH="$FK:$PATH"; . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_leak_guard "$dir" ) 2>&1; echo "rc=$?"
  rm -f "${FK:?}/${tool:?}"
}
rm -rf "$T/lg/gitfail"; mkdir -p "$T/lg/gitfail"; printf '{"description":"notes"}\n' > "$T/lg/gitfail/package.json"
( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/gitfail" > /dev/null )
printf '#!/bin/sh\ncase " $* " in *" $FAKE_GIT_FAIL "*) exit 128 ;; esac\nexec "$FAKE_GIT_REAL" "$@"\n' > "$FK/git"; chmod +x "$FK/git"
REALGIT="$(command -v git)"
lgfakegit() { ( PATH="$FK:$PATH"; FAKE_GIT_REAL="$REALGIT"; export FAKE_GIT_REAL; FAKE_GIT_FAIL="$1"; export FAKE_GIT_FAIL; . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_leak_guard "$2" ) 2>&1; echo "rc=$?"; }
out="$(lgfakegit log "$T/lg/gitfail")"
has "leak guard: a failing git log fails the guard" "$out" "git log failed in"
out="$(lgfakegit for-each-ref "$T/lg/gitfail")"
has "leak guard: a failing git for-each-ref fails the guard" "$out" "git for-each-ref failed in"
out="$(lgfakegit nothing "$T/lg/gitfail")"
has "leak guard: the same fake git that fails nothing lets a clean history pass (control)" "$out" "rc=0"
rm -f "${FK:?}/git"
rm -rf "$T/lg/gitnoscope"; mkdir -p "$T/lg/gitnoscope/src"; printf 'x\n' > "$T/lg/gitnoscope/src/x.js"
( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/gitnoscope" > /dev/null )
out="$(lgfake grep 'exit 2' "$T/lg/gitnoscope")"
has "leak guard: a failing grep fails the guard on a history" "$out" "grep failed on the git history"
# The git history is scanned too.
lgrepo() {
  local name="$1" msg="$2"
  rm -rf "$T/lg/hist"; mkdir -p "$T/lg/hist"; printf '{"description":"notes"}\n' > "$T/lg/hist/package.json"
  shift 2
  ( cd "$T/lg/hist" && git init -q -b main && git add -A \
    && env GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid "$@" git commit -q -m "$msg" ) || bad "setup: git commit failed for $name"
}
lgrepo neutral "initial import"
lgcase "leak guard: a neutral history passes (control)" "$T/lg/hist" 0 ""
lgrepo trapezoid "trapezoid and plantation notes"
lgcase "leak guard: near words in a history are fine (control)" "$T/lg/hist" 0 ""
lgrepo an "initial import" GIT_AUTHOR_NAME=abtest
lgcase "leak guard: an author name abtest is refused" "$T/lg/hist" 1 "git history of $T/lg/hist names the eval or the tool ('abtest')"
lgrepo ae "initial import" GIT_AUTHOR_EMAIL=abtest@example.invalid
lgcase "leak guard: an author email abtest is refused" "$T/lg/hist" 1 "('abtest')"
lgrepo cn "initial import" GIT_COMMITTER_NAME=eval
lgcase "leak guard: a committer name eval is refused" "$T/lg/hist" 1 "('eval')"
lgrepo ce "initial import" GIT_COMMITTER_EMAIL=claude@example.invalid
lgcase "leak guard: a committer email claude is refused" "$T/lg/hist" 1 "('claude')"
lgrepo m1 "fixture baseline"
lgcase "leak guard: the word fixture in a commit message is refused" "$T/lg/hist" 1 "('fixture')"
lgrepo m2 "add the trap"
lgcase "leak guard: the word trap in a commit message is refused" "$T/lg/hist" 1 "('trap')"
lgrepo m3 "AntiSlop import"
lgcase "leak guard: AntiSlop in a commit message is refused" "$T/lg/hist" 1 "('AntiSlop')"
lgrepo m4 "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --amend -m "initial import" -m "the plant is here"
lgcase "leak guard: a word in the body of a commit message is refused" "$T/lg/hist" 1 "('plant')"
for spec in "evals|evals" "pilots|pilots" "personas|personas" "holdouts|holdouts" "hidden checks|hidden checks" "Anti-Slop|Anti-Slop" "anti slop|anti slop" "traps|traps" "plants|plants" "fixtures|fixtures"; do
  IFS='|' read -r hm hw <<< "$spec"
  lgrepo hw "update $hm"
  lgcase "leak guard: the history word $hm is refused" "$T/lg/hist" 1 "('$hw')"
done
lgrepo br "initial import"
git -C "$T/lg/hist" branch eval-branch
lgcase "leak guard: a branch name with eval is refused" "$T/lg/hist" 1 "('eval')"
lgrepo tg "initial import"
git -C "$T/lg/hist" tag pilot-1
lgcase "leak guard: a tag name with pilot is refused" "$T/lg/hist" 1 "('pilot')"
lgrepo ta "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid tag -a v1 -m "persona release"
lgcase "leak guard: an annotated tag message with persona is refused" "$T/lg/hist" 1 "('persona')"
lgrepo tn "initial import"
git -C "$T/lg/hist" -c user.name=abtest -c user.email=dev@example.invalid tag -a v2 -m "release"
lgcase "leak guard: an annotated tag by a tagger abtest is refused" "$T/lg/hist" 1 "('abtest')"
lgrepo ob "initial import"
git -C "$T/lg/hist" checkout -q -b other && git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --allow-empty -m "fixture notes" && git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --allow-empty -m "tidy" && git -C "$T/lg/hist" checkout -q main && git -C "$T/lg/hist" branch -q -m other side
lgcase "leak guard: a commit reachable only from another branch is scanned" "$T/lg/hist" 1 "('fixture')"
lgrepo oc "fixture first"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --allow-empty -m "tidy"
lgcase "leak guard: a leaking subject on an older commit is refused" "$T/lg/hist" 1 "('fixture')"
lgrepo od "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --amend -m "initial import" -m "the plant is here"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --allow-empty -m "tidy"
lgcase "leak guard: a leaking body on an older commit is refused" "$T/lg/hist" 1 "('plant')"
lgrepo nw "subtrap and microeval notes"
lgcase "leak guard: a word glued to other letters in a history is fine (control)" "$T/lg/hist" 0 ""
# abt_fixture_baseline: neutral identity, neutral message, one branch, and a leaking history leaves no repository.
rm -rf "$T/lg/id"; mkdir -p "$T/lg/id"; printf '{"description":"notes"}\n' > "$T/lg/id/package.json"
( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/id" > /dev/null )
check "the baseline commit has a neutral identity and message" "$(git -C "$T/lg/id" log --format='%an|%ae|%cn|%ce|%s')" "dev|dev@example.invalid|dev|dev@example.invalid|initial import"
check "the baseline repository has one commit and one ref" "$(git -C "$T/lg/id" rev-list --all --count)|$(git -C "$T/lg/id" for-each-ref --format='%(refname)')" "1|refs/heads/main"
check "the baseline commit date is fixed" "$(git -C "$T/lg/id" log -1 --format='%aI|%cI' | sed 's/Z/+00:00/g')" "2026-01-01T00:00:00+00:00|2026-01-01T00:00:00+00:00"
check "a built E1 baseline passes the guard, history included" "$(lg "$T/lg/e01")" "rc=0"
check "the built E1 baseline history is neutral" "$(git -C "$T/lg/e01" log --format='%an|%ae|%s')" "dev|dev@example.invalid|initial import"
rm -rf "$T/lg/leakid"; mkdir -p "$T/lg/leakid"; printf '{"description":"notes"}\n' > "$T/lg/leakid/package.json"
out="$( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_env() { export GIT_AUTHOR_NAME=abtest GIT_AUTHOR_EMAIL=a@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid; }; abt_fixture_baseline "$T/lg/leakid" 2>&1 )"; rc=$?
check "a baseline whose history leaks is refused" "$rc" "1"
has "the history leak is named" "$out" "names the eval or the tool ('abtest')"
check "the refused baseline left no repository" "$(test -e "$T/lg/leakid/.git" && echo made || echo none)" "none"
# --- leak guard hardening (abt-u05e): plurals, spellings, file names, dot-directories, symlinks, tool failures ---
lgleak() {
  rm -rf "$T/lg/leak"; cp -r "$T/lg/clean" "$T/lg/leak" || bad "setup: cp failed for $1"; lgmk leak "$2" "$3"
  lgcase "leak guard: $1" "$T/lg/leak" 1 "$2 names the eval or the tool ('$4')"
}
lgleak "the plural evals in README.md is refused" README.md 'the evals run nightly' evals
lgleak "the plural personas in CONTEXT.md is refused" CONTEXT.md 'three personas review' personas
lgleak "the plural holdouts in docs is refused" docs/a.md 'two holdouts remain' holdouts
lgleak "the plural pilots in README.md is refused" README.md 'a pilots list' pilots
lgleak "the plural hidden checks in README.md is refused" README.md 'the hidden checks run' 'hidden checks'
lgleak "Anti-Slop with a hyphen is refused" README.md 'About Anti-Slop notes' Anti-Slop
lgleak "anti slop with a space is refused" README.md 'about anti slop notes' 'anti slop'
lgleak "abtest in README.md is refused" README.md 'run the abtest now' abtest
lgleak "a lower-case readme.md is scanned" readme.md 'the eval harness' eval
lgleak "a mixed-case Readme.MD is scanned" Readme.MD 'the eval harness' eval
lgleak "a README with no extension is scanned" README 'the eval harness' eval
lgleak "agents.md is scanned" agents.md 'the eval harness' eval
lgleak "AGENTS.md is scanned" AGENTS.md 'the eval harness' eval
lgleak "a lower-case context.md is scanned" context.md 'the eval harness' eval
lgleak "a lower-case claude.md is scanned" claude.md 'the eval harness' eval
lgleak "a nested README.md is scanned" sub/dir/README.md 'the eval harness' eval
lgleak "README.txt is scanned" README.txt 'the eval harness' eval
lgleak "README.markdown is scanned" README.markdown 'the eval harness' eval
lgleak "CONTEXT.mdx is scanned" CONTEXT.mdx 'the eval harness' eval
lgleak "agents.rst is scanned" agents.rst 'the eval harness' eval
lgleak "a Docs directory in another case is scanned" Docs/a.md 'the eval harness' eval
lgleak "a text file under docs is scanned" docs/notes.txt 'the eval harness' eval
lgleak "a file in .github is scanned" .github/workflows/ci.yml 'run claude here' claude
lgleak "a file in .claude is scanned" .claude/settings.json '{"note":"eval"}' eval
lgleak "a top-level dot file is scanned" .npmrc 'eval=true' eval
lgleak "a file in a nested dot-directory is scanned" src/.cache/x.txt 'the pilot run' pilot
rm -rf "$T/lg/leak"; cp -r "$T/lg/clean" "$T/lg/leak"; lgmk leak docs/a.md 'the eval harness'
lgcase "leak guard: a destination with a trailing slash is scanned in full" "$T/lg/leak/" 1 "docs/a.md names the eval or the tool ('eval')"
rm -rf "$T/lg/ctl"; cp -r "$T/lg/clean" "$T/lg/ctl"
lgmk ctl src/context.js 'function evalAll() { return eval("1"); }'
lgmk ctl src/notes.js '// a persona and a pilot, in source'
lgmk ctl test/readme-notes.test.js 'eval persona holdout'
lgmk ctl notes.md 'eval persona holdout, in a file the guard does not name'
lgmk ctl README.extra 'eval'
lgmk ctl docs/ok.md 'We evaluate options; personality, copilot, pilotage, claudette and anti-social slopes are fine.'
lgcase "leak guard: source, test and unnamed files are not scanned, near words are fine (control)" "$T/lg/ctl" 0 ""
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; lgmk sym src/x.js 'eval'; ln -s ../src/x.js "$T/lg/sym/docs/link.md"
lgcase "leak guard: a symlink under docs is refused" "$T/lg/sym" 1 "docs/link.md is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; ln -s missing.md "$T/lg/sym/docs/dangling.md"
lgcase "leak guard: a dangling symlink under docs is refused" "$T/lg/sym" 1 "docs/dangling.md is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; lgmk sym src/x.js 'eval'; ln -s src/x.js "$T/lg/sym/README.txt"
lgcase "leak guard: a symlink named README.txt is refused" "$T/lg/sym" 1 "README.txt is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; mkdir -p "$T/lg/sym/real"; ln -s real "$T/lg/sym/.claude"
lgcase "leak guard: a symlinked dot-directory is refused" "$T/lg/sym" 1 ".claude is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; mkdir -p "$T/lg/sym/real"; printf 'x\n' > "$T/lg/sym/real/a.md"; rm -rf "$T/lg/sym/docs"; ln -s real "$T/lg/sym/docs"
lgcase "leak guard: a symlinked docs directory is refused" "$T/lg/sym" 1 "docs is a symbolic link"
rm -rf "$T/lg/sym"; cp -r "$T/lg/clean" "$T/lg/sym"; lgmk sym src/x.js 'x'; ln -s x.js "$T/lg/sym/src/link.js"
lgcase "leak guard: a symlink outside the scanned files is fine (control)" "$T/lg/sym" 0 ""
out="$(lgfake find 'exit 2' "$T/lg/clean")"
has "leak guard: a failing find fails the guard" "$out" "find failed under"
out="$(lgfake find 'printf "x\0"; exit 2' "$T/lg/clean")"
has "leak guard: a find that fails after printing fails the guard" "$out" "find failed under"
out="$(lgfake grep 'echo eval; exit 2' "$T/lg/clean")"
has "leak guard: a failing grep fails the guard" "$out" "grep failed on"
has "leak guard: a failing grep exits 1" "$out" "rc=1"
out="$(lgfake sed 'exit 4' "$T/lg/clean")"
has "leak guard: a failing sed fails the guard" "$out" "cannot read"
out="$(lgfake mktemp 'exit 1' "$T/lg/clean")"
has "leak guard: a failing mktemp fails the guard" "$out" "cannot create a temp file"
lgrepo gd "initial import"
printf 'eval\n' > "$T/lg/hist/.git/hooks/note"
lgcase "leak guard: files inside .git are not scanned (control)" "$T/lg/hist" 0 ""
# A failing fixture build must be seen as failed (the exit code is read from the build itself, not from a pipe).
rm -rf "$T/lg/badroot"; mkdir -p "$T/lg/badroot/eval/abtest/fixtures" "$T/lg/badroot/eval/fixtures"
cp "$REPO_ROOT/eval/abtest/fixtures/lib.sh" "$T/lg/badroot/eval/abtest/fixtures/lib.sh"
cp -r "$REPO_ROOT/eval/fixtures/toy-lib-template" "$T/lg/badroot/eval/fixtures/toy-lib-template"
mkdir -p "$T/lg/badroot/eval/fixtures/toy-lib-template/docs"; printf 'The eval harness.\n' > "$T/lg/badroot/eval/fixtures/toy-lib-template/docs/notes.md"
ABT_REPO_ROOT="$T/lg/badroot" bash "$E1FX/build.sh" "$T/lg/badbuild" > "$T/lg/badbuild.out" 2> "$T/lg/badbuild.err"; brc=$?
check "a failing E1 build exits non-zero" "$brc" "1"
has "the failing build says why" "$(cat "$T/lg/badbuild.err")" "names the eval or the tool"
# --- leak guard, last hardening round (abt-u05f): symlinked destination, slashes, word delimiters, notes, sample hooks ---
printf 'x\n' > "$T/lg/blockfile"
out="$( bad() { echo "BAD:$*"; }; lgmk blockfile/sub f x 2> /dev/null )"
has "lgmk reports a setup that cannot write" "$out" "BAD:setup: could not write lg/blockfile/sub/f"
out="$( bad() { echo "BAD:$*"; }; lgrepo broken "initial import" GIT_AUTHOR_DATE=not-a-date 2> /dev/null )"
has "lgrepo reports a commit that fails" "$out" "BAD:setup: git commit failed for broken"
out="$( cp() { return 1; }; bad() { echo "BAD:$*"; }; lgleak "probe" README.md x eval 2> /dev/null )"
has "lgleak reports a copy that fails" "$out" "BAD:setup: cp failed for probe"
ln -s "$T/lg/clean" "$T/lg/linkdest"
lgcase "leak guard: a symlinked destination is refused" "$T/lg/linkdest" 1 "is a symbolic link"
lgcase "leak guard: a symlinked destination with trailing slashes is refused" "$T/lg/linkdest//" 1 "linkdest is a symbolic link"
rm -rf "$T/lg/linktarget" "$T/lg/linkbase"; mkdir -p "$T/lg/linktarget"; printf '{"description":"notes"}\n' > "$T/lg/linktarget/package.json"; ln -s "$T/lg/linktarget" "$T/lg/linkbase"
out="$( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/linkbase" 2>&1 )"; rc=$?
check "a baseline into a symlinked destination is refused" "$rc" "1"
check "the refused symlinked destination got no repository" "$(test -e "$T/lg/linktarget/.git" && echo made || echo none)" "none"
rm -rf "$T/lg/slash"; cp -r "$T/lg/clean" "$T/lg/slash" || bad "setup: cp failed for slash"
lgmk slash docs/a.md 'the eval harness'
lgcase "leak guard: two trailing slashes still scan docs" "$T/lg/slash//" 1 "docs/a.md names the eval or the tool ('eval')"
rm -f "${T:?}/lg/slash/docs/a.md"
lgmk slash .github/x.yml 'run claude here'
lgcase "leak guard: three trailing slashes still scan dot-paths" "$T/lg/slash///" 1 ".github/x.yml names the eval or the tool ('claude')"
# Word delimiters: anything that is not a letter or digit ends a word, so underscores and hyphens join nothing.
while IFS='|' read -r txt want; do
  rm -rf "$T/lg/word"; mkdir -p "$T/lg/word" && printf '%b\n' "$txt" > "$T/lg/word/README.md" || bad "setup: word table"
  lgcase "leak guard word table: '$txt' is refused" "$T/lg/word" 1 "README.md names the eval or the tool ('$want')"
done << 'EOF'
EVAL_MODE=1|EVAL
run_eval|eval
MY_CLAUDE|CLAUDE
use claude|claude
CLAUDE_API_KEY=x|CLAUDE
ANTI_SLOP_HOME=/x|ANTI_SLOP
anti_slop|anti_slop
eval_run|eval
my-eval-run|eval
hidden-check|hidden-check
hidden  check|hidden  check
hidden_checks|hidden_checks
(persona)|persona
--holdout=1|holdout
eval(x)|eval
Pilot.|Pilot
abtest_runner|abtest
anti\nslop|anti slop
hidden\ncheck|hidden check
EOF
while IFS= read -r txt; do
  rm -rf "$T/lg/word"; mkdir -p "$T/lg/word" && printf '%b\n' "$txt" > "$T/lg/word/README.md" || bad "setup: word table"
  lgcase "leak guard word table: '$txt' passes" "$T/lg/word" 0 ""
done << 'EOF'
Describe the retrieval of inscribed text
prevalent and medieval and evaluate and evaluation
personality, pilotage, copilot and claudette
anti-social slopes and a sloppy diff
hidden checkpoint and a hidden clock
ev\nal and anti\nsocial
EOF
while IFS= read -r txt; do
  rm -rf "$T/lg/word"; mkdir -p "$T/lg/word" && printf '%b\n' "$txt" > "$T/lg/word/README.md" || bad "setup: word table"
  lgcase "leak guard word table (out of scope, joined to letters or digits): '$txt' passes" "$T/lg/word" 0 ""
done << 'EOF'
HiddenCheck and hiddencheck
myEvalMode and AntiSlopHome
eval2 and 2eval
EOF
# History rows that were missing: singular words, joined words, tagger email, notes.
for spec in "a holdout run|holdout" "the hidden check|hidden check" "EVAL_MODE on|EVAL" "hidden-check|hidden-check" "anti_slop|anti_slop" "the hidden  check|hidden  check" "run_eval now|eval"; do
  IFS='|' read -r hm hw <<< "$spec"
  lgrepo hs "update $hm"
  lgcase "leak guard: the history phrase $hm is refused" "$T/lg/hist" 1 "('$hw')"
done
lgrepo te "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=abtest@example.invalid tag -a v9 -m "release" || bad "setup: tag failed"
lgcase "leak guard: an annotated tag by an abtest email is refused" "$T/lg/hist" 1 "('abtest')"
lgrepo nt "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid notes add -m "the plant is here" || bad "setup: notes add failed"
lgcase "leak guard: a git note is refused" "$T/lg/hist" 1 "('plant')"
lgrepo nt2 "initial import"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid notes --ref=review add -m "the trap is here" || bad "setup: notes add failed"
lgcase "leak guard: a note in another notes ref is refused" "$T/lg/hist" 1 "('trap')"
out="$(lgfake grep 'exit 2' "$T/lg/gitnoscope")"
has "leak guard: a failing grep on a history exits 1" "$out" "rc=1"
# git's sample hooks name eval and trap: the built baseline carries none, and no forbidden word sits anywhere in .git outside objects.
RE_GIT='(^|[^[:alnum:]])(eval|trap|fixture|plant|pilot|persona|claude|holdout|abtest)([^[:alnum:]]|$)'
gitwords() { find "$1/.git" -path "$1/.git/objects" -prune -o -type f -exec grep -IiEl "$RE_GIT" {} +; }
rm -rf "$T/lg/plain"; mkdir -p "$T/lg/plain"; git -C "$T/lg/plain" init -q || bad "setup: git init failed"
check "a plain git init does carry forbidden words in its sample hooks (control)" "$(test -n "$(gitwords "$T/lg/plain")" && echo found || echo none)" "found"
rm -rf "$T/lg/built"; mkdir -p "$T/lg/built"; printf '{"description":"notes"}\n' > "$T/lg/built/package.json"
( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/built" > /dev/null )
check "the built baseline carries no forbidden word in .git outside objects" "$(gitwords "$T/lg/built")" ""
check "the built baseline has no sample hook" "$(find "$T/lg/built/.git/hooks" -name '*.sample' | wc -l | tr -d ' ')" "0"
check "the built E1 baseline carries no forbidden word in .git outside objects" "$(gitwords "$T/lg/e01")" ""
check "the E1 description does not call the tree a fixture" "$(grep -c '"description": "Minimal library with no external dependencies."' "$T/lg/e01/package.json")|$(grep -ci fixture "$T/lg/e01/package.json")" "1|0"

# --- check timeout (abt-u06b): a hung check command is ended and recorded as failed ---
cat > "$T/lib-timeout.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
abt_init "$1" "$2" "$3" "$4"
abt_check hangs defect false 'sleep 30'
abt_check fast defect false 'true'
abt_emit
EOS
tstart=$SECONDS
tjson="$(ABT_CHECK_TIMEOUT_S=1 ABT_CHECKS_LIB="$REPO_ROOT/eval/abtest/checks/lib.sh" bash "$T/lib-timeout.sh" "$R" "$BASE" "$BASE" "$T/allowed")"
telapsed=$((SECONDS - tstart))
check "a check that hangs is ended well before it would finish" "$([ "$telapsed" -lt 20 ] && echo fast || echo "slow:$telapsed")" "fast"
check "the hung check is recorded as failed with exit 124" "$(printf '%s' "$tjson" | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d[0]["id"],d[0]["pass"],d[0]["exit"])')" "hangs False 124"
check "a fast check next to it still passes" "$(printf '%s' "$tjson" | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d[1]["id"],d[1]["pass"],d[1]["exit"])')" "fast True 0"

# --- fail-closed worktree guard (abt-u05h): a bad worktree argument exits 3 and copies nothing ---
# Safe by construction: every guard run puts a cp stub first on PATH that copies only inside this test's temp dir
# and logs DANGER for any other path, so a lib.sh without the guard still cannot copy the filesystem.
REAL_CP="$(command -v cp)"
GROOT="$(realpath "$T")"
mkdir -p "$T/gstub" "$T/gtmp" "$T/gcwd" "$T/ghome"
cat > "$T/gstub/cp" << 'EOS'
#!/usr/bin/env bash
printf 'cp %s\n' "$*" >> "$GUARD_CP_LOG"
for a in "$@"; do
  case "$a" in -*) continue ;; esac
  r="$(realpath -m -- "$a" 2> /dev/null)"
  case "$r/" in "$GUARD_CP_ROOT"/*) ;; *) echo "DANGER $a" >> "$GUARD_CP_LOG"; echo "cp stub: refusing $a" >&2; exit 97 ;; esac
done
exec "$GUARD_REAL_CP" "$@"
EOS
chmod +x "$T/gstub/cp"
cat > "$T/guard-check.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
abt_init "$1" "$2" "$3" "$4"
abt_check g defect true 'true'
abt_emit
EOS
cat > "$T/guard-noinit.sh" << 'EOS'
. "$ABT_CHECKS_LIB"
unset ABT_WT
ABT_BASE=x
abt_check g defect true 'true'
abt_emit
EOS
: > "$T/gcp.all"
guard_run() {
  : > "$T/gcp.log"
  gout="$(cd "$T/gcwd" && (ulimit -f 20480; PATH="$T/gstub:$PATH" TMPDIR="$T/gtmp" HOME="$T/ghome" GUARD_CP_LOG="$T/gcp.log" GUARD_CP_ROOT="$GROOT" GUARD_REAL_CP="$REAL_CP" ABT_CHECKS_LIB="$REPO_ROOT/eval/abtest/checks/lib.sh" timeout -k 2s 30s bash "$1" "$2" "$BASE" "$BASE" "$T/allowed" 2> "$T/gerr.txt"))"; grc=$?
  gerr="$(cat "$T/gerr.txt")"
  cat "$T/gcp.log" >> "$T/gcp.all"
}
guard_refused() {
  guard_run "$2" "$3"
  check "guard: $1 exits 3" "$grc" "3"
  has "guard: $1 says why" "$gerr" "$4"
  check "guard: $1 prints no JSON" "$gout" ""
  check "guard: $1 leaves TMPDIR empty" "$(ls -A "$T/gtmp" | wc -l | tr -d ' ')" "0"
  check "guard: $1 calls cp zero times" "$(wc -l < "$T/gcp.log" | tr -d ' ')" "0"
}
mkdir -p "$T/space dir" "$T/gitless/.git" "$T/nl"$'\n'
git -C "$T/nl"$'\n' init -q
printf 'x\n' > "$T/afile"
ln -s / "$T/rootlink"
guard_refused "a nonexistent worktree" "$T/guard-check.sh" "$T/nope" "not an existing directory"
guard_refused "an empty string argument" "$T/guard-check.sh" "" "empty or unset"
guard_refused "the root directory" "$T/guard-check.sh" "/" "filesystem root"
guard_refused "a symbolic link to the root directory" "$T/guard-check.sh" "$T/rootlink" "filesystem root"
guard_refused "a file instead of a directory" "$T/guard-check.sh" "$T/afile" "not an existing directory"
guard_refused "an unset ABT_WT" "$T/guard-noinit.sh" "$R" "empty or unset"
guard_refused "a nonexistent directory with a space in its name" "$T/guard-check.sh" "$T/no such dir" "not an existing directory"
guard_refused "an existing directory with a space that is no worktree" "$T/guard-check.sh" "$T/space dir" "has no .git"
guard_refused "a directory whose name ends in a newline" "$T/guard-check.sh" "$T/nl"$'\n' "contains a newline"
guard_refused "the home directory" "$T/guard-check.sh" "$T/ghome" "is, or contains"
guard_refused "a parent of the home directory" "$T/guard-check.sh" "$T" "is, or contains"
guard_refused "the TMPDIR itself" "$T/guard-check.sh" "$T/gtmp" "is, or contains"
guard_refused "a .git that is not a repository" "$T/guard-check.sh" "$T/gitless" "not a git worktree"
cp -r "$R" "$T/good repo"
guard_run "$T/guard-check.sh" "$T/good repo"
check "guard: a real worktree with a space in its name still runs" "$grc" "0"
check "guard: that run reports the check as passed" "$(printf '%s' "$gout" | python3 -I -c 'import json,sys;print(json.load(sys.stdin)[0]["pass"])')" "True"
check "guard: that run copied the tree exactly once" "$(wc -l < "$T/gcp.log" | tr -d ' ')" "1"
check "guard: that run removed its copy and its output file" "$(ls -A "$T/gtmp" | wc -l | tr -d ' ')" "0"
check "guard: no run offered cp a path outside the test temp dir" "$(grep -c '^DANGER' "$T/gcp.all")" "0"
check "guard: the agent tree is untouched by the guard runs" "$(cat "$R/package.json")" "x"

# verify-checks.sh: a failing mktemp stops it before any fixture is built (the build stub only records its argument).
mkdir -p "$T/vg/fx/syn-x" "$T/vg/ck/syn-x" "$T/vg/bin"
cat > "$T/vg/fx/syn-x/build.sh" << EOS
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "$T/vg/built.log"
exit 1
EOS
: > "$T/vg/fx/syn-x/reference.patch"
: > "$T/vg/fx/syn-x/allowed-paths.txt"
printf '#!/usr/bin/env bash\n' > "$T/vg/ck/syn-x/check.sh"
printf '#!/bin/sh\nexit 1\n' > "$T/vg/bin/mktemp"
chmod +x "$T/vg/bin/mktemp"
vout="$(PATH="$T/vg/bin:$PATH" ABT_FIXTURES_DIR="$T/vg/fx" ABT_CHECKS_ROOT="$T/vg/ck" timeout 30s bash "$VERIFY" syn-x 2>&1)"; vrc=$?
check "verify-checks: a failing mktemp exits 2" "$vrc" "2"
has "verify-checks: a failing mktemp says so" "$vout" "cannot create a temp directory"
check "verify-checks: a failing mktemp builds nothing" "$(test -e "$T/vg/built.log" && echo built || echo none)" "none"

# run-matrix.sh: ABT_WORK and ABT_RUNS may not be /, the home directory or a parent of it (dry runs only; nothing is removed).
mkdir -p "$T/rmhome/.claude"
printf '{}\n' > "$T/rmhome/.claude/.credentials.json"
rm_dry() { HOME="$T/rmhome" ABTEST_CLAUDE="$REPO_ROOT/tests/fixtures/abtest/fake-claude.sh" ABT_RESULTS="$T/rm-res.jsonl" ABT_RUNS="${ABT_RUNS:-$T/rm-runs}" ABT_WORK="$1" timeout 60s bash "$REPO_ROOT/eval/abtest/run-matrix.sh" --pilot --evals e01-ambiguous-tax --dry-run 2>&1; }
for rmcase in "/" "$T/rmhome" "$T"; do
  rmout="$(rm_dry "$rmcase")"; rmrc=$?
  check "run-matrix: ABT_WORK=$rmcase exits 2" "$rmrc" "2"
  has "run-matrix: ABT_WORK=$rmcase says why" "$rmout" "ABT_RUNS and ABT_WORK must not be"
done
rmout="$(ABT_RUNS=/ rm_dry "$T/rmhome/work")"; rmrc=$?
check "run-matrix: ABT_RUNS=/ exits 2" "$rmrc" "2"
has "run-matrix: ABT_RUNS=/ says why" "$rmout" "ABT_RUNS and ABT_WORK must not be"
rmout="$(rm_dry "$T/rmhome/work")"; rmrc=$?
check "run-matrix: a work root below the home directory still plans" "$rmrc" "0"
has "run-matrix: that dry run lists the plan" "$rmout" "plan: e01-ambiguous-tax/A/uniform/1 run"

# fixtures/lib.sh abt_dest_guard and the five build.sh scripts: a build destination may not be empty, /, the home directory or a parent of it.
mkdir -p "$T/fakehome" "$T/ftmp"
dg() { ( export HOME="$T/fakehome" TMPDIR="$T/ftmp"; . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_dest_guard "$1" ) > /dev/null 2>&1; echo $?; }
check "dest guard: an empty destination is refused" "$(dg "")" "1"
check "dest guard: / is refused" "$(dg "/")" "1"
check "dest guard: the home directory is refused" "$(dg "$T/fakehome")" "1"
check "dest guard: a parent of the home directory is refused" "$(dg "$T")" "1"
check "dest guard: the TMPDIR is refused" "$(dg "$T/ftmp")" "1"
check "dest guard: a fresh directory below the TMPDIR is accepted" "$(dg "$T/ftmp/new dest")" "0"
for fxid in e01-ambiguous-tax e02-preview-mutation e03-rename-query e04-search-injection e05-tags-feature; do
  HOME="$T/fakehome" TMPDIR="$T/ftmp" timeout 60s bash "$REPO_ROOT/eval/abtest/fixtures/$fxid/build.sh" "$T/fakehome" > /dev/null 2>&1; fxrc=$?
  check "build.sh $fxid refuses the home directory as its destination" "$fxrc" "2"
  check "build.sh $fxid wrote nothing into the refused destination" "$(ls -A "$T/fakehome" | wc -l | tr -d ' ')" "0"
done

# arms/common.sh: the config directory is never removed through an empty variable.
check "common.sh removes the config dir only through a guarded expansion" "$(grep -cF 'rm -rf "${dir:?}"' "$REPO_ROOT/eval/abtest/arms/common.sh")|$(grep -cF 'rm -rf "$dir"' "$REPO_ROOT/eval/abtest/arms/common.sh")" "2|0"
echo "abtest-checks: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-checks checks passed."
exit "$fail"
