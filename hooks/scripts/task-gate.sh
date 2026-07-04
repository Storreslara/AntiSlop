#!/usr/bin/env bash
# TaskCompleted (agent-teams mode only). TaskCompleted has no matcher
# support, so this script filters by task-name convention itself: only
# tasks prefixed "impl:" require a reviewer PASS marker before completion.
# Planning/research/documentation tasks pass through ungated. Guards on
# persona-config.json existing so it never fires in a project that hasn't
# run setup-personas.
set -euo pipefail

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

if [ ! -f "$marker" ]; then
  echo "Task '${task_name}' has no reviewer PASS marker at ${marker} - route it through the reviewer (which touches this file on PASS) before marking complete." >&2
  exit 2
fi
exit 0
