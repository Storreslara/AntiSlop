#!/usr/bin/env bash
# Fixture suite for bin/refutation-brief.sh (rfp-u1; budget cases rfp-u1b). Every case runs in a scratch
# git repo, never this tree.
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
has()  { printf '%s\n' "$out" | grep -qF -- "$1"; }
hasx() { printf '%s\n' "$out" | grep -qx -- "$1"; }

# (a) two valid defects: exit 0, both D-lines, the baseline sha, the changed file, the rules, the grammar
# and a budget of 4 calls per defect
run $'D1: src/a.sh:2 b is unquoted\n\nD2: src/a.sh:1-2 no guard on empty input\n' "$base"
if [ "$rc" = 0 ] \
   && hasx 'D1: src/a.sh:2 b is unquoted' \
   && hasx 'D2: src/a.sh:1-2 no guard on empty input' \
   && hasx "Baseline: $base" \
   && hasx '- src/a.sh' \
   && has 'When unsure, answer UNCERTAIN, never CONFIRMED. A verdict with no artifact is UNCERTAIN.' \
   && has 'D<n>: REFUTED|CONFIRMED|UNCERTAIN — q1=<yes|no> q2=<change|baseline> q3=<real|mitigated|n/a> — artifact:' \
   && has "on why it stops this defect on" \
   && hasx 'Budget: at most 9 tool calls in all, and at most 4 for each defect.' ; then
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
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'malformed'; then ok "(d) malformed"; else bad "(d) malformed rc=$rc"; fi

# (e) baseline that is not a commit
run $'D1: src/a.sh:1 x\n' deadbeefdeadbeef
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'not a commit'; then ok "(e) bad baseline"; else bad "(e) bad baseline rc=$rc"; fi

# (f) repeated D-number
run $'D1: src/a.sh:1 x\nD1: src/a.sh:2 y\n' "$base"
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'repeated D1'; then ok "(f) repeated id"; else bad "(f) repeated id rc=$rc"; fi

# (g) D-number above 3, even with fewer than 4 lines
run $'D7: src/a.sh:1 x\n' "$base"
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'over-cap'; then ok "(g) D-number cap"; else bad "(g) D-number cap rc=$rc"; fi

# (h) deterministic and writes nothing
run $'D1: src/a.sh:2 b\n' "$base"; first="$out"
run $'D1: src/a.sh:2 b\n' "$base"
st="$(cd "$repo" && git status --porcelain)"
if [ "$first" = "$out" ] && [ -z "$st" ]; then ok "(h) deterministic, no writes"; else bad "(h) deterministic, no writes"; fi

# (i) no baseline argument
run $'D1: src/a.sh:1 x\n'
if [ "$rc" = 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -q 'usage'; then ok "(i) no baseline"; else bad "(i) no baseline rc=$rc"; fi

# (j) the per-defect share is 9 calls divided by the number of defects: 9 for one, 3 for three
run $'D1: src/a.sh:2 b\n' "$base"; one="$out"
run $'D1: src/a.sh:1 x\nD2: src/a.sh:1 y\nD3: src/a.sh:2 z\n' "$base"
if printf '%s\n' "$one" | grep -qx 'Budget: at most 9 tool calls in all, and at most 9 for each defect.' \
   && hasx 'Budget: at most 9 tool calls in all, and at most 3 for each defect.' \
   && [ "$(printf '%s\n' "$out" | grep -c '^Budget: ')" = 1 ]; then
  ok "(j) budget share per defect count"
else
  bad "(j) budget share per defect count"
fi

# (k) the budget rules: what counts as a call, the 10-turn cap, UNCERTAIN when a share is spent, the
# large-file rule and one line per answer
run $'D1: src/a.sh:2 b\n' "$base"
if has 'including a refused call and each call in a parallel batch' \
   && hasx '10 turns, so batch independent calls into one turn.' \
   && has 'stop work on it and answer UNCERTAIN, naming' \
   && has 'the open question in the artifact. Do not spend another defect' \
   && has 'and say in the artifact which part you read.' \
   && has 'with no line break inside it, then your STATUS line:'; then
  ok "(k) budget rules"
else
  bad "(k) budget rules"
fi

# (l) the old turn note is gone
run $'D1: src/a.sh:2 b\n' "$base"
if [ "$rc" = 0 ] && ! has 'Batch independent reads in parallel'; then ok "(l) old turn note gone"; else bad "(l) old turn note gone"; fi

# (m) a CRLF defect line is accepted and echoed without its CR
run $'D1: src/a.sh:2 b\r\n' "$base"
if [ "$rc" = 0 ] && hasx 'D1: src/a.sh:2 b' && ! printf '%s' "$out" | grep -q $'\r'; then ok "(m) CRLF dropped"; else bad "(m) CRLF dropped rc=$rc"; fi

if [ "$fail" -eq 0 ]; then echo "All refutation-brief checks passed."; else echo "refutation-brief: FAILED"; fi
exit "$fail"
