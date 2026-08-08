#!/usr/bin/env bash
# Fixture-driven test for reviewer-route-gate.sh's per-unit review-join
# stamp block (issue #262 / spec Step 1:
# docs/plans/2026-08-07-per-unit-review-join.md). Canned PreToolUse(Agent)
# hook-input JSON piped to the real script - no real claude/agent dependency.
# Six fixture names below are mandatory literal strings per the spec's own
# acceptance criteria; route-gate-never-blocks re-runs all five other
# payloads and asserts exit 0 across the board.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  # $1 = case name -> echoes a fresh project dir seeded with persona-config.json
  # and an empty reviewer-owned marker directory (never the real repo tree).
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"]}\n' > "$dir/.claude/persona-config.json"
  echo "$dir"
}

reviewer_payload() {
  # $1 = prompt text -> PreToolUse(Agent) payload targeting the reviewer
  jq -n --arg p "$1" '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:"orchestrator",tool_input:{subagent_type:"reviewer",prompt:$p}}'
}

lp_payload() {
  # $1 = prompt text -> PreToolUse(Agent) payload targeting lead-programmer (non-reviewer)
  jq -n --arg p "$1" '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:"orchestrator",tool_input:{subagent_type:"lead-programmer",prompt:$p}}'
}

run_route_gate() {
  # $1 = project dir, $2 = JSON payload -> runs the real hook, returns its rc
  local rc=0
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/reviewer-route-gate.sh || rc=$?
  return "$rc"
}

stamp_count() {
  # $1 = project dir -> number of .claude/.review-join.* stamp files present
  local dir="$1"
  shopt -s nullglob
  local stamps=( "$dir"/.claude/.review-join.* )
  shopt -u nullglob
  echo "${#stamps[@]}"
}

# --- route-gate-stamps-unit: valid "Unit: <id>" first line + reviewer target, no prior marker -> stamp written ---
dir="$(make_project stamps-unit)"
payload1="$(reviewer_payload $'Unit: 300\n\nReview this commit.')"
rc=0
run_route_gate "$dir" "$payload1" || rc=$?
stamp="$dir/.claude/.review-join.300"
if [ "$rc" = 0 ] && [ -f "$stamp" ] \
   && grep -qE '^[0-9TZ:-]+ unit=300 prior=none prior_mtime=-$' "$stamp" \
   && grep -q '^review-join=300$' "$dir/.claude/review-audit.log"; then
  echo "OK   (route-gate-stamps-unit) valid Unit line + reviewer target -> stamp written + audit logged"
else
  echo "FAIL (route-gate-stamps-unit) stamp/audit content wrong or missing (rc=$rc)"
  fail=1
fi

# --- route-gate-no-unit-line-no-stamp: first non-blank line is not "Unit: <id>" -> no stamp, exit 0 ---
dir="$(make_project no-unit-line)"
payload2="$(reviewer_payload $'Please review the recent diff.')"
rc=0
run_route_gate "$dir" "$payload2" || rc=$?
if [ "$rc" = 0 ] && [ "$(stamp_count "$dir")" = 0 ]; then
  echo "OK   (route-gate-no-unit-line-no-stamp) no Unit line -> no stamp, exit 0"
else
  echo "FAIL (route-gate-no-unit-line-no-stamp) unexpected stamp or nonzero exit (rc=$rc)"
  fail=1
fi

# --- route-gate-existing-pass-no-stamp: a format-valid PASS marker already exists for the unit -> no stamp ---
dir="$(make_project existing-pass)"
printf 'PASS 301 2026-08-07T00:00:00Z commit: abc1234 criteria: true\n' > "$dir/.claude/reviewed/301.pass"
payload3="$(reviewer_payload $'Unit: 301\n\nSecond look.')"
rc=0
run_route_gate "$dir" "$payload3" || rc=$?
if [ "$rc" = 0 ] && [ "$(stamp_count "$dir")" = 0 ]; then
  echo "OK   (route-gate-existing-pass-no-stamp) format-valid PASS marker already exists -> no stamp"
else
  echo "FAIL (route-gate-existing-pass-no-stamp) unexpected stamp or nonzero exit (rc=$rc)"
  fail=1
fi

# --- route-gate-existing-fail-stamps: a FAIL marker exists (does NOT exempt) -> stamp written with prior=fail ---
dir="$(make_project existing-fail)"
printf 'FAIL 302 2026-08-07T00:00:00Z\n- some defect\n' > "$dir/.claude/reviewed/302.fail"
fail_mtime="$(stat -L --format=%Y "$dir/.claude/reviewed/302.fail" 2>/dev/null || date +%s)"
payload4="$(reviewer_payload $'Unit: 302\n\nRe-review after fix.')"
rc=0
run_route_gate "$dir" "$payload4" || rc=$?
stamp="$dir/.claude/.review-join.302"
if [ "$rc" = 0 ] && [ -f "$stamp" ] \
   && grep -qE "^[0-9TZ:-]+ unit=302 prior=fail prior_mtime=${fail_mtime}\$" "$stamp"; then
  echo "OK   (route-gate-existing-fail-stamps) prior FAIL marker does not exempt -> stamp written, prior=fail"
else
  echo "FAIL (route-gate-existing-fail-stamps) stamp missing or prior/prior_mtime wrong (rc=$rc)"
  fail=1
fi

# --- route-gate-non-reviewer-target-no-stamp: valid Unit line but target is NOT reviewer -> no stamp ---
dir="$(make_project non-reviewer-target)"
payload5="$(lp_payload $'Unit: 303\n\nImplement this.')"
rc=0
run_route_gate "$dir" "$payload5" || rc=$?
if [ "$rc" = 0 ] && [ "$(stamp_count "$dir")" = 0 ]; then
  echo "OK   (route-gate-non-reviewer-target-no-stamp) non-reviewer target -> no stamp, exit 0"
else
  echo "FAIL (route-gate-non-reviewer-target-no-stamp) unexpected stamp or nonzero exit (rc=$rc)"
  fail=1
fi

# --- route-gate-never-blocks: re-run all five payloads above (fresh project dirs); assert exit 0 across the board ---
never_blocks_fail=0
d1="$(make_project nb-1)"; rc=0; run_route_gate "$d1" "$payload1" || rc=$?; [ "$rc" = 0 ] || never_blocks_fail=1
d2="$(make_project nb-2)"; rc=0; run_route_gate "$d2" "$payload2" || rc=$?; [ "$rc" = 0 ] || never_blocks_fail=1
d3="$(make_project nb-3)"; printf 'PASS 301 2026-08-07T00:00:00Z commit: abc1234 criteria: true\n' > "$d3/.claude/reviewed/301.pass"; rc=0; run_route_gate "$d3" "$payload3" || rc=$?; [ "$rc" = 0 ] || never_blocks_fail=1
d4="$(make_project nb-4)"; printf 'FAIL 302 2026-08-07T00:00:00Z\n- some defect\n' > "$d4/.claude/reviewed/302.fail"; rc=0; run_route_gate "$d4" "$payload4" || rc=$?; [ "$rc" = 0 ] || never_blocks_fail=1
d5="$(make_project nb-5)"; rc=0; run_route_gate "$d5" "$payload5" || rc=$?; [ "$rc" = 0 ] || never_blocks_fail=1
if [ "$never_blocks_fail" = 0 ]; then
  echo "OK   (route-gate-never-blocks) all five other fixtures payloads exit 0 - writing a stamp never blocks"
else
  echo "FAIL (route-gate-never-blocks) at least one payload exited nonzero"
  fail=1
fi

# ============================================================================
# ADAPTER PORTS (spec Step 3). The Claude route-gate reads the dispatch prompt
# from `.tool_input.prompt` on a PreToolUse(Agent) payload. Neither adapter
# platform documents a prompt field on its subagent-start event, so both ports
# read a FALLBACK CHAIN (.prompt // .instructions // .task) and simply write no
# stamp when none of them carries a "Unit:" line - see each port's header. These
# fixtures drive that code path with the prompt present, which is what the chain
# would see IF a platform supplies it, plus the absent case and the never-blocks
# invariant that must hold either way.
# ============================================================================

adapter_dot()    { case "$1" in codex) echo .codex ;; cursor) echo .cursor ;; esac; }
adapter_script() { echo "adapters/$1/hooks/scripts/reviewer-route-gate.sh"; }

adapter_project() {
  # $1 = port, $2 = case name -> fresh project dir with that port's config
  local dot dir
  dot="$(adapter_dot "$1")"
  dir="$tmproot/$1-$2"
  mkdir -p "$dir/$dot/reviewed"
  printf '{"gatedAgents":["lead-programmer"]}\n' > "$dir/$dot/persona-config.json"
  echo "$dir"
}

adapter_payload() {
  # $1 = port, $2 = project dir, $3 = target type, $4 = prompt text
  case "$1" in
    codex)
      jq -n --arg d "$2" --arg t "$3" --arg p "$4" \
        '{hook_event_name:"SubagentStart",agent_type:$t,agent_id:"rev-1",cwd:$d,prompt:$p}' ;;
    cursor)
      jq -n --arg d "$2" --arg t "$3" --arg p "$4" \
        '{hook_event_name:"subagentStart",subagent_type:$t,workspace_roots:[$d],prompt:$p}' ;;
  esac
}

adapter_stamp_count() {
  # $1 = project dir, $2 = port
  local dot stamps
  dot="$(adapter_dot "$2")"
  shopt -s nullglob
  stamps=( "$1/$dot"/.review-join.* )
  shopt -u nullglob
  echo "${#stamps[@]}"
}

adapter_never_blocked=true

for port in codex cursor; do
  dot="$(adapter_dot "$port")"

  # --- adapter-route-gate-stamps-unit: Unit line + reviewer target -> stamp written ---
  dir="$(adapter_project "$port" stamps-unit)"
  payload="$(adapter_payload "$port" "$dir" reviewer $'Unit: 300\n\nReview this commit.')"
  rc=0
  printf '%s' "$payload" | bash "$(adapter_script "$port")" || rc=$?
  [ "$rc" = 0 ] || adapter_never_blocked=false
  stamp="$dir/$dot/.review-join.300"
  if [ "$rc" = 0 ] && [ -f "$stamp" ] \
     && grep -qE '^[0-9TZ:-]+ unit=300 prior=none prior_mtime=-$' "$stamp" \
     && grep -q '^review-join=300$' "$dir/$dot/review-audit.log"; then
    echo "OK   (adapter-route-gate-stamps-unit) $port: Unit line + reviewer target -> stamp written + audit logged"
  else
    echo "FAIL (adapter-route-gate-stamps-unit) $port: stamp/audit content wrong or missing (rc=$rc)"
    fail=1
  fi

  # --- adapter-route-gate-existing-pass-no-stamp: a format-valid PASS already exists -> no stamp ---
  dir="$(adapter_project "$port" existing-pass)"
  printf 'PASS 301 2026-08-07T12:00:00Z commit: abc criteria: bash tests/validate.sh\n' \
    > "$dir/$dot/reviewed/301.pass"
  payload="$(adapter_payload "$port" "$dir" reviewer $'Unit: 301\n\nRe-review.')"
  rc=0
  printf '%s' "$payload" | bash "$(adapter_script "$port")" || rc=$?
  [ "$rc" = 0 ] || adapter_never_blocked=false
  if [ "$rc" = 0 ] && [ "$(adapter_stamp_count "$dir" "$port")" = 0 ]; then
    echo "OK   (adapter-route-gate-existing-pass-no-stamp) $port: unit already holds a valid PASS -> no stamp"
  else
    echo "FAIL (adapter-route-gate-existing-pass-no-stamp) $port: unexpected stamp or nonzero exit (rc=$rc)"
    fail=1
  fi

  # --- adapter-route-gate-no-unit-line-no-stamp: no Unit line (also the shape a
  #     platform that supplies no prompt at all produces) -> no stamp, exit 0 ---
  dir="$(adapter_project "$port" no-unit-line)"
  payload="$(adapter_payload "$port" "$dir" reviewer $'Please review the latest commit.\n')"
  rc=0
  printf '%s' "$payload" | bash "$(adapter_script "$port")" || rc=$?
  [ "$rc" = 0 ] || adapter_never_blocked=false
  if [ "$rc" = 0 ] && [ "$(adapter_stamp_count "$dir" "$port")" = 0 ]; then
    echo "OK   (adapter-route-gate-no-unit-line-no-stamp) $port: no Unit line -> no stamp, exit 0"
  else
    echo "FAIL (adapter-route-gate-no-unit-line-no-stamp) $port: unexpected stamp or nonzero exit (rc=$rc)"
    fail=1
  fi

  # --- adapter-route-gate-absent-prompt-no-stamp: the degraded case this port
  #     actually expects on an unprobed platform - NO prompt field at all ---
  dir="$(adapter_project "$port" absent-prompt)"
  case "$port" in
    codex)  payload="$(jq -n --arg d "$dir" '{hook_event_name:"SubagentStart",agent_type:"reviewer",agent_id:"rev-1",cwd:$d}')" ;;
    cursor) payload="$(jq -n --arg d "$dir" '{hook_event_name:"subagentStart",subagent_type:"reviewer",workspace_roots:[$d]}')" ;;
  esac
  rc=0
  printf '%s' "$payload" | bash "$(adapter_script "$port")" || rc=$?
  [ "$rc" = 0 ] || adapter_never_blocked=false
  if [ "$rc" = 0 ] && [ "$(adapter_stamp_count "$dir" "$port")" = 0 ]; then
    echo "OK   (adapter-route-gate-absent-prompt-no-stamp) $port: no prompt field at all -> no stamp, exit 0 (degrades quietly)"
  else
    echo "FAIL (adapter-route-gate-absent-prompt-no-stamp) $port: unexpected stamp or nonzero exit (rc=$rc)"
    fail=1
  fi

  # --- adapter-route-gate-non-reviewer-target-no-stamp: valid Unit line, wrong target -> no stamp ---
  dir="$(adapter_project "$port" non-reviewer)"
  payload="$(adapter_payload "$port" "$dir" lead-programmer $'Unit: 302\n\nBuild it.')"
  rc=0
  printf '%s' "$payload" | bash "$(adapter_script "$port")" || rc=$?
  [ "$rc" = 0 ] || adapter_never_blocked=false
  if [ "$rc" = 0 ] && [ "$(adapter_stamp_count "$dir" "$port")" = 0 ]; then
    echo "OK   (adapter-route-gate-non-reviewer-target-no-stamp) $port: non-reviewer target -> no stamp, exit 0"
  else
    echo "FAIL (adapter-route-gate-non-reviewer-target-no-stamp) $port: unexpected stamp or nonzero exit (rc=$rc)"
    fail=1
  fi
done

# --- adapter-route-gate-never-blocks: writing a stamp must never change this
#     hook's exit status, on either port, on any of the payloads above ---
if [ "$adapter_never_blocked" = true ]; then
  echo "OK   (adapter-route-gate-never-blocks) every codex/cursor payload above exited 0 - the stamp block never blocks"
else
  echo "FAIL (adapter-route-gate-never-blocks) at least one codex/cursor payload exited nonzero"
  fail=1
fi

exit "$fail"
