#!/usr/bin/env bash
# Fixture suite for tests/lib/validate-quiet.sh, the quiet-output filter of
# tests/validate.sh (ptr-u1). Every fixture line ends in a token that says what
# the filter must do with it: DROPME (absent), SHOWME (present), CTXME (present
# as the context line above a failing result), SHOWHDR / DROPHDR (a section
# header that must / must not print).
set -uo pipefail
cd "$(dirname "$0")/.."
. tests/lib/validate-quiet.sh

fixture=tests/fixtures/validate-quiet/sample.txt
fail=0
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
validate_quiet_filter < "$fixture" > "$out"

check() { # <description> <exit status of the assertion>
  if [ "$2" -eq 0 ]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    fail=1
  fi
}

# The frozen KEEP regex is spelled out here, not read from the library, so a
# mutated library cannot also weaken this assertion.
missing="$(comm -23 <(grep -E '^(FAIL|WARN|SKIP)|⚠|✗|not ok|FAILED|Error|ERROR' "$fixture" | sort -u) <(sort -u "$out") | wc -l)"
[ "$missing" -eq 0 ]; check "every KEEP line of the fixture is printed" "$?"

grep -q 'DROPME' "$out"; [ "$?" -eq 1 ]; check "no DROP-only line is printed" "$?"

want="$(grep -c 'SHOWME' "$fixture")"
got="$(grep -c 'SHOWME' "$out")"
[ "$want" -gt 0 ] && [ "$want" -eq "$got" ]; check "every SHOWME line is printed exactly once ($got of $want)" "$?"

grep -A1 'CTXME' "$out" | tail -n 1 | grep -q '✗'; check "a Test announcement directly above a failing result is printed with it" "$?"

grep -q 'Test (y)' "$out"; [ "$?" -eq 1 ]; check "a Test announcement above a passing result is dropped" "$?"

[ "$(grep -c 'SHOWHDR' "$out")" -eq "$(grep -c 'SHOWHDR' "$fixture")" ]; check "a header with a printed line under it is printed" "$?"

grep -q 'DROPHDR' "$out"; [ "$?" -eq 1 ]; check "a header with only dropped lines under it is dropped" "$?"

# Wrapper cases (ptr-u1 revision): a throwaway tree whose tests/validate.sh is
# the real wrapper (every line up to and including the wrapper's closing `fi`)
# followed by a stub body, so the exit-code and mode behaviour run in seconds
# instead of a full gate run. ANTISLOP_VALIDATE_INNER is unset for the stub,
# because this suite itself runs inside validate.sh's inner pass.
# The OK line comes after the FAIL line on purpose: an OK line directly above
# a KEEP line is printed as its context line (the context rule).
stub="$(mktemp -d)"
trap 'rm -f "$out"; rm -rf "$stub"' EXIT
mkdir -p "$stub/tests/lib"
cp tests/lib/validate-quiet.sh "$stub/tests/lib/"
awk '{ print } seen && /^fi$/ { exit } index($0, "if [ -z \"${ANTISLOP_VALIDATE_INNER:-}\" ]; then") == 1 { seen = 1 }' tests/validate.sh > "$stub/tests/validate.sh"
printf '%s\n' 'echo "== stub section =="' 'echo "FAIL stub failing line"' 'echo "OK   stub ok line"' 'exit "${STUB_RC:-1}"' >> "$stub/tests/validate.sh"
run_stub() { # <STUB_RC> [env assignments and args after --]; prints the wrapper's output, then rc=<exit code>
  local rc="$1"; shift
  (cd "$stub" && env -u ANTISLOP_VALIDATE_INNER -u ANTISLOP_VALIDATE_VERBOSE STUB_RC="$rc" "$@"); echo "rc=$?"
}

o="$(run_stub 1 bash tests/validate.sh)"
printf '%s\n' "$o" | grep -qx 'rc=1'; check "quiet mode returns the inner exit code (1)" "$?"
printf '%s\n' "$o" | grep -qx 'FAIL stub failing line'; check "quiet mode prints the FAIL line" "$?"
printf '%s\n' "$o" | grep -q 'OK   stub ok line'; [ "$?" -eq 1 ]; check "quiet mode drops the OK line" "$?"
log="$(printf '%s\n' "$o" | sed -n 's/^Full log: //p')"
[ -n "$log" ] && grep -q 'OK   stub ok line' "$log"; check "quiet mode keeps the full log at the printed path" "$?"
[ -n "$log" ] && rm -f "$log"

o="$(run_stub 0 bash tests/validate.sh)"
printf '%s\n' "$o" | grep -qx 'rc=0'; check "quiet mode returns the inner exit code (0)" "$?"
log="$(printf '%s\n' "$o" | sed -n 's/^Full log: //p')"
[ -n "$log" ] && rm -f "$log"

o="$(run_stub 1 bash tests/validate.sh --verbose)"
printf '%s\n' "$o" | grep -qx 'rc=1'; check "--verbose returns the inner exit code (1)" "$?"
printf '%s\n' "$o" | grep -qx 'OK   stub ok line'; check "--verbose prints every line" "$?"
printf '%s\n' "$o" | grep -q '^Full log: '; [ "$?" -eq 1 ]; check "--verbose prints no Full log line" "$?"

o="$(run_stub 1 env ANTISLOP_VALIDATE_VERBOSE=1 bash tests/validate.sh)"
printf '%s\n' "$o" | grep -qx 'OK   stub ok line'; check "ANTISLOP_VALIDATE_VERBOSE=1 prints every line" "$?"
printf '%s\n' "$o" | grep -qx 'rc=1'; check "ANTISLOP_VALIDATE_VERBOSE=1 returns the inner exit code (1)" "$?"

if [ "$fail" -eq 0 ]; then
  echo "All validate-quiet cases passed."
else
  echo "One or more validate-quiet cases FAILED."
fi
exit "$fail"
