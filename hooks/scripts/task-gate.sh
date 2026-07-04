#!/usr/bin/env bash
# TaskCompleted (agent-teams mode only). TaskCompleted has no matcher
# support, so this script filters by task-name convention itself: only
# tasks prefixed "impl:" require a reviewer PASS marker before completion.
# Planning/research/documentation tasks pass through ungated.
set -euo pipefail

input="$(cat)"

task_name="$(echo "$input" | jq -r '.task.subject // .task.name // empty' 2>/dev/null || true)"
task_id="$(echo "$input" | jq -r '.task.id // .taskId // empty' 2>/dev/null || true)"

case "$task_name" in
  impl:*) ;;
  *) exit 0 ;;
esac

[ -n "$task_id" ] || exit 0
marker=".claude/reviewed/${task_id}.pass"

if [ ! -f "$marker" ]; then
  echo "Task '${task_name}' has no reviewer PASS marker at ${marker} - route it through the reviewer (which touches this file on PASS) before marking complete." >&2
  exit 2
fi
exit 0
