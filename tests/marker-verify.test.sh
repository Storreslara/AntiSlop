#!/usr/bin/env bash
# Behavioral fixture suite for hooks/scripts/marker-verify.sh - --list vs
# --execute contract, per docs/plans/2026-08-25-harness-trust-gaps.md Step 6.
# Builds its own throwaway git repo under mktemp -d; no real commit is pinned.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

script=hooks/scripts/marker-verify.sh

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

repo="$tmproot/repo"
mkdir -p "$repo/.claude/reviewed"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name Test

printf 'ORIGINAL\n' > "$repo/file.txt"
git -C "$repo" add file.txt
git -C "$repo" commit -q -m "feat(gh420-fixture): seed file"
sha_ok="$(git -C "$repo" rev-parse HEAD)"

write_marker() {
  # $1=task-id $2=commit $3=criteria-text (empty omits the field entirely)
  local line="PASS $1 2026-08-15T00:00:00Z commit: $2"
  [ -n "$3" ] && line="$line criteria: $3"
  printf '%s\n' "$line" > "$repo/.claude/reviewed/$1.pass"
}

expect() {
  # $1=out $2=expected-prefix $3=label
  if [[ $1 == "$2"* ]]; then
    echo "OK   $3: $1"
  else
    echo "FAIL $3: expected prefix '$2', got: $1"
    fail=1
  fi
}

# --- --list mode: parses and counts, executes nothing ---

write_marker three "$sha_ok" "true; true; true"
out="$(bash "$script" three "$repo")"
expect "$out" "marker-verify=listed unit=three criteria=3" "(list) counts criteria"

write_marker sentinel "$sha_ok" "touch $tmproot/SENTINEL"
out="$(bash "$script" sentinel "$repo")"
expect "$out" "marker-verify=listed unit=sentinel criteria=1" "(list) sentinel marker listed only"
if [ -f "$tmproot/SENTINEL" ]; then
  echo "FAIL: --list executed the criteria (SENTINEL appeared)"
  fail=1
else
  echo "OK   (list) SENTINEL never appears"
fi

# --- --execute mode: actually runs, in a throwaway worktree ---

out="$(bash "$script" sentinel "$repo" --execute)"
expect "$out" "marker-verify=ok unit=sentinel ran=1 failed=0" "(execute) sentinel runs criteria"
if [ -f "$tmproot/SENTINEL" ]; then
  echo "OK   (execute) SENTINEL does appear"
else
  echo "FAIL: --execute did not run the criteria (no SENTINEL)"
  fail=1
fi

# case: 3 passing criteria -> ok
out="$(bash "$script" three "$repo" --execute)"
expect "$out" "marker-verify=ok unit=three ran=3 failed=0" "(execute) 3 passing"

# case: 1 of 3 failing -> mismatch, failing=2
write_marker onefail "$sha_ok" "true; false; true"
out="$(bash "$script" onefail "$repo" --execute)"
expect "$out" "marker-verify=mismatch unit=onefail ran=3 failed=1 failing=2" "(execute) 1 of 3 failing"

# case: no criteria: field -> unverifiable (both modes)
write_marker nocriteria "$sha_ok" ""
out="$(bash "$script" nocriteria "$repo" --execute)"
expect "$out" "marker-verify=unverifiable unit=nocriteria" "(execute) no criteria field"
out="$(bash "$script" nocriteria "$repo")"
expect "$out" "marker-verify=unverifiable unit=nocriteria" "(list) no criteria field"

# case: unreachable commit -> unverifiable
write_marker badcommit "0000000000000000000000000000000000dead" "true"
out="$(bash "$script" badcommit "$repo" --execute)"
expect "$out" "marker-verify=unverifiable unit=badcommit" "(execute) unreachable commit"

# case: absent marker -> unverifiable (both modes)
rm -f "$repo/.claude/reviewed/absent.pass"
out="$(bash "$script" absent "$repo" --execute)"
expect "$out" "marker-verify=unverifiable unit=absent" "(execute) absent marker"
out="$(bash "$script" absent "$repo")"
expect "$out" "marker-verify=unverifiable unit=absent" "(list) absent marker"

# case: throwaway-worktree GUARD - a dirty live tree must not change the verdict
write_marker guard "$sha_ok" "grep -qxF ORIGINAL file.txt"
out="$(bash "$script" guard "$repo" --execute)"
expect "$out" "marker-verify=ok unit=guard ran=1 failed=0" "(execute) guard clean baseline"

printf 'DIRTY\n' > "$repo/file.txt"
out="$(bash "$script" guard "$repo" --execute)"
expect "$out" "marker-verify=ok unit=guard ran=1 failed=0" "(execute) GUARD: dirty live tree does not change verdict"
if [ "$(cat "$repo/file.txt")" = "DIRTY" ]; then
  echo "OK   GUARD: live tree still dirty after --execute (worktree isolated it)"
else
  echo "FAIL GUARD: live tree state was mutated by --execute"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "All marker-verify cases passed."
else
  echo "One or more marker-verify cases FAILED."
fi
exit "$fail"
