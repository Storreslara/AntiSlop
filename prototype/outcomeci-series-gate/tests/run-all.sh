#!/usr/bin/env bash
# Runs every *.test.sh suite in this directory plus mutation-proof.sh; exits non-zero iff any suite fails.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
suites=0 failed=0
for s in "$here"/*.test.sh "$here/mutation-proof.sh"; do
  suites=$((suites + 1))
  if bash "$s" >/dev/null 2>&1; then
    printf '%s: ok\n' "${s##*/}"
  else
    printf '%s: FAIL\n' "${s##*/}"
    failed=$((failed + 1))
  fi
done
printf 'suites=%s failed=%s\n' "$suites" "$failed"
[ "$failed" -eq 0 ]
