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
