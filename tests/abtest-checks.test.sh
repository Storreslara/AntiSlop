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
check "scope.sh rejects an unknown mode" "$(bash "$SCOPE" "$S" "$START" "$T/allowed" bogus >/dev/null 2>&1; echo $?)" "2"

echo "abtest-checks: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-checks checks passed."
exit "$fail"
