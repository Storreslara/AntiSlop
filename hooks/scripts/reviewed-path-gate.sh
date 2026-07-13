#!/usr/bin/env bash
# PreToolUse (Bash). Built against Probe A's confirmed result - agent_type IS
# present on a subagent-issued Bash PreToolUse payload - see
# docs/experiments/2026-07-probe-hook-payloads.md, Probe A. Attributes the
# caller from the top-level `agent_type` field and blocks Bash commands whose
# text touches `.claude/reviewed` (the PASS-marker directory) unless the
# caller is the reviewer, or the main session/team lead in the documented
# no-reviewer fallback (personaSelection does NOT contain "reviewer" -
# start-feature-team.md:49-53, orchestrator.md's "if no reviewer persona
# exists"). Any other agent_type (lead-programmer above all) is blocked.
# Guards on persona-config.json existing, same as every other gate.
#
# Collateral, accepted per the plan: any Bash command whose text merely
# CONTAINS the substring ".claude/reviewed" is blocked, including read-only
# ones (e.g. `cat .claude/reviewed/foo.pass`) - personas have the Read tool
# for that, and the block message says so. This is advisory, not airtight -
# a determined agent could obfuscate the path past the substring match; see
# README.md's "Known limitations", same framing as the existing `sed -i`
# bypass caveat on protected-paths.sh.
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
[ -f "$config" ] || exit 0

command="$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
case "$command" in
  *".claude/reviewed"*) ;;
  *) exit 0 ;;
esac

agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

if [ "$agent_type" = "reviewer" ]; then
  exit 0
fi

if [ -z "$agent_type" ]; then
  has_reviewer="$(jq -r '.personaSelection[]? // empty' "$config" 2>/dev/null | grep -x reviewer || true)"
  if [ -z "$has_reviewer" ]; then
    exit 0
  fi
  echo "BLOCKED: this project has a reviewer persona selected, so the main session/team lead may not write to .claude/reviewed/ itself - route the unit to the reviewer instead, per persona-protocol.md's Review Ownership section." >&2
  exit 2
fi

echo "BLOCKED: '${agent_type}' may not write or otherwise touch .claude/reviewed/ via Bash - only the reviewer writes the PASS marker there (or the main session/team lead, ONLY in the documented no-reviewer fallback where no reviewer persona is selected). Per persona-protocol.md's Review Ownership section. (Read-only commands are blocked too - use the Read tool for that.)" >&2
exit 2
