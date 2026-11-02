#!/usr/bin/env bash
# CURSOR entry point over the shared stop-gate decision logic (generated
# from hooks/scripts/lib/stop-gate-core.sh - node bin/cli.js --update
# --force-render). Registered on `stop` (main session) AND `subagentStop`.
# Gating is config-driven via persona-config.json's gatedAgents list
# (default ["lead-programmer"]).
#
# Cursor payload differences vs Claude (spec §3, §6 open q #5):
#  - `hook_event_name` is "stop" | "subagentStop" (camelCase) - normalized to
#    "Stop"/"SubagentStop" below before sourcing the core, which compares
#    against the canonical PascalCase form shared with Claude/codex.
#  - the caller-agent identity on subagentStop is `.subagent_type` (Claude's
#    `.agent_type`). CONFIRMED present per cursor.com/docs/hooks.
#  - the plain `stop` payload carries NO agent identity (same as Claude), so
#    that case keys off the configured main agent - read here from
#    persona-config.json's `mainAgent` (default "orchestrator"), since Cursor
#    has no settings.json `.agent` key.
#  - there is no `stop_hook_active`; the infinite-loop guard keys off Cursor's
#    `.loop_count` instead.
#  - there is no per-subagent id on subagentStop, so the pending-review flag is
#    keyed by `subagent_type` (LIMITATION: two concurrent same-type subagents
#    would share one flag - acceptable for the sequential MVP flow).
#
# The rules live in hooks/scripts/lib/stop-gate-core.sh. No dispatch-hygiene
# port exists here, so the writer-dispatch stamp is never touched and the
# marker check is inert.
#
# Agent identities may arrive namespaced ("<plugin>:<persona>"), so every
# comparison below goes through lib/agent-identity.sh - liberal at the GATE
# site (the gated-agent check), conservative at the GRANT site (the
# reviewer-clears-flags check). The EXTRACTION is unchanged, so a namespaced
# subagent's flag is keyed by the namespaced form; every consumer globs
# `.pending-review.*`, so that only affects the filename, not the lifecycle.
set -euo pipefail

# shellcheck source=lib/agent-identity.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/harness-arm.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
dot="${project_dir}/.cursor"
dot_label=".cursor"
config="${dot}/persona-config.json"
review_audit="${dot}/review-audit.log"
harness_arm_or_deny "$project_dir" "$dot_label"

block() { echo "$1" >&2; exit 2; }
allow() { exit 0; }

loop_count="$(echo "$input" | jq -r '.loop_count // 0' 2>/dev/null || echo 0)"
case "$loop_count" in ''|*[!0-9]*) loop_count=0 ;; esac
[ "$loop_count" -ge 5 ] && allow

raw_hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
case "$raw_hook_event" in
  stop) hook_event="Stop" ;;
  subagentStop) hook_event="SubagentStop" ;;
  *) hook_event="$raw_hook_event" ;;
esac
agent_type="$(echo "$input" | jq -r '.subagent_type // empty' 2>/dev/null || true)"
raw_agent_id="$(echo "$input" | jq -r '.subagent_type // .conversation_id // "main"' 2>/dev/null || echo main)"

main_agent_name=""
if [ "$hook_event" != "SubagentStop" ]; then
  main_agent_name="$(jq -r '.mainAgent // "orchestrator"' "$config" 2>/dev/null || echo orchestrator)"
fi

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
writer_lane=""
source "${lib_dir}/stop-gate-core.sh"
