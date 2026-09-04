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

# --- AC1b: parser tolerance for wrapped and indented tags (Step 1b) ---

# AC1b.1 classification table: A.1's Defect-B rows, four already-passing plus
# five previously-untagged rows now fixed by B1's wrapper normalization.
write_marker_body ac1b1 "$sha_ok" "true" $'Non-blocking notes:\nNOTE[spec]: x\n- NOTE[spec]: x\n* NOTE[code]: x\n1. NOTE[spec]: x\n1) NOTE[code]: x\n- **NOTE[spec]:** x\n**NOTE[code]:** x\n- `NOTE[spec]:` x\n- __NOTE[code]:__ x\n- _NOTE[spec]:_ x'
out="$(bash "$script" ac1b1 "$repo" --notes)"
tags="$(printf '%s\n' "$out" | grep '^marker-note=' | sed -E 's/^marker-note=([a-z]+).*/\1/' | paste -sd, -)"
expect_exact "$tags" "spec,spec,code,spec,code,spec,code,spec,code,spec" "(notes) AC1b.1 classification order"
expect_exact "$(printf '%s\n' "$out" | tail -n 1)" "marker-notes=10 unit=ac1b1 spec=6 code=4 untagged=0" "(notes) AC1b.1 summary"

# AC1b.2 over-match guards: tolerance must not become greedy.
write_marker_body ac1b2 "$sha_ok" "true" $'Non-blocking notes:\nNOTE[spec] no colon x\nsee NOTE[spec]: mid-sentence\nNOTE[other]: x\n- Non-blocking: plain prose'
out="$(bash "$script" ac1b2 "$repo" --notes)"
expect_exact "$(printf '%s\n' "$out" | tail -n 1)" "marker-notes=4 unit=ac1b2 spec=0 code=0 untagged=4" "(notes) AC1b.2 over-match guards stay untagged"

# AC1b.3 Defect A fixed: an indented, tagged line starts a NEW note.
write_marker_body ac1b3 "$sha_ok" "true" $'Non-blocking notes:\n- NOTE[code]: a\n  - NOTE[spec]: b'
out="$(bash "$script" ac1b3 "$repo" --notes)"
expect_exact "$(printf '%s\n' "$out" | sed -n '1p')" "marker-note=code unit=ac1b3 - NOTE[code]: a" "(notes) AC1b.3 first note code"
expect_exact "$(printf '%s\n' "$out" | sed -n '2p')" "marker-note=spec unit=ac1b3 - NOTE[spec]: b" "(notes) AC1b.3 second note spec"
expect_exact "$(printf '%s\n' "$out" | sed -n '3p')" "marker-notes=2 unit=ac1b3 spec=1 code=1 untagged=0" "(notes) AC1b.3 summary"

# AC1b.4 Defect A fix is narrow: an untagged indented line still merges.
write_marker_body ac1b4 "$sha_ok" "true" $'Non-blocking notes:\n- NOTE[code]: a\n  more prose about a'
out="$(bash "$script" ac1b4 "$repo" --notes)"
expect_exact "$out" $'marker-note=code unit=ac1b4 - NOTE[code]: a more prose about a\nmarker-notes=1 unit=ac1b4 spec=0 code=1 untagged=0' "(notes) AC1b.4 untagged indented line still merges"

# AC1b.5 legacy-parse invariance (fixture-based, expiry-proof): markers with
# no `NOTE[` substring anywhere must parse byte-identically. Isolated repo so
# the sweep below cannot pick up any of this file's tagged fixtures.
legacy_repo="$tmproot/legacy"
mkdir -p "$legacy_repo/.claude/reviewed"
write_legacy() {
  # $1=task-id $2=body (appended verbatim after header)
  printf 'PASS %s 2026-08-15T00:00:00Z commit: %s criteria: true\n%s\n' "$1" "$sha_ok" "$2" > "$legacy_repo/.claude/reviewed/$1.pass"
}
write_legacy ac1b5exact $'Non-blocking notes:\nsome remark without any tag here'
write_legacy ac1b5loose $' - Non-blocking notes\nanother remark, no anchor colon'
write_legacy ac1b5fallback $'plain first remark\nplain second remark'
legacy_out="$(bash bin/marker-audit.sh "$legacy_repo" --notes)"
expected_legacy=$'marker-note=untagged unit=ac1b5exact some remark without any tag here\nmarker-note=untagged unit=ac1b5fallback plain first remark\nmarker-note=untagged unit=ac1b5fallback plain second remark\nmarker-note=untagged unit=ac1b5loose another remark, no anchor colon\nmarker-notes-sweep=4 markers=3 spec=0 code=0 untagged=4 malformed=0'
expect_exact "$legacy_out" "$expected_legacy" "(audit) AC1b.5 legacy-parse invariance"

# AC1b.8 safety (R5, unchanged): the existing SENTINEL case above already
# covers this - --notes never executes a marker's criteria.

# AC1b.9 malformed count (OQ-A1 accepted: option a).
malformed_repo="$tmproot/malformed"
mkdir -p "$malformed_repo/.claude/reviewed"
printf 'PASS ac1b9bad 2026-08-15T00:00:00Z commit: %s criteria: true\nNon-blocking notes:\n- NOTE[bogus]: x\n' "$sha_ok" > "$malformed_repo/.claude/reviewed/ac1b9bad.pass"
malformed_out="$(bash bin/marker-audit.sh "$malformed_repo" --notes)"
expect_exact "$(printf '%s\n' "$malformed_out" | tail -n 1)" "marker-notes-sweep=1 markers=1 spec=0 code=0 untagged=1 malformed=1" "(audit) AC1b.9 malformed=1 with a bogus tag"

# --- AC2.1: branch agreement - the three literals the parser matches on
# must occur both in hooks/scripts/marker-verify.sh and in agents/reviewer.md.
# The script's own case patterns escape the brackets for bash glob syntax
# (`NOTE\[spec\]:*`), so the check tolerates one optional literal backslash
# before each bracket in either file - this is what "occurs" means given
# that constraint, not a loosening of the rule.

check_literal_pair() {
  # $1=ERE pattern $2=label
  # AC3.3: extended to include CONTEXT.md as a third file
  if grep -qE "$1" "$script" && grep -qE "$1" agents/reviewer.md && grep -qE "$1" CONTEXT.md; then
    echo "OK   (branch-agreement) AC2.1/AC3.3 $2 present in all three files"
  else
    echo "FAIL (branch-agreement) AC2.1/AC3.3 $2 missing from marker-verify.sh, agents/reviewer.md, and/or CONTEXT.md"
    fail=1
  fi
}

check_literal_pair 'Non-blocking notes:' "anchor literal"
check_literal_pair 'NOTE\\?\[spec\\?\]:' "NOTE[spec]: literal"
check_literal_pair 'NOTE\\?\[code\\?\]:' "NOTE[code]: literal"

# --- AC2.7 (Addendum A.4.2): the worked example in agents/reviewer.md,
# extracted verbatim, must parse under the exact anchor as one NOTE[spec]
# note then one NOTE[code] note, with its indented line merged as a
# continuation of the NOTE[code] note.

example_block="$(awk '
  /^[[:space:]]*Worked example:[[:space:]]*$/ { found=1; next }
  found && !infence && /^[[:space:]]*```[[:space:]]*$/ {
    match($0, /^[[:space:]]*/); indent=RLENGTH; infence=1; next
  }
  found && infence && /^[[:space:]]*```[[:space:]]*$/ { exit }
  found && infence { print substr($0, indent + 1) }
' agents/reviewer.md)"

if [ -z "$example_block" ]; then
  echo "FAIL (notes) AC2.7 could not extract worked example block from agents/reviewer.md"
  fail=1
else
  write_marker_body ac27 "$sha_ok" "true" "$(printf 'Non-blocking notes:\n%s' "$example_block")"
  out="$(bash "$script" ac27 "$repo" --notes)"
  tags="$(printf '%s\n' "$out" | grep '^marker-note=' | sed -E 's/^marker-note=([a-z]+).*/\1/' | paste -sd, -)"
  expect_exact "$tags" "spec,code" "(notes) AC2.7 worked example order"
  expect_exact "$(printf '%s\n' "$out" | tail -n 1)" "marker-notes=2 unit=ac27 spec=1 code=1 untagged=0" "(notes) AC2.7 worked example summary"
fi

if [ "$fail" -eq 0 ]; then
  echo "All marker-verify cases passed."
else
  echo "One or more marker-verify cases FAILED."
fi
exit "$fail"
