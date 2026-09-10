#!/usr/bin/env bash
# Behavioral suite for hooks/scripts/task-gate.sh (TaskCompleted, agent-teams
# mode). Canned hook-input JSON piped over stdin, fixtures under mktemp -d.
#
# M5 (gate-audit-step5): task_id is sanitized via the shared unit_id_sanitize
# rather than an inline charclass, so a unit id containing `#` finds its own
# marker instead of being silently rewritten to `_`.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"]}\n' > "$dir/.claude/persona-config.json"
  echo "$dir"
}

run_gate() {
  # $1 = project dir, $2 = task subject, $3 = task id
  local rc=0
  printf '%s' "$(jq -n --arg s "$2" --arg i "$3" '{task:{subject:$s,id:$i}}')" \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/task-gate.sh >/dev/null 2>"$tmproot/stderr" || rc=$?
  return "$rc"
}

echo "-- M5 drift reproduction: a unit id containing # finds its own marker --"
dir="$(make_project hash-id)"
printf 'PASS gh#348 2026-08-01T00:00:00Z commit: abc123 criteria: bash tests/validate.sh\n' \
  > "$dir/.claude/reviewed/gh#348.pass"
rc=0
run_gate "$dir" "impl: gh#348 do the thing" 'gh#348' || rc=$?
audit="$dir/.claude/review-audit.log"
if [ "$rc" = 0 ] && [ -f "$audit" ] && grep -q 'task=gh#348 marker-accepted' "$audit"; then
  pass "a #-bearing task id finds its own gh#348.pass marker (unrewritten)"
else
  bad "expected rc=0 and marker-accepted for gh#348, got rc=$rc, audit: $(cat "$audit" 2>/dev/null || echo '<missing>')"
fi

echo
echo "-- non-impl tasks pass through ungated --"
dir="$(make_project non-impl)"
rc=0
run_gate "$dir" "plan: something" 'unit-1' || rc=$?
if [ "$rc" = 0 ]; then
  pass "a non-'impl:' task subject exits 0 without a marker"
else
  bad "expected rc=0 for a non-impl task, got rc=$rc"
fi

exit "$fail"
