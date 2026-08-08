#!/usr/bin/env bash
# Fixture-driven test for the reviewer-SubagentStop branch of
# hooks/scripts/stop-gate.sh keeping pending-review flags standing while a
# .claude/reviewed/*.blocked marker is active, plus assertions that
# reviewer-route-gate.sh and task-gate.sh need NO change. Canned hook-input
# JSON piped to each script - no real claude/agent dependency.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  # $1 = case name -> echoes a fresh project dir seeded with persona-config.json
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
    > "$dir/.claude/persona-config.json"
  echo "$dir"
}

run_stop() {
  # $1 = project dir -> one main-session Stop against $2 (default: the real script)
  local rc=0
  printf '%s' '{"hook_event_name":"Stop","session_id":"main"}' \
    | CLAUDE_PROJECT_DIR="$1" bash "${2:-hooks/scripts/stop-gate.sh}" || rc=$?
  return "$rc"
}

reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'

# (a) reviewer SubagentStop WITH an active .blocked marker -> flag kept + audit
dir="$(make_project blocked)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
printf 'BLOCKED task-a 2026-07-22T00:00:00Z missing: constraint X\n' \
  > "$dir/.claude/reviewed/task-a.blocked"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
if [ "$rc" = 0 ] && [ -f "$dir/.claude/.pending-review.lp-1" ] \
   && grep -q 'verdict=blocked flags-kept' "$dir/.claude/review-audit.log"; then
  echo "OK   (a) active .blocked marker keeps pending-review flag standing + audit logged"
else
  echo "FAIL (a) flag removed or 'verdict=blocked flags-kept' audit line missing (rc=$rc)"
  fail=1
fi

# (b) reviewer SubagentStop WITHOUT any .blocked marker -> flag removed (existing behavior)
dir="$(make_project cleared)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-1" ] \
   && grep -q 'cleared-by=reviewer' "$dir/.claude/review-audit.log"; then
  echo "OK   (b) no .blocked marker -> flag cleared (existing behavior preserved)"
else
  echo "FAIL (b) flag not cleared or 'cleared-by=reviewer' audit line missing (rc=$rc)"
  fail=1
fi

# (c) with a flag standing, dispatching the next gated unit is still blocked (exit 2)
dir="$(make_project route)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' '{"agent_type":"orchestrator","tool_input":{"subagent_type":"lead-programmer"}}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/reviewer-route-gate.sh || rc=$?
if [ "$rc" = 2 ]; then
  echo "OK   (c) reviewer-route-gate.sh still blocks next gated dispatch while a flag stands"
else
  echo "FAIL (c) expected exit 2 from reviewer-route-gate.sh, got rc=$rc"
  fail=1
fi

# (d) a .blocked marker does not satisfy task-gate.sh's marker_valid()
dir="$(make_project taskgate)"
printf 'BLOCKED blk-1 2026-07-22T00:00:00Z missing: constraint Y\n' \
  > "$dir/.claude/reviewed/blk-1.blocked"
rc=0
printf '%s' '{"task":{"subject":"impl: blk-1 do the thing","id":"blk-1"}}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/task-gate.sh || rc=$?
audit="$dir/.claude/review-audit.log"
if [ ! -f "$audit" ] || ! grep -q 'task=blk-1 marker-accepted' "$audit"; then
  echo "OK   (d) .blocked marker is not accepted as a valid PASS by task-gate.sh"
else
  echo "FAIL (d) task-gate.sh accepted a .blocked marker as a valid PASS"
  fail=1
fi

# (e) sticky defer: one write permits every subsequent Stop, content unchanged
dir="$(make_project sticky)"
printf 'defer: reviewer already dispatched\n' > "$dir/.claude/.pending-review.lp-1"
before="$(cat "$dir/.claude/.pending-review.lp-1")"
ok=true
for i in 1 2 3; do
  rc=0
  printf '%s' '{"hook_event_name":"Stop","session_id":"main"}' \
    | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
  [ "$rc" = 0 ] || ok=false
done
after="$(cat "$dir/.claude/.pending-review.lp-1" 2>/dev/null || true)"
if [ "$ok" = true ] && [ -f "$dir/.claude/.pending-review.lp-1" ] && [ "$before" = "$after" ]; then
  echo "OK   (e) one defer: write permits three consecutive Stop events, flag content unchanged (sticky semantics)"
else
  echo "FAIL (e) sticky defer semantics broken (ok=$ok before=[$before] after=[$after])"
  fail=1
fi

# (f) consecutive duplicate defer: lines are suppressed - one write, three Stops, one line
dir="$(make_project dedupe)"
printf 'defer: reviewer already dispatched\n' > "$dir/.claude/.pending-review.lp-1"
ok=true
for i in 1 2 3; do
  run_stop "$dir" || ok=false
done
n="$(grep -c 'defer: ' "$dir/.claude/review-audit.log" 2>/dev/null || true)"
if [ "$ok" = true ] && [ "$n" = 1 ]; then
  echo "OK   (f) three Stop events with an unchanged defer: reason log exactly one line"
else
  echo "FAIL (f) expected one defer: audit line from three exit-0 Stops (ok=$ok lines=$n)"
  fail=1
fi

# (g) a CHANGED defer: reason is still recorded, in order
dir="$(make_project changed)"
flag="$dir/.claude/.pending-review.lp-1"
ok=true
printf 'defer: reason A\n' > "$flag"; run_stop "$dir" || ok=false
printf 'defer: reason B\n' > "$flag"; run_stop "$dir" || ok=false
got="$(cut -d' ' -f2- < "$dir/.claude/review-audit.log" | tr '\n' '|')"
if [ "$ok" = true ] && [ "$got" = 'defer: reason A|defer: reason B|' ]; then
  echo "OK   (g) defer: A -> Stop -> defer: B -> Stop logs both reasons, in order"
else
  echo "FAIL (g) expected 'defer: reason A|defer: reason B|' (ok=$ok got=[$got])"
  fail=1
fi

# (h) only CONSECUTIVE duplicates are suppressed: an identical defer: separated
#     from the earlier one by a cleared-by=reviewer line IS still appended
dir="$(make_project nonconsecutive)"
flag="$dir/.claude/.pending-review.lp-1"
ok=true
printf 'defer: reviewer already dispatched\n' > "$flag"; run_stop "$dir" || ok=false
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || ok=false
printf 'defer: reviewer already dispatched\n' > "$flag"; run_stop "$dir" || ok=false
got="$(cut -d' ' -f2- < "$dir/.claude/review-audit.log" | tr '\n' '|')"
# Expect: defer: | marker-check=bootstrap | cleared-by=reviewer | defer: (bootstrap line added by clear-watermark check)
want='defer: reviewer already dispatched|marker-check=bootstrap|cleared-by=reviewer|defer: reviewer already dispatched|'
if [ "$ok" = true ] && [ "$got" = "$want" ]; then
  echo "OK   (h) an identical defer: after an intervening log line is still appended (with bootstrap marker check)"
else
  echo "FAIL (h) expected [$want] (ok=$ok got=[$got])"
  fail=1
fi

# (i) MUTATION CONTROL for (f): a copy of the script with the dedupe guard
#     neutralized must log all three lines, proving (f) binds to the guard and
#     not to something that was already true.
mutant="$tmproot/mutant"
mkdir -p "$mutant"
cp hooks/scripts/stop-gate.sh "$mutant/stop-gate.sh"
cp -R hooks/scripts/lib "$mutant/lib"
guard='if [ "$last_logged" != "$flag_content" ]; then'
before_n="$(grep -cF "$guard" "$mutant/stop-gate.sh" || true)"
sed -i "s/$(printf '%s' "$guard" | sed 's/[][\\.*^$\/]/\\&/g')/if true; then/" "$mutant/stop-gate.sh"
after_n="$(grep -cF "$guard" "$mutant/stop-gate.sh" || true)"

dir="$(make_project mutation)"
printf 'defer: reviewer already dispatched\n' > "$dir/.claude/.pending-review.lp-1"
ok=true
for i in 1 2 3; do
  run_stop "$dir" "$mutant/stop-gate.sh" || ok=false
done
n="$(grep -c 'defer: ' "$dir/.claude/review-audit.log" 2>/dev/null || true)"
if [ "$before_n" = 1 ] && [ "$after_n" = 0 ] && [ "$ok" = true ] && [ "$n" = 3 ]; then
  echo "OK   (i) mutation control: without the dedupe guard the same run logs 3 lines, so (f) is binding"
else
  echo "FAIL (i) mutation not applied or did not change behavior (guard before=$before_n after=$after_n ok=$ok lines=$n)"
  fail=1
fi

# (j) a MULTI-LINE defer: reason dedupes exactly like a single-line one - the
#     flag content is flattened to one logical line, so it can compare equal to
#     the log's (single-line) last record.
dir="$(make_project multiline)"
printf 'defer: reviewer dispatched\nsee issue 201 for the reason\n' \
  > "$dir/.claude/.pending-review.lp-1"
ok=true
for i in 1 2 3; do
  run_stop "$dir" || ok=false
done
n="$(grep -c 'defer: ' "$dir/.claude/review-audit.log" 2>/dev/null || true)"
lines="$(wc -l < "$dir/.claude/review-audit.log" 2>/dev/null || echo 0)"
if [ "$ok" = true ] && [ "$n" = 1 ] && [ "$lines" = 1 ]; then
  echo "OK   (j) three Stops with an unchanged multi-line defer: reason log exactly one one-line record"
else
  echo "FAIL (j) expected one single-line defer: record from three exit-0 Stops (ok=$ok records=$n log-lines=$lines)"
  fail=1
fi

# (k) a reason that is empty after the colon is NOT a valid escape hatch: both
#     'defer: ' and 'skip: ' block (exit 2) and write no record, and the
#     'skip: ' form must additionally leave the flag in place.
for kind in defer skip; do
  dir="$(make_project "empty-$kind")"
  flag="$dir/.claude/.pending-review.lp-1"
  printf '%s: \n' "$kind" > "$flag"
  rc=0
  run_stop "$dir" 2>/dev/null || rc=$?
  # no log file at all is also "no record", so default the count to 0
  n="$(grep -c "$kind: " "$dir/.claude/review-audit.log" 2>/dev/null || true)"
  n="${n:-0}"
  if [ "$rc" = 2 ] && [ "$n" = 0 ] && [ -f "$flag" ]; then
    echo "OK   (k) an empty-after-colon '$kind: ' reason blocks, logs nothing, and keeps the flag"
  else
    echo "FAIL (k) expected rc=2, no '$kind: ' record and the flag kept (rc=$rc records=$n flag-exists=$([ -f "$flag" ] && echo yes || echo no))"
    fail=1
  fi
done

# (l) KEEP-UNCHANGED guard for the arm (k) now sits in front of: a NON-empty
#     skip: reason still allows the Stop, is logged, and still deletes the flag.
dir="$(make_project skip-nonempty)"
flag="$dir/.claude/.pending-review.lp-1"
printf 'skip: unit abandoned, superseded by issue 202\n' > "$flag"
rc=0
run_stop "$dir" || rc=$?
got="$(cut -d' ' -f2- < "$dir/.claude/review-audit.log" 2>/dev/null | tr '\n' '|' || true)"
if [ "$rc" = 0 ] && [ ! -e "$flag" ] \
   && [ "$got" = 'skip: unit abandoned, superseded by issue 202|' ]; then
  echo "OK   (l) a non-empty skip: reason still allows, logs, and deletes the flag"
else
  echo "FAIL (l) skip: deletion behaviour changed (rc=$rc flag-exists=$([ -e "$flag" ] && echo yes || echo no) got=[$got])"
  fail=1
fi

# (m) shape sweep on the dedupe, ONE-DIRECTIONAL: each shape must yield exactly
#     one record over three consecutive Stops. Only the deduped count is
#     asserted - no shape is asserted to produce two.
sweep() {
  local name="$1"
  local content="$2"
  local dir ok=true n
  dir="$(make_project "sweep-$name")"
  printf '%s' "$content" > "$dir/.claude/.pending-review.lp-1"
  for _ in 1 2 3; do
    run_stop "$dir" || ok=false
  done
  n="$(grep -c 'defer: ' "$dir/.claude/review-audit.log" 2>/dev/null || true)"
  if [ "$ok" = true ] && [ "${n:-0}" = 1 ]; then
    echo "OK   (m) $name defer: reason -> exactly one record over three Stops"
  else
    echo "FAIL (m) $name defer: reason -> ${n:-0} records over three Stops (ok=$ok)"
    fail=1
  fi
}
sweep multi-line          "$(printf 'defer: sweep line one\nsweep line two\nsweep line three\n')"
sweep trailing-whitespace "$(printf 'defer: sweep trailing   \n')"
sweep cr-terminated       "$(printf 'defer: sweep carriage return\r\n')"
sweep over-1kb            "defer: $(printf 'x%.0s' {1..1100})"

# (n) MUTATION CONTROL for the step: strip the flattening from a throwaway copy
#     and confirm (j) - the multi-line dedupe - fails there, proving (j)/(m)
#     bind to the flattening and not to something already true. Reverting
#     baseline for reference: git show c770cb9:hooks/scripts/stop-gate.sh.
mutant_flat="$tmproot/mutant-flatten"
mkdir -p "$mutant_flat"
cp hooks/scripts/stop-gate.sh "$mutant_flat/stop-gate.sh"
cp -R hooks/scripts/lib "$mutant_flat/lib"
flat_before="$(grep -c '| tr ' "$mutant_flat/stop-gate.sh" || true)"
sed -i '/| tr /d' "$mutant_flat/stop-gate.sh"
flat_after="$(grep -c '| tr ' "$mutant_flat/stop-gate.sh" || true)"
parses=yes
bash -n "$mutant_flat/stop-gate.sh" 2>/dev/null || parses=no

dir="$(make_project mutation-flatten)"
printf 'defer: reviewer dispatched\nsee issue 201 for the reason\n' \
  > "$dir/.claude/.pending-review.lp-1"
ok=true
for i in 1 2 3; do
  run_stop "$dir" "$mutant_flat/stop-gate.sh" || ok=false
done
n="$(grep -c 'defer: ' "$dir/.claude/review-audit.log" 2>/dev/null || true)"
if [ "${flat_before:-0}" = 1 ] && [ "${flat_after:-0}" = 0 ] && [ "$parses" = yes ] \
   && [ "$ok" = true ] && [ "${n:-0}" = 3 ]; then
  echo "OK   (n) mutation control: without the flattening the same run logs 3 records, so (j) is binding"
else
  echo "FAIL (n) mutation not applied or did not change behavior (flatten before=$flat_before after=$flat_after parses=$parses ok=$ok records=${n:-0})"
  fail=1
fi

# ============================================================================
# PER-UNIT REVIEW-JOIN TEST CASES (unit 263; replaces the clear-watermark set)
#
# The stamp reviewer-route-gate.sh writes at dispatch time is a single line:
#   <UTC ISO-8601> unit=<unit-id> prior=<none|fail|blocked> prior_mtime=<epoch|->
# stop-gate.sh consumes it: a marker counts only for the unit its stamp names.
# ============================================================================

seed_stamp() {
  # $1 = project dir, $2 = unit id, $3 = prior, $4 = prior_mtime
  printf '2026-08-07T12:00:00Z unit=%s prior=%s prior_mtime=%s\n' "$2" "$3" "$4" \
    > "$1/.claude/.review-join.$2"
}

# (o) join-absent-fails-open: no stamp at all -> exit 0, flags cleared, bootstrap
dir="$(make_project join-absent)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-1" ] \
   && grep -q 'marker-check=bootstrap' "$dir/.claude/review-audit.log"; then
  echo "OK   (o) join-absent-fails-open: no review-join stamp -> exit 0, flags cleared, 'marker-check=bootstrap' logged"
else
  echo "FAIL (o) join-absent-fails-open broken (rc=$rc flag-exists=$([ -e "$dir/.claude/.pending-review.lp-1" ] && echo yes || echo no) bootstrap=$(grep -c 'marker-check=bootstrap' "$dir/.claude/review-audit.log" 2>/dev/null || echo 0))"
  fail=1
fi

# (p) join-unsatisfied-blocks: a stamp with no marker at all -> exit 2, flags and
#     stamp both kept, one marker=MISSING line naming that unit
dir="$(make_project join-unsatisfied)"
seed_stamp "$dir" unit-p none -
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh 2>/dev/null || rc=$?
if [ "$rc" = 2 ] && [ -f "$dir/.claude/.pending-review.lp-1" ] \
   && [ -f "$dir/.claude/.review-join.unit-p" ] \
   && grep -q 'marker=MISSING unit=unit-p' "$dir/.claude/review-audit.log"; then
  echo "OK   (p) join-unsatisfied-blocks: stamp with no marker -> exit 2, flags kept, stamp kept, 'marker=MISSING unit=unit-p' logged"
else
  echo "FAIL (p) join-unsatisfied-blocks broken (rc=$rc flag-exists=$([ -f "$dir/.claude/.pending-review.lp-1" ] && echo yes || echo no) stamp-exists=$([ -f "$dir/.claude/.review-join.unit-p" ] && echo yes || echo no) missing-line=$(grep -c 'marker=MISSING unit=unit-p' "$dir/.claude/review-audit.log" 2>/dev/null || echo 0))"
  fail=1
fi

# (q) join-satisfied-clears: a stamp whose unit holds a format-valid .pass ->
#     exit 0, that stamp consumed, flags cleared, join-consumed logged
dir="$(make_project join-satisfied)"
seed_stamp "$dir" unit-q none -
printf 'PASS unit-q 2026-08-07T12:00:00Z commit: abc123 criteria: bash tests/validate.sh\n' \
  > "$dir/.claude/reviewed/unit-q.pass"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-1" ] \
   && [ ! -e "$dir/.claude/.review-join.unit-q" ] \
   && grep -q 'join-consumed=unit-q' "$dir/.claude/review-audit.log" \
   && grep -q 'cleared-by=reviewer' "$dir/.claude/review-audit.log"; then
  echo "OK   (q) join-satisfied-clears: format-valid .pass for the stamped unit -> exit 0, stamp consumed, flags cleared"
else
  echo "FAIL (q) join-satisfied-clears broken (rc=$rc flag-exists=$([ -e "$dir/.claude/.pending-review.lp-1" ] && echo yes || echo no) stamp-exists=$([ -e "$dir/.claude/.review-join.unit-q" ] && echo yes || echo no) consumed=$(grep -c 'join-consumed=unit-q' "$dir/.claude/review-audit.log" 2>/dev/null || echo 0))"
  fail=1
fi

# (r) join-fail-marker-satisfies: a FAIL verdict is still a verdict
dir="$(make_project join-fail-marker)"
seed_stamp "$dir" unit-r none -
printf 'FAIL unit-r 2026-08-07T12:00:00Z defects: 1) criterion 3 not met\n' \
  > "$dir/.claude/reviewed/unit-r.fail"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-1" ] \
   && [ ! -e "$dir/.claude/.review-join.unit-r" ] \
   && grep -q 'join-consumed=unit-r' "$dir/.claude/review-audit.log"; then
  echo "OK   (r) join-fail-marker-satisfies: a format-valid .fail satisfies the stamp -> exit 0, stamp consumed, flags cleared"
else
  echo "FAIL (r) join-fail-marker-satisfies broken (rc=$rc flag-exists=$([ -e "$dir/.claude/.pending-review.lp-1" ] && echo yes || echo no) stamp-exists=$([ -e "$dir/.claude/.review-join.unit-r" ] && echo yes || echo no))"
  fail=1
fi

# (s) join-zero-byte-marker-rejected: a bare `touch` is not a verdict (the format
#     check mirrors task-gate.sh's marker_valid())
dir="$(make_project join-zero-byte)"
seed_stamp "$dir" unit-s none -
: > "$dir/.claude/reviewed/unit-s.pass"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh 2>/dev/null || rc=$?
if [ "$rc" = 2 ] && [ -f "$dir/.claude/.pending-review.lp-1" ] \
   && [ -f "$dir/.claude/.review-join.unit-s" ] \
   && grep -q 'marker=MISSING unit=unit-s' "$dir/.claude/review-audit.log"; then
  echo "OK   (s) join-zero-byte-marker-rejected: zero-byte marker fails the format check -> exit 2, flags kept"
else
  echo "FAIL (s) join-zero-byte-marker-rejected broken (rc=$rc flag-exists=$([ -f "$dir/.claude/.pending-review.lp-1" ] && echo yes || echo no) stamp-exists=$([ -f "$dir/.claude/.review-join.unit-s" ] && echo yes || echo no))"
  fail=1
fi

# (t) join-restale-marker-blocks: a re-review after FAIL must produce a NEW
#     verdict - the pre-existing .fail the stamp recorded does not satisfy it
dir="$(make_project join-restale)"
printf 'FAIL unit-t 2026-08-07T12:00:00Z defects: 1) criterion 3 not met\n' \
  > "$dir/.claude/reviewed/unit-t.fail"
prior_mtime="$(stat -L --format=%Y "$dir/.claude/reviewed/unit-t.fail")"
seed_stamp "$dir" unit-t fail "$prior_mtime"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh 2>/dev/null || rc=$?
if [ "$rc" = 2 ] && [ -f "$dir/.claude/.pending-review.lp-1" ] \
   && [ -f "$dir/.claude/.review-join.unit-t" ] \
   && grep -q 'marker=MISSING unit=unit-t' "$dir/.claude/review-audit.log"; then
  echo "OK   (t) join-restale-marker-blocks: marker mtime not newer than the recorded prior_mtime -> exit 2, flags kept"
else
  echo "FAIL (t) join-restale-marker-blocks broken (rc=$rc flag-exists=$([ -f "$dir/.claude/.pending-review.lp-1" ] && echo yes || echo no) prior_mtime=$prior_mtime)"
  fail=1
fi

# (u) join-concurrent-liveness (REGRESSION for the bug this unit fixes): two
#     stamps stand, only unit-a holds a verdict. The stop must proceed on the
#     verdict it does have and consume ONLY that stamp - unit-b's review is
#     still owed and its stamp must survive. The old global watermark could not
#     express this: one clear satisfied every concurrent reviewer at once.
dir="$(make_project join-concurrent)"
seed_stamp "$dir" unit-a none -
seed_stamp "$dir" unit-b none -
printf 'PASS unit-a 2026-08-07T12:00:00Z commit: abc123 criteria: bash tests/validate.sh\n' \
  > "$dir/.claude/reviewed/unit-a.pass"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.review-join.unit-a" ] \
   && [ -f "$dir/.claude/.review-join.unit-b" ] \
   && grep -q 'join-consumed=unit-a' "$dir/.claude/review-audit.log" \
   && ! grep -q 'join-consumed=unit-b' "$dir/.claude/review-audit.log"; then
  echo "OK   (u) join-concurrent-liveness: a verdict for unit-a consumes only unit-a's stamp; unit-b's stamp still stands"
else
  echo "FAIL (u) join-concurrent-liveness broken (rc=$rc a-stamp=$([ -e "$dir/.claude/.review-join.unit-a" ] && echo yes || echo no) b-stamp=$([ -f "$dir/.claude/.review-join.unit-b" ] && echo yes || echo no) consumed-a=$(grep -c 'join-consumed=unit-a' "$dir/.claude/review-audit.log" 2>/dev/null || echo 0) consumed-b=$(grep -c 'join-consumed=unit-b' "$dir/.claude/review-audit.log" 2>/dev/null || echo 0))"
  fail=1
fi

# (u2) join-repeat-stop-allowed (REGRESSION for the bug this unit fixes): after a
#      satisfied stop consumed the stamp, a SECOND stop by the same reviewer with
#      no new marker must still be allowed - no stamp remains, so nothing is
#      owed. The global watermark blocked exactly this, stranding a reviewer that
#      legitimately stopped twice.
dir="$(make_project join-repeat-stop)"
seed_stamp "$dir" unit-u none -
printf 'PASS unit-u 2026-08-07T12:00:00Z commit: abc123 criteria: bash tests/validate.sh\n' \
  > "$dir/.claude/reviewed/unit-u.pass"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
first_rc="$rc"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh 2>/dev/null || rc=$?
if [ "$first_rc" = 0 ] && [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-1" ]; then
  echo "OK   (u2) join-repeat-stop-allowed: a second stop with the stamp already consumed -> exit 0 (no unit is owed a verdict)"
else
  echo "FAIL (u2) join-repeat-stop-allowed broken (first-rc=$first_rc second-rc=$rc flag-exists=$([ -e "$dir/.claude/.pending-review.lp-1" ] && echo yes || echo no))"
  fail=1
fi

# (u3) a .blocked marker still short-circuits ahead of the review-join check, so
#      an INSUFFICIENT-CONTEXT verdict keeps the flags standing rather than
#      blocking the reviewer's own stop (preserved from the old case (u))
dir="$(make_project join-blocked-shortcircuit)"
seed_stamp "$dir" unit-x none -
printf 'BLOCKED unit-x 2026-08-07T12:00:00Z missing: constraint Z\n' \
  > "$dir/.claude/reviewed/unit-x.blocked"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh || rc=$?
if [ "$rc" = 0 ] && [ -f "$dir/.claude/.pending-review.lp-1" ] \
   && [ -f "$dir/.claude/.review-join.unit-x" ] \
   && grep -q 'verdict=blocked flags-kept' "$dir/.claude/review-audit.log"; then
  echo "OK   (u3) .blocked short-circuits ahead of the review-join check: exit 0, flags kept, stamp untouched"
else
  echo "FAIL (u3) .blocked short-circuit broken (rc=$rc flag-exists=$([ -f "$dir/.claude/.pending-review.lp-1" ] && echo yes || echo no) stamp-exists=$([ -f "$dir/.claude/.review-join.unit-x" ] && echo yes || echo no))"
  fail=1
fi

# (v) MUTATION CONTROL: stub the review-join check in a throwaway copy so it
#     always sees zero stamps. Both blocking fixtures - join-unsatisfied-blocks
#     and join-zero-byte-marker-rejected - must then stop blocking, or they were
#     never binding on the check in the first place.
mutant_join="$tmproot/mutant-join"
mkdir -p "$mutant_join"
cp hooks/scripts/stop-gate.sh "$mutant_join/stop-gate.sh"
cp -R hooks/scripts/lib "$mutant_join/lib"
join_call='    review_join_state "$dot"'
join_before="$(grep -cxF "$join_call" "$mutant_join/stop-gate.sh" || true)"
sed -i 's/^    review_join_state "\$dot"$/    review_join_state "$dot"; JOIN_STAMP_COUNT=0/' \
  "$mutant_join/stop-gate.sh"
join_after="$(grep -cF 'JOIN_STAMP_COUNT=0' "$mutant_join/stop-gate.sh" || true)"
join_parses=yes
bash -n "$mutant_join/stop-gate.sh" 2>/dev/null || join_parses=no

# join-unsatisfied-blocks against the mutant - must NOT block
dir="$(make_project mutation-join-unsat)"
seed_stamp "$dir" unit-p none -
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
mut_unsat=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash "$mutant_join/stop-gate.sh" 2>/dev/null || mut_unsat=$?
# join-zero-byte-marker-rejected against the mutant - must NOT block
dir="$(make_project mutation-join-zero)"
seed_stamp "$dir" unit-s none -
: > "$dir/.claude/reviewed/unit-s.pass"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
mut_zero=0
printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash "$mutant_join/stop-gate.sh" 2>/dev/null || mut_zero=$?

if [ "${join_before:-0}" = 1 ] && [ "${join_after:-0}" = 1 ] && [ "$join_parses" = yes ] \
   && [ "$mut_unsat" = 0 ] && [ "$mut_zero" = 0 ]; then
  echo "OK   (v) mutation control: with the review-join check stubbed, join-unsatisfied-blocks and join-zero-byte-marker-rejected both stop blocking, so (p) and (s) are binding"
else
  echo "FAIL (v) mutation control: not applied or mutant still blocks (call before=$join_before stub after=$join_after parses=$join_parses unsat-rc=$mut_unsat zero-rc=$mut_zero)"
  fail=1
fi

# (w) Baseline check: grep for marker=MISSING in the hook script is GREEN
if tr '\n' ' ' < hooks/scripts/stop-gate.sh | tr -s ' ' | grep -qF -e 'marker=MISSING'; then
  echo "OK   (w) baseline: 'marker=MISSING' string is present in hooks/scripts/stop-gate.sh"
else
  echo "FAIL (w) baseline: 'marker=MISSING' string NOT found in the script"
  fail=1
fi

exit "$fail"
