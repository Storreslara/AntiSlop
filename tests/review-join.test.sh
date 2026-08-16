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

# --- route-gate-blocks-named-reviewer: named dispatch with name != "reviewer" -> exit 2, no stamp ---
dir="$(make_project blocks-named-reviewer)"
payload_named_rev="$(jq -n --arg p $'Unit: 306\n\nReview this.' '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:"orchestrator",tool_input:{subagent_type:"reviewer",name:"rev-302",prompt:$p}}')"
rc=0
run_route_gate "$dir" "$payload_named_rev" || rc=$?
if [ "$rc" = 2 ] && [ "$(stamp_count "$dir")" = 0 ]; then
  echo "OK   (route-gate-blocks-named-reviewer) name=rev-302 subagent_type=reviewer -> exit 2, no stamp"
else
  echo "FAIL (route-gate-blocks-named-reviewer) expected exit 2 and no stamp (rc=$rc, stamp_count=$(stamp_count "$dir"))"
  fail=1
fi

# --- route-gate-allows-bare-reviewer-name: named dispatch with name == "reviewer" -> exit 0, stamp written ---
dir="$(make_project allows-bare-reviewer-name)"
payload_named_bare="$(jq -n --arg p $'Unit: 307\n\nReview this.' '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:"orchestrator",tool_input:{subagent_type:"reviewer",name:"reviewer",prompt:$p}}')"
rc=0
run_route_gate "$dir" "$payload_named_bare" || rc=$?
stamp="$dir/.claude/.review-join.307"
if [ "$rc" = 0 ] && [ -f "$stamp" ] && [ "$(stamp_count "$dir")" = 1 ]; then
  echo "OK   (route-gate-allows-bare-reviewer-name) name=reviewer -> exit 0, stamp written"
else
  echo "FAIL (route-gate-allows-bare-reviewer-name) expected exit 0 and stamp (rc=$rc)"
  fail=1
fi

# --- route-gate-allows-unnamed-reviewer: no name key at all -> exit 0, stamp written ---
dir="$(make_project allows-unnamed-reviewer)"
payload_unnamed="$(jq -n --arg p $'Unit: 308\n\nReview this.' '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:"orchestrator",tool_input:{subagent_type:"reviewer",prompt:$p}}')"
rc=0
run_route_gate "$dir" "$payload_unnamed" || rc=$?
stamp="$dir/.claude/.review-join.308"
if [ "$rc" = 0 ] && [ -f "$stamp" ] && [ "$(stamp_count "$dir")" = 1 ]; then
  echo "OK   (route-gate-allows-unnamed-reviewer) no name key -> exit 0, stamp written"
else
  echo "FAIL (route-gate-allows-unnamed-reviewer) expected exit 0 and stamp (rc=$rc)"
  fail=1
fi

# --- route-gate-named-non-reviewer-unaffected: non-reviewer target with name -> exit 0 ---
dir="$(make_project named-non-reviewer-unaffected)"
payload_named_lp="$(jq -n --arg p $'Unit: 309\n\nBuild this.' '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:"orchestrator",tool_input:{subagent_type:"lead-programmer",name:"lp-302",prompt:$p}}')"
rc=0
run_route_gate "$dir" "$payload_named_lp" || rc=$?
if [ "$rc" = 0 ] && [ "$(stamp_count "$dir")" = 0 ]; then
  echo "OK   (route-gate-named-non-reviewer-unaffected) lead-programmer with name=lp-302 -> exit 0"
else
  echo "FAIL (route-gate-named-non-reviewer-unaffected) expected exit 0 (rc=$rc)"
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

# ============================================================================
# MARKER-COMMIT-CHECK WIRING (gh385-7, spec Step 7). stop-gate.sh's
# JOIN_SATISFIED_UNITS[] loop now invokes hooks/scripts/marker-commit-check.sh
# for each unit before its stamp is consumed. Each case builds its own
# throwaway git repo (same pattern as tests/marker-commit-check.test.sh) so a
# genuine mismatch can be produced.
# ============================================================================

mcc_reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-mcc","session_id":"s-mcc"}'

mcc_repo() {
  # $1 = case name -> echoes a fresh git-init'd project dir seeded with
  # .claude/reviewed and one commit naming unit "own-<case>".
  local dir="$tmproot/mcc-$1"
  mkdir -p "$dir/.claude/reviewed"
  git -C "$dir" init -q
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name Test
  git -C "$dir" commit -q --allow-empty -m "feat(own-$1): the unit's own commit"
  echo "$dir"
}

mcc_seed_mismatch() {
  # $1 = project dir, $2 = case name, $3 = markerCommitCheck mode -> adds a
  # sibling commit, a satisfied review-join stamp, a PASS marker citing the
  # SIBLING commit (a genuine mismatch), a pending-review flag, and config.
  local dir="$1" case="$2" mode="$3" sibling_sha
  git -C "$dir" commit -q --allow-empty -m "chore(sibling-$case): unrelated work"
  sibling_sha="$(git -C "$dir" rev-parse HEAD)"
  printf '{"gatedAgents":["lead-programmer"],"markerCommitCheck":{"mode":"%s"}}\n' "$mode" \
    > "$dir/.claude/persona-config.json"
  printf '2026-08-15T00:00:00Z unit=own-%s prior=none prior_mtime=-\n' "$case" \
    > "$dir/.claude/.review-join.own-$case"
  printf 'PASS own-%s 2026-08-15T00:00:00Z commit: %s criteria: true\n' "$case" "$sibling_sha" \
    > "$dir/.claude/reviewed/own-$case.pass"
  printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-mcc"
}

# --- mcc-warn-mismatch: mode warn, marker cites a sibling's commit -> exit 0, stderr warning, audit line, flags still cleared ---
dir="$(mcc_repo warn)"
mcc_seed_mismatch "$dir" warn warn
rc=0
stderr_out="$(printf '%s' "$mcc_reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh 2>&1 >/dev/null)" || rc=$?
if [ "$rc" = 0 ] \
   && grep -q 'marker-commit-check=mismatch unit=own-warn' "$dir/.claude/review-audit.log" \
   && [[ $stderr_out == *"own-warn"* ]] \
   && [ ! -e "$dir/.claude/.pending-review.lp-mcc" ]; then
  echo "OK   (mcc-warn-mismatch) mode warn + mismatch -> exit 0, stderr warning, audit logged, flags cleared"
else
  echo "FAIL (mcc-warn-mismatch) rc=$rc audit=$(grep -c 'marker-commit-check=mismatch' "$dir/.claude/review-audit.log" 2>/dev/null || echo 0) stderr=[$stderr_out]"
  fail=1
fi

# --- mcc-block-mismatch: mode block, marker cites a sibling's commit -> exit 2, pending-review flag still present ---
dir="$(mcc_repo block)"
mcc_seed_mismatch "$dir" block block
rc=0
printf '%s' "$mcc_reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 2 ] \
   && grep -q 'marker-commit-check=mismatch unit=own-block' "$dir/.claude/review-audit.log" \
   && [ -f "$dir/.claude/.pending-review.lp-mcc" ]; then
  echo "OK   (mcc-block-mismatch) mode block + mismatch -> exit 2, pending-review flag still present"
else
  echo "FAIL (mcc-block-mismatch) rc=$rc flag-exists=$([ -f "$dir/.claude/.pending-review.lp-mcc" ] && echo yes || echo no)"
  fail=1
fi

# --- mcc-off-no-audit-line: mode off -> no marker-commit-check= line at all ---
dir="$(mcc_repo off)"
mcc_seed_mismatch "$dir" off off
rc=0
printf '%s' "$mcc_reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && ! grep -q 'marker-commit-check=' "$dir/.claude/review-audit.log" 2>/dev/null; then
  echo "OK   (mcc-off-no-audit-line) mode off -> no marker-commit-check= line written"
else
  echo "FAIL (mcc-off-no-audit-line) rc=$rc lines=$(grep -c 'marker-commit-check=' "$dir/.claude/review-audit.log" 2>/dev/null || echo 0)"
  fail=1
fi

# --- mcc-degrade-gracefully (constitution P4): a fixture with zero .review-join.* stamps -> no marker-commit-check= line ---
dir="$(mcc_repo degrade)"
printf '{"gatedAgents":["lead-programmer"]}\n' > "$dir/.claude/persona-config.json"
rc=0
printf '%s' "$mcc_reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && ! grep -q 'marker-commit-check=' "$dir/.claude/review-audit.log" 2>/dev/null; then
  echo "OK   (mcc-degrade-gracefully) zero review-join stamps -> no marker-commit-check= line (constitution P4)"
else
  echo "FAIL (mcc-degrade-gracefully) rc=$rc lines=$(grep -c 'marker-commit-check=' "$dir/.claude/review-audit.log" 2>/dev/null || echo 0)"
  fail=1
fi

# --- mcc-helper-unavailable: classifier renamed away -> exit 0 on an otherwise-clean turn, logs marker-commit-check=unavailable ---
mcc_mutant="$tmproot/mcc-mutant"
mkdir -p "$mcc_mutant"
cp hooks/scripts/stop-gate.sh "$mcc_mutant/stop-gate.sh"
cp -R hooks/scripts/lib "$mcc_mutant/lib"
# deliberately NOT copying marker-commit-check.sh - simulates it being renamed away
dir="$(mcc_repo unavail)"
printf '{"gatedAgents":["lead-programmer"]}\n' > "$dir/.claude/persona-config.json"
printf '2026-08-15T00:00:00Z unit=own-unavail prior=none prior_mtime=-\n' \
  > "$dir/.claude/.review-join.own-unavail"
own_sha="$(git -C "$dir" rev-parse HEAD)"
printf 'PASS own-unavail 2026-08-15T00:00:00Z commit: %s criteria: true\n' "$own_sha" \
  > "$dir/.claude/reviewed/own-unavail.pass"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-mcc"
rc=0
printf '%s' "$mcc_reviewer_stop" | CLAUDE_PROJECT_DIR="$dir" bash "$mcc_mutant/stop-gate.sh" >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-mcc" ] \
   && grep -q 'marker-commit-check=unavailable unit=own-unavail' "$dir/.claude/review-audit.log"; then
  echo "OK   (mcc-helper-unavailable) marker-commit-check.sh renamed away -> exit 0, logs marker-commit-check=unavailable, gate itself unaffected"
else
  echo "FAIL (mcc-helper-unavailable) rc=$rc flag-exists=$([ -e "$dir/.claude/.pending-review.lp-mcc" ] && echo yes || echo no) audit=$(grep -c 'marker-commit-check=unavailable' "$dir/.claude/review-audit.log" 2>/dev/null || echo 0)"
  fail=1
fi

exit "$fail"
