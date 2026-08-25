#!/usr/bin/env bash
# Port-invariant decision logic for stop-gate.sh, shared byte-for-byte by all
# three ports (Claude/codex/cursor) — hand-edit only here;
# adapters/*/hooks/scripts/lib/stop-gate-core.sh are generated copies (node
# bin/cli.js --update --force-render). Sourced, never executed. The caller
# must have already sourced lib/agent-identity.sh (persona_matches_gate,
# persona_matches_grant, identity_persona_name, identity_drift_log,
# _identity_sanitize).
#
# Caller contract (set before sourcing):
#  - project_dir, dot (absolute path to the port's own dot-dir, e.g.
#    "${project_dir}/.claude"), dot_label (that dot-dir's relative form, e.g.
#    ".claude" — used only in user-facing messages), config, review_audit
#    (absolute paths).
#  - hook_event, NORMALIZED to exactly "Stop" or "SubagentStop" regardless of
#    the port's own native casing (Cursor's payload is lower/mixed-case
#    "stop"/"subagentStop" — the entry script maps it before sourcing).
#  - agent_type: the (sub)agent identity from the port's own field
#    (`.agent_type` on Claude/codex, `.subagent_type` on Cursor).
#  - raw_session_id, raw_agent_id: raw, unsanitized values already resolved
#    through the port's own field/fallback chain (e.g. codex's raw_agent_id
#    chain is `.agent_id // .agent_type // .session_id // "main"`, distinct
#    from Claude's `.agent_id // .session_id // "main"`) — sanitization
#    itself (strip to `[a-zA-Z0-9._-]`) is port-invariant and happens here.
#  - main_agent_name: the resolved main-agent identity to use as `check_name`
#    on a plain "Stop" event, ALREADY resolved via the port's own source
#    (Claude reads settings.json's `.agent`, codex/cursor read
#    persona-config.json's `.mainAgent`) — may be left unset/empty on a
#    "SubagentStop" event, since it is only read when hook_event = "Stop".
#  - mcc_script: absolute path to marker-commit-check.sh, resolved by the
#    entry script's OWN `${BASH_SOURCE[0]}` (this file is sourced from
#    hooks/scripts/lib/, one directory below the entry script, so this path
#    cannot be recomputed correctly from inside the core itself). May not
#    exist (no codex/cursor port of marker-commit-check.sh) — handled by the
#    existing `[ -x "$mcc_script" ]` check below.
#  - block() and allow(): shell functions the caller defines BEFORE sourcing.
#    Every terminal decision below routes through one of these two, rather
#    than a bare `exit`, because the loop-guard MECHANISM itself is port-
#    specific: Claude's `stop_hook_active` and Cursor's `.loop_count` are
#    proactive (checked once, before this core is even sourced), while
#    Codex has no documented equivalent field and instead self-tracks
#    consecutive blocks in its own `block()`/`allow()` (see its entry
#    script). Claude/Cursor's versions are the trivial
#    `block() { echo "$1" >&2; exit 2; }` / `allow() { exit 0; }`.
set -euo pipefail

# review-join: a marker counts only for the unit whose stamp names it. The
# stamps are written at dispatch time by reviewer-route-gate.sh because the
# SubagentStop payload carries no unit id and no prompt - the join cannot be
# established here, only consumed.

# marker_format_valid <path> <unit-id> <verb> - mirrors task-gate.sh's
# marker_valid(), so both mechanisms share one definition of "a marker was
# written": the file must exist, be non-empty, and its first line must begin
# "<verb> <unit-id> ". Prefix-only, so no pre-existing marker is retroactively
# rejected; a zero-byte `touch` is.
marker_format_valid() {
  local path="$1" unit="$2" verb="$3" first_line
  [ -f "$path" ] && [ -s "$path" ] || return 1
  first_line="$(head -n 1 "$path" 2>/dev/null || true)"
  case "$first_line" in
    "${verb} ${unit} "*) return 0 ;;
    *) return 1 ;;
  esac
}

# review_join_state <dot-dir> - classifies every .review-join.* stamp into the
# JOIN_* globals below. A stamp that is unreadable, or whose `unit=` field is
# absent or malformed, is deleted here and counted as satisfied (fail OPEN): it
# names no unit, so it could never be satisfied later and would deadlock the
# reviewer permanently instead.
review_join_state() {
  local dot="$1" stamp line unit prior_mtime pair ext verb mpath mtime satisfied
  local -a stamps
  JOIN_SATISFIED_STAMPS=()
  JOIN_SATISFIED_UNITS=()
  JOIN_UNSATISFIED_UNITS=()
  JOIN_FAILOPEN=false

  shopt -s nullglob
  stamps=( "$dot"/.review-join.* )
  shopt -u nullglob
  JOIN_STAMP_COUNT="${#stamps[@]}"
  [ "$JOIN_STAMP_COUNT" -gt 0 ] || return 0

  for stamp in "${stamps[@]}"; do
    line=""
    if [ -r "$stamp" ]; then
      line="$(head -n 1 "$stamp" 2>/dev/null || true)"
    fi

    unit=""
    if [[ $line =~ (^|[[:space:]])unit=([A-Za-z0-9][A-Za-z0-9._#-]{0,63})([[:space:]]|$) ]]; then
      unit="${BASH_REMATCH[2]}"
    fi
    # Same traversal guard reviewer-route-gate.sh applies before it writes the
    # id, re-applied on read: the stamp file is not a trusted channel.
    case "$unit" in
      ''|*/*|*..*)
        rm -f "$stamp" 2>/dev/null || true
        JOIN_FAILOPEN=true
        continue
        ;;
    esac

    prior_mtime=""
    if [[ $line =~ (^|[[:space:]])prior_mtime=([^[:space:]]+) ]]; then
      prior_mtime="${BASH_REMATCH[2]}"
    fi

    satisfied=false
    for pair in pass:PASS fail:FAIL; do
      ext="${pair%%:*}"
      verb="${pair##*:}"
      mpath="${dot}/reviewed/${unit}.${ext}"
      if ! marker_format_valid "$mpath" "$unit" "$verb"; then
        continue
      fi
      case "$prior_mtime" in
        ''|*[!0-9]*)
          # No usable prior_mtime recorded (a first review writes `-`): any
          # format-valid marker satisfies the stamp.
          satisfied=true
          ;;
        *)
          mtime="$(stat -L -c %Y "$mpath" 2>/dev/null || stat -L -f %m "$mpath" 2>/dev/null || true)"
          case "$mtime" in
            ''|*[!0-9]*) ;;
            *)
              # Never run `[ a -gt b ]` on unvalidated text: a non-numeric
              # operand is a `test` syntax error, and under set -e that aborts
              # the hook silently rather than failing the check.
              if [ "$mtime" -gt "$prior_mtime" ]; then
                satisfied=true
              fi
              ;;
          esac
          ;;
      esac
      if [ "$satisfied" = true ]; then
        break
      fi
    done

    if [ "$satisfied" = true ]; then
      JOIN_SATISFIED_STAMPS+=( "$stamp" )
      JOIN_SATISFIED_UNITS+=( "$unit" )
    else
      JOIN_UNSATISFIED_UNITS+=( "$unit" )
    fi
  done
}

identity_drift_log "$agent_type" "$hook_event" "$review_audit"

if [ "$hook_event" = "SubagentStop" ] && [ "$(identity_persona_name "$agent_type")" = "reviewer" ]; then
  if persona_matches_grant "$agent_type" reviewer; then
    [ -f "$config" ] || allow
    shopt -s nullglob
    blocked_markers=( "${dot}"/reviewed/*.blocked )
    escalated_markers=( "${dot}"/reviewed/*.escalated )
    shopt -u nullglob
    # Two independent logs, not an if/elif: a unit blocked and another escalated
    # in the same reviewer turn must both appear, or the audit log cannot tell
    # "the reviewer lacked context" from "policy wanted human eyes" afterwards.
    if [ "${#blocked_markers[@]}" -gt 0 ]; then
      printf '%s verdict=blocked flags-kept\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
    fi
    if [ "${#escalated_markers[@]}" -gt 0 ]; then
      printf '%s verdict=escalated flags-kept\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
    fi
    if [ "${#blocked_markers[@]}" -gt 0 ] || [ "${#escalated_markers[@]}" -gt 0 ]; then
      allow
    fi

    # Per-unit review-join, evaluated after the .blocked early-exit above and
    # before the flag rm -f below, so a blocked verdict still short-circuits.
    review_join_state "$dot"

    if [ "${JOIN_STAMP_COUNT:-0}" -eq 0 ]; then
      # Nothing joined this reviewer to a unit - an un-stamped dispatch, or a
      # unit that already held a valid PASS. Fail OPEN, as bootstrap did.
      printf '%s marker-check=bootstrap\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
    elif [ "${#JOIN_SATISFIED_STAMPS[@]}" -gt 0 ] || [ "${JOIN_FAILOPEN:-false}" = true ]; then
      # marker-commit-check: classify each satisfied unit's PASS marker
      # `commit:` field before its stamp is consumed. Advisory - see
      # docs/plans/2026-08-15-marker-commit-attribution.md Step 7.
      mcc_mode="$(jq -r '.markerCommitCheck.mode // "warn"' "$config" 2>/dev/null || echo warn)"
      case "$mcc_mode" in off|warn|block) ;; *) mcc_mode=warn ;; esac
      idx=0
      while [ "$idx" -lt "${#JOIN_SATISFIED_STAMPS[@]}" ]; do
        unit="${JOIN_SATISFIED_UNITS[$idx]}"
        if [ "$mcc_mode" != off ]; then
          mcc_state=unavailable
          mcc_out=""
          if [ -x "$mcc_script" ]; then
            mcc_out="$("$mcc_script" "$unit" "$project_dir" 2>/dev/null || true)"
          fi
          if [[ $mcc_out =~ ^marker-commit-check=([a-z]+)[[:space:]] ]]; then
            mcc_state="${BASH_REMATCH[1]}"
          fi
          printf '%s marker-commit-check=%s unit=%s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$mcc_state" "$unit" >> "$review_audit"
          if [ "$mcc_state" = mismatch ]; then
            echo "marker-commit-check: unit ${unit}'s PASS marker cites a commit that does not appear to belong to it - ${mcc_out}" >&2
            if [ "$mcc_mode" = block ]; then
              echo "Remediation: correct the commit: field in ${dot_label}/reviewed/${unit}.pass to name the unit's own final commit, then re-run." >&2
              exit 2
            fi
          fi
        fi
        rm -f "${JOIN_SATISFIED_STAMPS[$idx]}" 2>/dev/null || true
        printf '%s join-consumed=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          "${JOIN_SATISFIED_UNITS[$idx]}" >> "$review_audit"
        idx=$(( idx + 1 ))
      done
    else
      missing=""
      idx=0
      while [ "$idx" -lt "${#JOIN_UNSATISFIED_UNITS[@]}" ]; do
        printf '%s cleared-by=reviewer marker=MISSING unit=%s\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${JOIN_UNSATISFIED_UNITS[$idx]}" >> "$review_audit"
        missing="${missing:+$missing, }${JOIN_UNSATISFIED_UNITS[$idx]}"
        idx=$(( idx + 1 ))
      done
      block "No verdict is recorded for the unit(s) you were dispatched for: ${missing}. A v3 PASS or FAIL marker must be written for each, first line exactly:
  printf 'PASS <unit-id> %s commit: %s criteria: bash tests/validate.sh\\n' '$(date -u +%Y-%m-%dT%H:%M:%SZ)' '<the unit's own final commit, not HEAD>' > ${dot_label}/reviewed/<unit-id>.pass
The only two legal responses to this block are writing the genuine verdict you actually reached, or reporting the situation and waiting; touching a file's mtime - or writing a marker you do not believe - to satisfy this check is a violation, not a workaround."
    fi

    rm -f "${dot}"/.pending-review.* 2>/dev/null || true
    printf '%s cleared-by=reviewer\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
    allow
  fi
  # Clearing review flags is a privilege granted only to this project's own
  # reviewer, so a foreign namespace falls through with the flags standing.
  # That is a deadlock a human has to break, so say so here rather than
  # leaving only the identity-drift audit line above.
  # Log grant-denied if pending-review flags are standing
  shopt -s nullglob
  pending_flags_check=( "${dot}"/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags_check[@]}" -gt 0 ]; then
    { printf '%s grant-denied hook=stop-gate identity=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
        >> "$review_audit"; } 2>/dev/null || true
  fi
  echo "Reviewer identity '${agent_type}' is not this project's reviewer (unrecognized namespace) - pending-review flags were NOT cleared. Recover by dispatching this project's own reviewer, or per flag: 'printf \"defer: <reason>\\n\" > ${dot_label}/.pending-review.<agent-id>' (keeps it, review still owed) or 'skip: <reason>' (deletes it, unit abandoned)." >&2
fi

# C2 also bites when the SubagentStop identity does not resolve to this
# project's reviewer at all (a persona name other than "reviewer", not just
# a foreign namespace of it) - that identity never enters the branch above,
# so it needs its own, independent guard to leave a trace when flags are
# left standing.
if [ "$hook_event" = "SubagentStop" ] && [ "$(identity_persona_name "$agent_type")" != "reviewer" ]; then
  shopt -s nullglob
  pending_flags_check=( "${dot}"/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags_check[@]}" -gt 0 ]; then
    { printf '%s grant-denied hook=stop-gate identity=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
        >> "$review_audit"; } 2>/dev/null || true
  fi
fi

if [ "$hook_event" = "Stop" ]; then
  shopt -s nullglob
  pending_flags=( "${dot}"/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags[@]}" -gt 0 ]; then
    blocked=false
    for flag in "${pending_flags[@]}"; do
      [ -f "$flag" ] || continue
      flag_content="$(cat "$flag" 2>/dev/null || true)"
      # The audit log is one record per line, so a multi-line reason could
      # never compare equal to the log's last line and dedupe never fired for
      # it. Flatten to a single logical line before BOTH the comparison and
      # the write - do not widen the log record to multiple lines instead.
      flag_content="$(printf '%s' "$flag_content" | tr '\n\r' '  ')"
      case "$flag_content" in
        "defer: "|"skip: ")
          # Nothing after the colon is not a reason - the block messages have
          # always said so, and the WIP sentinel below enforces the same rule.
          # Must precede the two arms below, whose trailing * matches empty.
          blocked=true
          ;;
        "defer: "*)
          # A defer: is sticky, so an unchanged reason would otherwise log one
          # identical line per turn forever. Append only when it differs from
          # the last line's content (i.e. after the timestamp field) - distinct
          # events, including a defer: repeated after some other line, still log.
          last_logged="$(tail -n 1 "$review_audit" 2>/dev/null | cut -d' ' -f2- || true)"
          if [ "$last_logged" != "$flag_content" ]; then
            printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$flag_content" >> "$review_audit"
          fi
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
      block "Unit awaiting review. Dispatch reviewer, or: printf \"defer|skip: <reason>\\n\" > ${dot_label}/.pending-review.<agent-id> (defer: sticky/owed, skip: delete/abandon). Empty reason rejected."
    fi
    allow
  fi
fi

if [ "$hook_event" = "Stop" ] || [ "$hook_event" = "SubagentStop" ]; then
  [ -f "$config" ] || allow
  gated="$(jq -r '.gatedAgents[]? // empty' "$config" 2>/dev/null || true)"
  [ -n "$gated" ] || gated="lead-programmer"

  if [ "$hook_event" = "SubagentStop" ]; then
    check_name="$agent_type"
  else
    check_name="$main_agent_name"
  fi

  # Liberal on BOTH sides: a miss here fails OPEN (an unattributed gated agent
  # ends its turn ungated), so a gatedAgents entry and a payload identity match
  # whichever form either is written in.
  match=false
  while IFS= read -r name; do
    [ -n "$name" ] && persona_matches_gate "$name" "$check_name" && match=true
  done <<< "$gated"
  [ "$match" = true ] || allow
fi

agent_id="${raw_agent_id//[^a-zA-Z0-9._-]/_}"
sentinel="${dot}/wip-handoff.${agent_id}"

if [ -f "$sentinel" ]; then
  if [ -s "$sentinel" ]; then
    reason="$(cat "$sentinel")"
    printf '%s agent=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$reason" \
      >> "${dot}/wip-audit.log"
    rm -f "$sentinel"
    allow
  fi
  echo "WIP sentinel at ${sentinel} is empty - a reason is required (e.g. 'echo \"blocked on X\" > ${sentinel}'). Ignoring it and running the normal check instead." >&2
  rm -f "$sentinel"
fi

if [ "$hook_event" = "SubagentStop" ]; then
  pending_flag="${dot}/.pending-review.${agent_id}"
  [ -f "$pending_flag" ] || printf '%s agent=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" > "$pending_flag"
fi

dirty=false
[ -n "$(git -C "$project_dir" status --porcelain 2>/dev/null || true)" ] && dirty=true

session_id="${raw_session_id//[^a-zA-Z0-9._-]/_}"
baseline_file="${dot}/.session-baseline.${session_id}"

moved=false
if [ -f "$baseline_file" ]; then
  baseline_sha="$(cat "$baseline_file" 2>/dev/null || true)"
  current_sha="$(git -C "$project_dir" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$baseline_sha" ] && [ -n "$current_sha" ] && [ "$baseline_sha" != "$current_sha" ]; then
    moved=true
  fi
fi

if [ "$dirty" = false ] && [ "$moved" = false ]; then
  allow
fi

[ -f "$config" ] || allow
check_cmd="$(jq -r '.testAndLintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$check_cmd" ] || allow

tmp_out="$(mktemp)"
if ! (cd "$project_dir" && eval "$check_cmd") >"$tmp_out" 2>&1; then
  out="$(cat "$tmp_out")"
  rm -f "$tmp_out"
  block "Test/lint check failed - fix before ending the turn, or 'echo \"<reason>\" > ${sentinel}' if this is a legitimate mid-task pause (TDD red phase, blocked report, plan-is-wrong escalation). The sentinel must contain a reason - an empty file is ignored.
${out}"
fi
rm -f "$tmp_out"
allow
