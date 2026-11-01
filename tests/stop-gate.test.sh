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

# rv-stopgate: a writer whose dispatch-lane record is small (D3) leaves no flag; every miss writes one.
# lane_case <name> <mode> <record lane> <record prompt: same|other> -> sets $d and $lpt (payload)
lane_case() {
  d="$(project "$1" "$2")"
  local prompt=$'Unit: u1\n\n## Objective\nx' ph
  ph="$(printf '%s' "$prompt" | sha256sum | cut -d' ' -f1)"
  [ "$4" = same ] || ph="$(printf 'other' | sha256sum | cut -d' ' -f1)"
  jq -cn --arg c "$prompt" '{type:"user",message:{role:"user",content:$c}}' > "$d/agent-lp-1.jsonl"
  printf '{"agentType":"lead-programmer","toolUseId":"toolu_01AbC"}\n' > "$d/agent-lp-1.meta.json"
  printf '2026-11-01T00:00:00Z tool_use_id=toolu_01AbC prompt=%s unit=u1 lane=%s\n' "$ph" "$3" \
    > "$d/.claude/$r/dispatch-lane.log"
  lpt="${lp%\}},\"agent_transcript_path\":\"$d/agent-lp-1.jsonl\"}"
}

lane_case s1 enforce small same
run "$d" "$lpt"
if [ "$rc" = 0 ] && [ ! -e "$d/.claude/.pending-review.lp-1" ] \
  && grep -qE '^[0-9TZ:-]+ small-lane agent=lp-1 no-flag$' "$d/.claude/review-audit.log"; then
  ok "(rv-s1) small-lane writer stop writes no flag and logs it"
else bad "(rv-s1) small-lane stop: rc=$rc files=$(ls -A "$d/.claude")"; fi

lane_case s2 enforce small same
touch -d '2026-01-01 00:00:00' "$d/.claude/$r/.writer-dispatch-stamp"
printf 'PASS u1 x\n' > "$d/.claude/$r/u1.pass"; touch -d '2026-01-02 00:00:00' "$d/.claude/$r/u1.pass"
run "$d" "$lpt"
if [ "$rc" = 2 ] && grep -q 'u1\.pass' <<< "$err"; then ok "(rv-s2) small-lane stop still runs the D6 marker check"
else bad "(rv-s2) small-lane D6: rc=$rc err=$err"; fi

lane_case s3 enforce medium same
run "$d" "$lpt"
if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp-1" ]; then ok "(rv-s3) medium-lane writer stop writes the flag"
else bad "(rv-s3) medium-lane stop: rc=$rc"; fi

lane_case s4 enforce small other
run "$d" "$lpt"
if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp-1" ]; then ok "(rv-s4) prompt-hash mismatch writes the flag"
else bad "(rv-s4) hash mismatch: rc=$rc"; fi

lane_case s5 enforce small same
rm -f "$d/agent-lp-1.jsonl"
run "$d" "$lpt"
if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp-1" ]; then ok "(rv-s5) no transcript writes the flag"
else bad "(rv-s5) no transcript: rc=$rc"; fi

lane_case s6 off small same
run "$d" "$lpt"
if [ "$rc" = 0 ] && ! ls -A "$d/.claude" | grep -q '^\.pending-review\.'; then ok "(rv-s6) mode off: rc 0 and no flag"
else bad "(rv-s6) mode off: rc=$rc"; fi

# rv-mainstop: a review-dispatched flag lets the main Stop through; the block text names the bookkeeping tool.
d="$(project m1 enforce)"
printf 'review-dispatched: u1\n' > "$d/.claude/.pending-review.lp-1"
run "$d" "$main"
if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp-1" ] && [ ! -e "$d/.claude/review-audit.log" ]; then
  ok "(rv-m1) review-dispatched flag lets the main Stop through, kept, unlogged"
else bad "(rv-m1) review-dispatched: rc=$rc err=$err"; fi

printf 'x agent=lp-2\n' > "$d/.claude/.pending-review.lp-2"
run "$d" "$main"
if [ "$rc" = 2 ] && grep -q 'awaiting review' <<< "$err"; then ok "(rv-m2) a plain flag still blocks beside a review-dispatched one"
else bad "(rv-m2) plain flag: rc=$rc err=$err"; fi

d="$(project m3 enforce)"
mkdir -p "$d/.claude/bin"; : > "$d/.claude/bin/unit-bookkeeping.sh"
printf 'x agent=lp-1\n' > "$d/.claude/.pending-review.lp-1"
run "$d" "$main"
if [ "$rc" = 2 ] && grep -q 'bash .claude/bin/unit-bookkeeping.sh flag <defer|skip> <reason>' <<< "$err" \
   && ! grep -q 'printf' <<< "$err"; then ok "(rv-m3) script present: block text names unit-bookkeeping.sh flag, no printf"
else bad "(rv-m3) script present: rc=$rc err=$err"; fi

d="$(project m4 enforce)"
printf 'x agent=lp-1\n' > "$d/.claude/.pending-review.lp-1"
run "$d" "$main"
if [ "$rc" = 2 ] && grep -q 'printf "defer|skip: <reason>' <<< "$err" && ! grep -q 'unit-bookkeeping' <<< "$err"; then
  ok "(rv-m4) script absent: old block text"
else bad "(rv-m4) script absent: rc=$rc err=$err"; fi

lane_case m5 enforce small same
touch -d '2026-01-01 00:00:00' "$d/.claude/$r/.writer-dispatch-stamp"
printf 'PASS u1 x\n' > "$d/.claude/$r/u1.pass"; touch -d '2026-01-02 00:00:00' "$d/.claude/$r/u1.pass"
run "$d" "$lpt"; rc_lp="$rc"
run "$d" "$main"; rc_main="$rc"
if [ "$rc_lp" = 2 ] && [ "$rc_main" = 2 ] && [ -f "$d/.claude/.pending-review.lp-1" ] \
   && grep -qE '^[0-9TZ:-]+ small-lane d6-trip agent=lp-1 flag$' "$d/.claude/review-audit.log" \
   && ! grep -q 'no-flag' "$d/.claude/review-audit.log"; then
  ok "(rv-m5) small-lane D6 trip writes the flag and logs d6-trip"
else bad "(rv-m5) small D6 trip: lp=$rc_lp main=$rc_main"; fi

# rv-flagprose: the prose names the flag channel and the small-lane route, on the source and deployed copy.
sq() { tr -s ' \n' ' ' < "$1" | grep -qF -- "$2"; }
pin() { # $1 = id, $2 = phrase, $3.. = files
  local id="$1" ph="$2" f; shift 2; local miss=""
  for f in "$@"; do sq "$f" "$ph" || miss="$miss $f"; done
  if [ -z "$miss" ]; then ok "($id) prose pin"; else bad "($id) missing in:$miss"; fi
}
pin rv-p1 'marks open flags `review-dispatched:`, so your turn may end' agents/orchestrator.md .claude/agents/orchestrator.md
pin rv-p2 'unit-bookkeeping.sh flag' templates/persona-protocol.md .claude/agents/lead-programmer.md
pin rv-p3 'unit-bookkeeping.sh flag' templates/protocol-digest.md .claude/protocol-digest.md
pin rv-p4 'a small unit gets `check`, see "Lane routing")' agents/orchestrator.md .claude/agents/orchestrator.md
pin rv-p5 "flag left by its writer's stop (it overrides" agents/orchestrator.md .claude/agents/orchestrator.md

exit "$fail"
