#!/usr/bin/env bash
# Registered on Stop (main session) AND SubagentStop with NO matcher -
# gating which agents this actually checks is config-driven via
# persona-config.json's gatedAgents list (default: ["lead-programmer"]),
# not the hook registration. Adding a future code-writing persona is a
# config edit, not a plugin file edit. The SubagentStop payload carries an
# `agent_type`, so this filtering is reliable for SubagentStop. The plain
# Stop payload (main session) carries NO agent_type at all, so for Stop this
# filtering instead keys off the configured main agent (settings.json's
# `.agent`, default "orchestrator", per templates/settings-fragment.json) -
# a static, per-project value, not a per-event field. With the default config (main agent = orchestrator,
# gatedAgents = ["lead-programmer"]) this means the main-session check is
# skipped entirely: the orchestrator has no Write/Edit tools (see its
# `tools:` frontmatter) and cannot dirty the tree itself, so a dirty tree at
# orchestrator-Stop time can only mean a dispatched subagent is mid-flight -
# and that subagent is already gated independently at its own SubagentStop.
# A project that makes a code-writing persona the main agent still gets
# gated correctly, since gatedAgents is checked against that agent's identity.
#
# Identity vocabulary (contract in hooks/scripts/lib/agent-identity.sh): a
# PERSONA NAME is bare ("reviewer"); an AGENT IDENTITY is the possibly
# namespaced wire value ("antislop:reviewer"); `agent_type`, `subagent_type`
# and settings.json's `.agent` are the three FIELDS that carry an identity.
# No field is assumed to arrive bare. Gate comparisons canonicalize BOTH
# sides liberally (persona_matches_gate) because a miss there fails OPEN -
# so gatedAgents entries and `.agent` may be written in either form. The
# reviewer's privilege to clear pending-review flags is instead granted
# conservatively (persona_matches_grant), only to an identity resolving to
# this plugin's own namespace: a miss there fails CLOSED, which is loud and
# recoverable. Identities whose form cannot be attributed are recorded in
# .claude/review-audit.log as identity-drift lines.
#
# Logic, in order:
#  0) stop_hook_active guard - never re-trigger ourselves in a loop.
#  0.5) reviewer's own SubagentStop -> if any .claude/reviewed/*.blocked
#     marker stands (an INSUFFICIENT-CONTEXT verdict), do NOT clear the
#     pending-review flags: log `verdict=blocked flags-kept` and ALLOW, so
#     turn-end/next-gated-dispatch stay blocked until a real PASS/FAIL
#     resolves the unit (the reviewer deletes the .blocked marker then). A
#     .claude/reviewed/*.escalated marker (an ESCALATE-TO-HUMAN verdict) does
#     the same, logging `verdict=escalated flags-kept` instead - a DISTINCT
#     token, so "the reviewer lacked context" and "policy wanted human eyes"
#     stay apart in the audit log; both globs are checked and both log, so one
#     never masks the other. `.directed` is DELIBERATELY absent from both
#     globs: it records a human decision the fix still has to be dispatched
#     for, and only the flags clearing lets that dispatch through - adding it
#     here would deadlock the very route it exists to open. Otherwise consult
#     the PER-UNIT review-join stamps that
#     reviewer-route-gate.sh wrote at dispatch time (one
#     .claude/.review-join.<unit-id> per unit this reviewer was dispatched
#     for). A stamp is SATISFIED when a format-valid `PASS <id> ` / `FAIL <id> `
#     marker exists for that unit and, where the stamp recorded a prior_mtime,
#     the marker is strictly newer than it. Then: no stamps at all -> fail OPEN,
#     log `marker-check=bootstrap`; at least one satisfied -> delete every
#     satisfied stamp, log one `join-consumed=<id>` per deletion; stamps exist
#     and none is satisfied -> log `cleared-by=reviewer marker=MISSING
#     unit=<id>` per unsatisfied stamp and BLOCK (exit 2). On the two allowing
#     paths, CLEAR every .claude/.pending-review.* flag (PASS or FAIL - a
#     reviewer having run is what the flag tracks, not the verdict) and log
#     `cleared-by=reviewer`. Unsatisfied stamps are never deleted here, so a
#     later stop that does carry the verdict still consumes them. Keying the
#     join per UNIT is what lets two reviewers running concurrently each make
#     progress; the global watermark this replaced could not, since one
#     reviewer's clear silently satisfied every other reviewer's check and any
#     second stop by the same reviewer blocked. Runs before the gatedAgents
#     early-exit below, which would otherwise skip reviewer stops entirely
#     since "reviewer" is not normally in gatedAgents.
#  0.75) main-session Stop with any pending-review flag present -> BLOCK
#     (exit 2), checked BEFORE the gatedAgents early-exit at step 1, since
#     the default orchestrator is deliberately non-gated but must still be
#     stopped from ending the turn while a unit awaits review. Escape hatch
#     mirrors the WIP sentinel: overwrite the flag's content with
#     "defer: <reason>" (logged, flag KEPT - sticky: every subsequent Stop
#     is allowed too, until the reviewer's SubagentStop clears the flag or
#     a skip: deletes it; review is still owed) or "skip: <reason>" (logged,
#     flag DELETED, unit abandoned) - a reason-less overwrite is rejected the
#     same way an empty WIP sentinel is at step 2.
#  1) Stop for a non-gated main agent, or SubagentStop for a non-gated
#     agent -> ALLOW immediately (cheap/high-frequency personas like
#     explorer never pay this cost, and the default orchestrator-as-main
#     case never pays it either).
#  2) per-agent WIP sentinel -> if it holds a non-empty reason, log it to
#     .claude/wip-audit.log, delete it, ALLOW. An empty sentinel (bare
#     `touch`, no stated reason) is rejected: deleted but NOT honored, so it
#     falls through to the normal check instead of silently bypassing it.
#     This is a friction/audit-trail fix, not a guarantee against abuse - a
#     determined agent can still write a bogus reason - but it closes the
#     silent, invisible bare-touch bypass that existed before.
#  2.5) a gated agent's SubagentStop that reaches this point (i.e. NOT
#     honored by a WIP sentinel at step 2) -> CREATE
#     .claude/.pending-review.<agent_id> if it doesn't already exist,
#     regardless of whether step 3/4 below then allows or blocks this same
#     stop. Idempotent by design: a unit with multiple check-in SubagentStops
#     (e.g. a long-running lead-programmer resumed several times) must not
#     have a later check-in's flag-creation clobber a defer:/skip: reason the
#     main session already wrote into the flag at step 0.75 - only the first
#     SubagentStop for a given agent_id creates the flag; subsequent ones are
#     no-ops here. This is the default-mode "done = reviewer PASS" backstop:
#     a hook cannot force the orchestrator's next action, but it can block
#     turn-end (here) and the next implementation dispatch
#     (reviewer-route-gate.sh) while the flag stands.
#  3) tree clean AND no commits since this session's baseline -> ALLOW.
#  4) otherwise run the configured test+lint command; non-zero exit -> BLOCK.
# Step 3's baseline check closes a gap where a lead-programmer that commits
# per-step (tree clean at handoff) would otherwise never actually hit the
# check - the reviewer independently re-runs checks before PASS regardless,
# so this is defense-in-depth, not the only safety net.
#
# Honest limit (same framing as the WIP sentinel): this cannot force the
# orchestrator's next action. `rm -f .claude/.pending-review.*` via Bash
# remains possible; `.claude/review-audit.log` is the deterrent, not a
# guarantee.
#
# Claude entry point over the shared stop-gate decision logic
# (hooks/scripts/lib/stop-gate-core.sh) — sets Claude's payload contract
# (project dir, dot-dir, field names, loop guard) then sources the
# port-invariant core.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/audit-log.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/harness-arm.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
dot="${project_dir}/.claude"
dot_label=".claude"
config="${dot}/persona-config.json"
review_audit="${dot}/review-audit.log"
harness_arm_or_deny "$project_dir" "$dot_label"

block() { echo "$1" >&2; exit 2; }
allow() { exit 0; }

stop_active="$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
[ "$stop_active" = "true" ] && allow

hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"
raw_session_id="$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
raw_agent_id="$(echo "$input" | jq -r '.agent_id // .session_id // "main"' 2>/dev/null || echo main)"

main_agent_name=""
if [ "$hook_event" != "SubagentStop" ]; then
  settings="${dot}/settings.json"
  main_agent_name="$(jq -r '.agent // "orchestrator"' "$settings" 2>/dev/null || echo orchestrator)"
fi

mcc_script="$(dirname "${BASH_SOURCE[0]}")/marker-commit-check.sh"
harness_integrity_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/bin/harness-integrity.sh"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/stop-gate-core.sh"
