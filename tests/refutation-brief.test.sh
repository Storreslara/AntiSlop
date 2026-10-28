#!/usr/bin/env bash
# Fixture suite for bin/refutation-brief.sh (rfp-u1). Every case runs in a scratch git repo, never this tree.
set -uo pipefail
cd "$(dirname "$0")/.."
script="$(pwd)/${BRIEF_UNDER_TEST:-bin/refutation-brief.sh}"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
mkdir -p "$repo/src"
( cd "$repo" && git init -q . && printf 'a\n' > src/a.sh && git add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m base \
  && printf 'a\nb\n' > src/a.sh && git -c user.email=t@t -c user.name=t commit -q -am change )
base="$(cd "$repo" && git rev-parse HEAD~1)"

run() { # <stdin text> <args...> -> sets out, err, rc
  local input="$1"; shift
  out="$(cd "$repo" && printf '%s' "$input" | bash "$script" "$@" 2>"$tmp/err")"; rc=$?
  err="$(cat "$tmp/err")"
}

# (a) two valid defects: exit 0, both D-lines, the baseline sha, the changed file, the rules and the grammar
run $'D1: src/a.sh:2 b is unquoted\n\nD2: src/a.sh:1-2 no guard on empty input\n' "$base"
if [ "$rc" = 0 ] \
   && printf '%s\n' "$out" | grep -qx 'D1: src/a.sh:2 b is unquoted' \
   && printf '%s\n' "$out" | grep -qx 'D2: src/a.sh:1-2 no guard on empty input' \
   && printf '%s\n' "$out" | grep -qx "Baseline: $base" \
   && printf '%s\n' "$out" | grep -qx -- '- src/a.sh' \
   && printf '%s\n' "$out" | grep -qF 'When unsure, answer UNCERTAIN, never CONFIRMED. A verdict with no artifact is UNCERTAIN.' \
   && printf '%s\n' "$out" | grep -qF 'D<n>: REFUTED|CONFIRMED|UNCERTAIN — q1=<yes|no> q2=<change|baseline> q3=<real|mitigated|n/a> — artifact:' \
   && printf '%s\n' "$out" | grep -qF "on why it stops this defect on" ; then
  ok "(a) valid brief"
else
  bad "(a) valid brief rc=$rc err=$err"
fi

# (b) four defects: over-cap, exit 2, nothing on stdout
run $'D1: src/a.sh:1 x\nD2: src/a.sh:1 y\nD3: src/a.sh:1 z\nD4: src/a.sh:1 w\n' "$base"
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'over-cap'; then ok "(b) over-cap"; else bad "(b) over-cap rc=$rc"; fi

# (c) no defect lines
run $'\n\n' "$base"
if [ "$rc" = 2 ] && [ -z "$out" ]; then ok "(c) empty stdin"; else bad "(c) empty stdin rc=$rc"; fi

# (d) malformed line (no file:line)
run $'D1: the code is wrong\n' "$base"
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'malformed'; then ok "(d) malformed"; else bad "(d) malformed rc=$rc"; fi

# (e) baseline that is not a commit
run $'D1: src/a.sh:1 x\n' deadbeefdeadbeef
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'not a commit'; then ok "(e) bad baseline"; else bad "(e) bad baseline rc=$rc"; fi

# (f) repeated D-number
run $'D1: src/a.sh:1 x\nD1: src/a.sh:2 y\n' "$base"
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'repeated D1'; then ok "(f) repeated id"; else bad "(f) repeated id rc=$rc"; fi

# (g) D-number above 3, even with fewer than 4 lines
run $'D7: src/a.sh:1 x\n' "$base"
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'over-cap'; then ok "(g) D-number cap"; else bad "(g) D-number cap rc=$rc"; fi

# (h) deterministic and writes nothing
run $'D1: src/a.sh:2 b\n' "$base"; first="$out"
run $'D1: src/a.sh:2 b\n' "$base"
st="$(cd "$repo" && git status --porcelain)"
if [ "$first" = "$out" ] && [ -z "$st" ]; then ok "(h) deterministic, no writes"; else bad "(h) deterministic, no writes"; fi

# (i) no baseline argument
run $'D1: src/a.sh:1 x\n'
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'usage'; then ok "(i) no baseline"; else bad "(i) no baseline rc=$rc"; fi

if [ "$fail" -eq 0 ]; then echo "All refutation-brief checks passed."; else echo "refutation-brief: FAILED"; fi
exit "$fail"
