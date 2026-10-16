#!/usr/bin/env bash
# ptr-u2: the grep-first glossary recipe (glossary-index markers) in SKILL.md and
# agents/scribe.md. Every count is computed live from the glossaries.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
ok()  { echo "ok   $*"; }
bad() { echo "FAIL $*"; fail=1; }

skill=skills/ubiquitous-language/SKILL.md
scribe=agents/scribe.md
block() { awk '/<!-- glossary-index:begin -->/{f=1} f{print} /<!-- glossary-index:end -->/{f=0}' "$1"; }

b_skill="$(block "$skill")"
b_scribe="$(block "$scribe")"
if [ -n "$b_skill" ] && [ "$b_skill" = "$b_scribe" ]; then
  ok "the recipe block in $scribe is byte-identical to the one in $skill"
else
  bad "the recipe block is missing from, or differs between, $skill and $scribe"
fi
# The index command is the quoted grep -nE span inside the block.
idx="$(printf '%s\n' "$b_skill" | grep -oE "grep -nE '[^']*'" | head -1)"
if [ -z "$idx" ]; then
  bad "no grep -nE index command inside the recipe block of $skill"
else
  for g in CONTEXT.md docs/harness-glossary.md; do
    out="$(bash -c "$idx \"\$1\"" _ "$g")"
    want="$(grep -c '^\*\*' "$g")"
    got="$(printf '%s\n' "$out" | grep -cE '^[0-9]+:\*\*')"
    if [ "$want" -gt 0 ] && [ "$got" = "$want" ]; then
      ok "$g: the index lists all $want term lines"
    else
      bad "$g: the index lists $got term lines, the glossary has $want"
    fi
    avoid="$(grep -cE '^\s*_Avoid_:' "$g")"
    lost="$(comm -23 <(grep -nE '^\s*_Avoid_:' "$g" | sort) <(printf '%s\n' "$out" | sort) | wc -l | tr -d ' ')"
    if [ "$avoid" -gt 0 ] && [ "$lost" = 0 ]; then
      ok "$g: the index carries all $avoid _Avoid_: lines"
    else
      bad "$g: $lost of $avoid _Avoid_: lines are missing from the index"
    fi
    out_bytes="$(printf '%s\n' "$out" | wc -c | tr -d ' ')"
    size="$(wc -c < "$g" | tr -d ' ')"
    if [ $((out_bytes * 10)) -le "$size" ]; then
      ok "$g: the index is $out_bytes of $size bytes (at most 10 percent)"
    else
      bad "$g: the index is $out_bytes of $size bytes (over 10 percent)"
    fi
  done

  out="$(bash -c "$idx \"\$1\"" _ CONTEXT.md)"
  n="$(grep -n '^\*\*contract of record\*\*' CONTEXT.md | head -1 | cut -d: -f1)"
  nxt="$(printf '%s\n' "$out" | grep -E '^[0-9]+:\*\*' | cut -d: -f1 | awk -v n="${n:-0}" '$1 > n { print; exit }')"
  if [ -n "$n" ] && [ -n "$nxt" ]; then
    rng="$(sed -n "${n},$((nxt - 1))p" CONTEXT.md)"
    first="$(printf '%s\n' "$rng" | head -1)"
    others="$(printf '%s\n' "$rng" | tail -n +2 | grep -c '^\*\*')"
    case "$first" in
      '**contract of record**'*)
        if [ "$others" = 0 ]; then
          ok "the range recipe returns the contract of record entry alone"
        else
          bad "the range recipe for contract of record holds $others other term lines"
        fi ;;
      *) bad "the range recipe for contract of record starts with: $first" ;;
    esac
  else
    bad "could not locate the contract of record term line and its successor"
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "All glossary-index checks passed."
else
  echo "glossary-index: failures above."
fi
exit "$fail"
