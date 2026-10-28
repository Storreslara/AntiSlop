#!/usr/bin/env bash
# Fixture suite for eval/refutation-replay/ (rfp-u2): corpus builder, --check, scorer gate and run.sh
# --dry-run. Every fixture lives under mktemp -d. It never runs claude and never reads this repo's markers.
set -uo pipefail
cd "$(dirname "$0")/.."
root="$(pwd)"
d="$root/eval/refutation-replay"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"; mk="$tmp/markers"; mkdir -p "$repo/src" "$mk"
g() { ( cd "$repo" && GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git -c user.email=t@t -c user.name=t "${@:2}" ); }
( cd "$repo" && git init -q . )
printf 'a\n' > "$repo/src/a.sh"; printf 'b\n' > "$repo/src/b.sh"
g 2026-01-01T00:00:00Z add -A; g 2026-01-01T00:00:00Z commit -q -m base
printf 'a\nx\n' > "$repo/src/a.sh"; g 2026-01-02T00:00:00Z commit -q -am "feat(u9): first"
printf 'a\ny\n' > "$repo/src/a.sh"; g 2026-01-04T00:00:00Z commit -q -am "fix(u9): second"
printf 'b\nz\n' > "$repo/src/b.sh"; g 2026-01-05T00:00:00Z commit -q -am "feat(u8): only"
# u9: one judgment block (two defects citing src/a.sh) and one mechanical block; u9 later PASSes.
cat > "$mk/u9.fail" <<'EOF'
FAIL u9 2026-01-03T00:00:00Z
tier: haiku
- src/a.sh:2 x is unquoted, so a space splits it
- src/a.sh:1 no guard on empty input
- src/a.sh:1 review-precheck printed `criterion 2: fail`

EOF
printf 'PASS u9 2026-01-05T00:00:00Z commit: abc criteria: x\n' > "$mk/u9.pass"
# u8: a judgment defect with no PASS marker and no later fix: never proxy-real.
printf 'FAIL u8 2026-01-06T00:00:00Z\ntier: haiku\n- src/b.sh:2 z is wrong\n\n' > "$mk/u8.fail"

c="$tmp/out/corpus.jsonl"; mkdir -p "$tmp/out"
o1="$(python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk" --size 40 --out "$c")"; h1="$(md5sum < "$c")"
python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk" --size 40 --out "$c" >/dev/null; h2="$(md5sum < "$c")"
rows="$(grep -c . "$c")"
# (a) two rows, both u9, none from the mechanical line or from u8; deterministic
if [ "$rows" = 2 ] && [ "$(grep -c '"unit": "u9"' "$c")" = 2 ] && ! grep -q 'criterion 2' "$c" && [ "$h1" = "$h2" ] \
   && grep -q '"dline": "D1: src/a.sh:2 x is unquoted, so a space splits it"' "$c"; then
  ok "(a) builder keeps proxy-real judgment defects only, deterministically"
else
  bad "(a) builder rows=$rows out=$o1"
fi
# (b) --check: valid, all unlabeled
chk="$(python3 "$d/build-corpus.py" --repo "$repo" --out "$c" --check)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$chk" | grep -q 'rows=2 groups=1 units=1 unlabeled=2 real=0 bogus=0 errors=0'; then ok "(b) --check"; else bad "(b) --check rc=$rc $chk"; fi
# (c) --check rejects an unreachable baseline
sed 's/"baseline": "[0-9a-f]*"/"baseline": "0000000000000000000000000000000000000000"/' "$c" > "$tmp/out/bad.jsonl"
cp "$tmp/out/labels.tsv" "$tmp/out/labels.keep"
python3 "$d/build-corpus.py" --repo "$repo" --out "$tmp/out/bad.jsonl" --check >/dev/null; rc=$?
if [ "$rc" = 1 ]; then ok "(c) --check rejects a bad baseline"; else bad "(c) --check rc=$rc"; fi

# scorer fixtures: N real rows, M of them REFUTED with an artifact
mkrep() { # <dir> <real> <misses> <turns> <unanswered>
  local dir="$1" i; mkdir -p "$dir"; : > "$dir/report.jsonl"; printf '# id\tlabel\n' > "$dir/labels.tsv"
  for i in $(seq 1 "$2"); do
    a=CONFIRMED; [ "$i" -le "$3" ] && a=REFUTED; [ "$i" -gt "$(( $2 - $5 ))" ] && a=NONE
    printf '{"id": "r%d", "answer": "%s", "artifact": "src/a.sh:1 guard", "num_turns": %d, "cost_usd": 0.1}\n' "$i" "$a" "$4" >> "$dir/report.jsonl"
    printf 'r%d\treal\n' "$i" >> "$dir/labels.tsv"
  done
}
sc() { python3 "$d/score.py" "$1/report.jsonl" --gate; }
mkrep "$tmp/s1" 30 1 9 0; o="$(sc "$tmp/s1")"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$o" | grep -q '^replay-gate: pass real=30 refuted-real=1 ' && ok "(d) gate pass at 1 miss in 30" || bad "(d) rc=$rc $o"
mkrep "$tmp/s2" 30 2 9 0; o="$(sc "$tmp/s2")"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q '^replay-gate: fail ' && ok "(e) gate fail at 2 misses" || bad "(e) rc=$rc $o"
mkrep "$tmp/s3" 29 0 9 0; o="$(sc "$tmp/s3")"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$o" | grep -q '^replay-gate: insufficient real=29 ' && ok "(f) insufficient below 30" || bad "(f) rc=$rc $o"
mkrep "$tmp/s4" 30 0 11 0; o="$(sc "$tmp/s4")"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'max-turns=11' && ok "(g) gate fail above 10 turns" || bad "(g) rc=$rc $o"
mkrep "$tmp/s5" 30 0 9 7; o="$(sc "$tmp/s5")"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$o" | grep -q 'unanswered=7' && ok "(h) gate fail above 20% unanswered" || bad "(h) rc=$rc $o"
mkdir -p "$tmp/s6"; o="$(python3 "$d/score.py" "$tmp/s6/report.jsonl" --gate)"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$o" | grep -q '^replay-gate: insufficient real=0 ' && ok "(i) empty report is insufficient" || bad "(i) rc=$rc $o"

# (j) run.sh --dry-run: one line per group, sonnet, 10 turns, read-only tools, no claude run
dr="$(bash "$d/run.sh" --dry-run --corpus "$c" --repo "$repo")"; rc=$?
lines="$(printf '%s\n' "$dr" | grep -c '^group=')"
if [ "$rc" = 0 ] && [ "$lines" = 1 ] && printf '%s' "$dr" | grep -q -- '--model sonnet --max-turns 10' \
   && ! printf '%s' "$dr" | grep -qE 'Write|Edit'; then ok "(j) run.sh --dry-run"; else bad "(j) rc=$rc lines=$lines"; fi

if [ "$fail" -eq 0 ]; then echo "All refutation-replay checks passed."; else echo "refutation-replay: FAILED"; fi
exit "$fail"
