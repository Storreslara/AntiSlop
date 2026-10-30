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

main_stop='{"hook_event_name":"Stop","session_id":"main"}'
dispatch() {
  # $1 = subagent_type, $2 = prompt -> PreToolUse(Agent) payload from the main session
  jq -cn --arg t "$1" --arg p "$2" '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:"orchestrator",tool_input:{subagent_type:$t,prompt:$p}}'
}

stop_gate()  { local rc=0; printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$hooks/stop-gate.sh" >/dev/null 2>&1 || rc=$?; echo "$rc"; }
route_gate() { local rc=0; printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$hooks/reviewer-route-gate.sh" >/dev/null 2>&1 || rc=$?; echo "$rc"; }

audit() { cat "$1/.claude/review-audit.log" 2>/dev/null || true; }

# (R1)-(R5) drove the stop gate's tombstones and bounded clear, which
# lp-stopgate removed; the route-gate cases below remain until lp-joinstamp.

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
