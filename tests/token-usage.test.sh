#!/usr/bin/env bash
# Fixture suite for scripts/token-usage/ (ptr-u0): the per-persona token-usage
# measurement. The fixture under tests/fixtures/token-usage holds four synthetic
# dispatches (three reviewers with known first-turn and total input, one
# lead-programmer attributed only through its parent Agent tool_use).
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v python3 > /dev/null 2>&1; then
  echo "SKIP tests/token-usage.test.sh (python3 not found)"
  exit 0
fi

root=tests/fixtures/token-usage
agg() { python3 -I scripts/token-usage/agg.py --root "$root" "$@"; }

total=0
passed=0
check() { # <description> <exit status of the assertion>
  total=$((total + 1))
  if [ "$2" -eq 0 ]; then
    passed=$((passed + 1))
    echo "ok   $1"
  else
    echo "FAIL $1"
  fi
}

all="$(agg 36500)"

printf '%s\n' "$all" | grep -qE '^reviewer +3 +3,000 +7,000 '
check "medians: three reviewers give first-turn 3,000 and total 7,000" "$?"

printf '%s\n' "$all" | grep -qE '^lead-programmer +1 +500 +1,200 ' && ! printf '%s\n' "$all" | grep -q '^other'
check "attribution: the lead-programmer dispatch is named by its parent Agent tool_use" "$?"

since="$(agg --since 2026-01-20T00:00:00Z 36500)"
printf '%s\n' "$since" | grep -qE '^reviewer +2 +5,500 +12,000 ' && ! printf '%s\n' "$since" | grep -q '^lead-programmer'
check "--since drops the two dispatches that began before it" "$?"

until_out="$(agg --until 2026-02-15T00:00:00Z 36500)"
printf '%s\n' "$until_out" | grep -qE '^reviewer +2 +2,000 +5,000 ' && printf '%s\n' "$until_out" | grep -qE '^lead-programmer +1 '
check "--until drops the dispatch that began after it" "$?"

printf '%s\n' "$all" | grep -q '1st-ctx med'
check "the header keeps the 1st-ctx med column" "$?"

python3 -I scripts/token-usage/agg2.py --root "$root" 36500 > /dev/null && python3 -I scripts/token-usage/cache.py --root "$root" 36500 > /dev/null
check "agg2.py and cache.py run on the fixture" "$?"

mroot=tests/fixtures/token-usage-main
agg2m() { python3 -I scripts/token-usage/agg2.py --root "$mroot" 36500 "$@"; }

agg2m --since 2026-01-02T00:00:00Z | grep -q 'sessions=0'
check "agg2 main-session section: --since after the session's first usage record drops it" "$?"

agg2m --since 2025-12-31T00:00:00Z | grep -q 'sessions=1 '
check "agg2 main-session section: --since before the first usage record keeps it" "$?"

agg2m --until 2026-01-01T00:00:00Z | grep -q 'sessions=0'
check "agg2 main-session section: --until at the first usage record drops it" "$?"

echo "token-usage: $passed/$total passed"
[ "$passed" -eq "$total" ]
