#!/usr/bin/env bash
# CODEX ADAPTER over the shared stop-gate logic (ported from
# hooks/scripts/stop-gate.sh via adapters/cursor/hooks/scripts/stop-gate.sh -
# the ordered decision logic is identical; only the payload field extraction
# and the loop guard differ). Registered on `Stop` (main session) AND
# `SubagentStop`. Gating is config-driven via persona-config.json's
# gatedAgents list (default ["lead-programmer"]).
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
# Ordered logic (identical to the Claude/Cursor versions):
#  0) loop guard (self-tracked fallback, see above).
#  0.5) reviewer's SubagentStop -> if any .codex/reviewed/*.blocked marker
#     stands, KEEP the pending-review flags (log `verdict=blocked flags-kept`,
#     ALLOW); otherwise consume the PER-UNIT review-join stamps
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
          mtime="$(stat -L --format=%Y "$mpath" 2>/dev/null || true)"
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

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.codex/persona-config.json"
review_audit="${project_dir}/.codex/review-audit.log"

hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

raw_session_id="$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
session_id="${raw_session_id//[^a-zA-Z0-9._-]/_}"
loop_guard_file="${project_dir}/.codex/.stop-loop-guard.${session_id}"

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

identity_drift_log "$agent_type" "$hook_event" "$review_audit"

if [ "$hook_event" = "SubagentStop" ] && [ "$(identity_persona_name "$agent_type")" = "reviewer" ]; then
  if persona_matches_grant "$agent_type" reviewer; then
    [ -f "$config" ] || allow
    shopt -s nullglob
    blocked_markers=( "${project_dir}"/.codex/reviewed/*.blocked )
    shopt -u nullglob
    if [ "${#blocked_markers[@]}" -gt 0 ]; then
      printf '%s verdict=blocked flags-kept\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
      allow
    fi

    # Per-unit review-join, evaluated after the .blocked early-exit above and
    # before the flag rm -f below, so a blocked verdict still short-circuits.
    dot="${project_dir}/.codex"
    review_join_state "$dot"

    if [ "${JOIN_STAMP_COUNT:-0}" -eq 0 ]; then
      # Nothing joined this reviewer to a unit - an un-stamped dispatch, or a
      # unit that already held a valid PASS. Fail OPEN, as bootstrap did.
      printf '%s marker-check=bootstrap\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
    elif [ "${#JOIN_SATISFIED_STAMPS[@]}" -gt 0 ] || [ "${JOIN_FAILOPEN:-false}" = true ]; then
      idx=0
      while [ "$idx" -lt "${#JOIN_SATISFIED_STAMPS[@]}" ]; do
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
      # Must go through block() (not a bare exit 2) so this check participates
      # in the loop guard like every other block site here.
      block "No verdict is recorded for the unit(s) you were dispatched for: ${missing}. A v3 PASS or FAIL marker must be written for each, first line exactly:
  printf 'PASS <unit-id> %s commit: %s criteria: bash tests/validate.sh\\n' '$(date -u +%Y-%m-%dT%H:%M:%SZ)' '$(git rev-parse HEAD 2>/dev/null || echo none)' > .codex/reviewed/<unit-id>.pass
The only two legal responses to this block are writing the genuine verdict you actually reached, or reporting the situation and waiting; touching a file's mtime - or writing a marker you do not believe - to satisfy this check is a violation, not a workaround."
    fi

    rm -f "${project_dir}"/.codex/.pending-review.* 2>/dev/null || true
    printf '%s cleared-by=reviewer\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
    allow
  fi
  # A reviewer from an UNRECOGNIZED namespace: clearing review flags is a
  # privilege granted only to this project's own reviewer, so the match is
  # conservative and this one fails CLOSED. That is deliberate, but it can
  # strand a flag the same namespace's gated agent created (the gate side is
  # liberal), so say out loud how to recover instead of silently doing nothing.
  echo "Pending-review flags NOT cleared: '${agent_type}' is not this project's reviewer (unrecognized namespace; see the identity-drift line in .codex/review-audit.log). Recover by dispatching this project's own reviewer, or write 'defer: <reason>' / 'skip: <reason>' into .codex/.pending-review.<agent-id>." >&2
fi

if [ "$hook_event" = "Stop" ]; then
  shopt -s nullglob
  pending_flags=( "${project_dir}"/.codex/.pending-review.* )
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
          # Nothing after the colon is not a reason - the block message has
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
      block "Unit awaiting review - confirm the reviewer is dispatched for it, or dispatch it now if not (persona-protocol's Review ownership section); this hook cannot tell which. Escape hatch: 'printf \"defer|skip: <reason>\\n\" > .codex/.pending-review.<agent-id>' - defer keeps the flag (sticky: allows every subsequent Stop too, still owed), skip deletes it (abandoned). Empty reason rejected."
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
    check_name="$(jq -r '.mainAgent // "orchestrator"' "$config" 2>/dev/null || echo orchestrator)"
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

raw_agent_id="$(echo "$input" | jq -r '.agent_id // .agent_type // .session_id // "main"' 2>/dev/null || echo main)"
agent_id="${raw_agent_id//[^a-zA-Z0-9._-]/_}"
sentinel="${project_dir}/.codex/wip-handoff.${agent_id}"

if [ -f "$sentinel" ]; then
  if [ -s "$sentinel" ]; then
    reason="$(cat "$sentinel")"
    printf '%s agent=%s reason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$reason" \
      >> "${project_dir}/.codex/wip-audit.log"
    rm -f "$sentinel"
    allow
  fi
  echo "WIP sentinel at ${sentinel} is empty - a reason is required (e.g. 'echo \"blocked on X\" > ${sentinel}'). Ignoring it and running the normal check instead." >&2
  rm -f "$sentinel"
fi

if [ "$hook_event" = "SubagentStop" ]; then
  pending_flag="${project_dir}/.codex/.pending-review.${agent_id}"
  [ -f "$pending_flag" ] || printf '%s agent=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" > "$pending_flag"
fi

dirty=false
[ -n "$(git -C "$project_dir" status --porcelain 2>/dev/null || true)" ] && dirty=true

baseline_file="${project_dir}/.codex/.session-baseline.${session_id}"

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
