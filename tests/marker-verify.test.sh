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

# --- --notes mode: enumerates non-blocking notes, executes nothing ---

write_marker_body() {
  # $1=task-id $2=commit $3=criteria-text $4=body (appended verbatim after header)
  local line="PASS $1 2026-08-15T00:00:00Z commit: $2"
  [ -n "$3" ] && line="$line criteria: $3"
  printf '%s\n%s\n' "$line" "$4" > "$repo/.claude/reviewed/$1.pass"
}

expect_exact() {
  # $1=actual $2=expected(exact) $3=label
  if [ "$1" = "$2" ]; then
    echo "OK   $3"
  else
    echo "FAIL $3: expected '$2', got '$1'"
    fail=1
  fi
}

# AC1.3 exact anchor, one NOTE[spec] + one NOTE[code] note
write_marker_body notesboth "$sha_ok" "true" $'Non-blocking notes:\n- NOTE[spec]: spec drift found here\n- NOTE[code]: code style nit here'
out="$(bash "$script" notesboth "$repo" --notes)"
expect_exact "$(printf '%s\n' "$out" | sed -n '1p')" "marker-note=spec unit=notesboth - NOTE[spec]: spec drift found here" "(notes) AC1.3 spec note"
expect_exact "$(printf '%s\n' "$out" | sed -n '2p')" "marker-note=code unit=notesboth - NOTE[code]: code style nit here" "(notes) AC1.3 code note"
expect_exact "$(printf '%s\n' "$out" | sed -n '3p')" "marker-notes=2 unit=notesboth spec=1 code=1 untagged=0" "(notes) AC1.3 summary"

# AC1.4 loosened anchor (leading space + dash, no colon) -> untagged
write_marker_body notesloose "$sha_ok" "true" $' - Non-blocking notes\nsomething worth flagging later'
out="$(bash "$script" notesloose "$repo" --notes)"
expect_exact "$(printf '%s\n' "$out" | sed -n '1p')" "marker-note=untagged unit=notesloose something worth flagging later" "(notes) AC1.4 loose anchor untagged"
expect_exact "$(printf '%s\n' "$out" | sed -n '2p')" "marker-notes=1 unit=notesloose spec=0 code=0 untagged=1" "(notes) AC1.4 summary"

# AC1.5 fallback: no anchor of either form -> non-zero notes, not empty
write_marker_body notesfallback "$sha_ok" "true" $'first remark line\nsecond remark line'
out="$(bash "$script" notesfallback "$repo" --notes)"
expect_exact "$(printf '%s\n' "$out" | sed -n '3p')" "marker-notes=2 unit=notesfallback spec=0 code=0 untagged=2" "(notes) AC1.5 fallback yields notes"

# AC1.6 safety (R5): --notes never runs a marker's criteria, still exits 0.
# Fresh sentinel path: the "sentinel" fixture's criteria already ran earlier
# in --execute mode above, so its own $tmproot/SENTINEL already exists.
write_marker notessentinel "$sha_ok" "touch $tmproot/SENTINEL2"
out="$(bash "$script" notessentinel "$repo" --notes)"
expect_exact "$out" "marker-notes=0 unit=notessentinel spec=0 code=0 untagged=0" "(notes) AC1.6 sentinel: single-line marker has no notes"
if [ -f "$tmproot/SENTINEL2" ]; then
  echo "FAIL: --notes executed the criteria (SENTINEL2 appeared)"
  fail=1
else
  echo "OK   (notes) AC1.6 SENTINEL2 never appears"
fi

# AC1.7 bin/marker-audit.sh --surface filter
write_marker_body surfacea "$sha_ok" "true" $'Non-blocking notes:\n- NOTE[code]: touches bin/cli.js render loop'
write_marker_body surfaceb "$sha_ok" "true" $'Non-blocking notes:\n- NOTE[code]: touches hooks/scripts/stop-gate.sh'
audit_out="$(bash bin/marker-audit.sh "$repo" --notes --surface=bin/cli.js)"
note_line_count="$(printf '%s\n' "$audit_out" | grep -c '^marker-note=')"
if [ "$note_line_count" -eq 1 ] && printf '%s\n' "$audit_out" | grep -q 'bin/cli.js'; then
  echo "OK   (audit) AC1.7 surface filter: exactly one bin/cli.js line"
else
  echo "FAIL (audit) AC1.7 surface filter: got: $audit_out"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "All marker-verify cases passed."
else
  echo "One or more marker-verify cases FAILED."
fi
exit "$fail"
