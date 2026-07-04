#!/usr/bin/env bash
# SessionStart. Two jobs, both no-ops if this project never ran
# setup-personas (no persona-config.json):
#  1) Record this session's starting HEAD sha, so stop-gate.sh can tell
#     whether commits happened this session even when the tree ends clean.
#  2) Drift check: compare persona-config.json's stamped pluginVersion
#     against the installed plugin's own current version, and surface one
#     line of context on mismatch pointing at `--update`.
# NOTE: verify the additionalContext output shape against this Claude Code
# version's actual SessionStart hook contract on first real use - the
# hookSpecificOutput.additionalContext form is the documented mechanism, but
# wasn't re-verified empirically the way the agent-namespacing behavior was.
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

raw_session_id="$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
session_id="${raw_session_id//[^a-zA-Z0-9._-]/_}"
baseline_file="${project_dir}/.claude/.session-baseline.${session_id}"

if [ ! -f "$baseline_file" ]; then
  mkdir -p "${project_dir}/.claude"
  git -C "$project_dir" rev-parse HEAD 2>/dev/null > "$baseline_file" || true
fi

adapted_version="$(jq -r '.pluginVersion // empty' "$config" 2>/dev/null || true)"
current_version=""
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
  current_version="$(jq -r '.version // empty' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || true)"
fi

if [ -n "$adapted_version" ] && [ -n "$current_version" ] && [ "$adapted_version" != "$current_version" ]; then
  msg="seb-personas plugin is v${current_version} but this project was adapted at v${adapted_version} - run /seb-personas:setup-personas --update to resync."
  jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $msg}}'
fi
exit 0
