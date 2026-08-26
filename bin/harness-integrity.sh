#!/usr/bin/env bash
# Read-only harness-health reporter, modelled on marker-commit-check.sh's
# always-exit-0, one-line contract. See docs/plans/2026-08-25-harness-trust-
# gaps.md Step 3.
#
# Usage: harness-integrity.sh [project-dir] [--rotate]
# Output (report mode, always):
#   harness-integrity=<ok|drift|tampered|unverifiable> config=<ok|drift|missing> logs=<ok|LIST>
# --rotate: rotates the four audit logs (R3) instead of reporting.
set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/../hooks/scripts/lib/audit-log.sh"

project_dir="."
do_rotate=false
for arg in "$@"; do
  case "$arg" in
    --rotate) do_rotate=true ;;
    *) project_dir="$arg" ;;
  esac
done

dot="${project_dir}/.claude"
log_names="review-audit.log dispatch-audit.log microworld-audit.log wip-audit.log"

if [ "$do_rotate" = true ]; then
  for name in $log_names; do
    log="${dot}/${name}"
    [ -f "$log" ] && audit_rotate "$log"
  done
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
