#!/usr/bin/env bash
# Read-only harness-health reporter, modelled on marker-commit-check.sh's
# always-exit-0, one-line contract. See docs/plans/2026-08-25-harness-trust-
# gaps.md Steps 3 and 7.
#
# Usage: harness-integrity.sh [project-dir] [--rotate]
#        harness-integrity.sh [project-dir] --self-report [baseline-sha]
# Output (report mode, always):
#   harness-integrity=<ok|drift|tampered|unverifiable> config=<ok|drift|missing> logs=<ok|LIST>
# --rotate: rotates the four audit logs (R3) instead of reporting.
# --self-report: tallies the irreducible self-reports (Step 7b, F4 rows 6-8)
#   since <baseline-sha> (default: the most recently modified
#   .claude/.session-baseline.* file's contents), printing:
#     self-report wip-sentinels=<n> defers=<n> skips=<n> abandoned-unrecorded=<n>
#   "Since" is decided by string-comparing each audit-log line's own UTC
#   timestamp against <baseline-sha>'s COMMITTER date (also rendered UTC) -
#   the same sha the config-drift check (Step 4) uses as its baseline, here
#   applied to a timestamp comparison instead of a content diff. An
#   unresolvable sha (bad hash, no git repo) disarms the filter rather than
#   reporting zero: the whole log is tallied instead, so a broken baseline
#   fails toward over-reporting, not silence.
#   abandoned-unrecorded mechanizes only the CONSEQUENCE of a skip: -
#   candidate unit id = the first whitespace-delimited token of the text
#   after "skip: ", if it matches the same id grammar dispatch-hygiene.sh
#   uses for its own `Unit: <id>` line. Distinct candidate ids are deduped;
#   an id with no .pass/.fail/.blocked/.escalated marker on disk counts once.
#   This can never tell "id never really dispatched" from "dispatched,
#   skipped, never marked" - it counts unmarked ids, not proven abandonments.
set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/../hooks/scripts/lib/audit-log.sh"

project_dir="."
do_rotate=false
do_self_report=false
pos_args=()
for arg in "$@"; do
  case "$arg" in
    --rotate) do_rotate=true ;;
    --self-report) do_self_report=true ;;
    *) pos_args+=("$arg") ;;
  esac
done
[ "${#pos_args[@]}" -ge 1 ] && project_dir="${pos_args[0]}"
baseline_sha="${pos_args[1]:-}"

dot="${project_dir}/.claude"
log_names="review-audit.log dispatch-audit.log microworld-audit.log wip-audit.log"

if [ "$do_rotate" = true ]; then
  for name in $log_names; do
    log="${dot}/${name}"
    [ -f "$log" ] && audit_rotate "$log"
  done
  exit 0
fi

if [ "$do_self_report" = true ]; then
  if [ -z "$baseline_sha" ]; then
    latest_baseline_file="$(ls -t "${dot}"/.session-baseline.* 2>/dev/null | head -n 1 || true)"
    [ -n "$latest_baseline_file" ] && baseline_sha="$(cat "$latest_baseline_file" 2>/dev/null || true)"
  fi
  baseline_ts=""
  if [ -n "$baseline_sha" ]; then
    baseline_ts="$(TZ=UTC git -C "$project_dir" show -s --date=format:'%Y-%m-%dT%H:%M:%SZ' \
      --format=%cd "$baseline_sha" 2>/dev/null || true)"
  fi

  wip_log="${dot}/wip-audit.log"
  review_log="${dot}/review-audit.log"
  reviewed_dir="${dot}/reviewed"

  # count_since <log> <needle> - number of lines in <log> containing <needle>
  # as a plain substring, whose own leading timestamp field is >= baseline_ts
  # (or every matching line, when baseline_ts could not be resolved).
  count_since() {
    local log="$1" needle="$2" n=0 line ts
    [ -f "$log" ] || { echo 0; return; }
    while IFS= read -r line; do
      case "$line" in *"$needle"*) ;; *) continue ;; esac
      if [ -n "$baseline_ts" ]; then
        ts="${line%% *}"
        [[ "$ts" < "$baseline_ts" ]] && continue
      fi
      n=$((n + 1))
    done < "$log"
    echo "$n"
  }

  wip_sentinels="$(count_since "$wip_log" "agent=")"
  defers="$(count_since "$review_log" " defer: ")"
  skips=$(( $(count_since "$review_log" " skip: ") + $(count_since "$wip_log" " skip: ") ))

  abandoned=0
  declare -A seen_abandoned=()
  for log in "$wip_log" "$review_log"; do
    [ -f "$log" ] || continue
    while IFS= read -r line; do
      case "$line" in *" skip: "*) ;; *) continue ;; esac
      if [ -n "$baseline_ts" ]; then
        ts="${line%% *}"
        [[ "$ts" < "$baseline_ts" ]] && continue
      fi
      reason="${line#*" skip: "}"
      token="${reason%% *}"
      [[ $token =~ ^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$ ]] || continue
      [ -n "${seen_abandoned[$token]:-}" ] && continue
      seen_abandoned[$token]=1
      if [ ! -f "${reviewed_dir}/${token}.pass" ] && [ ! -f "${reviewed_dir}/${token}.fail" ] \
         && [ ! -f "${reviewed_dir}/${token}.blocked" ] && [ ! -f "${reviewed_dir}/${token}.escalated" ]; then
        abandoned=$((abandoned + 1))
      fi
    done < "$log"
  done

  printf 'self-report wip-sentinels=%s defers=%s skips=%s abandoned-unrecorded=%s\n' \
    "$wip_sentinels" "$defers" "$skips" "$abandoned"
  exit 0
fi

config_state=ok
[ -f "${dot}/persona-config.json" ] || config_state=missing

bad_logs=""
worst=ok
for name in $log_names; do
  log="${dot}/${name}"
  # Never created (no log, no seal) is not tampering - just unused.
  [ -f "$log" ] || [ -f "${log}.seal" ] || continue
  state="$(audit_seal_verify "$log")"
  [ "$state" = ok ] && continue
  bad_logs="${bad_logs:+$bad_logs,}${state}:${name}"
  case "$state" in
    truncated|absent) worst=tampered ;;
    *) [ "$worst" = tampered ] || worst=unverifiable ;;
  esac
done
[ -n "$bad_logs" ] || bad_logs=ok

overall="$worst"
if [ "$config_state" != ok ] && [ "$overall" != tampered ]; then
  overall=unverifiable
fi

printf 'harness-integrity=%s config=%s logs=%s\n' "$overall" "$config_state" "$bad_logs"
exit 0
