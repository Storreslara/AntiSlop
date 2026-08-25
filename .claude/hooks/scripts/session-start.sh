#!/usr/bin/env bash
# SessionStart. Four jobs, all no-ops if this project never ran
# install-antislop (no persona-config.json):
#  1) Record this session's starting HEAD sha, so stop-gate.sh can tell
#     whether commits happened this session even when the tree ends clean.
#  2) Drift check: compare persona-config.json's stamped pluginVersion
#     against the installed plugin's own current version, and surface one
#     line of context on mismatch pointing at `--update`.
#  3) Anti-drift re-anchor: on `source` == resume|compact ONLY (not
#     startup/clear, where the main session's persona (orchestrator) already
#     carries the protocol inlined in its own body, so it's freshly in
#     context), re-inject .claude/protocol-digest.md as
#     additionalContext. Compaction/resume is precisely when a long-running
#     session (the orchestrator's main session most of all - it has no
#     maxTurns cap) is likely to have summarized the shared protocol away;
#     this is a recency boost for the rules most prone to drifting, not a
#     substitute for the full protocol doc.
# NOTE: verify the additionalContext output shape against this Claude Code
# version's actual SessionStart hook contract on first real use - the
# hookSpecificOutput.additionalContext form is the documented mechanism, but
# wasn't re-verified empirically the way the agent-namespacing behavior was.
# The `source` field (startup/resume/clear/compact) is per Claude Code's
# documented SessionStart hook contract - reconfirm if this ever drifts.
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

context_parts=()

adapted_version="$(jq -r '.pluginVersion // empty' "$config" 2>/dev/null || true)"
current_version=""
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
  current_version="$(jq -r '.version // empty' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || true)"
fi

if [ -n "$adapted_version" ] && [ -n "$current_version" ] && [ "$adapted_version" != "$current_version" ]; then
  context_parts+=("antislop plugin is v${current_version} but this project was adapted at v${adapted_version} - run /antislop:update-antislop to resync (cheap, deterministic).")
fi

source_type="$(echo "$input" | jq -r '.source // empty' 2>/dev/null || true)"
digest_file="${project_dir}/.claude/protocol-digest.md"
if { [ "$source_type" = "resume" ] || [ "$source_type" = "compact" ]; } && [ -f "$digest_file" ]; then
  context_parts+=("$(cat "$digest_file")")
fi

# Job 4: Microworld layer status reporting (per D5)
human_review_mode="$(jq -r '.humanReviewMode // empty' "$config" 2>/dev/null || true)"
[ -n "$human_review_mode" ] || human_review_mode="critical"

# Count bundles and watch-map entries
bundle_count=0
[ -d "${project_dir}/microworlds" ] && bundle_count=$(find "${project_dir}/microworlds" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)

watchmap_count=0
watchmap_file="${project_dir}/tests/watch-map.json"
if [ -f "$watchmap_file" ]; then
  watchmap_count=$(jq -r '.entries | length' "$watchmap_file" 2>/dev/null || echo 0)
fi

# Find orphaned .escalated markers (marker exists but packet directory absent)
orphaned_markers=()
reviewed_dir="${project_dir}/.claude/reviewed"
if [ -d "$reviewed_dir" ]; then
  for marker in "$reviewed_dir"/*.escalated; do
    [ -f "$marker" ] || continue
    task_id=$(basename "$marker" .escalated)
    packet_dir="${project_dir}/.claude/human-review/${task_id}"
    if [ ! -d "$packet_dir" ]; then
      orphaned_markers+=("$task_id")
    fi
  done
fi

# Emission logic per D5 emission rules
microworld_msg=""
if [ ${#orphaned_markers[@]} -gt 0 ]; then
  # always warn on orphaned markers, regardless of humanReviewMode
  orphaned_list=$(printf ', %s' "${orphaned_markers[@]}" | sed 's/^, //')
  microworld_msg="Orphaned .escalated marker(s): ${orphaned_list} (packet directory missing)"
elif [ "$human_review_mode" != "off" ]; then
  if [ "$bundle_count" -eq 0 ]; then
    microworld_msg="humanReviewMode: $human_review_mode but zero microworld bundles present"
  else
    microworld_msg="Microworld status: $bundle_count bundle(s), $watchmap_count watch-map entry(ies)"
  fi
fi

if [ -n "$microworld_msg" ]; then
  context_parts+=("$microworld_msg")
fi

if [ "${#context_parts[@]}" -gt 0 ]; then
  joined="$(printf '%s\n\n' "${context_parts[@]}")"
  jq -n --arg msg "$joined" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $msg}}'
fi
exit 0
