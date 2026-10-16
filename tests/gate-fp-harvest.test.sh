#!/usr/bin/env bash
# Synthetic-store test for scripts/gate-fp-harvest.py (ptr-u7b-2); never reads the real store.
cd "$(dirname "$0")/.." || exit 1
script="${HARVEST_SCRIPT:-scripts/gate-fp-harvest.py}"
fx=tests/fixtures/gate-fp-harvest
w="$(mktemp -d)"
trap 'rm -rf "$w"' EXIT
fail=0
pass() { echo "ok   $*"; }
bad()  { echo "FAIL $*"; fail=1; }
S=ZZ-PRIVATE-SENTINEL-42
since=2026-09-25T00:00:00Z
stop=2026-10-16T00:00:00Z

# mkrec <file> <tool_use id> <timestamp> <command> <is_error> <result text> [list]
mkrec() {
  local res='$t'
  [ "${7:-}" = list ] && res='[{type:"text",text:$t}]'
  jq -cn --arg id "$2" --arg ts "$3" --arg c "$4" \
    '{type:"assistant",timestamp:$ts,message:{content:[{type:"tool_use",id:$id,name:"Bash",input:{command:$c}}]}}' >> "$1"
  jq -cn --arg id "$2" --argjson e "$5" --arg t "$6" \
    "{type:\"user\",message:{content:[{type:\"tool_result\",tool_use_id:\$id,is_error:\$e,content:$res}]}}" >> "$1"
}

store="$w/store"
mkdir -p "$store/sess2/subagents"
in=2026-10-01T12:00:00.000Z
s1="$store/s1.jsonl"
s2="$store/sess2/subagents/a1.jsonl"
mkrec "$s1" a1 "$in" 'cd docs && ls' true 'BLOCKED: human-decision-gate refused this command'
mkrec "$s2" a2 "$in" 'cd docs && ls' true 'BLOCKED: human-decision-gate refused this command'
mkrec "$s1" b1 "$in" 'sort f | uniq -c' true 'BLOCKED by reviewed-path-gate'
mkrec "$s1" c1 "$in" 'cd x; sort y 2>/dev/null' true 'BLOCKED: harness-integrity-gate'
mkrec "$s1" d1 "$in" 'rm -f x' true 'BLOCKED: no gate named'
mkrec "$s2" e1 "$in" "rm $S" true 'BLOCKED: reviewed-path-gate' list
mkrec "$s1" f1 "$in" "ls $(head -c 5000 /dev/zero | tr '\0' a)" true 'BLOCKED: oversize, no gate named'
mkrec "$s1" g1 2026-10-17T00:00:00.000Z 'cd out && ls' true 'BLOCKED: human-decision-gate'
mkrec "$s1" h1 "$in" 'sort h' false 'BLOCKED text, but the result is not an error'
mkrec "$s1" i1 "$in" 'sort i' true 'permission denied'

cat > "$w/expected.md" <<'EOF'
| row | count | share |
| --- | --- | --- |
| hits | 7 | - |
| distinct | 6 | - |
| oversize | 1 | - |
| classified | 5 | - |
| F1 | 2 | 0.400 |
| F2 | 1 | 0.200 |
| F3 | 2 | 0.400 |
| flipped | 3 | 0.600 |
| still-blocked | 2 | 0.400 |
| gate:reviewed-path-gate | 2 | - |
| gate:human-decision-gate | 2 | - |
| gate:harness-integrity-gate | 1 | - |
| gate:other | 2 | - |
EOF

: > "$w/all.txt"
run() {
  local rc=0
  python3 -I "$script" "$@" > "$w/last.out" 2>&1 || rc=$?
  cat "$w/last.out" >> "$w/all.txt"
  cat "$w/last.out"
  return "$rc"
}
win=(--since "$since" --until "$stop")
common=("${win[@]}" --lib "$fx/lib-new.sh" --baseline-lib "$fx/lib-base.sh")

run --root "$store" "${common[@]}" > "$w/t1.txt"
if diff "$w/t1.txt" "$w/expected.md" > /dev/null; then pass "table equals the literal expected table"; else bad "table differs from the expected table"; fi

printf '%s\n' '# Doc' "It quotes: rm $S" > "$w/leak.md"
printf '%s\n' '# Doc' 'It quotes no command.' > "$w/clean.md"
l1="$(run --root "$store" "${win[@]}" --check-doc "$w/leak.md")"
l0="$(run --root "$store" "${win[@]}" --check-doc "$w/clean.md")"
if [ "$l1" = leaks=1 ] && [ "$l0" = leaks=0 ]; then pass "check-doc prints leaks=1 and leaks=0"; else bad "check-doc printed $l1 and $l0"; fi

printf '%s\n' '# Doc' 'Before the span.' '<!-- harvest:begin -->' 'PENDING: placeholder' '<!-- harvest:end -->' 'After the span.' > "$w/doc.md"
cp "$w/doc.md" "$w/fill.md"
f1="$(run --root "$store" "${common[@]}" --fill-doc "$w/fill.md")"
if [ "$f1" = "filled $w/fill.md" ]; then pass "fill-doc prints filled <path>"; else bad "fill-doc stdout differs"; fi
awk '/harvest:begin/{f=1;next} /harvest:end/{f=0} f' "$w/fill.md" > "$w/span.txt"
if diff "$w/span.txt" "$w/expected.md" > /dev/null; then pass "fill-doc span equals the expected table"; else bad "fill-doc span differs from the expected table"; fi
strip='/harvest:begin/{print;skip=1;next} /harvest:end/{skip=0} !skip'
if diff <(awk "$strip" "$w/fill.md") <(awk "$strip" "$w/doc.md") > /dev/null; then pass "fill-doc leaves every line outside the span unchanged"; else bad "fill-doc changed a line outside the span"; fi
if [ "$(grep -c "$S" "$w/fill.md")" = 0 ]; then pass "filled doc holds no sentinel"; else bad "filled doc holds the sentinel"; fi
printf '%s\n' '# Doc' '<!-- harvest:begin -->' '<!-- harvest:begin -->' '<!-- harvest:end -->' > "$w/two.md"
cp "$w/two.md" "$w/two.orig"
rc=0
run --root "$store" "${common[@]}" --fill-doc "$w/two.md" > /dev/null || rc=$?
if [ "$rc" = 2 ] && cmp -s "$w/two.md" "$w/two.orig"; then pass "fill-doc exits 2 and leaves a two-begin doc unchanged"; else bad "fill-doc on a two-begin doc: rc=$rc or the file changed"; fi

dr="$w/home/.claude/projects/$(pwd -P | tr / -)"
mkdir -p "$dr"
cp -r "$store"/. "$dr"/
HOME="$w/home" python3 -I "$script" "${common[@]}" > "$w/t2.txt" 2>&1
if diff "$w/t2.txt" "$w/expected.md" > /dev/null; then pass "the default root resolves under HOME"; else bad "the default root did not resolve to the project directory"; fi

if [ "$(grep -c "$S" "$w/all.txt")" = 0 ]; then pass "$S appears in no output"; else bad "$S leaked into an output"; fi

[ "$fail" = 0 ] && echo "All gate-fp-harvest checks passed."
exit "$fail"
