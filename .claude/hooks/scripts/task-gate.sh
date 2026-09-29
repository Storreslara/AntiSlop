#!/usr/bin/env bash
# TaskCompleted (agent-teams mode only). TaskCompleted has no matcher
# support, so this script filters by task-name convention itself: only
# tasks prefixed "impl:" require a reviewer PASS marker before completion.
# Planning/research/documentation tasks pass through ungated. Guards on
# persona-config.json existing so it never fires in a project that hasn't
# run install-antislop.
#
# Marker format v3 (agents/reviewer.md's printf, mirroring the WIP-sentinel
# content-validation precedent at stop-gate.sh:75-85): the marker must be
# non-empty AND its first line must read exactly
#   PASS <task-id> <UTC ISO-8601 timestamp> commit: <sha|none> criteria: <acceptance-criteria command(s) run>
# A bare `touch` (empty file) or a first line not matching that shape is
# rejected outright, as of v0.6.0's release (2026-07-13), closing the
# anyone-with-Bash forgery gap a bare touch left open. On acceptance, an
# audit line is appended to .claude/review-audit.log (sibling of
# wip-audit.log) so accepted markers leave the same kind of trail the WIP
# sentinel's honored path does.
#
# A FAIL verdict writes a sibling `<task-id>.fail` record (agents/reviewer.md)
# — this gate does not check it and never blocks on it; it exists purely as
# a durable warning for future spec-master/orchestrator spawns (see
# persona-protocol.md's "FAIL record" section), not a completion gate.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/harness-arm.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
harness_arm_or_deny "$project_dir" ".claude"
[ -f "$config" ] || exit 0
# Review gating off: reviewer verdicts are advisory, so no marker is owed.
[ "$(jq -r '.reviewGating.mode // "enforce"' "$config" 2>/dev/null || echo enforce)" = "off" ] && exit 0

task_name="$(echo "$input" | jq -r '.task.subject // .task.name // empty' 2>/dev/null || true)"
raw_task_id="$(echo "$input" | jq -r '.task.id // .taskId // empty' 2>/dev/null || true)"

case "$task_name" in
  impl:*) ;;
  *) exit 0 ;;
esac

[ -n "$raw_task_id" ] || exit 0
task_id="$(unit_id_sanitize "$raw_task_id")"
marker="${project_dir}/.claude/reviewed/${task_id}.pass"

marker_valid() {
  state_unit_marker_exists "$task_id" pass || return 1
  local first_line
  first_line="$(state_read_unit_marker "$task_id" pass 2>/dev/null | head -n 1)"
  case "$first_line" in
    "PASS ${task_id} "*) return 0 ;;
    *) return 1 ;;
  esac
}

reject() {
  echo "Task '${task_name}' has no valid reviewer PASS marker at ${marker}." >&2
  echo "The reviewer (or the no-reviewer fallback lead) must write it in v3 format, first line exactly:" >&2
  echo "  mkdir -p \"$(dirname "$marker")\" && printf 'PASS ${task_id} %s commit: %s criteria: <acceptance-criteria command(s) run>\\n' \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \"<the unit's own final commit, not HEAD>\" > ${marker}" >&2
  echo "A bare 'touch' or an empty/malformed marker is rejected - existence alone is not enough." >&2
  echo "If your copied reviewer.md predates plugin v0.6.0 (still teaches a bare touch), run /antislop:update-antislop to pick up the v3 format." >&2
  exit 2
}

if marker_valid; then
  audit_append "${project_dir}/.claude/review-audit.log" \
    "$(printf '%s task=%s marker-accepted' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$task_id")"
  exit 0
fi

reject
