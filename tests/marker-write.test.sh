#!/usr/bin/env bash
# Behavioral suite for hooks/scripts/marker-write.sh (spec2-unitC): the
# single-call marker-write helper collapsing the reviewer's documented
# "mkdir -p .claude/reviewed" + printf two-step into one invocation.
#
# AC-C4: one invocation writes a format-valid marker, is not denied by
# reviewed-path-gate.sh or human-decision-gate.sh (as the reviewer identity),
# and the marker satisfies stop-gate-core.sh's marker_format_valid() - the
# same function task-gate.sh's marker_valid() mirrors, so testing against it
# covers "one definition of a valid marker, not a third".
# AC-C5: malformed unit id / missing commit are rejected, and the helper's
# own CLI invocation is BLOCKED for a non-reviewer identity exactly as the
# raw printf write is today (reviewed-path-gate.test.sh cases 6/13) - proving
# no new capability.
# AC-C6: reviewed-path-gate.sh and human-decision-gate.sh are byte-identical
# to the pinned commit 33ac79b (the last commit that touched either file),
# proving this unit's own commit made no edit to either gate.
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

# --- extract the real marker_format_valid() definition, rather than
# reimplementing it, so this suite drifts if and only if the real one does.
fmt_valid_src="$tmproot/marker_format_valid.sh"
sed -n '/^marker_format_valid() {/,/^}/p' hooks/scripts/lib/stop-gate-core.sh > "$fmt_valid_src"
[ -s "$fmt_valid_src" ] || { echo "FAIL could not extract marker_format_valid() from stop-gate-core.sh"; exit 1; }
source "$fmt_valid_src"

echo "-- AC-C4: single-call PASS/FAIL/BLOCKED writes ------------------------"

proj="$tmproot/proj1"
mkdir -p "$proj"
run_helper() { ( cd "$proj" && "$helper" "$@" ); }

rc=0
run_helper PASS unitA abc123 "bash tests/validate.sh" .claude/reviewed/unitA.pass || rc=$?
if [ "$rc" = 0 ] && marker_format_valid "$proj/.claude/reviewed/unitA.pass" unitA PASS; then
  pass "PASS: one call writes a marker_format_valid()-valid marker"
else
  bad "PASS: rc=$rc, marker_format_valid failed"
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
echo "-- AC-C5: rejection (malformed id / missing commit / no write) -------"

reject_case() {
  local label="$1" expect_no_file="$2"; shift 2
  local rc=0
  ( cd "$proj" && "$helper" "$@" ) >/dev/null 2>"$tmproot/stderr" || rc=$?
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
mkdir -p "$gproj/.claude/reviewed"
printf '%s\n' "$cfg" > "$gproj/.claude/persona-config.json"

helper_cmd="bash hooks/scripts/marker-write.sh PASS spec2-unitC abc123 \"bash tests/validate.sh\" .claude/reviewed/spec2-unitC.pass"

gate_run() {
  local gate="$1" agent="$2"
  printf '%s' "$(jq -n --arg a "$agent" --arg c "$helper_cmd" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" \
    | CLAUDE_PROJECT_DIR="$gproj" bash "$gate" >/dev/null 2>"$tmproot/stderr"
}

rc=0; gate_run "$gate_rpg" lead-programmer || rc=$?
if [ "$rc" = 2 ] && [ -s "$tmproot/stderr" ]; then
  pass "reviewed-path-gate.sh: helper invocation BLOCKED for lead-programmer (no new capability)"
else
  bad "reviewed-path-gate.sh: helper invocation for lead-programmer -> rc=$rc, expected 2"
fi

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
# spells the marker path) staying BLOCKED above for the same identity.
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
( cd "$gproj" && "$helper" PASS spec2-unitC abc123 "bash tests/validate.sh" .claude/reviewed/spec2-unitC.pass ) >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && marker_format_valid "$gproj/.claude/reviewed/spec2-unitC.pass" spec2-unitC PASS; then
  pass "one real invocation produces a marker_format_valid()-valid marker"
else
  bad "real invocation failed or produced an invalid marker (rc=$rc)"
fi

echo
echo "-- AC-C6: scope guard - reviewed-path-gate.sh / human-decision-gate.sh unchanged --"

pin=33ac79b
for f in hooks/scripts/reviewed-path-gate.sh hooks/scripts/human-decision-gate.sh; do
  pinned_hash="$(git show "$pin:$f" | sha256sum | cut -d' ' -f1)"
  cur_hash="$(sha256sum "$f" | cut -d' ' -f1)"
  if [ "$pinned_hash" = "$cur_hash" ]; then
    pass "AC-C6: $f byte-identical to pinned $pin"
  else
    bad "AC-C6: $f differs from pinned $pin (pinned=$pinned_hash cur=$cur_hash)"
  fi
done

echo
exit "$fail"
