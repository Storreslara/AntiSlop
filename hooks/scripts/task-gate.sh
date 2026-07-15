#!/usr/bin/env bash
# TaskCompleted (agent-teams mode only). TaskCompleted has no matcher
# support, so this script filters by task-name convention itself: only
# tasks prefixed "impl:" require a reviewer PASS marker before completion.
# Planning/research/documentation tasks pass through ungated. Guards on
# persona-config.json existing so it never fires in a project that hasn't
# run install-antislop.
#
# Marker format v2 (agents/reviewer.md's printf, mirroring the WIP-sentinel
# content-validation precedent at stop-gate.sh:75-85): the marker must be
# non-empty AND its first line must read exactly
#   PASS <task-id> <UTC ISO-8601 timestamp> criteria: <acceptance-criteria command(s) run>
# A bare `touch` (empty file) or a first line not matching that shape used to
# be rejected outright as of v0.6.0's release (2026-07-13). Per Open Question
# 4 (human decision, 2026-07-13): a two-week legacy-marker GRACE PERIOD softens
# that instead of a hard cutover - see GRACE_PERIOD_END below. Existence alone
# is still never sufficient once the grace period ends, closing the
# anyone-with-Bash forgery gap a bare touch left open. On acceptance, an
# audit line is appended to .claude/review-audit.log (sibling of
# wip-audit.log) so accepted markers leave the same kind of trail the WIP
# sentinel's honored path does; a grace-period warning is logged too, so its
# use is reviewable, same rationale as every other audit log in this system.
#
# A FAIL verdict writes a sibling `<task-id>.fail` record (agents/reviewer.md)
# — this gate does not check it and never blocks on it; it exists purely as
# a durable warning for future spec-master/orchestrator spawns (see
# persona-protocol.md's "FAIL record" section), not a completion gate.
set -euo pipefail

# Two weeks from the v0.6.0 release date (2026-07-13). Before this date, a
# legacy/missing/malformed marker gets a loud warning and is ALLOWED; on or
# after this date, the same marker is REJECTED. Bump this only alongside a
# future format change that needs its own grace window - it is not meant to
# be extended for the v2 rollout itself.
GRACE_PERIOD_END="2026-07-27"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

task_name="$(echo "$input" | jq -r '.task.subject // .task.name // empty' 2>/dev/null || true)"
raw_task_id="$(echo "$input" | jq -r '.task.id // .taskId // empty' 2>/dev/null || true)"

case "$task_name" in
  impl:*) ;;
  *) exit 0 ;;
esac

[ -n "$raw_task_id" ] || exit 0
task_id="${raw_task_id//[^a-zA-Z0-9._-]/_}"
marker="${project_dir}/.claude/reviewed/${task_id}.pass"

marker_valid() {
  [ -f "$marker" ] && [ -s "$marker" ] || return 1
  local first_line
  first_line="$(head -n 1 "$marker")"
  case "$first_line" in
    "PASS ${task_id} "*) return 0 ;;
    *) return 1 ;;
  esac
}

reject() {
  echo "Task '${task_name}' has no valid reviewer PASS marker at ${marker}." >&2
  echo "The reviewer (or the no-reviewer fallback lead) must write it in v2 format, first line exactly:" >&2
  echo "  mkdir -p \"$(dirname "$marker")\" && printf 'PASS ${task_id} %s criteria: <acceptance-criteria command(s) run>\\n' \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" > ${marker}" >&2
  echo "A bare 'touch' or an empty/malformed marker is rejected - existence alone is not enough." >&2
  echo "The v0.6.0 legacy-marker grace period ended ${GRACE_PERIOD_END} - it no longer softens this block." >&2
  echo "If your copied reviewer.md predates plugin v0.6.0 (still teaches a bare touch), run /antislop:update-antislop to pick up the v2 format." >&2
  exit 2
}

warn_and_allow_legacy() {
  echo "WARNING: Task '${task_name}' has no valid v2 reviewer PASS marker at ${marker}." >&2
  echo "Allowed ONLY under the v0.6.0 legacy-marker grace period, which ends ${GRACE_PERIOD_END} (UTC) - after that date this will BLOCK." >&2
  echo "Run /antislop:update-antislop now to pick up the v2 marker format before the grace period ends." >&2
  printf '%s task=%s legacy-marker-grace-period-warning\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$task_id" \
    >> "${project_dir}/.claude/review-audit.log"
  exit 0
}

if marker_valid; then
  printf '%s task=%s marker-accepted\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$task_id" \
    >> "${project_dir}/.claude/review-audit.log"
  exit 0
fi

today="$(date -u +%Y-%m-%d)"
if [[ "$today" < "$GRACE_PERIOD_END" ]]; then
  warn_and_allow_legacy
else
  reject
fi
