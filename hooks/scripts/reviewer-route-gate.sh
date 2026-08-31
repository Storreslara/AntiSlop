#!/usr/bin/env bash
# PreToolUse (Agent). Mechanically enforces the "lead-programmer never spawns
# or messages the reviewer directly" rule from persona-protocol.md's Review
# Ownership section, instead of leaving it instruction-only. Also blocks
# dispatching the NEXT gated-agent unit while an earlier one still awaits
# review (the other half of the default-mode "done = reviewer PASS"
# backstop - stop-gate.sh sets/clears the flag this checks; see
# templates/persona-protocol.md's "Pending-review flag" section).
#
# A nested Agent-tool call carries both the CALLING agent's identity and the
# call's own tool_input: PreToolUse's JSON payload includes a top-level
# `agent_type` (the caller) alongside `tool_input.subagent_type` (the spawn
# target). Both fields carry an AGENT IDENTITY - a possibly-namespaced wire
# value like `antislop:reviewer` - while a PERSONA NAME is always bare, so
# neither may be compared as a bare string. Each side is normalized
# independently via lib/agent-identity.sh; both sites here are GATE sites,
# where a missed match fails OPEN, so both use the liberal matcher.
#
# ONE DELIBERATE EXCEPTION to that fail-OPEN direction: the caller ALLOWLIST for
# reviewer-targeted dispatches below fails CLOSED - an unrecognized caller is
# refused, not waved through. Do not "correct" it back. The invariant is
# positive ("only the orchestrator dispatches the reviewer"), and a blocklist
# would have to enumerate every generic identity forever (`general-purpose`,
# `Explore`, ...) while still leaving every persona able to spawn the reviewer.
# The closed direction applies ONLY when the target is `reviewer`, and the
# allowlist admits both main-session forms (empty agent_type, and
# `orchestrator`), so the review path cannot deadlock. See
# docs/plans/2026-08-12-reviewer-dispatch-caller-allowlist.md.
# This only covers the `Agent` tool (a direct spawn attempt); it does not
# cover SendMessage to an existing reviewer teammate in agent-teams mode -
# that's a different tool with a different payload shape, out of scope here.
#
# Claude entry point over the shared reviewer-route-gate gating logic
# (hooks/scripts/lib/reviewer-route-gate-core.sh) — sets Claude's payload
# contract then sources the port-invariant core. The two blocks below (lead-
# programmer-may-not-spawn-reviewer, caller allowlist) stay here rather than
# in the core: they key off the CALLING agent's identity, which only
# Claude's PreToolUse payload carries — see the core file's own header.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/harness-arm.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
dot="${project_dir}/.claude"
dot_label=".claude"
config="${dot}/persona-config.json"
review_audit="${dot}/review-audit.log"
harness_arm_or_deny "$project_dir" "$dot_label"

agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"
target_type="$(echo "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)"

# Only in an adapted project (the audit log is part of the review lifecycle
# this config declares). Empty identities are a no-op inside the library.
if [ -f "$config" ]; then
  identity_drift_log "$agent_type" "reviewer-route-gate" "$review_audit"
fi

if persona_matches_gate "$agent_type" "lead-programmer" \
   && persona_matches_gate "$target_type" "reviewer"; then
  echo "BLOCKED: lead-programmer may not spawn the reviewer directly. Report 'ready-for-review' and let the orchestrator (or team lead) route it, per persona-protocol.md's Review Ownership section." >&2
  exit 2
fi

# Caller allowlist (fails CLOSED - see the header). Empty agent_type is the main
# session with settings.json's .agent unset; `orchestrator` is the same session
# with it set, which ADAPT always does.
if persona_matches_gate "$target_type" "reviewer" \
   && [ -n "$agent_type" ] \
   && ! persona_matches_gate "$agent_type" "orchestrator"; then
  echo "BLOCKED: '$agent_type' may not spawn the reviewer - only the orchestrator (the main session) dispatches it, per persona-protocol.md's Review Ownership section. Likely cause: an \`Agent\` call with no \`subagent_type\`, which defaults to 'general-purpose'. If a gate refused a write and you are spawning a reviewer to perform it, that is a self-authorized bypass: report the block to the orchestrator and wait, per persona-protocol.md's \"Blocked by a gate you do not own\" section." >&2
  exit 2
fi

hook_event_label="reviewer-route-gate"
dispatch_name="$(echo "$input" | jq -r '.tool_input.name // empty' 2>/dev/null || true)"
prompt="$(echo "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/audit-log.sh"
source "${lib_dir}/reviewer-route-gate-core.sh"
