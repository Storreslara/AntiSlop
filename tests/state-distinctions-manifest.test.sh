#!/usr/bin/env bash
# Distinctions-manifest test (A18).
# Per the spec: "Every distinction listed in M3 is covered by a named test."
# The spec's own enumeration (docs/plans/2026-08-25-harness-ceremony-consolidation.md,
# "Distinctions that must survive") lists exactly 15 bullets - counted by hand
# against that section, not taken on faith from any prior packet. This suite
# asserts one id per bullet (not one id per sub-property within a bullet,
# which is what the old D1/D2/D3-all-map-to-one-bullet shape got wrong), and
# every id must resolve or the suite fails - no partial-credit threshold.
#
# Each id's evidence is a FIXED STRING (grep -F) matched against the REAL
# harness file that implements or documents the property - never against
# tests/*.test.sh's own fixture text. Checking a test file against its own
# array (the old bug: every id matched itself, unconditionally) is exactly
# what made this suite unable to ever report a miss.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

# Parallel arrays, one entry per spec bullet, in the spec's own order.
declare -a ids=(
  D1_pending_review_agent_keyed
  D2_review_join_staleness_anchor
  D3_session_baseline_create_if_absent
  D4_wip_handoff_empty_not_absent
  D5_dispatch_override_one_shot
  D6_dispatch_consumed_epoch_hash
  D7_pass_commit_attestation
  D8_fail_2cap_not_filesystem_derivable
  D9_blocked_existence_glob_only
  D10_escalated_decision_timestamp_bind
  D11_directed_excluded_from_globs
  D12_human_review_packet_location
  D13_decision_zero_identity_write_ban
  D14_four_logs_review_audit_control_input
  D15_codex_stop_loop_guard_counter
)
declare -a patterns=(
  'pending-review.${agent_id}'
  'prior_mtime'
  'CONSTRAINT 4: create-only-if-absent'
  'DISTINCTION: empty'
  'Reason-less override is not honored'
  'DISTINCTION: content-embedded epoch'
  'commit: <sha|none>'
  'durable FAIL record'
  'blocked_markers='
  'escalationTimestamp'
  ''
  'human-review'
  'may not write'
  'tail -n 1 "$review_audit"'
  'stop-loop-guard'
)
declare -a files=(
  hooks/scripts/lib/state-access.sh
  hooks/scripts/stop-gate.sh
  hooks/scripts/lib/state-access.sh
  hooks/scripts/lib/state-access.sh
  hooks/scripts/lib/state-access.sh
  hooks/scripts/lib/state-access.sh
  hooks/scripts/task-gate.sh
  hooks/scripts/reviewer-tier.sh
  hooks/scripts/lib/stop-gate-core.sh
  bin/microworld-dashboard/server.js
  hooks/scripts/lib/stop-gate-core.sh
  hooks/scripts/human-decision-gate.sh
  hooks/scripts/human-decision-gate.sh
  hooks/scripts/lib/stop-gate-core.sh
  adapters/codex/hooks/scripts/stop-gate.sh
)

test_manifest() {
  local count_found=0 total=${#ids[@]}
  local i id pattern file

  for i in "${!ids[@]}"; do
    id="${ids[$i]}"
    pattern="${patterns[$i]}"
    file="${files[$i]}"

    if [ "$id" = "D11_directed_excluded_from_globs" ]; then
      # Negative check: stop-gate-core.sh's *.blocked/*.escalated glob logic
      # must contain NO mention of .directed at all - that absence IS the
      # distinction (including it would deadlock the very dispatch it
      # authorizes). A positive-match check cannot express this.
      if ! grep -qF '.directed' "$file"; then
        count_found=$((count_found + 1))
        echo "OK   $id: .directed is genuinely absent from ${file}'s glob logic"
      else
        echo "FAIL $id: ${file} now mentions .directed - re-check it hasn't entered the .blocked/.escalated glob"
      fi
      continue
    fi

    if [ -f "$file" ] && grep -qF -- "$pattern" "$file"; then
      count_found=$((count_found + 1))
      echo "OK   $id found in $file"
    else
      echo "FAIL $id not found in $file (pattern: $pattern)"
    fi
  done

  echo ""
  echo "Distinctions manifest:"
  echo "  Total expected: $total"
  echo "  Found: $count_found"

  # Per the spec ("a missing id fails the suite"): every one of the 15 must
  # resolve, not merely 10 of them.
  if [ "$count_found" -eq "$total" ]; then
    pass "manifest: $count_found / $total distinctions genuinely referenced in real harness code"
    return 0
  else
    bad "manifest: only $count_found / $total distinctions found (all $total are required)"
    return 1
  fi
}

test_manifest
exit "$fail"
