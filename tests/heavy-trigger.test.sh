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
    # Verify the exact format and check if it contains expected
    if echo "$got" | grep -q "$expected"; then
      echo "OK   $label -> $got"
    else
      echo "FAIL $label expected to contain '$expected', got '$got' (rc=$rc)"
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

# Real-world test shapes (18 files 116 lines = heavy, 24 files 328 lines = heavy)
r_gh137=$(add_commit gh137-18f-116L \
  src/f1.js:8 src/f2.js:8 src/f3.js:8 src/f4.js:8 src/f5.js:8 \
  src/f6.js:8 src/f7.js:8 src/f8.js:8 src/f9.js:8 src/f10.js:8 \
  test/t1.js:8 test/t2.js:8 test/t3.js:8 test/t4.js:8 test/t5.js:8 \
  test/t6.js:8 test/t7.js:8 test/t8.js:8)
r_gh299=$(add_commit gh299-24f-328L \
  app/a1.ts:14 app/a2.ts:14 app/a3.ts:14 app/a4.ts:14 app/a5.ts:14 \
  app/a6.ts:14 app/a7.ts:14 app/a8.ts:14 app/a9.ts:14 app/a10.ts:14 \
  lib/l1.ts:14 lib/l2.ts:14 lib/l3.ts:14 lib/l4.ts:14 lib/l5.ts:14 \
  lib/l6.ts:14 lib/l7.ts:14 lib/l8.ts:14 lib/l9.ts:14 lib/l10.ts:14 \
  lib/l11.ts:14 lib/l12.ts:14 lib/l13.ts:14 lib/l14.ts:14)

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
if grep -qF '1. Large surface: ≥~8 impacted files OR ≥~400 changed lines' /home/sebas/AntiSlop/docs/adr/0004-reviewer-roast-work-dual-model-routing.md; then
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

exit "$fail"
