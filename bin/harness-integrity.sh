#!/usr/bin/env bash
# Read-only harness-health reporter, modelled on marker-commit-check.sh's
# always-exit-0, one-line contract. See docs/plans/2026-08-25-harness-trust-
# gaps.md Steps 3 and 7.
#
# Usage: harness-integrity.sh [project-dir] [baseline-sha] [--rotate]
#        harness-integrity.sh [project-dir] --self-report [baseline-sha]
# Output (report mode, always):
#   harness-integrity=<ok|drift|tampered|unverifiable> config=<ok|drift|missing> fields=<-|f1,f2,...> logs=<ok|LIST>
# <baseline-sha> (default: the most recently modified .claude/.session-
#   baseline.* file's contents, same lookup --self-report uses) drives the
#   disarm-surface config-drift comparison (Step 4): the nine fields listed
#   in normalize_disarm_surface() below are read from BOTH
#   `git show <baseline-sha>:.claude/persona-config.json` and the working
#   tree, each normalized to its effective value, and compared. A difference
#   sets config=drift and lists the drifted field names in `fields=`; an
#   unresolvable baseline (bad sha, no git repo) leaves config at its
#   existence-only value (ok/missing) rather than fabricating a verdict from
#   nothing to compare against.
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
#   The window this produces is "since the project's last commit at the
#   moment this session began" - NOT "since this session's wall-clock
#   start". session-start.sh writes .session-baseline.<id> as HEAD at first
#   SessionStart, so a session that starts right after a commit gets a
#   near-now baseline and will under-report anything logged before that
#   commit, converging toward all-zero until the session's own new self-
#   reports accumulate past it. This is the same D4 baseline-sha mechanism
#   the config-drift check (Step 4) uses, reused here for a timestamp
#   comparison rather than a content diff - intentional reuse, not a bug.
#   abandoned-unrecorded is held at a fixed 0 (gh421 fix-2). A skip: line's
#   reason (hooks/scripts/lib/stop-gate-core.sh:460) is free text an
#   operator/orchestrator wrote, with no structured unit-id field - real
#   examples put the id first, mid-sentence, or not at all, so no fixed
#   token position can find it. Scanning every id-shaped word instead
#   doesn't work either: an ordinary word ("human", "abandoning") matches the
#   same grammar as a real id, and the only ground truth available for "is
#   this really a unit id" - a marker file under .claude/reviewed/ - already
#   means the unit was NOT abandoned by the time it can be confirmed as a
#   real id. Nothing else in this project's logs enumerates every unit ever
#   dispatched, so a truly unmarked id can never be told apart from a
#   coincidental word. Making this count meaningful requires
#   stop-gate-core.sh to write a structured `unit=<id>` field into the
#   skip: line itself.
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

# normalize_disarm_surface <json-content> -> compact JSON of the nine
# disarm-surface fields (D6/Ordered edit 1), each mapped to its EFFECTIVE
# value: an absent key normalizes to the documented default so an absent
# key and an explicit default-valued key compare equal, while an explicit
# non-default value is never silently defaulted away. Defaults mirror each
# consuming gate's own fallback exactly (dispatch-hygiene.sh:118,130-131;
# stop-gate-core.sh:351,478; reviewer.md's documented humanReviewMode
# default; spec 6's A24b for reviewGating.mode). requireContract is compared
# against the literal boolean `false`, not via `//`, because jq's `//`
# treats `false` the same as absent and would silently undo an explicit
# opt-out (same footgun dispatch-hygiene.sh:126-130 already documents).
# fileHashes/pluginVersion/substitutions are deliberately absent from this
# list - bin/cli.js --update rewrites them routinely and they carry no
# gating authority.
normalize_disarm_surface() {
  local content="$1"
  [ -n "$content" ] || content='{}'
  printf '%s' "$content" | jq -c '
    (if type == "object" then . else {} end) as $c |
    {
      gatedAgents: ($c.gatedAgents // ["lead-programmer"]),
      protectedPaths: ($c.protectedPaths // []),
      personaSelection: ($c.personaSelection // []),
      "dispatchHygiene.mode": ($c.dispatchHygiene.mode // "block"),
      "dispatchHygiene.requireContract":
        (if $c.dispatchHygiene.requireContract == false then false else true end),
      "markerCommitCheck.mode": ($c.markerCommitCheck.mode // "warn"),
      humanReviewMode: ($c.humanReviewMode // "critical"),
      testAndLintCommand: ($c.testAndLintCommand // ""),
      "reviewGating.mode": ($c.reviewGating.mode // "enforce")
    }
  ' 2>/dev/null || echo '{}'
}

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
  # wip-audit.log never carries a "skip: " line (its own shape is always
  # `agent=<id> reason=<text>`, per stop-gate-core.sh:502) - only review_log
  # does (stop-gate-core.sh:460), so it is the sole source scanned here.
  skips="$(count_since "$review_log" " skip: ")"

  # See the header comment above: no unit id can be reliably read out of a
  # skip: line's free text, so this stays a fixed 0 rather than guessing.
  abandoned=0

  printf 'self-report wip-sentinels=%s defers=%s skips=%s abandoned-unrecorded=%s\n' \
    "$wip_sentinels" "$defers" "$skips" "$abandoned"
  exit 0
fi

config_state=ok
drift_fields=""
if [ ! -f "${dot}/persona-config.json" ]; then
  config_state=missing
else
  if [ -z "$baseline_sha" ]; then
    latest_baseline_file="$(ls -t "${dot}"/.session-baseline.* 2>/dev/null | head -n 1 || true)"
    [ -n "$latest_baseline_file" ] && baseline_sha="$(cat "$latest_baseline_file" 2>/dev/null || true)"
  fi
  if [ -n "$baseline_sha" ]; then
    baseline_content="$(git -C "$project_dir" show "${baseline_sha}:.claude/persona-config.json" 2>/dev/null || true)"
    if [ -n "$baseline_content" ]; then
      tree_content="$(cat "${dot}/persona-config.json" 2>/dev/null || true)"
      baseline_norm="$(normalize_disarm_surface "$baseline_content")"
      tree_norm="$(normalize_disarm_surface "$tree_content")"
      if [ "$baseline_norm" != "$tree_norm" ]; then
        config_state=drift
        drift_fields="$(jq -nr --argjson a "$baseline_norm" --argjson b "$tree_norm" \
          '($a | keys) as $k | [$k[] | select($a[.] != $b[.])] | join(",")' 2>/dev/null || true)"
      fi
    fi
  fi
fi

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
case "$config_state" in
  missing) [ "$overall" = tampered ] || overall=unverifiable ;;
  drift)   [ "$overall" = tampered ] || overall=drift ;;
esac

printf 'harness-integrity=%s config=%s fields=%s logs=%s\n' \
  "$overall" "$config_state" "${drift_fields:--}" "$bad_logs"
exit 0
