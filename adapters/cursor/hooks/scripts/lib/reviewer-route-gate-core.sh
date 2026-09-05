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
# empty if none), prompt (the dispatch's raw prompt/instructions text,
# already extracted from the port's own field chain).
set -euo pipefail

if [ -f "$config" ] && [ -n "$target_type" ]; then
  identity_drift_log "$target_type" "$hook_event_label" "$review_audit"

  shopt -s nullglob
  pending_flags=( "${dot}"/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ]; then
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

if [ -f "$config" ] && persona_matches_gate "$target_type" reviewer; then
  if [ -n "$dispatch_name" ]; then
    dispatch_persona="$(identity_persona_name "$dispatch_name")"
    if [ "$dispatch_persona" != "reviewer" ]; then
      echo "BLOCKED: a reviewer dispatch must carry no \`name:\` parameter, or exactly \`name: \"reviewer\"\`. This dispatch's \`name: \"$dispatch_name\"\` will report an \`agent_type\` of '$dispatch_name', which fails the grant matcher. The reviewer will be unable to write its verdict marker or clear the pending-review flag. Fix: re-dispatch with no \`name\` at all, or (in agent-teams mode) with exactly \`name: \"reviewer\"\`." >&2
      exit 2
    fi
  fi

  first_line=""
  while IFS= read -r line; do
    if [ -n "${line//[[:space:]]/}" ]; then first_line="$line"; break; fi
  done <<< "$prompt"

  if [[ $first_line =~ ^Unit:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._#-]{0,63})[[:space:]]*$ ]]; then
    unit_id="${BASH_REMATCH[1]}"
    case "$unit_id" in
      */*|*..*) ;;
      *)
        second_line=""
        seen_first=false
        while IFS= read -r line; do
          [ -n "${line//[[:space:]]/}" ] || continue
          if [ "$seen_first" = true ]; then second_line="$line"; break; fi
          seen_first=true
        done <<< "$prompt"

        if [[ $second_line =~ ^Mode:[[:space:]]+advisory[[:space:]]*$ ]]; then
          audit_append "$review_audit" "advisory-dispatch=$unit_id"
          exit 0
        fi

        reviewed_dir="${dot}/reviewed"
        pass_marker="${reviewed_dir}/${unit_id}.pass"
        pass_valid=false
        if state_unit_marker_exists "$unit_id" pass; then
          first="$(state_read_unit_marker "$unit_id" "pass" 2>/dev/null)"
          case "$first" in
            "PASS ${unit_id} "*) pass_valid=true ;;
          esac
        fi
        if [ "$pass_valid" = false ]; then
          prior=none
          prior_mtime=-
          fail_marker="${reviewed_dir}/${unit_id}.fail"
          blocked_marker="${reviewed_dir}/${unit_id}.blocked"
          if state_unit_marker_exists "$unit_id" fail; then
            prior=fail
            fail_marker="${reviewed_dir}/${unit_id}.fail"
            prior_mtime="$(stat -L -c %Y "$fail_marker" 2>/dev/null || stat -L -f %m "$fail_marker" 2>/dev/null || echo -)"
          elif state_unit_marker_exists "$unit_id" blocked; then
            prior=blocked
            blocked_marker="${reviewed_dir}/${unit_id}.blocked"
            prior_mtime="$(stat -L -c %Y "$blocked_marker" 2>/dev/null || stat -L -f %m "$blocked_marker" 2>/dev/null || echo -)"
          fi
          stamp="${dot}/.review-join.${unit_id}"
          printf '%s unit=%s prior=%s prior_mtime=%s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$unit_id" "$prior" "$prior_mtime" > "$stamp" || true
          audit_append "$review_audit" "review-join=$unit_id"
        fi
        ;;
    esac
  fi
fi

exit 0
