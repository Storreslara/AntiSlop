#!/usr/bin/env bash
# TDD suite for state-access.sh — tests for ordering/atomicity constraints.
# Written BEFORE consolidation to verify current behavior.
# Each constraint test is mutation-proved: reverting the fix must make the test red.
# Constraints the LIB itself owns (C3, C4, C6, C8, C9) exercise state-access.sh
# functions directly. Constraints owned by a CALLER instead (C1, C2, C5)
# invoke the real hooks/scripts/*.sh that
# actually implements the ordering/binding, since the lib alone cannot prove it.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

# == Test harness setup ==
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export dot="$tmpdir/.claude"
mkdir -p "$dot/reviewed" "$dot/human-review"

# Source the library under test
source hooks/scripts/lib/state-access.sh

# Source supporting libs
source hooks/scripts/lib/audit-log.sh

# == CONSTRAINT 1: .consumed-before-rm ==
# The .dispatch-override.consumed stamp MUST exist BEFORE the override is deleted.
# This prevents loss of the replay window on crash.
test_consumed_before_rm() {
  state_write_dispatch_override "test waiver"

  # Write consumed marker
  local epoch=$(date +%s)
  state_write_dispatch_consumed "$epoch" "abc123def456"

  # Verify consumed exists
  [ -f "${dot}/.dispatch-override.consumed" ] || { bad "C1: consumed not written"; return 1; }

  # Delete override
  state_delete_dispatch_override

  # CONSTRAINT: consumed must still exist after override is deleted
  [ -f "${dot}/.dispatch-override.consumed" ] && pass "C1: consumed survives rm" || bad "C1: consumed lost after rm"

  # Content is THREE fields: epoch hash reason (reason may be empty, leaving
  # a trailing space) - state_write_dispatch_consumed emits this exactly,
  # and dispatch-hygiene.sh:200's consumer regex requires the third field.
  grep -E "^[0-9]+ [a-f0-9]+ .*$" "${dot}/.dispatch-override.consumed" >/dev/null && \
    pass "C1: consumed has epoch + hash + reason" || bad "C1: consumed format wrong"

  # The lib does not own this ordering at all - state_delete_dispatch_override's
  # own comment says "Caller must handle this constraint". The real ordering
  # invariant lives in the CALLER, hooks/scripts/dispatch-hygiene.sh, which is
  # protectedPaths-listed and cannot be mutated from this suite to prove it
  # behaviorally; the full behavioral mutation-proof (a reordered copy of the
  # real script deterministically loses a staggered concurrent replay) already
  # lives in tests/dispatch-hygiene.test.sh's T38. Re-derive the source-order
  # invariant here against the REAL, unmutated script, so a regression that
  # swaps the two lines is caught by this suite too, not only by T38's copy.
  local real_hook="hooks/scripts/dispatch-hygiene.sh"
  local rm_line write_line
  rm_line="$(grep -n '^[[:space:]]*state_delete_dispatch_override$' "$real_hook" | head -1 | cut -d: -f1)"
  write_line="$(grep -n '^[[:space:]]*state_write_dispatch_consumed ' "$real_hook" | head -1 | cut -d: -f1)"
  if [ -n "$write_line" ] && [ -n "$rm_line" ] && [ "$write_line" -lt "$rm_line" ]; then
    pass "C1: real dispatch-hygiene.sh writes .consumed before deleting .dispatch-override (full behavioral proof: tests/dispatch-hygiene.test.sh T38)"
  else
    bad "C1: real dispatch-hygiene.sh does not write .consumed before deleting .dispatch-override"
  fi
}

# == CONSTRAINT 2: reviewer stop -> clear .pending-review ==
# A reviewer's SubagentStop clears every .pending-review flag, whatever the
# verdict. Exercised through the REAL hooks/scripts/stop-gate.sh (via
# lib/stop-gate-core.sh), not by writing files and re-reading them back.
test_reviewer_stop_clears() {
  local agent_id="lead-programmer"
  local reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'
  local dir1="${tmpdir}/c2-clear"
  mkdir -p "$dir1/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' > "$dir1/.claude/persona-config.json"
  printf 'lead-programmer flag\n' > "$dir1/.claude/.pending-review.${agent_id}"

  local rc=0
  printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir1" bash hooks/scripts/stop-gate.sh || rc=$?
  if [ "$rc" = 0 ] && [ ! -f "$dir1/.claude/.pending-review.${agent_id}" ] \
     && grep -q 'cleared-by=reviewer' "$dir1/.claude/review-audit.log"; then
    pass "C2: real stop-gate.sh clears pending-review on a reviewer stop"
  else
    bad "C2: reviewer stop did not clear pending-review (rc=$rc)"
  fi
}

# == CONSTRAINT 3: .pending-review create-only-if-absent ==
# A .pending-review flag must be created ONLY on first SubagentStop.
# If main session writes a defer: reason first, SubagentStop must not clobber it.
test_pending_review_idempotent() {
  local agent_id="test-agent-1"
  local flag_file="${dot}/.pending-review.${agent_id}"

  # First: main session writes a reason directly (not via state_write, simulating manual edit)
  printf 'defer: user wrote this\n' > "$flag_file"
  local original_content=$(cat "$flag_file")

  # Second: SubagentStop calls state_write_pending_review with empty content
  # The state-access.sh function checks -f before writing, so it should NOT overwrite
  state_write_pending_review "$agent_id" ""

  # Verify content unchanged
  local current_content=$(cat "$flag_file")
  [ "$current_content" = "$original_content" ] && pass "C3: pending-review not clobbered" || bad "C3: pending-review was overwritten"
}

# l2-sg1: state_replace_pending_review replaces whatever stands at the flag path, and fails on a directory.
test_replace_pending_review() {
  local flag_file="${dot}/.pending-review.rp-1"
  printf 'defer: later\n' > "$flag_file"; chmod 600 "$flag_file"
  if state_replace_pending_review rp-1 "new agent=rp-1" && [ "$(cat "$flag_file")" = "new agent=rp-1" ] \
     && [ "$(stat -c %a "$flag_file")" = 644 ]; then pass "(l2-c1) replace over a defer: flag: new content, mode 644"
  else bad "(l2-c1) replace over a defer: flag"; fi
  mkdir "${dot}/.pending-review.rp-2"
  if ! declare -F state_replace_pending_review >/dev/null || state_replace_pending_review rp-2 x 2>/dev/null \
     || [ -n "$(ls -A "${dot}/.pending-review.rp-2")" ]; then bad "(l2-c2) replace over a directory"
  else pass "(l2-c2) replace over a directory returns non-zero, writes nothing into it"; fi
}

# == CONSTRAINT 4: .session-baseline create-only-if-absent ==
# A .session-baseline is created once at session start and never overwritten.
test_session_baseline_idempotent() {
  local session_id="sess-001"
  local baseline_file="${dot}/.session-baseline.${session_id}"

  # First session start: write baseline
  state_write_session_baseline "$session_id" "abc123def456"
  local original=$(cat "$baseline_file")

  # Second attempt (later in session): should NOT overwrite
  state_write_session_baseline "$session_id" "xyz789abc000"
  local after=$(cat "$baseline_file")

  [ "$original" = "$after" ] && pass "C4: session-baseline not overwritten" || bad "C4: session-baseline was clobbered"
}

# == CONSTRAINT 5: no marker keeps flags at a reviewer stop ==
# A .directed marker keeping the flag would deadlock the dispatch it is meant
# to authorize. Exercised through the REAL hooks/scripts/stop-gate.sh.
test_directed_excluded_from_globs() {
  local unit_id="test-unit-2"
  local reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'

  # (a) a .directed marker must NOT keep a pending-review flag standing.
  local dir1="${tmpdir}/c5-directed-only"
  mkdir -p "$dir1/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' > "$dir1/.claude/persona-config.json"
  printf 'DIRECTED %s human resolution\n' "$unit_id" > "$dir1/.claude/reviewed/${unit_id}.directed"
  printf 'lead-programmer flag\n' > "$dir1/.claude/.pending-review.lp-1"

  local rc=0
  printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir1" bash hooks/scripts/stop-gate.sh || rc=$?
  if [ "$rc" = 0 ] && [ ! -f "$dir1/.claude/.pending-review.lp-1" ] \
     && ! grep -q 'verdict=blocked\|verdict=escalated' "$dir1/.claude/review-audit.log" 2>/dev/null; then
    pass "C5: real stop-gate.sh does not treat .directed as .blocked/.escalated (flag clears)"
  else
    bad "C5: .directed changed stop-gate.sh's clearing behavior - check it hasn't entered the glob"
  fi

  # (b) a sibling .blocked marker no longer keeps the flag standing either:
  # the reviewer stop clears whatever the verdict.
  local dir2="${tmpdir}/c5-directed-and-blocked"
  mkdir -p "$dir2/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' > "$dir2/.claude/persona-config.json"
  printf 'DIRECTED %s human resolution\n' "$unit_id" > "$dir2/.claude/reviewed/${unit_id}.directed"
  printf 'BLOCKED other-unit 2026-07-22T00:00:00Z missing: X\n' > "$dir2/.claude/reviewed/other-unit.blocked"
  printf 'lead-programmer flag\n' > "$dir2/.claude/.pending-review.lp-1"

  rc=0
  printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$dir2" bash hooks/scripts/stop-gate.sh || rc=$?
  if [ "$rc" = 0 ] && [ ! -f "$dir2/.claude/.pending-review.lp-1" ]; then
    pass "C5: a sibling .blocked marker does not keep the flag standing"
  else
    bad "C5: a .blocked marker kept the flag standing (rc=$rc)"
  fi
}

# == CONSTRAINT 6: DECISION zero-identity write ban ==
# No agent may write .claude/human-review/<id>/DECISION.
# (This constraint is enforced by gates; lib should not provide a write function for it)
test_decision_zero_identity_write() {
  local unit_id="test-unit-3"

  # Verify state-access.sh has NO function to write DECISION
  if declare -f state_write_decision >/dev/null 2>&1; then
    bad "C6: state_write_decision should not exist"
  else
    pass "C6: no write function for DECISION"
  fi
}

# == CONSTRAINT 8: wip-handoff empty ≠ absent ==
# An empty wip-handoff file must be deleted, NOT preserved.
# Empty does not mean "pause honored"; it means "misconfigured — delete it."
# Path has no leading dot, matching the real sentinel path
# ".claude/wip-handoff.<agent-id>" in stop-gate-core.sh (defect 1 fix).
test_wip_handoff_empty_not_absent() {
  local agent_id="test-agent-2"

  # Write empty handoff via state_write
  state_write_wip_handoff "$agent_id" ""

  # Verify it was deleted (not preserved as empty)
  [ ! -f "${dot}/wip-handoff.${agent_id}" ] && pass "C8: empty wip-handoff deleted" || bad "C8: empty file not deleted"

  # Write non-empty and verify it survives
  state_write_wip_handoff "$agent_id" "TDD red phase"
  [ -f "${dot}/wip-handoff.${agent_id}" ] && pass "C8: non-empty wip-handoff written" || bad "C8: non-empty not preserved"
}

# == CONSTRAINT 9: .dispatch-override.consumed content-embedded epoch ==
# The epoch in .dispatch-override.consumed must be embedded in content, not mtime.
# This survives clock skew and file operations that would reset mtime.
test_dispatch_consumed_epoch_embedded() {
  local epoch=$(date +%s)
  state_write_dispatch_consumed "$epoch" "hash123"

  # Read back the file
  local content=$(cat "${dot}/.dispatch-override.consumed")

  # Verify epoch is in the first field
  local first_field=$(echo "$content" | cut -d' ' -f1)
  [ "$first_field" = "$epoch" ] && pass "C9: epoch embedded in content" || bad "C9: epoch not in content"

  # Sleep 1 second and touch the file (change mtime without changing content)
  sleep 1
  touch "${dot}/.dispatch-override.consumed"

  # Read back - epoch should still be the original, not derived from mtime
  local new_content=$(cat "${dot}/.dispatch-override.consumed")
  [ "$new_content" = "$content" ] && pass "C9: epoch survives touch" || bad "C9: epoch lost after mtime change"
}

# == CONSTRAINT 10: .fail consumes 2-FAIL-cap without filesystem derivation ==
# The .fail marker is overwritten in place (each new FAIL overwrites the previous).
# The 2-FAIL cap count cannot be derived from filesystem state alone —
# it requires parsing the audit log or tracking state.
# (This constraint documents a property, not a testable lib function;
#  the actual count is tracked by reviewer-tier.sh via review-audit.log)
test_fail_overwrites_cap() {
  local unit_id="test-unit-5"
  local fail_file="${dot}/reviewed/${unit_id}.fail"

  # First FAIL
  state_write_unit_marker "$unit_id" "fail" "FAIL $unit_id 2026-08-27T09:00:00Z"$'\n'"Defect A"

  # Second FAIL overwrites
  state_write_unit_marker "$unit_id" "fail" "FAIL $unit_id 2026-08-27T10:00:00Z"$'\n'"Defect B"

  # Only one .fail file exists (overwritten)
  [ -f "$fail_file" ] && pass "C10: fail file exists" || bad "C10: fail file missing"

  # Content is the second one
  grep -q "Defect B" "$fail_file" && pass "C10: fail overwrites in place" || bad "C10: fail content wrong"

  # The named property: NOT filesystem-derivable. Modeled on C9's proof that
  # .dispatch-override.consumed's epoch survives an mtime-only touch - here
  # it's the mirror case: a second write destroys the first write's content
  # entirely, so nothing readable from the file (or its single directory
  # entry) can recover how many times it has been overwritten. That is
  # exactly why the 2-FAIL cap is tracked by parsing review-audit.log
  # (reviewer-tier.sh), never by anything derivable from .fail alone.
  if grep -q "Defect A" "$fail_file"; then
    bad "C10: prior FAIL content survived an overwrite - cap count would be filesystem-derivable"
  else
    pass "C10: prior FAIL content is destroyed by overwrite - 2-FAIL-cap count is not filesystem-derivable"
  fi

  local entry_count
  entry_count=$(find "${dot}/reviewed" -maxdepth 1 -name "${unit_id}.fail" | wc -l)
  [ "$entry_count" = "1" ] && pass "C10: exactly one directory entry regardless of overwrite count" || bad "C10: unexpected .fail entry count ($entry_count)"
}

# == M5: one shared unit-id grammar (gate-audit-step5, criteria 2, 3) ==
# 2a/2b/2c are a file/line allowlist per spelling, not a bare count: a moved
# line must not silently satisfy them (see docs/plans/2026-09-09-fable-gate-
# audit-remediation.md Step 5, criterion 2). Scoped to hooks/scripts/ only -
# never .claude/hooks/scripts/ or adapters/, which are generated (CC1).
test_unit_id_grammar() {
  local out

  # 2a - spelling A (A-Za-z0-9._#-) has exactly one home: the
  # UNIT_ID_CHARCLASS assignment itself.
  out="$(git grep -c -F 'A-Za-z0-9._#-' -- hooks/scripts/ || true)"
  if [ "$out" = "hooks/scripts/lib/state-access.sh:1" ]; then
    pass "2a: spelling A has exactly one home (state-access.sh)"
  else
    bad "2a: expected exactly hooks/scripts/lib/state-access.sh:1, got: $out"
  fi

  # 2b - spelling B ([^a-zA-Z0-9._-]) survives only outside the unit-id
  # domain: the agent_id/session_id sanitizers, asserted by file AND by the
  # assigned-variable name on each line (not just a count) so that reaching
  # "two remaining" by editing the wrong (non-unit-id) line still fails.
  out="$(git grep -n -F '[^a-zA-Z0-9._-]' -- hooks/scripts/ || true)"
  local b_lines
  b_lines="$(echo "$out" | wc -l)"
  if [ "$b_lines" = 2 ] \
     && echo "$out" | grep -q '^hooks/scripts/lib/stop-gate-core.sh:.*agent_id=' \
     && echo "$out" | grep -q '^hooks/scripts/session-start.sh:.*session_id='; then
    pass "2b: spelling B survives only at the agent_id/session_id sanitizers"
  else
    bad "2b: expected exactly the two agent_id/session_id lines, got: $out"
  fi
  if echo "$out" | grep -q 'state-access.sh'; then
    bad "2b: state-access.sh must not appear (unit_id_sanitize spells its complement as [^\${UNIT_ID_CHARCLASS}])"
  else
    pass "2b: state-access.sh does not appear (complement is spelled via the variable)"
  fi

  # 2c - spelling C (A-Za-z0-9_#.-) is eliminated.
  out="$(git grep -l -F 'A-Za-z0-9_#.-' -- hooks/scripts/ || true)"
  if [ -z "$out" ]; then
    pass "2c: spelling C is eliminated"
  else
    bad "2c: spelling C still present in: $out"
  fi

  # 3 - traversal still rejected, and the per-site */*|*..* redundancy stays.
  local id
  for id in '../x' 'a/b' 'a..b' '.hidden' "$(printf 'a%.0s' $(seq 1 65))" ''; do
    if unit_id_valid "$id"; then
      bad "3: unit_id_valid incorrectly accepted [$id]"
    else
      pass "3: unit_id_valid rejects [$id]"
    fi
  done
  if unit_id_valid 'gh#348' && unit_id_valid 'unit-1'; then
    pass "3: unit_id_valid still accepts well-formed ids (incl. #)"
  else
    bad "3: unit_id_valid rejected a well-formed id"
  fi
  if git grep -q -F '*/*|*..*' -- hooks/scripts/dispatch-hygiene.sh; then
    pass "3: dispatch-hygiene.sh's per-site */*|*..* redundancy is still present"
  else
    bad "3: dispatch-hygiene.sh's per-site traversal redundancy was removed"
  fi
}

# == Run all tests ==
test_consumed_before_rm
test_reviewer_stop_clears
test_pending_review_idempotent
test_replace_pending_review
test_session_baseline_idempotent
test_directed_excluded_from_globs
test_decision_zero_identity_write
test_wip_handoff_empty_not_absent
test_dispatch_consumed_epoch_embedded
test_fail_overwrites_cap
test_unit_id_grammar

exit "$fail"
