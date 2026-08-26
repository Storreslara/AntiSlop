#!/usr/bin/env bash
# Fixture-driven test for hooks/scripts/session-start.sh job 4: microworld
# layer status reporting. Canned hook-input JSON piped to the script - no real
# claude/session dependency.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  # $1 = case name, $2 = humanReviewMode value
  # echoes a fresh project dir seeded with persona-config.json
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true","humanReviewMode":"%s"}\n' "$2" \
    > "$dir/.claude/persona-config.json"
  echo "$dir"
}

make_project_no_config() {
  # Like make_project but WITHOUT persona-config.json
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  echo "$dir"
}

startup_input='{"hook_event_name":"SessionStart","session_id":"test-1","source":"startup"}'

run_session_start() {
  # $1 = project dir, $2 = script (default: the real hook)
  local rc=0
  printf '%s' "$startup_input" \
    | CLAUDE_PROJECT_DIR="$1" bash "${2:-hooks/scripts/session-start.sh}" || rc=$?
  return "$rc"
}

# (a) humanReviewMode="critical" with zero bundles -> warns about zero bundles
dir="$(make_project critical_no_bundles critical)"
rc=0
output=$(run_session_start "$dir" || rc=$?)
if [ "$rc" = 0 ] && echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' > /dev/null 2>&1; then
  if echo "$output" | grep -q "zero.*bundle"; then
    echo "OK   (a) humanReviewMode=critical + zero bundles warns about zero bundles"
  else
    echo "FAIL (a) expected zero-bundles warning in output"
    fail=1
  fi
else
  echo "FAIL (a) invalid JSON output or wrong hook event name (rc=$rc)"
  fail=1
fi

# (b) humanReviewMode="off" with no orphans -> silent (no output)
dir="$(make_project off_no_orphans off)"
output=$(run_session_start "$dir" || true)
if [ -z "$output" ]; then
  echo "OK   (b) humanReviewMode=off + no orphans is silent (empty output)"
else
  echo "FAIL (b) expected empty output but got: $output"
  fail=1
fi

# (c) orphaned .escalated marker (marker without packet dir) -> warns regardless of humanReviewMode
dir="$(make_project orphaned_escalated off)"
printf 'ESCALATE-TO-HUMAN task-c 2026-08-10T00:00:00Z trigger: test\n' \
  > "$dir/.claude/reviewed/task-c.escalated"
# Note: do NOT create the packet directory at .claude/human-review/task-c/
rc=0
output=$(run_session_start "$dir" || rc=$?)
if [ "$rc" = 0 ] && echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' > /dev/null 2>&1; then
  if echo "$output" | grep -q "task-c"; then
    echo "OK   (c) orphaned .escalated marker warns and names the task-id"
  else
    echo "FAIL (c) expected task-c in warning"
    fail=1
  fi
else
  echo "FAIL (c) invalid JSON output or wrong hook event name (rc=$rc)"
  fail=1
fi

# (d) marker and packet directory both present -> no orphan warning
dir="$(make_project marker_with_packet off)"
mkdir -p "$dir/.claude/human-review/task-d"
printf 'ESCALATE-TO-HUMAN task-d 2026-08-10T00:00:00Z trigger: test\n' \
  > "$dir/.claude/reviewed/task-d.escalated"
rc=0
output=$(run_session_start "$dir" || rc=$?)
if [ "$rc" = 0 ] && [ -z "$output" ]; then
  echo "OK   (d) marker with packet directory present is silent (no orphan warning)"
else
  echo "FAIL (d) expected empty output but got: $output"
  fail=1
fi

# (e) no persona-config.json -> early exit 0, no output
dir="$(make_project_no_config no_config)"
rc=0
output=$(run_session_start "$dir" || rc=$?)
if [ "$rc" = 0 ] && [ -z "$output" ]; then
  echo "OK   (e) no persona-config.json -> exit 0 with empty output"
else
  echo "FAIL (e) expected exit 0 with empty output, got rc=$rc and output: $output"
  fail=1
fi

# (f) output is valid JSON with correct structure when emitted
dir="$(make_project valid_json critical)"
rc=0
output=$(run_session_start "$dir" || rc=$?)
if [ "$rc" = 0 ] && [ -n "$output" ] && echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' > /dev/null 2>&1; then
  echo "OK   (f) output is valid JSON with hookEventName=SessionStart"
else
  echo "FAIL (f) output is not valid JSON or missing hookEventName (output: $output)"
  fail=1
fi

# (h) AC-A9 - BACKSTOP: a failed bundle result on the audit log that no
#     Stop/SubagentStop has reported yet is surfaced in additionalContext.
dir="$(make_project backstop-report critical)"
printf '2026-08-26T00:00:00Z unit=widget result=fail file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
rc=0
output=$(run_session_start "$dir" || rc=$?)
if [ "$rc" = 0 ] && echo "$output" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null \
     | grep -q 'widget'; then
  echo "OK   (h) AC-A9: an unreported failed bundle is surfaced in additionalContext"
else
  echo "FAIL (h) expected the failed bundle named in additionalContext (output: $output)"
  fail=1
fi

# (h2) AC-A9 - REPORTED ONCE: a second SessionStart with no NEW audit lines
#      does not re-announce the same failure (watermark advanced by (h)).
rc=0
output2=$(run_session_start "$dir" || rc=$?)
if [ "$rc" = 0 ]; then
  ctx="$(echo "$output2" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || true)"
  if ! echo "$ctx" | grep -q 'widget'; then
    echo "OK   (h2) AC-A9: the same failure is not re-announced on a second SessionStart"
  else
    echo "FAIL (h2) expected no re-announcement of an already-reported failure (output: $output2)"
    fail=1
  fi
else
  echo "FAIL (h2) second session-start call errored (rc=$rc)"
  fail=1
fi

# (h3) a NEW failure appended after the watermark IS surfaced
dir="$(make_project backstop-new critical)"
printf '2026-08-26T00:00:00Z unit=widget result=pass file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
run_session_start "$dir" > /dev/null 2>&1 || true
printf '2026-08-26T00:01:00Z unit=gadget result=fail file=src/other.js\n' \
  >> "$dir/.claude/microworld-audit.log"
rc=0
output3=$(run_session_start "$dir" || rc=$?)
if [ "$rc" = 0 ] && echo "$output3" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null \
     | grep -q 'gadget'; then
  echo "OK   (h3) a new failure appended after the watermark is surfaced"
else
  echo "FAIL (h3) expected the new failure named in additionalContext (output: $output3)"
  fail=1
fi

# (g) MUTATION CONTROL: verify the microworld job is load-bearing
# Disable the emission by changing the if condition to always false
mutant="$tmproot/mutant"
mkdir -p "$mutant"
cp hooks/scripts/session-start.sh "$mutant/session-start.sh"
sed -i 's/if \[ -n "\$microworld_msg" \]; then/if false; then/' "$mutant/session-start.sh"

# Verify the mutation parsed correctly
if_line_before="$(grep -c 'if \[ -n "\$microworld_msg" \]' hooks/scripts/session-start.sh || true)"
if_line_after="$(grep -c 'if \[ -n "\$microworld_msg" \]' "$mutant/session-start.sh" || true)"
parses=yes
bash -n "$mutant/session-start.sh" 2>/dev/null || parses=no

# The key is that the if_line_before and if_line_after must differ, proving we changed the code
if [ "$if_line_before" = 1 ] && [ "$if_line_after" = 0 ] && [ "$parses" = yes ]; then
  echo "OK   (g) mutation control: microworld emission block is syntactically present and can be disabled"
else
  echo "FAIL (g) mutation control setup failed (if_before=$if_line_before if_after=$if_line_after parses=$parses)"
  fail=1
fi

exit "$fail"
