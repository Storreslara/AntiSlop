#!/usr/bin/env bash
# Behavioral suite for hooks/scripts/marker-write.sh (spec2-unitC): the
# single-call marker-write helper collapsing the reviewer's documented
# "mkdir -p .claude/reviewed" + printf two-step into one invocation.
#
# AC-C4: one invocation writes a format-valid marker, is not denied by
# reviewed-path-gate.sh or human-decision-gate.sh (as the reviewer identity),
# and the marker's first line starts "<VERB> <unit> ", task-gate.sh's rule
# for a valid marker. PASS markers are checked with task-gate.sh's real
# marker_valid(); FAIL and BLOCKED markers keep the local marker_format_valid()
# below, since task-gate.sh has no predicate for them.
# AC-C5: malformed unit id / missing commit are rejected, and the helper's
# own CLI invocation is BLOCKED for a non-reviewer identity exactly as the
# raw printf write is today (reviewed-path-gate.test.sh cases 6/13) - proving
# no new capability.
# AC-C6: commit 233c0fc (this unit's own commit, feat(spec2-unitC): single-
# call marker-write helper) touched neither reviewed-path-gate.sh nor
# human-decision-gate.sh, nor either .claude/ mirror - an attestation about
# that one frozen commit, not a byte-identity pin on the files themselves.
# A byte pin of files those files' own maintainers keep editing is a freeze
# with no owner (R11); this asserts the historical fact the pin was
# chartered to prove instead, and declines (SKIP) rather than fails if
# 233c0fc is ever unreachable (shallow clone or rewritten history).
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$(pwd)"
helper="$repo/hooks/scripts/marker-write.sh"
gate_rpg="$repo/hooks/scripts/reviewed-path-gate.sh"
gate_hdg="$repo/hooks/scripts/human-decision-gate.sh"
fail=0

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

# marker_format_valid <path> <unit> <VERB>: non-empty, first line starts "<VERB> <unit> ".
marker_format_valid() {
  [ -s "$1" ] || return 1
  case "$(head -n 1 "$1")" in "${3} ${2} "*) return 0 ;; *) return 1 ;; esac
}
source hooks/scripts/lib/state-access.sh
source <(sed -n '/^marker_valid() {/,/^}/p' hooks/scripts/task-gate.sh)

echo "-- AC-C4: single-call PASS/FAIL/BLOCKED writes ------------------------"

proj="$tmproot/proj1"
dot="$proj/.claude"
mkdir -p "$proj"
run_helper() { ( cd "$proj" && CLAUDE_PROJECT_DIR="$proj" "$helper" "$@" ); }

rc=0
run_helper PASS unitA abc123 "bash tests/validate.sh" .claude/reviewed/unitA.pass || rc=$?
if [ "$rc" = 0 ] && task_id=unitA dot="$proj/.claude" marker_valid; then
  pass "PASS: one call writes a marker_valid()-valid marker"
else
  bad "PASS: rc=$rc, marker_valid failed"
fi
first="$(head -n1 "$proj/.claude/reviewed/unitA.pass" 2>/dev/null || true)"
case "$first" in
  "PASS unitA "*"commit: abc123 criteria: bash tests/validate.sh")
    pass "PASS: first line carries commit and criteria fields" ;;
  *) bad "PASS: unexpected first line [$first]" ;;
esac

rc=0
run_helper FAIL unitB - $'defect one\ndefect two' .claude/reviewed/unitB.fail || rc=$?
if [ "$rc" = 0 ] && marker_format_valid "$proj/.claude/reviewed/unitB.fail" unitB FAIL; then
  pass "FAIL: one call writes a marker_format_valid()-valid marker"
else
  bad "FAIL: rc=$rc, marker_format_valid failed"
fi
if grep -q '^defect one$' "$proj/.claude/reviewed/unitB.fail" && grep -q '^defect two$' "$proj/.claude/reviewed/unitB.fail"; then
  pass "FAIL: defect list persisted verbatim on the lines after the first"
else
  bad "FAIL: defect list not found verbatim"
fi

rc=0
run_helper BLOCKED unitC - "criterion X could not be reached" .claude/reviewed/unitC.blocked || rc=$?
if [ "$rc" = 0 ] && marker_format_valid "$proj/.claude/reviewed/unitC.blocked" unitC BLOCKED; then
  pass "BLOCKED: one call writes a marker_format_valid()-valid marker"
else
  bad "BLOCKED: rc=$rc, marker_format_valid failed"
fi
first="$(head -n1 "$proj/.claude/reviewed/unitC.blocked" 2>/dev/null || true)"
case "$first" in
  "BLOCKED unitC "*"missing: criterion X could not be reached")
    pass "BLOCKED: first line carries the missing: field" ;;
  *) bad "BLOCKED: unexpected first line [$first]" ;;
esac

echo
echo "-- item12-1: FAIL blocks append, not truncate --------------------------"

run_helper FAIL unitG - 'Defect A' .claude/reviewed/unitG.fail
run_helper FAIL unitG - 'Defect B' .claude/reviewed/unitG.fail
fail_file="$proj/.claude/reviewed/unitG.fail"
anchor_count="$(grep -cE '^FAIL unitG ' "$fail_file" || true)"
if [ "$anchor_count" = 2 ]; then
  pass "item12-1: two FAILs for one unit yield 2 FAIL anchor lines"
else
  bad "item12-1: expected 2 FAIL anchor lines, got $anchor_count"
fi
first="$(head -n1 "$fail_file")"
case "$first" in
  "FAIL unitG "*) pass "item12-1: first line is still the first FAIL's anchor" ;;
  *) bad "item12-1: unexpected first line [$first]" ;;
esac
if grep -q '^Defect A$' "$fail_file" && grep -q '^Defect B$' "$fail_file"; then
  pass "item12-1: both defect lists persisted verbatim"
else
  bad "item12-1: a defect list was lost"
fi

run_helper PASS unitH abc123 "criteria one" .claude/reviewed/unitH.pass
run_helper PASS unitH def456 "criteria two" .claude/reviewed/unitH.pass
pass_anchor_count="$(grep -cE '^PASS unitH ' "$proj/.claude/reviewed/unitH.pass" || true)"
if [ "$pass_anchor_count" = 1 ]; then
  pass "item12-1: two PASSes for one unit still yield exactly 1 PASS anchor line (no leak into .pass)"
else
  bad "item12-1: expected 1 PASS anchor line, got $pass_anchor_count"
fi

echo
echo "-- AC-C5: rejection (malformed id / missing commit / no write) -------"

reject_case() {
  local label="$1" expect_no_file="$2"; shift 2
  local rc=0
  ( cd "$proj" && CLAUDE_PROJECT_DIR="$proj" "$helper" "$@" ) >/dev/null 2>"$tmproot/stderr" || rc=$?
  if [ "$rc" = 0 ]; then
    bad "$label -> rc=0, expected a nonzero rejection"
    return
  fi
  if [ ! -s "$tmproot/stderr" ]; then
    bad "$label -> rejected with no stderr reason"
    return
  fi
  if [ -n "$expect_no_file" ] && [ -e "$proj/$expect_no_file" ]; then
    bad "$label -> rejected, but $expect_no_file was written anyway"
    return
  fi
  pass "$label -> rejected (rc=$rc) with a reason, no write"
}

reject_case "malformed unit id (leading dot)" .claude/reviewed/.bad.pass \
  PASS .bad abc123 "criteria" .claude/reviewed/.bad.pass
reject_case "malformed unit id (embedded slash)" "" \
  PASS "unit/x" abc123 "criteria" ".claude/reviewed/unit/x.pass"
reject_case "malformed unit id (embedded space)" "" \
  PASS "unit x" abc123 "criteria" ".claude/reviewed/unit x.pass"
reject_case "malformed unit id (65 chars, over the 64 cap)" "" \
  PASS "$(printf 'a%.0s' $(seq 1 65))" abc123 "criteria" \
  ".claude/reviewed/$(printf 'a%.0s' $(seq 1 65)).pass"
echo
echo "-- M5 drift reproduction: a unit id containing # round-trips (gate-audit-step5) --"
rc=0
run_helper FAIL 'gh#348' - 'defect' '.claude/reviewed/gh#348.fail' || rc=$?
if [ "$rc" = 0 ] && [ -f "$proj/.claude/reviewed/gh#348.fail" ] && marker_format_valid "$proj/.claude/reviewed/gh#348.fail" 'gh#348' FAIL; then
  pass "M5: marker-write.sh writes .claude/reviewed/gh#348.fail for a #-bearing unit id, unrewritten"
else
  bad "M5: marker-write.sh -> rc=$rc, expected a valid gh#348.fail marker"
fi

reject_case "PASS with a missing/empty commit" unitD.pass \
  PASS unitD "" "criteria" .claude/reviewed/unitD.pass
reject_case "unknown verdict" unitE.pass \
  ESCALATED unitE abc123 "criteria" .claude/reviewed/unitE.pass
reject_case "marker-path does not match verdict/unit-id" unitF.fail \
  PASS unitF abc123 "criteria" .claude/reviewed/unitF.fail

echo
echo "-- AC-C4/AC-C5: gate interaction (the empirical check) ----------------"

cfg='{"gatedAgents":["lead-programmer"],"personaSelection":["reviewer"],"testAndLintCommand":"true"}'
gproj="$tmproot/gate-proj"
dot="$gproj/.claude"
mkdir -p "$gproj/.claude/reviewed"
printf '%s\n' "$cfg" > "$gproj/.claude/persona-config.json"

helper_cmd="bash hooks/scripts/marker-write.sh PASS spec2-unitC abc123 \"bash tests/validate.sh\" .claude/reviewed/spec2-unitC.pass"

gate_run() {
  local gate="$1" agent="$2"
  printf '%s' "$(jq -n --arg a "$agent" --arg c "$helper_cmd" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" \
    | CLAUDE_PROJECT_DIR="$gproj" bash "$gate" >/dev/null 2>"$tmproot/stderr"
}

# Since lean-pipeline D5 both path gates allow every Bash command, so this loop,
# the design-constraint proof and the human-decision-gate loop below can no longer fail
# and are kept as smoke checks.
for id in reviewer antislop:reviewer; do
  rc=0; gate_run "$gate_rpg" "$id" || rc=$?
  if [ "$rc" = 0 ]; then
    pass "reviewed-path-gate.sh: helper invocation ALLOWED for $id"
  else
    bad "reviewed-path-gate.sh: helper invocation for $id -> rc=$rc, expected 0"
  fi
done

# Design-constraint proof (not merely reasoned about): a hypothetical helper
# invocation whose command text omits the marker-path argument entirely would
# NOT mention .claude/reviewed at all, so reviewed-path-gate.sh's substring
# early-exit would let it through the gate even for lead-programmer - this is
# exactly the capability leak the "Critical design constraint" section warns
# against. Demonstrated here, then contrasted with the real helper_cmd (which
# spells the marker path); since 0.32.0 the gates allow every Bash command, so
# the real helper_cmd is allowed too.
vuln_cmd="bash hooks/scripts/marker-write.sh PASS spec2-unitC abc123 \"bash tests/validate.sh\""
rc=0
printf '%s' "$(jq -n --arg a lead-programmer --arg c "$vuln_cmd" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" \
  | CLAUDE_PROJECT_DIR="$gproj" bash "$gate_rpg" >/dev/null 2>"$tmproot/stderr" || rc=$?
if [ "$rc" = 0 ]; then
  pass "design-constraint proof: a hypothetical no-marker-path-argument invocation would slip past the gate (rc=0) - confirms spelling the path is load-bearing"
else
  bad "design-constraint proof: expected the no-marker-path-argument invocation to be ALLOWED (demonstrating the leak this design avoids), got rc=$rc"
fi

for id in lead-programmer reviewer; do
  rc=0; gate_run "$gate_hdg" "$id" || rc=$?
  if [ "$rc" = 0 ]; then
    pass "human-decision-gate.sh: helper invocation ALLOWED for $id (unrelated file)"
  else
    bad "human-decision-gate.sh: helper invocation for $id -> rc=$rc, expected 0"
  fi
done

# Execute the helper for real, as the reviewer would, proving the single
# invocation both passes the gate AND produces a correct marker.
rc=0
( cd "$gproj" && CLAUDE_PROJECT_DIR="$gproj" "$helper" PASS spec2-unitC abc123 "bash tests/validate.sh" .claude/reviewed/spec2-unitC.pass ) >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && task_id=spec2-unitC dot="$gproj/.claude" marker_valid; then
  pass "one real invocation produces a marker_valid()-valid marker"
else
  bad "real invocation failed or produced an invalid marker (rc=$rc)"
fi

echo
echo "-- AC-C6: scope guard - spec2-unitC's own commit touched neither path gate --"

unit_commit=233c0fc   # feat(spec2-unitC): single-call marker-write helper
if git -C "$repo" cat-file -e "${unit_commit}^{commit}" 2>/dev/null; then
  touched="$(git -C "$repo" show --name-only --format= "$unit_commit" -- \
    hooks/scripts/reviewed-path-gate.sh \
    hooks/scripts/human-decision-gate.sh \
    .claude/hooks/scripts/reviewed-path-gate.sh \
    .claude/hooks/scripts/human-decision-gate.sh)"
  if [ -z "$touched" ]; then
    pass "AC-C6: spec2-unitC commit $unit_commit edited neither path gate (nor either mirror)"
  else
    bad "AC-C6: spec2-unitC commit $unit_commit edited: $(echo "$touched" | tr '\n' ' ')"
  fi
else
  echo "SKIP AC-C6: commit $unit_commit is unreachable here (shallow or rewritten history)"
fi

echo
exit "$fail"
