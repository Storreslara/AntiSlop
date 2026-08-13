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
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib/agent-identity.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
review_audit="${project_dir}/.claude/review-audit.log"

agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"
target_type="$(echo "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)"

# Only in an adapted project (the audit log is part of the review lifecycle
# this config declares). Empty identities are a no-op inside the library.
if [ -f "$config" ]; then
  identity_drift_log "$agent_type" "reviewer-route-gate" "$review_audit"
  identity_drift_log "$target_type" "reviewer-route-gate" "$review_audit"
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

if [ -f "$config" ]; then
  shopt -s nullglob
  pending_flags=( "${project_dir}"/.claude/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ]; then
    gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
    [ -n "$gated" ] || gated="lead-programmer"

    match=false
    while IFS= read -r name; do
      persona_matches_gate "$name" "$target_type" && match=true
    done <<< "$gated"

    if [ "$match" = true ]; then
      echo "BLOCKED: a completed unit is awaiting review - route it to the reviewer first, or use the defer:/skip: escape in the flag file (.claude/.pending-review.*), per persona-protocol.md's Pending-review flag section." >&2
      exit 2
    fi
  fi
fi


if persona_matches_gate "$target_type" "reviewer"; then
  dispatch_name="$(echo "$input" | jq -r '.tool_input.name // empty' 2>/dev/null || true)"
  if [ -n "$dispatch_name" ]; then
    dispatch_persona="$(identity_persona_name "$dispatch_name")"
    if [ "$dispatch_persona" != "reviewer" ]; then
      echo "BLOCKED: a reviewer dispatch must carry no \`name:\` parameter, or exactly \`name: \"reviewer\"\`. This dispatch's \`name: \"$dispatch_name\"\` will report an \`agent_type\` of '$dispatch_name', which fails the grant matcher. The reviewer will be unable to write its verdict marker or clear the pending-review flag. Fix: re-dispatch with no \`name\` at all, or (in agent-teams mode) with exactly \`name: \"reviewer\"\`." >&2
      exit 2
    fi
  fi

  prompt="$(echo "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)"
  first_line=""
  while IFS= read -r line; do
    if [ -n "${line//[[:space:]]/}" ]; then first_line="$line"; break; fi
  done <<< "$prompt"

  if [[ $first_line =~ ^Unit:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._#-]{0,63})[[:space:]]*$ ]]; then
    unit_id="${BASH_REMATCH[1]}"
    case "$unit_id" in
      */*|*..*) ;;
      *)
        if [ -f "$config" ]; then
          reviewed_dir="${project_dir}/.claude/reviewed"
          pass_marker="${reviewed_dir}/${unit_id}.pass"
          pass_valid=false
          if [ -f "$pass_marker" ] && [ -s "$pass_marker" ]; then
            first="$(head -n 1 "$pass_marker")"
            case "$first" in
              "PASS ${unit_id} "*) pass_valid=true ;;
            esac
          fi
          if [ "$pass_valid" = false ]; then
            prior=none
            prior_mtime=-
            fail_marker="${reviewed_dir}/${unit_id}.fail"
            blocked_marker="${reviewed_dir}/${unit_id}.blocked"
            if [ -f "$fail_marker" ]; then
              prior=fail
              prior_mtime="$(stat -L -c %Y "$fail_marker" 2>/dev/null || stat -L -f %m "$fail_marker" 2>/dev/null || echo -)"
            elif [ -f "$blocked_marker" ]; then
              prior=blocked
              prior_mtime="$(stat -L -c %Y "$blocked_marker" 2>/dev/null || stat -L -f %m "$blocked_marker" 2>/dev/null || echo -)"
            fi
            stamp="${project_dir}/.claude/.review-join.${unit_id}"
            printf '%s unit=%s prior=%s prior_mtime=%s\n' \
              "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$unit_id" "$prior" "$prior_mtime" > "$stamp" || true
            printf 'review-join=%s\n' "$unit_id" >> "$review_audit" || true
          fi
        fi
        ;;
    esac
  fi
fi
exit 0
