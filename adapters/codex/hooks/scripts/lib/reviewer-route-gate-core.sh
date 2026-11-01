#!/usr/bin/env bash
# Port-invariant decision logic for reviewer-route-gate.sh, shared
# byte-for-byte by all three ports (Claude/codex/cursor) — hand-edit only
# here; adapters/*/hooks/scripts/lib/reviewer-route-gate-core.sh are
# generated copies (node bin/cli.js --update --force-render). Sourced,
# never executed. The caller must have already sourced lib/agent-identity.sh
# (persona_matches_gate, identity_persona_name, identity_drift_log).
#
# NOT covered here: the "lead-programmer may not spawn the reviewer
# directly" block and the caller allowlist. Both key off the CALLING agent's
# identity, which only Claude's payload carries (PreToolUse's top-level
# `agent_type` alongside `tool_input.subagent_type`) — codex/cursor cannot
# distinguish a lead-programmer spawn of the reviewer from a legitimate
# orchestrator one, so that half stays INSTRUCTION-ONLY there (see each
# port's own entry script header). Those two blocks therefore run in the
# Claude entry script BEFORE this core is sourced, not in here.
#
# Caller contract (set before sourcing): project_dir, dot (absolute path to
# the port's own dot-dir, e.g. "${project_dir}/.claude"), dot_label (that
# same dot-dir's relative form, e.g. ".claude", used only in user-facing
# messages), config (absolute path to persona-config.json), review_audit
# (absolute path to review-audit.log), hook_event_label (string passed as
# identity_drift_log's event-name argument — each port's own label for this
# hook site), target_type (the spawn target's raw identity from the port's
# own payload field), dispatch_name (the dispatch's raw `name` field value,
# empty if none).
set -euo pipefail

if [ -f "$config" ] && [ -n "$target_type" ]; then
  identity_drift_log "$target_type" "$hook_event_label" "$review_audit"

  shopt -s nullglob
  pending_flags=( "${dot}"/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ] && ! [ "$(jq -r '.reviewGating.mode // "enforce"' "$config" 2>/dev/null || echo enforce)" = "off" ]; then
    gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
    [ -n "$gated" ] || gated="lead-programmer"

    # Liberal on both sides: a miss here fails OPEN (the next gated unit
    # dispatches while review is owed).
    match=false
    while IFS= read -r name; do
      [ -n "$name" ] && persona_matches_gate "$name" "$target_type" && match=true
    done <<< "$gated"

    if [ "$match" = true ]; then
      echo "BLOCKED: a completed unit is awaiting review - route it to the reviewer first, or use the defer:/skip: escape in the flag file (${dot_label}/.pending-review.*), per persona-protocol.md's Pending-review flag section." >&2
      exit 2
    fi
  fi
fi

# C1: unconditional dispatch-`name:` identity-forgery check. A `name:` field
# resolving to a privileged persona must not be paired with a `subagent_type`
# that doesn't match it - that's identity forgery, regardless of which
# target_type-keyed block below would otherwise apply. Runs before every
# target_type-keyed block; not gated on $config, unlike them. See
# tests/reviewer-route-gate-caller.test.sh's derivation test for why this
# array's membership is not a restatement to be edited freely.
PRIVILEGED_PERSONAS=(reviewer orchestrator)
if [ -n "$dispatch_name" ]; then
  dispatch_persona="$(identity_persona_name "$dispatch_name")"
  is_privileged=false
  for p in ${PRIVILEGED_PERSONAS[@]+"${PRIVILEGED_PERSONAS[@]}"}; do
    if [ "$dispatch_persona" = "$p" ]; then
      is_privileged=true
      break
    fi
  done
  if [ "$is_privileged" = true ] && ! persona_matches_gate "$target_type" "$dispatch_persona"; then
    echo "BLOCKED: this dispatch's \`name: \"$dispatch_name\"\` resolves to the privileged persona '$dispatch_persona', but its \`subagent_type\` ('$target_type') does not match it. A \`name:\` field cannot be used to forge a privileged identity. Fix: re-dispatch with a \`name\` matching the actual \`subagent_type\`, or drop \`name\` entirely." >&2
    exit 2
  fi
fi

if [ -f "$config" ] && persona_matches_gate "$target_type" reviewer; then
  if [ -n "$dispatch_name" ]; then
    dispatch_persona="$(identity_persona_name "$dispatch_name")"
    if [ "$dispatch_persona" != "reviewer" ]; then
      echo "BLOCKED: a reviewer dispatch must carry no \`name:\` parameter, or exactly \`name: \"reviewer\"\`. This dispatch's \`name: \"$dispatch_name\"\` will report an \`agent_type\` of '$dispatch_name', which fails the grant matcher. The reviewer will be unable to write its verdict marker or clear the pending-review flag. Fix: re-dispatch with no \`name\` at all, or (in agent-teams mode) with exactly \`name: \"reviewer\"\`." >&2
      exit 2
    fi
  fi

  # The allowed reviewer dispatch marks each plain flag `review-dispatched: <ts>` (old content kept
  # below), so the main Stop passes while it runs. Only a target whose SubagentStop clears the flags
  # (persona_matches_grant, as in stop-gate-core.sh) marks them; a failed rewrite leaves the flag
  # plain, so that Stop still blocks. The tmp name sits outside the .pending-review.* glob.
  if persona_matches_grant "$target_type" reviewer \
     && ! [ "$(jq -r '.reviewGating.mode // "enforce"' "$config" 2>/dev/null || echo enforce)" = "off" ]; then
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    marked=0
    for flag in "${dot}"/.pending-review.*; do
      [ -f "$flag" ] || continue
      case "$(head -n 1 "$flag" 2>/dev/null || true)" in
        "defer: "*|"skip: "*|"review-dispatched: "*) continue ;;
      esac
      tmp="$(mktemp "${dot}/.review-dispatched-tmp.XXXXXX" 2>/dev/null)" || continue
      if { printf 'review-dispatched: %s\n' "$ts" && cat "$flag"; } > "$tmp" 2>/dev/null \
         && mv -f "$tmp" "$flag" 2>/dev/null; then
        marked=$((marked + 1))
      else
        rm -f "$tmp" 2>/dev/null || true
      fi
    done
    [ "$marked" -eq 0 ] || audit_append "$review_audit" "${ts} review-dispatched flags=${marked}"
  fi
fi

exit 0
