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
#  - session/baseline id is `.conversation_id` (Claude's `.session_id`).
#
# Ordered logic (identical to the Claude version - see
# hooks/scripts/lib/stop-gate-core.sh):
#  0) loop guard - never re-trigger ourselves into an infinite loop.
#  0.5) reviewer's subagentStop -> if any .cursor/reviewed/*.blocked marker
#     stands, KEEP the pending-review flags (log `verdict=blocked flags-kept`,
#     ALLOW); a .cursor/reviewed/*.escalated marker (ESCALATE-TO-HUMAN) does
#     the same under its own token `verdict=escalated flags-kept`, and both
#     globs log so neither masks the other. `.directed` is DELIBERATELY not
#     globbed: the flags must clear for the human-directed fix to be
#     dispatched at all. Otherwise consume the PER-UNIT review-join stamps
#     (.cursor/.review-join.<unit-id>) that reviewer-route-gate.sh wrote at
#     dispatch time: no stamps at all -> fail OPEN (`marker-check=bootstrap`);
#     at least one stamp satisfied by a format-valid PASS/FAIL marker for its
#     unit -> delete those stamps, log `join-consumed=<id>` per deletion,
#     CLEAR every pending-review flag, log, ALLOW; stamps present but none
#     satisfied -> keep the flags, log `marker=MISSING unit=<id>` per stamp,
#     BLOCK. Keying per UNIT is what lets concurrent reviewers each make
#     progress, which the global watermark this replaced could not.
#  0.75) main stop with any pending-review flag -> BLOCK (defer:/skip: escape).
#  1) non-gated stop/subagentStop -> ALLOW immediately.
#  2) per-agent WIP sentinel with a non-empty reason -> log, delete, ALLOW.
#  2.5) a gated subagentStop reaching here -> CREATE the pending-review flag
#     if absent (idempotent: does not clobber an existing defer:/skip:).
#  3) tree clean AND no commits since baseline -> ALLOW.
#  4) otherwise run the configured test+lint command; non-zero -> BLOCK.
#
# Agent identities may arrive namespaced ("<plugin>:<persona>"), so every
# comparison below goes through lib/agent-identity.sh - liberal at the GATE
# site (0.5's gated-agent check), conservative at the GRANT site (0.5's
# reviewer-clears-flags). The EXTRACTION is unchanged, so a namespaced
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
raw_session_id="$(echo "$input" | jq -r '.conversation_id // "unknown"' 2>/dev/null || echo unknown)"
raw_agent_id="$(echo "$input" | jq -r '.subagent_type // .conversation_id // "main"' 2>/dev/null || echo main)"

main_agent_name=""
if [ "$hook_event" != "SubagentStop" ]; then
  main_agent_name="$(jq -r '.mainAgent // "orchestrator"' "$config" 2>/dev/null || echo orchestrator)"
fi

mcc_script="$(dirname "${BASH_SOURCE[0]}")/marker-commit-check.sh"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/stop-gate-core.sh"
