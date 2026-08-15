#!/usr/bin/env bash
# Behavioural suite for hooks/scripts/heavy-trigger.sh (Step 12 of
# docs/plans/2026-07-28-microworlds-ubiquitous-language-human-review.md).
# Builds a throwaway git repo whose commits have exactly-known numstat shapes,
# so the 8-file / 400-line boundaries can be pinned on BOTH sides rather than
# by example. Measures ADR-0004 criterion 1 only (file count and line count);
# deliberately does NOT measure criteria 2 (structural) or 3 (security-sensitive).
set -euo pipefail
cd "$(dirname "$0")/.."
SCRIPT="$PWD/hooks/scripts/heavy-trigger.sh"
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
repo="$tmproot/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email tester@example.com
git -C "$repo" config user.name tester
git -C "$repo" config commit.gpgsign false
: > "$repo/README"
git -C "$repo" add -A
git -C "$repo" commit -qm base

snap() {
  # <label> -> commits the current worktree, echoes the range it spans
  git -C "$repo" add -A
  git -C "$repo" commit -qm "$1"
  echo "$(git -C "$repo" rev-parse HEAD~1)..$(git -C "$repo" rev-parse HEAD)"
}

add_commit() {
  # <label> <path:lines>... -> echoes the sha..sha range that commit spans
  local label="$1"; shift
  local pair path lines
  for pair in "$@"; do
    path="${pair%%:*}"
    lines="${pair##*:}"
    mkdir -p "$repo/$(dirname "$path")"
    seq 1 "$lines" > "$repo/$path"
  done
  snap "$label"
}

run_case() {
  # <label> <expected> <range> [script-under-test]
  local label="$1" expected="$2" range="$3" script="${4:-$SCRIPT}"
  local got rc=0
  got="$(cd "$repo" && bash "$script" "$range" 2>/dev/null)" || rc=$?
  if [ "$rc" = 0 ]; then
    # Anchored: the whole line must be exactly this shape, not just contain
    # $expected as a substring somewhere in a malformed tail.
    if printf '%s\n' "$got" | grep -Eq "^surface: ${expected} files: ([0-9]+|-) lines: ([0-9]+|-)\$"; then
      echo "OK   $label -> $got"
    else
      echo "FAIL $label expected 'surface: $expected files: <n|-> lines: <n|->', got '$got' (rc=$rc)"
      fail=1
    fi
  else
    echo "FAIL $label expected format 'surface: <heavy|light|unknown> files: ...', got '$got' (rc=$rc)"
    fail=1
  fi
}

# Build test fixtures
r_8f_1L=$(add_commit 8f-1L docs/f1.md:1 docs/f2.md:1 docs/f3.md:1 docs/f4.md:1 docs/f5.md:1 docs/f6.md:1 docs/f7.md:1 docs/f8.md:1)
r_7f_1L=$(add_commit 7f-1L docs/f1b.md:1 docs/f2b.md:1 docs/f3b.md:1 docs/f4b.md:1 docs/f5b.md:1 docs/f6b.md:1 docs/f7b.md:1)
r_1f_400L=$(add_commit 1f-400L docs/f400.md:400)
r_1f_399L=$(add_commit 1f-399L docs/f399.md:399)

# Real-world test shapes (18 files 116 lines = heavy, 24 files 328 lines = heavy).
# Line counts per group are chosen so the totals sum exactly to the labeled
# shape: 10*6 + 8*7 = 116; 10*16 + 14*12 = 328.
r_gh137=$(add_commit gh137-18f-116L \
  src/f1.js:6 src/f2.js:6 src/f3.js:6 src/f4.js:6 src/f5.js:6 \
  src/f6.js:6 src/f7.js:6 src/f8.js:6 src/f9.js:6 src/f10.js:6 \
  test/t1.js:7 test/t2.js:7 test/t3.js:7 test/t4.js:7 test/t5.js:7 \
  test/t6.js:7 test/t7.js:7 test/t8.js:7)
r_gh299=$(add_commit gh299-24f-328L \
  app/a1.ts:16 app/a2.ts:16 app/a3.ts:16 app/a4.ts:16 app/a5.ts:16 \
  app/a6.ts:16 app/a7.ts:16 app/a8.ts:16 app/a9.ts:16 app/a10.ts:16 \
  lib/l1.ts:12 lib/l2.ts:12 lib/l3.ts:12 lib/l4.ts:12 lib/l5.ts:12 \
  lib/l6.ts:12 lib/l7.ts:12 lib/l8.ts:12 lib/l9.ts:12 lib/l10.ts:12 \
  lib/l11.ts:12 lib/l12.ts:12 lib/l13.ts:12 lib/l14.ts:12)

echo "-- boundary sweep: files = 8 (the heavy threshold) --"
run_case "8f-1L-each" "heavy" "$r_8f_1L"
echo "-- boundary sweep: files = 7 (below the heavy threshold) --"
run_case "7f-1L-each" "light" "$r_7f_1L"

echo "-- boundary sweep: lines = 400 (the heavy threshold) --"
run_case "1f-400L" "heavy" "$r_1f_400L"
echo "-- boundary sweep: lines = 399 (below the heavy threshold) --"
run_case "1f-399L" "light" "$r_1f_399L"

echo "-- unmeasurable range --"
run_case "empty-range" "unknown" ""

echo "-- real-world regression shapes --"
run_case "gh137-shape-18f-116L" "heavy" "$r_gh137"
run_case "gh299-shape-24f-328L" "heavy" "$r_gh299"

echo "-- ADR-0004 threshold drift guard --"
if grep -qF '1. Large surface: ≥~8 impacted files OR ≥~400 changed lines' docs/adr/0004-reviewer-roast-work-dual-model-routing.md; then
  echo "OK   adr-threshold-drift-guard -> ADR line present"
else
  echo "FAIL adr-threshold-drift-guard -> ADR line missing"
  fail=1
fi

echo "-- mutation controls --"
MUTANT=""
mutate() {
  # <name> <sed-expr>: writes the mutant to $MUTANT, fails loudly if the sed
  # matched nothing (a silently-unmutated copy would "prove" anything).
  MUTANT="$tmproot/$1.sh"
  sed "$2" "$SCRIPT" > "$MUTANT"
  if cmp -s "$MUTANT" "$SCRIPT"; then
    echo "FAIL mutation control '$1': the sed matched nothing"
    fail=1
    return 1
  fi
  return 0
}

if mutate files-8-to-7 's/^MIN_CHANGED_FILES=8$/MIN_CHANGED_FILES=7/'; then
  run_case "(mc1) MIN_CHANGED_FILES 8->7: case 7f should flip to" \
    "heavy" "$r_7f_1L" "$MUTANT"
fi
if mutate lines-400-to-399 's/^MIN_CHANGED_LINES=400$/MIN_CHANGED_LINES=399/'; then
  run_case "(mc2) MIN_CHANGED_LINES 400->399: case 1f-399L should flip to" \
    "heavy" "$r_1f_399L" "$MUTANT"
fi

echo "-- hardening guard coverage (unmeasurable/injection paths) --"

# Guard at :30 - a leading dash must never reach git as an option. Repo is
# left dirty on purpose: if the dash guard is gone, "-U0" is a real git-diff
# flag and, with no revision given, git falls back to diffing the dirty
# worktree against the index -- silently measuring an unintended range
# instead of refusing the input.
inj_repo="$tmproot/inj"
mkdir -p "$inj_repo"
git -C "$inj_repo" init -q
git -C "$inj_repo" config user.email tester@example.com
git -C "$inj_repo" config user.name tester
git -C "$inj_repo" config commit.gpgsign false
seq 1 10 > "$inj_repo/f.txt"
git -C "$inj_repo" add -A
git -C "$inj_repo" commit -qm base
seq 1 20 > "$inj_repo/f.txt"
got="$(cd "$inj_repo" && bash "$SCRIPT" "-U0" 2>/dev/null)"
if [ "$got" = "surface: unknown files: - lines: -" ]; then
  echo "OK   leading-dash-injection -> $got"
else
  echo "FAIL leading-dash-injection expected 'surface: unknown files: - lines: -', got '$got'"
  fail=1
fi
if mutate leading-dash-removed '30d'; then
  got2="$(cd "$inj_repo" && bash "$MUTANT" "-U0" 2>/dev/null)"
  if [ "$got2" != "surface: unknown files: - lines: -" ]; then
    echo "OK   (mc3) leading-dash guard removed -> flips to '$got2'"
  else
    echo "FAIL (mc3) leading-dash guard removed: mutation didn't flip"
    fail=1
  fi
fi

# Guard at :37-40 - an unresolvable range (bad refs) must fail closed to
# "unknown" rather than letting `set -e` kill the script with a nonzero exit,
# which would break the exit-0-always contract.
rc=0
got="$(cd "$repo" && bash "$SCRIPT" "nonexistent-ref-aaa..nonexistent-ref-bbb" 2>/dev/null)" || rc=$?
if [ "$rc" = 0 ] && [ "$got" = "surface: unknown files: - lines: -" ]; then
  echo "OK   unresolvable-range -> $got"
else
  echo "FAIL unresolvable-range expected rc=0 'surface: unknown files: - lines: -', got '$got' (rc=$rc)"
  fail=1
fi
if mutate resolve-fallback-removed '37,40c\
numstat="$(git -c core.quotepath=false -c diff.relative=false diff --no-renames --numstat "$range" -- 2>/dev/null)"'; then
  rc2=0
  got2="$(cd "$repo" && bash "$MUTANT" "nonexistent-ref-aaa..nonexistent-ref-bbb" 2>/dev/null)" || rc2=$?
  if [ "$rc2" != 0 ] || [ "$got2" != "surface: unknown files: - lines: -" ]; then
    echo "OK   (mc4) unresolvable-range fallback removed -> flips (rc=$rc2, got='$got2')"
  else
    echo "FAIL (mc4) unresolvable-range fallback removed: mutation didn't flip"
    fail=1
  fi
fi

# Guard at :49-52 - a path C-quoted because it contains a literal quote
# character cannot be measured and must fail closed.
quote_repo="$tmproot/quote"
mkdir -p "$quote_repo/docs"
git -C "$quote_repo" init -q
git -C "$quote_repo" config user.email tester@example.com
git -C "$quote_repo" config user.name tester
git -C "$quote_repo" config commit.gpgsign false
: > "$quote_repo/README"
git -C "$quote_repo" add -A
git -C "$quote_repo" commit -qm base
printf '1\n2\n3\n' > "$quote_repo/docs/f\"quote.md"
git -C "$quote_repo" add -A
git -C "$quote_repo" commit -qm withquote
quote_range="$(git -C "$quote_repo" rev-parse HEAD~1)..$(git -C "$quote_repo" rev-parse HEAD)"
got="$(cd "$quote_repo" && bash "$SCRIPT" "$quote_range" 2>/dev/null)"
if [ "$got" = "surface: unknown files: - lines: -" ]; then
  echo "OK   quoted-path -> $got"
else
  echo "FAIL quoted-path expected 'surface: unknown files: - lines: -', got '$got'"
  fail=1
fi
if mutate quoted-path-guard-removed '49,52d'; then
  got2="$(cd "$quote_repo" && bash "$MUTANT" "$quote_range" 2>/dev/null)"
  if [ "$got2" != "surface: unknown files: - lines: -" ]; then
    echo "OK   (mc5) quoted-path guard removed -> flips to '$got2'"
  else
    echo "FAIL (mc5) quoted-path guard removed: mutation didn't flip"
    fail=1
  fi
fi

# Guard at :54-57 - a binary file reports "-" instead of a numeric count;
# without the guard the arithmetic on "-" is a bash syntax error.
bin_repo="$tmproot/bin"
mkdir -p "$bin_repo"
git -C "$bin_repo" init -q
git -C "$bin_repo" config user.email tester@example.com
git -C "$bin_repo" config user.name tester
git -C "$bin_repo" config commit.gpgsign false
printf 'a' > "$bin_repo/x.txt"
git -C "$bin_repo" add -A
git -C "$bin_repo" commit -qm base
printf '\x00\x01binary2' > "$bin_repo/bin.dat"
git -C "$bin_repo" add -A
git -C "$bin_repo" commit -qm addbin
bin_range="$(git -C "$bin_repo" rev-parse HEAD~1)..$(git -C "$bin_repo" rev-parse HEAD)"
got="$(cd "$bin_repo" && bash "$SCRIPT" "$bin_range" 2>/dev/null)"
if [ "$got" = "surface: unknown files: - lines: -" ]; then
  echo "OK   binary-file -> $got"
else
  echo "FAIL binary-file expected 'surface: unknown files: - lines: -', got '$got'"
  fail=1
fi
if mutate binary-guard-removed '54,57d'; then
  got2="$(cd "$bin_repo" && bash "$MUTANT" "$bin_range" 2>/dev/null)"
  if [ "$got2" != "surface: unknown files: - lines: -" ]; then
    echo "OK   (mc6) binary guard removed -> flips to '$got2'"
  else
    echo "FAIL (mc6) binary guard removed: mutation didn't flip"
    fail=1
  fi
fi

exit "$fail"
