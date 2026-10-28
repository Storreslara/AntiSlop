#!/usr/bin/env bash
# Fixture suite for eval/refutation-replay/ (rfp-u2): corpus builder, --check, scorer gate and run.sh
# --dry-run; whole claims and --refresh-claims (rfp-u2f). Every fixture lives under mktemp -d. It never runs
# claude and never reads this repo's markers.
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

# rfp-u2f: the same u9 block, with its defects wrapped. The claim is the whole item, across a blank line;
# a word on a continuation line (`mutation`) does not change which defects are kept; the cut is 8000.
mk2="$tmp/markers2"; mkdir -p "$mk2"; cp "$mk/u9.pass" "$mk2/"
long="$(printf 'w %.0s' $(seq 1 4500))"
{ printf 'FAIL u9 2026-01-03T00:00:00Z\ntier: haiku\n'
  printf -- '- src/a.sh:2 x is unquoted, so a space splits it\n  when the caller passes "a b"; a mutation test\n    would not see it.\n\n  Repro: run a.sh with "a b".\n'
  printf -- '- src/a.sh:1 no guard on empty input %s\n' "$long"
  printf -- '- src/a.sh:1 review-precheck printed `criterion 2: fail`\nsummary, not indented\n  indented after an unindented line\n\n'; } > "$mk2/u9.fail"
w1='D1: src/a.sh:2 x is unquoted, so a space splits it when the caller passes "a b"; a mutation test would not see it. Repro: run a.sh with "a b".'
c2="$tmp/out2/corpus.jsonl"; mkdir -p "$tmp/out2"
python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk2" --size 40 --out "$c2" >/dev/null
dl="$(python3 -c 'import json, sys
print("|".join("%s:%d" % (json.loads(l)["dline"][:2], len(json.loads(l)["dline"])) for l in open(sys.argv[1])))' "$c2" 2>/dev/null)"
d1="$(python3 -c 'import json, sys; print(json.loads(open(sys.argv[1]).readline())["dline"])' "$c2" 2>/dev/null)"
if [ "$d1" = "$w1" ] && [ "$dl" = "D1:${#w1}|D2:8015" ] && ! grep -q 'criterion 2\|summary\|indented after' "$c2"; then
  ok "(k) builder keeps the whole defect item, selects on the bullet line, cuts at 8000"
else
  bad "(k) dlines=$dl d1=$d1"
fi
# (l) --refresh-claims extends the committed claims in place: same ids and other fields, labels untouched,
# idempotent
r3="$tmp/out3"; mkdir -p "$r3"; cp "$c" "$r3/corpus.jsonl"; printf 'KEEP\n' > "$r3/labels.tsv"
o3="$(python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk2" --out "$r3/corpus.jsonl" --refresh-claims)"; rc3=$?
h3="$(md5sum < "$r3/corpus.jsonl")"
o4="$(python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk2" --out "$r3/corpus.jsonl" --refresh-claims)"; rc4=$?
same="$(python3 -c 'import json, sys
a, b, w = ([json.loads(l) for l in open(p)] for p in sys.argv[1:4])
rest = lambda r: {k: v for k, v in r.items() if k != "dline"}
print(len(a) == len(b) == 2 and all(rest(x) == rest(y) for x, y in zip(a, b)) and [r["dline"] for r in b] == [r["dline"] for r in w])' "$c" "$r3/corpus.jsonl" "$c2" 2>/dev/null)"
if [ "$rc3" = 0 ] && [ "$o3" = "corpus: refreshed rows=2 longer=2 errors=0" ] && [ "$rc4" = 0 ] \
   && [ "$o4" = "corpus: refreshed rows=2 longer=0 errors=0" ] && [ "$(md5sum < "$r3/corpus.jsonl")" = "$h3" ] \
   && [ "$same" = True ] && [ "$(cat "$r3/labels.tsv")" = KEEP ]; then
  ok "(l) --refresh-claims rewrites only the claims, keeps labels.tsv, and is idempotent"
else
  bad "(l) rc3=$rc3 $o3 rc4=$rc4 $o4 same=$same"
fi
# (m) a row whose claim matches no defect of its block fails closed: exit 1, nothing written
sed 's/no guard on empty input/no such claim/' "$c" > "$r3/bad.jsonl"; h4="$(md5sum < "$r3/bad.jsonl")"
o5="$(python3 "$d/build-corpus.py" --repo "$repo" --markers "$mk2" --out "$r3/bad.jsonl" --refresh-claims)"; rc5=$?
if [ "$rc5" = 1 ] && printf '%s' "$o5" | grep -q '^corpus: refreshed rows=2 longer=0 errors=1$' && [ "$(md5sum < "$r3/bad.jsonl")" = "$h4" ]; then
  ok "(m) --refresh-claims refuses a row it cannot match and writes nothing"
else
  bad "(m) rc5=$rc5 $o5"
fi

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
