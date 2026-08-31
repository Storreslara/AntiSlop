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

# --- Unit A (async microworld rerun): deferred result surfacing -----------
# PostToolUse's microworld-rerun.sh now enqueues bundle/watch-map runs and
# returns immediately (hooks/scripts/lib/microworld-queue.sh); this is the
# PRIMARY channel that surfaces what it deferred, in the SAME session that
# caused it (session-start.sh's Job 5 is the backstop for anything this
# misses). Placed first, unconditionally, ahead of every gating decision
# below (review-join, gatedAgents, WIP sentinel, testAndLintCommand), so
# that when spec 6's `reviewGating.mode: off` early exit lands, it can be
# inserted immediately AFTER this block per docs/plans/2026-08-25-agent-
# throughput-performance-dampeners.md ("Surfacing must survive spec 6's
# gate-silencing flip") without losing same-session feedback - this unit
# does not implement that mode-off branch itself (spec 6 has not landed).
# A line-count watermark (not a timestamp - avoids any date-parsing
# portability trap) tracks what has already been surfaced, so a result is
# reported exactly once; session-start.sh reads and advances the SAME
# watermark file, so whichever channel sees a result first is the one that
# reports it and the other does not re-announce it.
if [ "$hook_event" = "Stop" ] || [ "$hook_event" = "SubagentStop" ]; then
  microworld_audit="${dot}/microworld-audit.log"
  microworld_watermark="${dot}/.microworld-results-reported"
  if [ -f "$microworld_audit" ]; then
    total_lines="$(wc -l < "$microworld_audit" 2>/dev/null || echo 0)"
    last_reported=0
    if [ -f "$microworld_watermark" ]; then
      last_reported="$(cat "$microworld_watermark" 2>/dev/null || echo 0)"
    fi
    case "$last_reported" in ''|*[!0-9]*) last_reported=0 ;; esac

    if [ "$total_lines" -gt "$last_reported" ]; then
      # `paste -s` (deliberately not the pipe-into-tr idiom step 0.75 uses
      # below for its own multi-line flattening) joins lines with a space -
      # that other idiom's mutation-control test greps this file for exactly
      # one match of that pipe spelling, so reusing it here would break it.
      broken="$(tail -n "+$((last_reported + 1))" "$microworld_audit" 2>/dev/null \
        | grep -v ' result=pass ' \
        | grep -o 'unit=[^ ]*' | cut -d= -f2 | paste -s -d' ' - || true)"
      printf '%s\n' "$total_lines" > "$microworld_watermark" 2>/dev/null || true
      if [ -n "$broken" ]; then
        block "microworld: bundle(s) broken by a deferred run: ${broken}
see ${dot_label}/microworld-audit.log"
      fi
    fi
  fi
fi
# --- end Unit A deferred surfacing -----------------------------------------

# --- Unit B (cheapen the redundant stop-gate run): skip precondition ------
# Step 4 below (testAndLintCommand) is redundant work whenever Unit A's
# rerun queue has ALREADY proven every changed file clean via a bundle that
# watches it, and nothing has changed since. microworld_skip_ok is provably
# conservative (AC-B5): any changed file watched by no bundle, any bundle
# whose latest result for that file isn't a pass, or a pass no fresher than
# the file's own mtime (an edit may have landed after it) each make it
# return 1 - it only ever adds a skip, never removes a check.
#
# _mw_file_iso <abs-path> - the file's mtime as a UTC ISO-8601 string,
# comparable lexicographically against the audit log's own timestamp field
# (same format). GNU/BSD stat dual-fallback matches review_join_state's
# existing convention below.
_mw_file_iso() {
  local mtime
  mtime="$(stat -L -c %Y "$1" 2>/dev/null || stat -L -f %m "$1" 2>/dev/null)" || return 1
  case "$mtime" in ''|*[!0-9]*) return 1 ;; esac
  date -u -d "@${mtime}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -r "$mtime" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null
}

# _mw_bundles_for_file <project_dir> <rel_path> - one bundle slug per line
# for every microworlds/*/manifest.json whose `watch` globs match rel_path,
# using the SAME glob-matching semantics as microworld-rerun-core.sh's own
# tier-B check, so "watched" here means exactly what enqueued it there.
_mw_bundles_for_file() {
  local project_dir="$1" rel_path="$2" manifest slug globs glob matched
  for manifest in "${project_dir}"/microworlds/*/manifest.json; do
    [ -f "$manifest" ] || continue
    slug="$(basename "$(dirname "$manifest")")"
    globs="$(jq -r '.watch[]? // empty' "$manifest" 2>/dev/null)" || continue
    matched=false
    while IFS= read -r glob; do
      [ -n "$glob" ] || continue
      case "$rel_path" in
        $glob) matched=true ;;
      esac
    done <<< "$globs"
    [ "$matched" = true ] && echo "$slug"
  done
}

# _mw_latest_result <audit> <slug> <file> - prints "<timestamp> <result>"
# for the LAST audit-log line naming this exact (unit, file) pair, or
# nothing. Field-parsed, not regex-matched against the raw line, so a
# slug/path containing regex metacharacters can never produce a false match.
_mw_latest_result() {
  awk -v slug="$2" -v file="$3" '
    { u=""; r=""; f="";
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^unit=/) u = substr($i, 6);
        else if ($i ~ /^result=/) r = substr($i, 8);
        else if ($i ~ /^file=/) f = substr($i, 6);
      }
      if (u == slug && f == file) { last_ts = $1; last_r = r }
    }
    END { if (last_ts != "") print last_ts" "last_r }
  ' "$1" 2>/dev/null
}

# _mw_changed_files <project_dir> <baseline_sha> <moved> - one relative path
# per line: the dirty working tree (git status --porcelain) plus, if HEAD
# has moved since this session's baseline, everything committed since.
# Returns non-zero if the baseline diff was needed but could not be computed
# (e.g. an unreachable baseline commit), so the caller never mistakes "found
# nothing" for "verified nothing changed".
_mw_changed_files() {
  local project_dir="$1" baseline_sha="$2" moved="$3" line path
  git -C "$project_dir" status --porcelain 2>/dev/null | while IFS= read -r line; do
    path="${line:3}"
    case "$path" in *' -> '*) path="${path##* -> }" ;; esac
    printf '%s\n' "$path"
  done || true
  if [ "$moved" = true ] && [ -n "$baseline_sha" ]; then
    git -C "$project_dir" rev-parse --verify "${baseline_sha}^{commit}" >/dev/null 2>&1 || return 1
    git -C "$project_dir" diff --name-only "$baseline_sha" HEAD 2>/dev/null
  fi
}

# microworld_skip_ok <project_dir> <audit> <baseline_sha> <moved> - AC-B1/B5.
# Returns 0 only when EVERY changed file is watched by at least one bundle
# and EVERY such bundle's latest result for that file is a pass logged
# strictly after the file's own mtime. Any other outcome - no bundle, no
# recorded result, a fail/timeout/error result, or an unreadable timestamp -
# returns 1 (fail closed, AC-B5).
microworld_skip_ok() {
  local project_dir="$1" audit="$2" baseline_sha="$3" moved="$4"
  local file slug bundles file_iso latest ts result seen="" changed_files
  [ -r "$audit" ] || return 1

  changed_files="$(_mw_changed_files "$project_dir" "$baseline_sha" "$moved")" || return 1

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    case " $seen " in *" $file "*) continue ;; esac
    seen="$seen $file"

    bundles="$(_mw_bundles_for_file "$project_dir" "$file")"
    [ -n "$bundles" ] || return 1

    file_iso="$(_mw_file_iso "${project_dir}/${file}")" || return 1

    while IFS= read -r slug; do
      [ -n "$slug" ] || continue
      latest="$(_mw_latest_result "$audit" "$slug" "$file")"
      [ -n "$latest" ] || return 1
      ts="${latest%% *}"
      result="${latest#* }"
      [ "$result" = pass ] || return 1
      [[ "$ts" > "$file_iso" ]] || return 1
    done <<< "$bundles"
  done <<< "$changed_files"

  return 0
}
# --- end Unit B skip precondition ------------------------------------------

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
  local path="$1" unit="$2" verb="$3" first_line content
  if ! content="$(state_read_unit_marker "$unit" "$verb" 2>/dev/null)"; then
    return 1
  fi
  [ -n "$content" ] || return 1
  first_line="$(echo "$content" | head -n 1)"
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
      audit_append "$review_audit" "$(printf '%s verdict=blocked flags-kept' "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
    fi
    if [ "${#escalated_markers[@]}" -gt 0 ]; then
      audit_append "$review_audit" "$(printf '%s verdict=escalated flags-kept' "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
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
      audit_append "$review_audit" "$(printf '%s marker-check=bootstrap' "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
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
          audit_append "$review_audit" "$(printf '%s marker-commit-check=%s unit=%s' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$mcc_state" "$unit")"
          if [ "$mcc_state" = mismatch ]; then
            echo "marker-commit-check: unit ${unit}'s PASS marker cites a commit that does not appear to belong to it - ${mcc_out}" >&2
            if [ "$mcc_mode" = block ]; then
              echo "Remediation: correct the commit: field in ${dot_label}/reviewed/${unit}.pass to name the unit's own final commit, then re-run." >&2
              exit 2
            fi
          fi
        fi
        rm -f "${JOIN_SATISFIED_STAMPS[$idx]}" 2>/dev/null || true
        audit_append "$review_audit" "$(printf '%s join-consumed=%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          "${JOIN_SATISFIED_UNITS[$idx]}")"
        idx=$(( idx + 1 ))
      done
    else
      missing=""
      idx=0
      while [ "$idx" -lt "${#JOIN_UNSATISFIED_UNITS[@]}" ]; do
        audit_append "$review_audit" "$(printf '%s cleared-by=reviewer marker=MISSING unit=%s' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${JOIN_UNSATISFIED_UNITS[$idx]}")"
        missing="${missing:+$missing, }${JOIN_UNSATISFIED_UNITS[$idx]}"
        idx=$(( idx + 1 ))
      done
      block "No verdict is recorded for the unit(s) you were dispatched for: ${missing}. A v3 PASS or FAIL marker must be written for each, first line exactly:
  printf 'PASS <unit-id> %s commit: %s criteria: bash tests/validate.sh\\n' '$(date -u +%Y-%m-%dT%H:%M:%SZ)' '<the unit's own final commit, not HEAD>' > ${dot_label}/reviewed/<unit-id>.pass
The only two legal responses to this block are writing the genuine verdict you actually reached, or reporting the situation and waiting; touching a file's mtime - or writing a marker you do not believe - to satisfy this check is a violation, not a workaround."
    fi

    rm -f "${dot}"/.pending-review.* 2>/dev/null || true
    audit_append "$review_audit" "$(printf '%s cleared-by=reviewer' "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
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
    audit_append "$review_audit" "$(printf '%s grant-denied hook=stop-gate identity=%s' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")")"
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
    audit_append "$review_audit" "$(printf '%s grant-denied hook=stop-gate identity=%s' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_identity_sanitize "$agent_type")")"
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
            audit_append "$review_audit" "$(printf '%s %s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$flag_content")"
          fi
          ;;
        "skip: "*)
          audit_append "$review_audit" "$(printf '%s %s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$flag_content")"
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
    audit_append "${dot}/wip-audit.log" "$(printf '%s agent=%s reason=%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$reason")"
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

# Step 4 (disarm-surface config drift, RD3): a GATED agent's SubagentStop
# blocks when persona-config.json has weakened since this session's
# baseline sha - never the main-session Stop (RD3), and never when the
# baseline is unresolvable (nothing to compare against). Placed ahead of
# the dirty/moved early-allow below so a drift committed mid-session (tree
# clean, HEAD moved) is still caught. harness_integrity_bin is read
# defensively (${...:-}) because only the Claude entry script currently
# sets it - a port without it simply skips this check (see stop-gate.sh's
# mcc_script precedent for the same caller-resolved-path pattern).
if [ "$hook_event" = "SubagentStop" ] && [ -n "${baseline_sha:-}" ] \
   && [ -x "${harness_integrity_bin:-}" ]; then
  drift_out="$("$harness_integrity_bin" "$project_dir" "$baseline_sha" 2>/dev/null || true)"
  if [[ $drift_out == *" config=drift "* ]]; then
    drifted_fields=""
    if [[ $drift_out =~ fields=([^\ ]+) ]]; then
      drifted_fields="${BASH_REMATCH[1]}"
    fi
    override_file="${dot}/.config-drift-override.${agent_id}"
    overridden=false
    if [ -f "$override_file" ]; then
      override_content="$(cat "$override_file" 2>/dev/null || true)"
      override_content="$(tr '\n\r' '  ' < <(printf '%s' "$override_content"))"
      case "$override_content" in
        "defer: "|"skip: ") ;;
        "defer: "*)
          audit_append "$review_audit" "$(printf '%s config-drift-%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$override_content")"
          overridden=true
          ;;
        "skip: "*)
          audit_append "$review_audit" "$(printf '%s config-drift-%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$override_content")"
          rm -f "$override_file"
          overridden=true
          ;;
      esac
    fi
    if [ "$overridden" != true ]; then
      block "Disarm-surface config drift detected (fields: ${drifted_fields:-unknown}) since this session's baseline - a gated agent's SubagentStop is refused rather than ending on a weakened trust config (see docs/plans/2026-08-25-harness-trust-gaps.md Step 4). Override: 'printf \"defer: <reason>\\n\" > ${dot_label}/.config-drift-override.${agent_id}' (sticky, review still owed) or 'skip: <reason>' (one-shot). Empty reason rejected."
    fi
  fi
fi

if [ "$dirty" = false ] && [ "$moved" = false ]; then
  allow
fi

[ -f "$config" ] || allow
check_cmd="$(jq -r '.testAndLintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$check_cmd" ] || allow

# Unit B: skip testAndLintCommand when Unit A's queue already proved every
# changed file clean (AC-B1/B2/B5). Logged with a token distinct from every
# other review-audit.log line, so "checked and passed" (no line here) is
# never conflated with "skipped because already checked" (this line).
if microworld_skip_ok "$project_dir" "${dot}/microworld-audit.log" "${baseline_sha:-}" "$moved"; then
  audit_append "$review_audit" "$(printf '%s microworld-skip=testAndLintCommand' "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
  allow
fi

tmp_out="$(mktemp)"
if ! (cd "$project_dir" && eval "$check_cmd") >"$tmp_out" 2>&1; then
  out="$(cat "$tmp_out")"
  rm -f "$tmp_out"
  block "Test/lint check failed - fix before ending the turn, or 'echo \"<reason>\" > ${sentinel}' if this is a legitimate mid-task pause (TDD red phase, blocked report, plan-is-wrong escalation). The sentinel must contain a reason - an empty file is ignored.
${out}"
fi
rm -f "$tmp_out"

allow
