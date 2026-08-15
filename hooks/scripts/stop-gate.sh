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

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
config="${project_dir}/.claude/persona-config.json"
review_audit="${project_dir}/.claude/review-audit.log"

stop_active="$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
[ "$stop_active" = "true" ] && exit 0

hook_event="$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
agent_type="$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null || true)"

identity_drift_log "$agent_type" "$hook_event" "$review_audit"

if [ "$hook_event" = "SubagentStop" ] && [ "$(identity_persona_name "$agent_type")" = "reviewer" ]; then
  if persona_matches_grant "$agent_type" reviewer; then
    [ -f "$config" ] || exit 0
    shopt -s nullglob
    blocked_markers=( "${project_dir}"/.claude/reviewed/*.blocked )
    escalated_markers=( "${project_dir}"/.claude/reviewed/*.escalated )
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
      exit 0
    fi

    # Per-unit review-join, evaluated after the .blocked early-exit above and
    # before the flag rm -f below, so a blocked verdict still short-circuits.
    dot="${project_dir}/.claude"
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
      echo "No verdict is recorded for the unit(s) you were dispatched for: ${missing}. A v3 PASS or FAIL marker must be written for each, first line exactly:" >&2
      echo "  printf 'PASS <unit-id> %s commit: %s criteria: bash tests/validate.sh\\n' '$(date -u +%Y-%m-%dT%H:%M:%SZ)' '$(git rev-parse HEAD 2>/dev/null || echo none)' > .claude/reviewed/<unit-id>.pass" >&2
      echo "The only two legal responses to this block are writing the genuine verdict you actually reached, or reporting the situation and waiting; touching a file's mtime - or writing a marker you do not believe - to satisfy this check is a violation, not a workaround." >&2
      exit 2
    fi

    rm -f "${project_dir}"/.claude/.pending-review.* 2>/dev/null || true
    printf '%s cleared-by=reviewer\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$review_audit"
    exit 0
  fi
  # Clearing review flags is a privilege granted only to this project's own
  # reviewer, so a foreign namespace falls through with the flags standing.
  # That is a deadlock a human has to break, so say so here rather than
  # leaving only the identity-drift audit line above.
  # Log grant-denied if pending-review flags are standing
  shopt -s nullglob
  pending_flags_check=( "${project_dir}"/.claude/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags_check[@]}" -gt 0 ]; then
    { printf '%s grant-denied hook=stop-gate identity=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
        >> "$review_audit"; } 2>/dev/null || true
  fi
  echo "Reviewer identity '${agent_type}' is not this project's reviewer (unrecognized namespace) - pending-review flags were NOT cleared. Recover by dispatching this project's own reviewer, or per flag: 'printf \"defer: <reason>\\n\" > .claude/.pending-review.<agent-id>' (keeps it, review still owed) or 'skip: <reason>' (deletes it, unit abandoned)." >&2
fi

# C2 also bites when the SubagentStop identity does not resolve to this
# project's reviewer at all (a persona name other than "reviewer", not just
# a foreign namespace of it) - that identity never enters the branch above,
# so it needs its own, independent guard to leave a trace when flags are
# left standing.
if [ "$hook_event" = "SubagentStop" ] && [ "$(identity_persona_name "$agent_type")" != "reviewer" ]; then
  shopt -s nullglob
  pending_flags_check=( "${project_dir}"/.claude/.pending-review.* )
  shopt -u nullglob
  if [ "${#pending_flags_check[@]}" -gt 0 ]; then
    { printf '%s grant-denied hook=stop-gate identity=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")" \
        >> "$review_audit"; } 2>/dev/null || true
  fi
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
      echo "Unit awaiting review - confirm the reviewer is dispatched for it, or dispatch it now if not (persona-protocol.md's Review Ownership section); this hook cannot tell which. Escape hatch: 'printf \"defer|skip: <reason>\\n\" > .claude/.pending-review.<agent-id>' - defer keeps the flag (sticky: allows every subsequent Stop too, still owed), skip deletes it (abandoned). Empty reason rejected." >&2
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
    [ -n "$name" ] && persona_matches_gate "$name" "$check_name" && match=true
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
  [ -f "$pending_flag" ] || printf '%s agent=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" > "$pending_flag"
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
