#!/usr/bin/env bash
# Size caps on spec-master plans and contracts dated 2026-10-31 or later.
PLANS_DIR="${PLANS_DIR:-docs/plans}"
CUTOFF=20261031
fail=0

if [ "${PLAN_CAP_SELFTEST:-1}" != 0 ]; then
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
  run_case() { # name expected_exit dir
    local rc=0
    PLAN_CAP_SELFTEST=0 PLANS_DIR="$3" bash "$0" >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq "$2" ]; then echo "OK   self-test $1 (exit $rc)"
    else echo "FAIL self-test $1: expected exit $2, got $rc"; fail=1; fi
  }
  mkdir -p "$T/a" "$T/b" "$T/c/2026-11-01-x/contracts" "$T/d" "$T/e"
  seq 401 > "$T/a/2026-11-01-x.md"
  head -c 25601 /dev/zero | tr '\0' x > "$T/b/2026-11-01-x.md"
  head -c 3073 /dev/zero | tr '\0' x > "$T/c/2026-11-01-x/contracts/u.md"
  seq 500 > "$T/d/2026-10-30-x.md"
  # (e): 400 lines of 64 bytes = 25600
  printf '%s\n' "$(yes "$(head -c 63 /dev/zero | tr '\0' x)" | head -n 400)" > "$T/e/2026-11-01-x.md"
  run_case "(a) plan 401 lines" 1 "$T/a"
  run_case "(b) plan 25601 bytes" 1 "$T/b"
  run_case "(c) contract 3073 bytes" 1 "$T/c"
  run_case "(d) pre-cutoff plan 500 lines" 0 "$T/d"
  run_case "(e) plan 400 lines 25600 bytes" 0 "$T/e"
  [ "$fail" -eq 0 ] || exit 1
fi

for f in "$PLANS_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md; do
  [ -f "$f" ] || continue
  b=$(basename "$f"); [ "$(( 10#$(echo "${b:0:10}" | tr -d -) ))" -ge "$CUTOFF" ] || continue
  bytes=$(wc -c < "$f"); lines=$(wc -l < "$f")
  if [ "$bytes" -gt 25600 ] || [ "$lines" -gt 400 ]; then
    echo "FAIL $f: $bytes bytes, $lines lines (max 25600 bytes, 400 lines)"; fail=1
  fi
done
for f in "$PLANS_DIR"/*/contracts/*.md; do
  [ -f "$f" ] || continue
  slug=$(basename "$(dirname "$(dirname "$f")")")
  d=$(echo "${slug:0:10}" | tr -d -)
  case "$d" in [0-9]*) ;; *) continue;; esac
  [ "$d" -ge "$CUTOFF" ] || continue
  bytes=$(wc -c < "$f")
  if [ "$bytes" -gt 3072 ]; then echo "FAIL $f: $bytes bytes (max 3072)"; fail=1; fi
done
exit "$fail"
