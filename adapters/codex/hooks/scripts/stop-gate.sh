#!/usr/bin/env bash
# CODEX entry point over the shared stop-gate decision logic (generated from
# hooks/scripts/lib/stop-gate-core.sh - node bin/cli.js --update
# --force-render). Registered on `Stop` (main session) AND `SubagentStop`.
# Gating is config-driven via persona-config.json's gatedAgents list
# (default ["lead-programmer"]).
#
# Codex payload differences vs Claude/Cursor (docs/specs/codex-plugin.md §6,
# §12):
#  - `hook_event_name` is "Stop" | "SubagentStop" (PascalCase, confirmed).
#  - caller-agent identity on SubagentStop: `.agent_type` (the stopped
#    subagent's own profile/type - confirmed field, though whether it's
#    distinct from any PARENT identity is unresolved, see
#    reviewer-route-gate.sh).
#  - `.agent_id`: CONFIRMED per-subagent field, used here as the pending-
#    review-flag / WIP-sentinel filename key. If this is genuinely a stable
#    per-spawn-instance id (not just a repeat of agent_type - unverified),
#    this FIXES the Cursor port's known limitation where two concurrent
#    same-type subagents shared one flag.
#  - the plain `Stop` payload carries NO agent identity (same as every
#    platform), so that case keys off the configured main agent - read here
#    from persona-config.json's `mainAgent` (default "orchestrator"), since
#    Codex has no config.toml key equivalent to Claude's settings.json
#    `.agent` field.
#  - NO CONFIRMED loop-guard field (Claude's `stop_hook_active`, Cursor's
#    `.loop_count`) exists in Codex's documented common/turn-scoped payload
#    fields. Rather than skip the guard, this implements a SELF-TRACKED
#    fallback: a per-session counter file incremented each time this script
#    is about to BLOCK (exit 2), reset whenever it reaches a genuine ALLOW
#    after running the real check. If 5 consecutive blocks accumulate, force
#    an ALLOW instead of blocking again, logging that the guard tripped. This
#    is a workaround for an unconfirmed primitive, not a confirmed platform
#    behavior - revisit if Codex turns out to expose its own re-trigger
#    signal (docs/codex-port-notes.md).
#  - session/baseline id: `.session_id` (Codex has this natively, unlike
#    Cursor's reused `.conversation_id`).
#
# Ordered logic (identical to the Claude/Cursor versions - see
# hooks/scripts/lib/stop-gate-core.sh):
#  0) loop guard (self-tracked fallback, see above).
#  0.5) reviewer's SubagentStop -> if any .codex/reviewed/*.blocked marker
#     stands, KEEP the pending-review flags (log `verdict=blocked flags-kept`,
#     ALLOW); a .codex/reviewed/*.escalated marker (ESCALATE-TO-HUMAN) does the
#     same under its own token `verdict=escalated flags-kept`, and both globs
#     log so neither masks the other. `.directed` is DELIBERATELY not globbed:
#     the flags must clear for the human-directed fix to be dispatched at all.
#     Otherwise consume the PER-UNIT review-join stamps
#     (.codex/.review-join.<unit-id>) that reviewer-route-gate.sh wrote at
#     dispatch time: no stamps at all -> fail OPEN (`marker-check=bootstrap`);
#     at least one stamp satisfied by a format-valid PASS/FAIL marker for its
#     unit -> delete those stamps, log `join-consumed=<id>` per deletion,
#     CLEAR every pending-review flag, log, ALLOW; stamps present but none
#     satisfied -> keep the flags, log `marker=MISSING unit=<id>` per stamp,
#     BLOCK. Keying per UNIT is what lets concurrent reviewers each make
#     progress, which the global watermark this replaced could not.
#  0.75) main Stop with any pending-review flag -> BLOCK (defer:/skip: escape).
#  1) non-gated stop/SubagentStop -> ALLOW immediately.
#  2) per-agent WIP sentinel with a non-empty reason -> log, delete, ALLOW.
#  2.5) a gated SubagentStop reaching here -> CREATE the pending-review flag
#     if absent (idempotent: does not clobber an existing defer:/skip:).
#  3) tree clean AND no commits since baseline -> ALLOW.
#  4) otherwise run the configured test+lint command; non-zero -> BLOCK.
#
# Agent identities may arrive namespaced ("<plugin>:<persona>"), so every
# comparison below goes through lib/agent-identity.sh - liberal at the GATE
# site (the gatedAgents check, where a miss fails OPEN), conservative at the
# GRANT site (the reviewer-clears-flags check, where a miss fails CLOSED).
# Any identity that drifts (an unrecognized namespace or an unparseable
# value) is logged to identity-drift, at either site, not just the GRANT
# one. A PERSONA NAME (e.g. "reviewer") is always bare; an AGENT IDENTITY
# (`.agent_type`/`.agent_id`) is the possibly-namespaced wire value - no
# field here is assumed to arrive bare.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo .)"
dot="${project_dir}/.codex"
dot_label=".codex"
config="${dot}/persona-config.json"
review_audit="${dot}/review-audit.log"

raw_session_id="$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
session_id_for_guard="${raw_session_id//[^a-zA-Z0-9._-]/_}"
loop_guard_file="${dot}/.stop-loop-guard.${session_id_for_guard}"

block() {
  # $1 = message to write to stderr before exiting 2.
  local count=0
  [ -f "$loop_guard_file" ] && count="$(cat "$loop_guard_file" 2>/dev/null || echo 0)"
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  count=$((count + 1))
  if [ "$count" -ge 5 ]; then
    printf '%s loop-guard tripped (5 consecutive blocks) - forcing ALLOW\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
    rm -f "$loop_guard_file"
    exit 0
  fi
  echo "$count" > "$loop_guard_file"
  echo "$1" >&2
  exit 2
}

allow() {
  rm -f "$loop_guard_file"
  exit 0
}

hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"
raw_agent_id="$(echo "$input" | jq -r '.agent_id // .agent_type // .session_id // "main"' 2>/dev/null || echo main)"

main_agent_name=""
if [ "$hook_event" != "SubagentStop" ]; then
  main_agent_name="$(jq -r '.mainAgent // "orchestrator"' "$config" 2>/dev/null || echo orchestrator)"
fi

mcc_script="$(dirname "${BASH_SOURCE[0]}")/marker-commit-check.sh"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/stop-gate-core.sh"
