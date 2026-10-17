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
lgmk() { mkdir -p "$T/lg/$1/$(dirname "$2")"; printf '%s\n' "$3" > "$T/lg/$1/$2"; }
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
lgcase "leak guard: the T2 template passes (every named file and docs/ scanned)" "$T/lg/real" 0 ""
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
sha="$(ABT_REPO_ROOT="$REPO_ROOT" bash "$REPO_ROOT/eval/abtest/fixtures/e01-ambiguous-tax/build.sh" "$T/lg/e01" | tail -n1)"; rc=$?
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
    && env GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid "$@" git commit -q -m "$msg" )
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
git -C "$T/lg/hist" commit -q --amend -m "initial import" -m "the plant is here"
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
git -C "$T/lg/hist" commit -q --amend -m "initial import" -m "the plant is here"
git -C "$T/lg/hist" -c user.name=dev -c user.email=dev@example.invalid commit -q --allow-empty -m "tidy"
lgcase "leak guard: a leaking body on an older commit is refused" "$T/lg/hist" 1 "('plant')"
lgrepo nw "subtrap and microeval notes"
lgcase "leak guard: a word glued to other letters in a history is fine (control)" "$T/lg/hist" 0 ""
# abt_fixture_baseline: neutral identity, neutral message, one branch, and a leaking history leaves no repository.
rm -rf "$T/lg/id"; mkdir -p "$T/lg/id"; printf '{"description":"notes"}\n' > "$T/lg/id/package.json"
( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_baseline "$T/lg/id" > /dev/null )
check "the baseline commit has a neutral identity and message" "$(git -C "$T/lg/id" log --format='%an|%ae|%cn|%ce|%s')" "dev|dev@example.invalid|dev|dev@example.invalid|initial import"
check "the baseline repository has one commit and one ref" "$(git -C "$T/lg/id" rev-list --all --count)|$(git -C "$T/lg/id" for-each-ref --format='%(refname)')" "1|refs/heads/main"
check "the baseline commit date is fixed" "$(git -C "$T/lg/id" log -1 --format='%aI|%cI')" "2026-01-01T00:00:00+00:00|2026-01-01T00:00:00+00:00"
check "a built E1 baseline passes the guard, history included" "$(lg "$T/lg/e01")" "rc=0"
check "the built E1 baseline history is neutral" "$(git -C "$T/lg/e01" log --format='%an|%ae|%s')" "dev|dev@example.invalid|initial import"
rm -rf "$T/lg/leakid"; mkdir -p "$T/lg/leakid"; printf '{"description":"notes"}\n' > "$T/lg/leakid/package.json"
out="$( . "$REPO_ROOT/eval/abtest/fixtures/lib.sh"; abt_fixture_env() { export GIT_AUTHOR_NAME=abtest GIT_AUTHOR_EMAIL=a@example.invalid GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.invalid; }; abt_fixture_baseline "$T/lg/leakid" 2>&1 )"; rc=$?
check "a baseline whose history leaks is refused" "$rc" "1"
has "the history leak is named" "$out" "names the eval or the tool ('abtest')"
check "the refused baseline left no repository" "$(test -e "$T/lg/leakid/.git" && echo made || echo none)" "none"

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
echo "abtest-checks: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-checks checks passed."
exit "$fail"
