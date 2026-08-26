#!/usr/bin/env bash
# CODEX entry point over the shared reviewer-route-gate gating logic
# (generated from hooks/scripts/lib/reviewer-route-gate-core.sh - node
# bin/cli.js --update --force-render). Registered on `SubagentStart`. Sets
# codex's payload contract then sources the port-invariant core.
#
# IMPORTANT DEGRADATION (docs/specs/codex-plugin.md §6, §12 #2 - UNRESOLVED):
# Codex's `SubagentStart` payload is confirmed to carry `.agent_id`/
# `.agent_type` for the subagent being spawned (the SPAWN TARGET), but no
# field distinct from those has been confirmed to carry the CALLING agent's
# identity. So, same as the Cursor port, the "lead-programmer may not spawn
# the reviewer directly" block is NOT implementable here with confidence (we
# cannot distinguish a lead-programmer spawn of the reviewer from a
# legitimate orchestrator one). That half is therefore INSTRUCTION-ONLY on
# Codex - stated in the reviewer/lead-programmer/orchestrator bodies and
# agents-md-fragment.md.
#
# What IS still enforced mechanically: blocking the dispatch of the NEXT
# gated-agent unit (default lead-programmer) while an earlier completed unit
# still awaits review - the other half of the "done = reviewer PASS"
# backstop. stop-gate.sh sets/clears the `.codex/.pending-review.*` flag this
# checks.
#
# The spawn target's `.agent_type` may arrive namespaced ("<plugin>:<persona>"),
# so the gatedAgents comparison goes through lib/agent-identity.sh's LIBERAL
# matcher - this is a GATE, where a miss fails open and silently stops
# enforcing. A PERSONA NAME is always bare; an AGENT IDENTITY is the
# possibly-namespaced wire value the payload actually carries.
#
# REVIEW-JOIN STAMP - DEGRADED ON THIS PLATFORM (spec Step 3, porting Step 1).
# The Claude version reads the reviewer's dispatch prompt from
# `.tool_input.prompt` on a PreToolUse(Agent) payload and parses `Unit: <id>`
# off its first non-blank line. This platform's `SubagentStart` payload has NO
# DOCUMENTED prompt field - docs/specs/codex-plugin.md §2 row 5 / §6 lists only the spawn
# target's identity and records the shape as unresolved until probed live. The
# block below therefore reads a FALLBACK CHAIN of plausible field names, the
# same shape as the `.agent_id // .agent_type // .session_id` chain stop-gate.sh
# already uses for the unverified caller identity, and is UNVERIFIED here for
# the same reason. If none of them carries the prompt, no `Unit:` line is
# found, no stamp is written, and the stop-gate side fail-opens on bootstrap -
# i.e. exactly the behaviour that preceded this block, never a false block.
# Writing a stamp never changes this hook's exit status on any path.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo .)"
dot="${project_dir}/.codex"
dot_label=".codex"
config="${dot}/persona-config.json"
review_audit="${dot}/review-audit.log"

target_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

hook_event_label="SubagentStart"
dispatch_name="$(echo "$input" | jq -r '.name // empty' 2>/dev/null || true)"
prompt="$(echo "$input" | jq -r '.prompt // .instructions // .task // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/audit-log.sh"
source "${lib_dir}/reviewer-route-gate-core.sh"
