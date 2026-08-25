#!/usr/bin/env bash
# CURSOR entry point over the shared reviewer-route-gate gating logic
# (generated from hooks/scripts/lib/reviewer-route-gate-core.sh - node
# bin/cli.js --update --force-render). Registered on `subagentStart`, which
# "can allow or deny subagent creation" and carries the SPAWN TARGET's type
# (`.subagent_type`). Sets cursor's payload contract then sources the
# port-invariant core.
#
# IMPORTANT DEGRADATION (spec §6 open q #5): the Cursor `subagentStart` payload
# does NOT carry the CALLING agent's identity - only the target's
# `.subagent_type`. So the Claude version's "lead-programmer may not spawn the
# reviewer directly" block is NOT implementable here (we cannot distinguish a
# lead-programmer spawn of the reviewer from a legitimate orchestrator one).
# That half is therefore INSTRUCTION-ONLY on Cursor - stated in the reviewer
# and lead-programmer bodies and the persona-protocol rule. (Cursor's one-level
# subagent nesting also makes a subagent-spawns-subagent path unlikely in
# practice, but we do not rely on that.)
#
# What IS still enforced mechanically: blocking the dispatch of the NEXT gated-
# agent unit (default lead-programmer) while an earlier completed unit still
# awaits review - the other half of the "done = reviewer PASS" backstop.
# stop-gate.sh sets/clears the `.cursor/.pending-review.*` flag this checks.
#
# The spawn target may arrive namespaced ("<plugin>:<persona>"), so the
# gatedAgents comparison goes through lib/agent-identity.sh's LIBERAL matcher -
# this is a GATE, where a miss fails open and silently stops enforcing.
#
# REVIEW-JOIN STAMP - DEGRADED ON THIS PLATFORM (spec Step 3, porting Step 1).
# The Claude version reads the reviewer's dispatch prompt from
# `.tool_input.prompt` on a PreToolUse(Agent) payload and parses `Unit: <id>`
# off its first non-blank line. This platform's `subagentStart` payload has NO
# DOCUMENTED prompt field - docs/specs/codex-cursor-plugin.md row 10d lists only the spawn
# target's identity and records the shape as unresolved until probed live. The
# block below therefore reads a FALLBACK CHAIN of plausible field names, the
# same shape as the `.agent_id // .agent_type // .session_id` chain stop-gate.sh
# already uses for the unverified caller identity, and is UNVERIFIED here for
# the same reason. If none of them carries the prompt, no `Unit:` line is
# found, no stamp is written, and the stop-gate side fail-opens on bootstrap -
# i.e. exactly the behaviour that preceded this block, never a false block.
# Writing a stamp never changes this hook's exit status on any path.
set -euo pipefail

# shellcheck source=lib/agent-identity.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
dot="${project_dir}/.cursor"
dot_label=".cursor"
config="${dot}/persona-config.json"
review_audit="${dot}/review-audit.log"

target_type="$(echo "$input" | jq -r '.subagent_type // empty' 2>/dev/null || true)"

hook_event_label="subagentStart"
dispatch_name="$(echo "$input" | jq -r '.name // empty' 2>/dev/null || true)"
prompt="$(echo "$input" | jq -r '.prompt // .instructions // .task // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/reviewer-route-gate-core.sh"
