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
want='defer: reviewer already dispatched|cleared-by=reviewer|defer: reviewer already dispatched|'
if [ "$ok" = true ] && [ "$got" = "$want" ]; then
  echo "OK   (h) an identical defer: after an intervening log line is still appended"
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

exit "$fail"
