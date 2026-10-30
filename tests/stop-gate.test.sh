#!/usr/bin/env bash
# Behavioural suite for hooks/scripts/stop-gate.sh: the pending-review flag check plus the
# writer-dispatch marker check. Canned payloads over stdin, one mktemp project per case.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

hook=hooks/scripts/stop-gate.sh
r=revi; r="${r}ewed"

ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1"; fail=1; }

project() {
  # $1 = case name, $2 = reviewGating.mode
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/$r"
  printf '{"gatedAgents":["lead-programmer"],"reviewGating":{"mode":"%s"}}\n' "$2" \
    > "$dir/.claude/persona-config.json"
  echo "$dir"
}

run() {
  # $1 = project dir, $2 = payload -> sets $rc and $err
  rc=0
  err="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$hook" 2>&1 >/dev/null)" || rc=$?
}

lp='{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","agent_id":"lp-1","session_id":"s1"}'
rv='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rv-1","session_id":"s1"}'
ex='{"hook_event_name":"SubagentStop","agent_type":"explorer","agent_id":"ex-1","session_id":"s1"}'
main='{"hook_event_name":"Stop","session_id":"s1"}'
main_active='{"hook_event_name":"Stop","session_id":"s1","stop_hook_active":true}'

# (a) a gated writer's stop writes a flag
d="$(project a enforce)"
run "$d" "$lp"
if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp-1" ]; then ok "(a) writer stop writes the flag"
else bad "(a) writer stop: rc=$rc flag=$(ls -A "$d/.claude")"; fi

# (b) a reviewer stop clears it
run "$d" "$rv"
if [ "$rc" = 0 ] && [ ! -e "$d/.claude/.pending-review.lp-1" ]; then ok "(b) reviewer stop clears the flag"
else bad "(b) reviewer stop: rc=$rc"; fi

# (c) the main Stop blocks while a flag stands
d="$(project c enforce)"
printf 'x agent=lp-1\n' > "$d/.claude/.pending-review.lp-1"
run "$d" "$main"
if [ "$rc" = 2 ] && grep -q 'awaiting review' <<< "$err"; then ok "(c) main Stop blocks with a flag"
else bad "(c) main Stop: rc=$rc err=$err"; fi

# (d) a skip: flag does not block and is deleted; a defer: flag does not block and stays
d="$(project d enforce)"
printf 'skip: abandoned\n' > "$d/.claude/.pending-review.lp-1"
printf 'defer: later\n' > "$d/.claude/.pending-review.lp-2"
run "$d" "$main"
if [ "$rc" = 0 ] && [ ! -e "$d/.claude/.pending-review.lp-1" ] && [ -f "$d/.claude/.pending-review.lp-2" ]; then
  ok "(d) skip:/defer: flags do not block"
else bad "(d) skip/defer: rc=$rc err=$err"; fi

# (e) mode off never blocks and writes no flag
d="$(project e off)"
printf 'x agent=lp-9\n' > "$d/.claude/.pending-review.lp-9"
touch -d '2026-01-01 00:00:00' "$d/.claude/$r/.writer-dispatch-stamp"
printf 'PASS u1 x\n' > "$d/.claude/$r/u1.pass"; touch -d '2026-01-02 00:00:00' "$d/.claude/$r/u1.pass"
run "$d" "$main"; rc_main="$rc"
run "$d" "$lp"
if [ "$rc_main" = 0 ] && [ "$rc" = 0 ] && [ ! -e "$d/.claude/.pending-review.lp-1" ]; then ok "(e) mode off never blocks"
else bad "(e) mode off: main=$rc_main writer=$rc"; fi

# (f) a .pass newer than the stamp blocks the writer stop and names the file
d="$(project f enforce)"
touch -d '2026-01-01 00:00:00' "$d/.claude/$r/.writer-dispatch-stamp"
printf 'PASS u1 x\n' > "$d/.claude/$r/u1.pass"; touch -d '2026-01-02 00:00:00' "$d/.claude/$r/u1.pass"
run "$d" "$lp"
if [ "$rc" = 2 ] && grep -q 'u1\.pass' <<< "$err" && [ -f "$d/.claude/.pending-review.lp-1" ]; then
  ok "(f) newer .pass blocks the writer stop, names it and still writes the flag"
else bad "(f) newer .pass: rc=$rc err=$err"; fi

# (g) an older .pass does not block
d="$(project g enforce)"
touch -d '2026-01-02 00:00:00' "$d/.claude/$r/.writer-dispatch-stamp"
printf 'PASS u1 x\n' > "$d/.claude/$r/u1.pass"; touch -d '2026-01-01 00:00:00' "$d/.claude/$r/u1.pass"
run "$d" "$lp"
if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp-1" ]; then ok "(g) older .pass does not block"
else bad "(g) older .pass: rc=$rc err=$err"; fi

# (h) a WIP sentinel stop writes no flag
d="$(project h enforce)"
printf 'TDD red phase\n' > "$d/.claude/wip-handoff.lp-1"
run "$d" "$lp"
if [ "$rc" = 0 ] && [ ! -e "$d/.claude/.pending-review.lp-1" ] && [ ! -e "$d/.claude/wip-handoff.lp-1" ] \
   && grep -q 'reason=TDD red phase' "$d/.claude/wip-audit.log"; then ok "(h) WIP sentinel stop writes no flag"
else bad "(h) WIP sentinel: rc=$rc"; fi

# (i) a missing stamp does not block
d="$(project i enforce)"
printf 'FAIL u1 x\n' > "$d/.claude/$r/u1.fail"
run "$d" "$lp"
if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp-1" ]; then ok "(i) missing stamp does not block"
else bad "(i) missing stamp: rc=$rc err=$err"; fi

# (j) stop_hook_active exits 0
d="$(project j enforce)"
printf 'x agent=lp-1\n' > "$d/.claude/.pending-review.lp-1"
run "$d" "$main_active"
if [ "$rc" = 0 ]; then ok "(j) stop_hook_active exits 0"
else bad "(j) stop_hook_active: rc=$rc"; fi

# (k) a non-gated agent's SubagentStop writes no flag
d="$(project k enforce)"
run "$d" "$ex"
if [ "$rc" = 0 ] && ! ls -A "$d/.claude" | grep -q '^\.pending-review\.'; then ok "(k) non-gated stop writes no flag"
else bad "(k) non-gated stop: rc=$rc"; fi

# (l) a reviewer stop clears the flag even when a .blocked marker stands (user decision G1)
d="$(project l enforce)"
printf 'x agent=lp-1\n' > "$d/.claude/.pending-review.lp-1"
printf 'BLOCKED u1 x\n' > "$d/.claude/$r/u1.blocked"
run "$d" "$rv"
if [ "$rc" = 0 ] && [ ! -e "$d/.claude/.pending-review.lp-1" ]; then ok "(l) reviewer stop clears the flag despite .blocked"
else bad "(l) .blocked reviewer stop: rc=$rc"; fi

# (m) a blocked writer stop leaves a flag; the loop-guarded retry is allowed and the main Stop blocks
d="$(project m enforce)"
touch -d '2026-01-01 00:00:00' "$d/.claude/$r/.writer-dispatch-stamp"
printf 'PASS u1 x\n' > "$d/.claude/$r/u1.pass"; touch -d '2026-01-02 00:00:00' "$d/.claude/$r/u1.pass"
run "$d" "$lp"; rc_lp="$rc"
run "$d" "${lp%\}},\"stop_hook_active\":true}"; rc_retry="$rc"
run "$d" "$main"; rc_main="$rc"
if [ "$rc_lp" = 2 ] && [ "$rc_retry" = 0 ] && [ "$rc_main" = 2 ] && [ -f "$d/.claude/.pending-review.lp-1" ]; then
  ok "(m) blocked writer stop leaves a flag the main Stop blocks on"
else bad "(m) blocked writer stop: lp=$rc_lp retry=$rc_retry main=$rc_main"; fi

exit "$fail"
