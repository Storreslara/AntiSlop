#!/usr/bin/env bash
# Flag resurrection (docs/plans/2026-10-02-escalation-followups.md, unit
# esf-flag-fix): a pending-review flag re-created by a non-gate writer after
# the hook deleted it must block neither turn-end nor the next gated dispatch,
# while a genuine new completion by the same agent still raises a flag.
# Hermetic: mktemp projects, the real entry scripts, canned payloads.
set -euo pipefail
cd "$(dirname "$0")/.."
hooks="${HOOKS_UNDER_TEST:-hooks/scripts}"
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

make_project() {
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"]}\n' > "$dir/.claude/persona-config.json"
  echo "$dir"
}

reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'
main_stop='{"hook_event_name":"Stop","session_id":"main"}'
lp_stop() { jq -cn --arg id "$1" '{hook_event_name:"SubagentStop",agent_type:"lead-programmer",agent_id:$id,session_id:"s1"}'; }
dispatch() {
  # $1 = subagent_type, $2 = prompt -> PreToolUse(Agent) payload from the main session
  jq -cn --arg t "$1" --arg p "$2" '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:"orchestrator",tool_input:{subagent_type:$t,prompt:$p}}'
}

stop_gate()  { local rc=0; printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$hooks/stop-gate.sh" >/dev/null 2>&1 || rc=$?; echo "$rc"; }
route_gate() { local rc=0; printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$hooks/reviewer-route-gate.sh" >/dev/null 2>&1 || rc=$?; echo "$rc"; }

flag_count() {
  shopt -s nullglob
  local flags=( "$1"/.claude/.pending-review.* )
  shopt -u nullglob
  echo "${#flags[@]}"
}

pass_marker() { printf 'PASS %s 2026-10-02T12:00:00Z commit: abc123 criteria: bash tests/validate.sh\n' "$2" > "$1/.claude/reviewed/$2.pass"; }
audit() { cat "$1/.claude/review-audit.log" 2>/dev/null || true; }

# --- (R1) incident replay: bounded clear picks u2's flag by tie-break, the
# orchestrator's defer: re-creates it, and the u2 review must still end at 0.
dir="$(make_project r1)"
d="$dir/.claude"
printf 'gate\n' > "$d/.pending-review.lp-a"
printf 'gate\n' > "$d/.pending-review.lp-b"
printf 'defer: reviewer dispatched for u2\n' > "$d/.pending-review.lp-a"
printf 'defer: reviewer dispatched for u1\n' > "$d/.pending-review.lp-b"
touch -d '2026-10-02 17:14:01' "$d/.pending-review.lp-a" "$d/.pending-review.lp-b"
rc_d1="$(route_gate "$dir" "$(dispatch reviewer 'Unit: u1')")"
pass_marker "$dir" u1
rc_s1="$(stop_gate "$dir" "$reviewer_stop")"
after_u1="$(flag_count "$dir")"
deleted=""
for id in lp-a lp-b; do [ -f "$d/.pending-review.$id" ] || deleted="$id"; done
[ -n "$deleted" ] && printf 'defer: reviewer dispatched for whichever\n' > "$d/.pending-review.$deleted"
rc_d2="$(route_gate "$dir" "$(dispatch reviewer 'Unit: u2')")"
pass_marker "$dir" u2
rc_s2="$(stop_gate "$dir" "$reviewer_stop")"
last_clear="$(audit "$dir" | grep 'cleared-by=reviewer' | tail -n 1 || true)"
if [ "$rc_d1$rc_s1$rc_d2$rc_s2" = 0000 ] && [ "$after_u1" = 1 ] && [ -n "$deleted" ] \
   && [ "$(flag_count "$dir")" = 0 ] \
   && audit "$dir" | grep -q 'flag-resurrected-dropped=' \
   && [[ $last_clear == *"remaining=0" ]]; then
  ok "(R1) incident replay ends with 0 flags, a dropped-resurrection line and remaining=0"
else
  bad "(R1) incident replay: rcs=$rc_d1$rc_s1$rc_d2$rc_s2 after_u1=$after_u1 deleted=$deleted flags=$(flag_count "$dir") last='$last_clear'"
fi

# --- (R2) route gate: only a resurrected flag stands -> lead dispatch passes.
dir="$(make_project r2)"
printf 'gate\n' > "$dir/.claude/.pending-review.lp-a"
rc_r="$(stop_gate "$dir" "$reviewer_stop")"
printf 'defer: resurrected\n' > "$dir/.claude/.pending-review.lp-a"
rc="$(route_gate "$dir" "$(dispatch lead-programmer 'next unit')")"
if [ "$rc_r" = 0 ] && [ "$rc" = 0 ] && [ "$(flag_count "$dir")" = 0 ]; then
  ok "(R2) a resurrected flag alone does not block the next gated dispatch"
else
  bad "(R2) expected rc 0 and 0 flags (reviewer rc=$rc_r dispatch rc=$rc flags=$(flag_count "$dir"))"
fi

# --- (R3a) re-arm: a tombstoned id completes again -> flag raised, tombstone gone.
dir="$(make_project r3a)"
printf 'gate\n' > "$dir/.claude/.pending-review.lp-a"
stop_gate "$dir" "$reviewer_stop" >/dev/null
tomb_before=false; [ -f "$dir/.claude/.pending-review-cleared.lp-a" ] && tomb_before=true
rc_lp="$(stop_gate "$dir" "$(lp_stop lp-a)")"
content="$(cat "$dir/.claude/.pending-review.lp-a" 2>/dev/null || true)"
rc_main="$(stop_gate "$dir" "$main_stop")"
if [ "$tomb_before" = true ] && [ "$rc_lp" = 0 ] && [[ $content == *" agent=lp-a" ]] \
   && [ ! -f "$dir/.claude/.pending-review-cleared.lp-a" ] && [ "$rc_main" = 2 ]; then
  ok "(R3a) a resumed agent's genuine completion re-arms its flag and main Stop blocks"
else
  bad "(R3a) tomb_before=$tomb_before lp rc=$rc_lp content='$content' main rc=$rc_main"
fi

# --- (R3b) as R3a, but a resurrecting defer: was written before the stop.
dir="$(make_project r3b)"
printf 'gate\n' > "$dir/.claude/.pending-review.lp-a"
stop_gate "$dir" "$reviewer_stop" >/dev/null
printf 'defer: resurrected\n' > "$dir/.claude/.pending-review.lp-a"
rc_lp="$(stop_gate "$dir" "$(lp_stop lp-a)")"
content="$(cat "$dir/.claude/.pending-review.lp-a" 2>/dev/null || true)"
rc_main="$(stop_gate "$dir" "$main_stop")"
if [ "$rc_lp" = 0 ] && [[ $content == *" agent=lp-a" ]] \
   && [ ! -f "$dir/.claude/.pending-review-cleared.lp-a" ] && [ "$rc_main" = 2 ] \
   && [ -f "$dir/.claude/.pending-review.lp-a" ]; then
  ok "(R3b) a genuine completion overwrites a resurrected defer: and stays owed"
else
  bad "(R3b) lp rc=$rc_lp content='$content' main rc=$rc_main"
fi

# --- (R4) skip then defer: the skip tombstones, the later defer: is dropped.
dir="$(make_project r4)"
printf 'skip: abandoned for the test\n' > "$dir/.claude/.pending-review.lp-a"
rc1="$(stop_gate "$dir" "$main_stop")"
tomb=false; [ -f "$dir/.claude/.pending-review-cleared.lp-a" ] && tomb=true
printf 'defer: written after the skip\n' > "$dir/.claude/.pending-review.lp-a"
rc2="$(stop_gate "$dir" "$main_stop")"
if [ "$rc1" = 0 ] && [ "$tomb" = true ] && [ "$rc2" = 0 ] && [ "$(flag_count "$dir")" = 0 ] \
   && audit "$dir" | grep -q 'flag-resurrected-dropped=lp-a'; then
  ok "(R4) a defer: written after a honoured skip: is dropped on the next Stop"
else
  bad "(R4) rc1=$rc1 tomb=$tomb rc2=$rc2 flags=$(flag_count "$dir")"
fi

# --- (R5) bootstrap: zero stamps, two flags -> both cleared and tombstoned.
dir="$(make_project r5)"
printf 'gate\n' > "$dir/.claude/.pending-review.lp-a"
printf 'gate\n' > "$dir/.claude/.pending-review.lp-b"
rc="$(stop_gate "$dir" "$reviewer_stop")"
if [ "$rc" = 0 ] && [ "$(flag_count "$dir")" = 0 ] \
   && [ -f "$dir/.claude/.pending-review-cleared.lp-a" ] && [ -f "$dir/.claude/.pending-review-cleared.lp-b" ] \
   && audit "$dir" | grep -q 'marker-check=bootstrap'; then
  ok "(R5) the bootstrap clear-all tombstones every flag it deletes"
else
  bad "(R5) rc=$rc flags=$(flag_count "$dir")"
fi

# --- (R6) live defer is unchanged: no tombstone -> sticky, still blocks dispatch.
dir="$(make_project r6)"
printf 'defer: review owed for u6\n' > "$dir/.claude/.pending-review.lp-a"
rc_main="$(stop_gate "$dir" "$main_stop")"
rc_disp="$(route_gate "$dir" "$(dispatch lead-programmer 'next unit')")"
if [ "$rc_main" = 0 ] && [ -f "$dir/.claude/.pending-review.lp-a" ] && [ "$rc_disp" = 2 ] \
   && ! audit "$dir" | grep -q 'flag-resurrected-dropped='; then
  ok "(R6) a live defer: with no tombstone stays sticky and still blocks the next gated dispatch"
else
  bad "(R6) main rc=$rc_main dispatch rc=$rc_disp"
fi

# --- (R7) a tombstone alone is ignored by every flag glob.
dir="$(make_project r7)"
printf '2026-10-02T12:00:00Z\n' > "$dir/.claude/.pending-review-cleared.lp-a"
rc_main="$(stop_gate "$dir" "$main_stop")"
rc_expl="$(stop_gate "$dir" '{"hook_event_name":"SubagentStop","agent_type":"explorer","agent_id":"ex-1","session_id":"s1"}')"
rc_disp="$(route_gate "$dir" "$(dispatch lead-programmer 'next unit')")"
shopt -s nullglob; stamps=( "$dir"/.claude/.review-join.* ); shopt -u nullglob
if [ "$rc_main" = 0 ] && [ "$rc_expl" = 0 ] && [ "$rc_disp" = 0 ] && [ "${#stamps[@]}" = 0 ] \
   && ! audit "$dir" | grep -q 'grant-denied' && ! audit "$dir" | grep -q 'join' \
   && [ -f "$dir/.claude/.pending-review-cleared.lp-a" ]; then
  ok "(R7) a tombstone alone triggers no block, no grant-denied line and no join effect"
else
  bad "(R7) main rc=$rc_main explorer rc=$rc_expl dispatch rc=$rc_disp stamps=${#stamps[@]}"
fi

exit "$fail"
