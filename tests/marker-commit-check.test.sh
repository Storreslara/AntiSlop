#!/usr/bin/env bash
# Behavioral fixture suite for hooks/scripts/marker-commit-check.sh. Builds its
# own throwaway git repo under mktemp -d with three commits naming three
# different units - no SHA from this repo's real history is ever pinned (a
# rebase must never be able to expire a case here). See
# docs/plans/2026-08-15-marker-commit-attribution.md Step 6, cases (a)-(j).
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

script=hooks/scripts/marker-commit-check.sh

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

repo="$tmproot/repo"
mkdir -p "$repo/.claude/reviewed"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name Test

git -C "$repo" commit -q --allow-empty -m "feat(gh450): add feature for A"
sha_a="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" commit -q --allow-empty -m "chore(gh299): version bump 0.31.53 -> 0.31.54"
sha_b="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" commit -q --allow-empty -m "docs(gh137): update docs"
sha_c="$(git -C "$repo" rev-parse HEAD)"

write_marker() {
  # $1 = task-id, $2 = commit value (sha or "none")
  printf 'PASS %s 2026-08-15T00:00:00Z commit: %s criteria: true\n' "$1" "$2" \
    > "$repo/.claude/reviewed/$1.pass"
}

rm_marker() {
  rm -f "$repo/.claude/reviewed/$1.pass"
}

check() {
  # $1 = task-id, $2 = project-dir, $3 = expected state,
  # $4 = case label -> sets $out
  out="$(bash "$script" "$1" "$2")"
  if [[ $out == "marker-commit-check=$3 unit=$1"* ]]; then
    echo "OK   $4: $out"
  else
    echo "FAIL $4: expected state '$3', got: $out"
    fail=1
  fi
}

# (a) marker cites its own unit's commit -> ok
write_marker gh450 "$sha_a"
check gh450 "$repo" ok "(a) own commit"

# (b) marker cites a sibling unit's commit; the unit's own commit exists -> mismatch
write_marker gh450 "$sha_b"
out=""
check gh450 "$repo" mismatch "(b) sibling commit"
if [[ $out == *"candidates="*"$sha_a"* ]]; then
  echo "OK   (b) candidates include the correct sha"
else
  echo "FAIL (b) candidates missing correct sha ($sha_a): $out"
  fail=1
fi

# (c) marker cites a commit naming no unit; no commit anywhere names the unit -> unverifiable
write_marker gh999 "$sha_b"
check gh999 "$repo" unverifiable "(c) no commit names the unit"

# (d) commit: none -> unverifiable
write_marker gh450 none
check gh450 "$repo" unverifiable "(d) commit: none"

# (e) missing marker file -> unverifiable
rm_marker ghmissing
check ghmissing "$repo" unverifiable "(e) missing marker"

# (f) SHA not in history -> unverifiable
write_marker gh450 "0000000000000000000000000000000000dead"
check gh450 "$repo" unverifiable "(f) sha not in history"

# (g) bare-numeric id 137 against subject docs(gh137): ... -> ok (pinned regression)
write_marker 137 "$sha_c"
check 137 "$repo" ok "(g) naive-pattern false positive stays ok"

# (h) id 31 against subject chore(gh299): version bump 0.31.53 -> 0.31.54 -> not ok
write_marker 31 "$sha_b"
check 31 "$repo" unverifiable "(h) bare-digit false positive is rejected"

# (i) adhoc-* id against a subject naming no such slug, repo has no such commit -> unverifiable, never mismatch
write_marker adhoc-2026-08-14-someslug "$sha_a"
check adhoc-2026-08-14-someslug "$repo" unverifiable "(i) adhoc id with no reference"

# (j) not a git repo -> unverifiable, exit 0
nogit="$tmproot/nogit"
mkdir -p "$nogit/.claude/reviewed"
printf 'PASS ghplain 2026-08-15T00:00:00Z commit: 0000000000000000000000000000000000dead criteria: true\n' \
  > "$nogit/.claude/reviewed/ghplain.pass"
rc=0
out="$(bash "$script" ghplain "$nogit")" || rc=$?
if [ "$rc" -eq 0 ] && [[ $out == "marker-commit-check=unverifiable unit=ghplain"* ]]; then
  echo "OK   (j) not a git repo, exit 0"
else
  echo "FAIL (j) not a git repo: rc=$rc out=$out"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "All marker-commit-check cases passed."
else
  echo "One or more marker-commit-check cases FAILED."
fi
exit "$fail"
