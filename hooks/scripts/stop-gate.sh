#!/usr/bin/env bash
# Registered on Stop (main session) AND SubagentStop with NO matcher -
# gating which agents this actually checks is config-driven via
# persona-config.json's gatedAgents list (default: ["lead-programmer"]),
# not the hook registration. Adding a future code-writing persona is a
# config edit, not a plugin file edit. Confirmed empirically that the
# SubagentStop payload carries `agent_type`, so this filtering is reliable
# for SubagentStop. The plain Stop payload (main session) carries NO
# agent_type at all, so for Stop this filtering instead keys off the
# configured main agent (settings.json's `.agent`, default "orchestrator",
# per templates/settings-fragment.json) - a static, per-project value, not
# a per-event field. With the default config (main agent = orchestrator,
# gatedAgents = ["lead-programmer"]) this means the main-session check is
# skipped entirely: the orchestrator has no Write/Edit tools (see its
# `tools:` frontmatter) and cannot dirty the tree itself, so a dirty tree at
# orchestrator-Stop time can only mean a dispatched subagent is mid-flight -
# and that subagent is already gated independently at its own SubagentStop.
# A project that makes a code-writing persona the main agent still gets
# gated correctly, since gatedAgents is checked against that agent's name.
#
# Logic, in order:
#  0) stop_hook_active guard - never re-trigger ourselves in a loop.
#  0.5) reviewer's own SubagentStop -> CLEAR every .claude/.pending-review.*
#     flag (PASS or FAIL - a reviewer having run is what the flag tracks,
#     not the verdict), log `cleared-by=reviewer`, ALLOW. Runs before the
#     gatedAgents early-exit below, which would otherwise skip reviewer
#     stops entirely since "reviewer" is not normally in gatedAgents.
#  0.75) main-session Stop with any pending-review flag present -> BLOCK
#     (exit 2), checked BEFORE the gatedAgents early-exit at step 1, since
#     the default orchestrator is deliberately non-gated but must still be
#     stopped from ending the turn while a unit awaits review. Escape hatch
#     mirrors the WIP sentinel: overwrite the flag's content with
#     "defer: <reason>" (logged, flag KEPT, this one Stop allowed) or
#     "skip: <reason>" (logged, flag DELETED, unit abandoned) - a
#     reason-less overwrite is rejected the same way an empty WIP sentinel
#     is at step 2.
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
#     honored by a WIP sentinel at step 2) -> SET
#     .claude/.pending-review.<agent_id>, regardless of whether step 3/4
#     below then allows or blocks this same stop. This is the default-mode
#     "done = reviewer PASS" backstop: a hook cannot force the orchestrator's
#     next action, but it can block turn-end (here) and the next
#     implementation dispatch (reviewer-route-gate.sh) while the flag stands.
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
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
review_audit="${project_dir}/.claude/review-audit.log"

stop_active="$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
[ "$stop_active" = "true" ] && exit 0

hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

if [ "$hook_event" = "SubagentStop" ] && [ "$agent_type" = "reviewer" ]; then
  [ -f "$config" ] || exit 0
  rm -f "${project_dir}"/.claude/.pending-review.* 2>/dev/null || true
  printf '%s cleared-by=reviewer\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
  exit 0
fi

if [ "$hook_event" = "Stop" ]; then
  shopt -s nullglob
  pending_flags=( "${project_dir}"/.claude/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ]; then
    blocked=false
    for flag in "${pending_flags[@]}"; do
      [ -f "$flag" ] || continue
      flag_content="$(cat "$flag" 2>/dev/null || true)"
      case "$flag_content" in
        "defer: "*)
          printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$flag_content" >> "$review_audit"
          ;;
        "skip: "*)
          printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$flag_content" >> "$review_audit"
          rm -f "$flag"
          ;;
        *)
          blocked=true
          ;;
      esac
    done
    if [ "$blocked" = true ]; then
      echo "A completed unit is awaiting review - spawn the reviewer (persona-protocol.md's Review Ownership section) before ending the turn. Escape hatch: overwrite the flag's content with a reason, e.g. 'printf \"defer: <reason>\\n\" > .claude/.pending-review.<agent-id>' (kept, review still owed next turn) or 'printf \"skip: <reason>\\n\" > .claude/.pending-review.<agent-id>' (deleted, unit abandoned) - a reason-less overwrite is rejected the same way an empty WIP sentinel is." >&2
      exit 2
    fi
    exit 0
  fi
fi

if [ "$hook_event" = "Stop" ] || [ "$hook_event" = "SubagentStop" ]; then
  [ -f "$config" ] || exit 0
  gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
  [ -n "$gated" ] || gated="lead-programmer"

  if [ "$hook_event" = "SubagentStop" ]; then
    check_name="$agent_type"
  else
    settings="${project_dir}/.claude/settings.json"
    check_name="$(jq -r '.agent // "orchestrator"' "$settings" 2>/dev/null || echo orchestrator)"
  fi

  match=false
  while IFS= read -r name; do
    [ -n "$name" ] && [ "$name" = "$check_name" ] && match=true
  done <<< "$gated"
  [ "$match" = true ] || exit 0
fi

raw_agent_id="$(echo "$input" | jq -r '.agent_id // .session_id // "main"' 2>/dev/null || echo main)"
agent_id="${raw_agent_id//[^a-zA-Z0-9._-]/_}"
sentinel="${project_dir}/.claude/wip-handoff.${agent_id}"

if [ -f "$sentinel" ]; then
  if [ -s "$sentinel" ]; then
    reason="$(cat "$sentinel")"
    printf '%s agent=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$reason" \
      >> "${project_dir}/.claude/wip-audit.log"
    rm -f "$sentinel"
    exit 0
  fi
  echo "WIP sentinel at ${sentinel} is empty - a reason is required (e.g. 'echo \"blocked on X\" > ${sentinel}'). Ignoring it and running the normal check instead." >&2
  rm -f "$sentinel"
fi

if [ "$hook_event" = "SubagentStop" ]; then
  pending_flag="${project_dir}/.claude/.pending-review.${agent_id}"
  printf '%s agent=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" > "$pending_flag"
fi

dirty=false
[ -n "$(git -C "$project_dir" status --porcelain 2>/dev/null || true)" ] && dirty=true

raw_session_id="$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
session_id="${raw_session_id//[^a-zA-Z0-9._-]/_}"
baseline_file="${project_dir}/.claude/.session-baseline.${session_id}"

moved=false
if [ -f "$baseline_file" ]; then
  baseline_sha="$(cat "$baseline_file" 2>/dev/null || true)"
  current_sha="$(git -C "$project_dir" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$baseline_sha" ] && [ -n "$current_sha" ] && [ "$baseline_sha" != "$current_sha" ]; then
    moved=true
  fi
fi

if [ "$dirty" = false ] && [ "$moved" = false ]; then
  exit 0
fi

[ -f "$config" ] || exit 0
check_cmd="$(jq -r '.testAndLintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$check_cmd" ] || exit 0

tmp_out="$(mktemp)"
if ! (cd "$project_dir" && eval "$check_cmd") >"$tmp_out" 2>&1; then
  echo "Test/lint check failed - fix before ending the turn, or 'echo \"<reason>\" > ${sentinel}' if this is a legitimate mid-task pause (TDD red phase, blocked report, plan-is-wrong escalation). The sentinel must contain a reason - an empty file is ignored." >&2
  cat "$tmp_out" >&2
  rm -f "$tmp_out"
  exit 2
fi
rm -f "$tmp_out"
exit 0
