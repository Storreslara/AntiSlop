#!/usr/bin/env bash
# Runs the non-vacuity verifier and the fixture proof scripts over the real E1-E5 fixtures and compares
# each output with its pinned copy under tests/fixtures/abtest/proofs/ (abt-u17b). A change to a hidden
# check, a fixture or a reference that moves any line fails here, not at the pilot. ABT_PROOFS_DIR points
# the comparison at another directory of pinned files.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
unset ABT_REPO_ROOT ABT_FIXTURES_DIR ABT_CHECKS_ROOT ABT_CHECKS_LIB
EXP="${ABT_PROOFS_DIR:-$REPO_ROOT/tests/fixtures/abtest/proofs}"
FX="$REPO_ROOT/eval/abtest/fixtures"
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
# same NAME PINNED_FILE COMMAND...: the command exits 0 and prints exactly the pinned file.
same() {
  local name="$1" want="$2" got rc
  shift 2
  got="$("$@" 2> /dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "$name (exit $rc)"
  elif [ "$got" = "$(cat "$want" 2> /dev/null)" ]; then
    ok "$name"
  else
    bad "$name (output differs from $(basename "$want"))"
    diff <(printf '%s\n' "$got") "$want" 2> /dev/null | head -n 6
  fi
}

same "verify-checks proves E1 to E5" "$EXP/verify-all.expected" bash "$REPO_ROOT/eval/abtest/verify-checks.sh" --all
same "E3 comment proof" "$EXP/e03-comment-proof.expected" bash "$FX/e03-rename-query/comment-proof.sh"
same "E3 careless rename proof" "$EXP/e03-careless-proof.expected" bash "$FX/e03-rename-query/careless-proof.sh"
same "E4 vulnerable route proof" "$EXP/e04-vulnerable-proof.expected" bash "$FX/e04-search-injection/vulnerable-proof.sh"
same "E4 comment proof" "$EXP/e04-comment-proof.expected" bash "$FX/e04-search-injection/comment-proof.sh"
same "E4 forty-eight route proof" "$EXP/e04-variants-proof.expected" bash "$FX/e04-search-injection/variants-proof.sh"
same "E5 checks proof" "$EXP/e05-checks-proof.expected" bash "$FX/e05-tags-feature/checks-proof.sh"

echo "abtest-fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-fixtures checks passed."
exit "$fail"
