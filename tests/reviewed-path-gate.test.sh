#!/usr/bin/env bash
# Behavioral regression suite for hooks/scripts/reviewed-path-gate.sh: the
# identity check on the Write/Edit path, and the Bash branch that allows every
# command (lean-pipeline D5, Risk R1). Canned hook-input JSON piped over stdin,
# fixtures seeded under mktemp -d - no claude CLI, no network, no live dispatch.
#
# Fixture hygiene: testAndLintCommand is "true", NEVER this repo's
# `bash tests/validate.sh` - this suite runs FROM validate.sh and would recurse.
set -euo pipefail
cd "$(dirname "$0")/.."
unset CLAUDE_PLUGIN_ROOT || true
fail=0

marker=".claude/reviewed"
# Overridable so a mutation control can point the whole suite at a mutated
# scratch copy without editing the gate in place. Defaults to the real one.
gate="${GATE_UNDER_TEST:-hooks/scripts/reviewed-path-gate.sh}"

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
errf="$tmproot/stderr"

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

cfg_reviewer='{"gatedAgents":["lead-programmer"],"personaSelection":["reviewer"],"testAndLintCommand":"true"}'
cfg_none='{"gatedAgents":["lead-programmer"],"personaSelection":["explorer"],"testAndLintCommand":"true"}'

mk() {
  local d="$tmproot/$1"
  mkdir -p "$d/.claude/reviewed"
  printf '%s\n' "$2" > "$d/.claude/persona-config.json"
  printf '%s' "$d"
}
proj="$(mk with-reviewer "$cfg_reviewer")"
proj_none="$(mk no-reviewer "$cfg_none")"
proj_escalated="$(mk no-reviewer-escalated "$cfg_none")"
touch "$proj_escalated/.claude/reviewed/u9.escalated"

rc=0
run() {
  rc=0
  : > "$errf"
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$2" bash "$gate" >/dev/null 2>"$errf" || rc=$?
}

# Exact exit codes on purpose: a script that crashes under `set -e` exits 1, and
# a blocked verdict must also carry a reason on stderr, so neither can be
# mistaken for a deliberate block.
check() {
  if [ "$2" = allowed ]; then
    [ "$rc" = 0 ] && pass "$1 -> allowed" || bad "$1 -> rc=$rc, expected 0 (allowed)"
  elif [ "$rc" = 2 ] && [ -s "$errf" ]; then
    pass "$1 -> blocked"
  else
    bad "$1 -> rc=$rc with $(wc -c < "$errf") bytes of stderr, expected rc=2 and a reason"
  fi
}

# $1 label, $2 verdict, $3 agent_type, $4 command, $5 project dir (default $proj)
bash_case() {
  run "$(jq -n --arg a "$3" --arg c "$4" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" \
      "${5:-$proj}"
  check "$1" "$2"
}

# $1 label, $2 verdict, $3 agent_type, $4 file_path, $5 project dir
write_case() {
  run "$(jq -n --arg a "$3" --arg p "$4" '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$p}}')" \
      "${5:-$proj}"
  check "$1" "$2"
}

echo "-- Bash is never scanned (lean-pipeline D5, Risk R1) --"
bash_case "lean-pipeline R1 bash marker write allowed" allowed lead-programmer \
  "printf x > $marker/a.pass"
write_case "lean-pipeline R1 write marker blocked" blocked lead-programmer \
  "$marker/a.pass"

echo
echo "-- identity rules preserved --"
for id in reviewer antislop:reviewer; do
  write_case "case 13 $id Write into the marker dir (GRANT intact)" allowed "$id" \
    "$marker/9.pass"
done
write_case "case 14 empty agent_type Write, no reviewer selected (fallback intact)" \
  allowed "" "$marker/9.pass" "$proj_none"
write_case "case 14 empty agent_type Write, reviewer selected" \
  blocked "" "$marker/9.pass" "$proj"

echo
echo "-- Write/Edit tool path (Step 2) --"
write_case "case 15 Write into the marker dir as lead-programmer" blocked lead-programmer \
  "$marker/9.pass"
write_case "case 16 Write into the marker dir as reviewer (GRANT intact)" allowed reviewer \
  "$marker/9.pass"
write_case "case 17 Write to an unrelated path as lead-programmer (no over-block)" allowed \
  lead-programmer "docs/notes.md"
write_case "case 18 absolute-path form of case 15 (normalization)" blocked lead-programmer \
  "$proj/$marker/9.pass"
write_case "case 18b dot-segment form of case 15 (normalization)" blocked lead-programmer \
  ".claude/agents/../reviewed/9.pass"
run '{"tool_name":"NotebookEdit","agent_type":"lead-programmer","tool_input":{"notebook_path":".claude/reviewed/9.ipynb"}}' "$proj"
check "case 18c payload with no file_path key at all (notebook editing unaffected)" allowed
run '{"tool_name":"Write","agent_type":"lead-programmer","tool_input":{"file_path":""}}' "$proj"
check "case 18d Write with an unreadable target fails closed" blocked

echo
echo "-- path-gate-logs-grant-denied: audit logging for blocked non-reviewer access --"
# Create a fixture with audit log and test grant-denied logging
audit_fixture="$(mk audit-test "$cfg_reviewer")"
audit_log="$audit_fixture/.claude/review-audit.log"
touch "$audit_log"

# Test 1: non-reviewer agent should log grant-denied when blocked
run "$(jq -n --arg a "rev-302" --arg c "$marker/9.pass" '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$c}}')" "$audit_fixture"
check "case 33 non-reviewer blocked Write logs grant-denied" blocked
if [ -s "$audit_log" ] && grep -q "grant-denied.*identity=" "$audit_log"; then
  grant_denied_count=$(grep -c "grant-denied" "$audit_log" 2>/dev/null || true)
  if [ "$grant_denied_count" -eq 1 ]; then
    pass "case 33 grant-denied audit: exactly one grant-denied line logged"
  else
    bad "case 33 grant-denied audit: got $grant_denied_count lines, expected 1"
  fi
else
  bad "case 33 grant-denied audit: no grant-denied line found in audit log"
fi

# Test 2: reviewer agent should NOT log grant-denied (access allowed)
: > "$audit_log"  # Clear the log
run "$(jq -n --arg a "reviewer" --arg c "$marker/9.pass" '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$c}}')" "$audit_fixture"
check "case 34 reviewer Write allowed (no grant-denied logged)" allowed
if grep -q "grant-denied" "$audit_log" 2>/dev/null; then
  bad "case 34 reviewer access: grant-denied should not be logged for allowed access"
else
  pass "case 34 reviewer access: no grant-denied line (as expected)"
fi

# Test 3: mutation control - verify grant-denied is logged only when blocked
run "$(jq -n --arg a "lead-programmer" --arg c "$marker/9.pass" '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$c}}')" "$audit_fixture"
: > "$audit_log"  # Reset before checking
check "case 35 lead-programmer also blocked" blocked
echo

echo "-- gh326: no-reviewer fallback suspended while an escalation stands --"
write_case "case j  empty agent_type Write, standing escalation" blocked "" \
  "$marker/u9.pass" "$proj_escalated"
write_case "case l  empty agent_type Write, no escalation standing (fallback preserved)" allowed "" \
  "$marker/u9.pass" "$proj_none"
write_case "case n  antislop:reviewer Write, standing escalation (GRANT unaffected)" allowed \
  "antislop:reviewer" "$marker/u9.pass" "$proj_escalated"
echo

echo "-- gate-audit-step4/M4: orchestrator identity in the no-reviewer fallback --"
for id in orchestrator antislop:orchestrator; do
  write_case "case o  $id Write, no reviewer selected (now reachable)" allowed "$id" \
    "$marker/9.pass" "$proj_none"
done
write_case "case p  orchestrator Write, standing escalation (still refused)" blocked \
  orchestrator "$marker/9.pass" "$proj_escalated"
write_case "case q  orchestrator Write, reviewer selected (no widening)" blocked \
  orchestrator "$marker/9.pass" "$proj"
write_case "case r  lead-programmer Write, no reviewer selected (no widening)" blocked \
  lead-programmer "$marker/9.pass" "$proj_none"
echo

echo "-- denial message shape (ptr-u7a): at most 70 words, remedy tokens, glossary pointer --"
denial_shape() { # $1 label, $2 hook-input JSON, $3 newline-separated fixed-string tokens
  local words first tok
  run "$2" "$proj"
  words="$(wc -w < "$errf")"
  first="$(head -n 1 "$errf" | wc -w)"
  [ "$rc" = 2 ] && pass "$1 exit code 2" || bad "$1 exit code -> $rc, expected 2"
  [ "$(wc -l < "$errf")" = 3 ] && pass "$1 is 3 lines" || bad "$1 is not 3 lines"
  [ "$first" -le 25 ] && pass "$1 line 1 is $first words (<= 25)" || bad "$1 line 1 is $first words, expected <= 25"
  [ "$words" -le 70 ] && pass "$1 is $words words (<= 70)" || bad "$1 is $words words, expected <= 70"
  while IFS= read -r tok; do
    if grep -qF -- "$tok" "$errf"; then pass "$1 carries: $tok"; else bad "$1 lacks: $tok"; fi
  done <<< "$3"
}
rpg_toks='grep -r
git commit -F
self-authorized bypass whether or not this gate blocks it
More: docs/harness-glossary.md — "reviewed-path denial"'
denial_shape "write branch denial" "$(jq -n --arg a lead-programmer --arg p "$marker/9.pass" '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$p}}')" "$rpg_toks"
if grep -qF '**reviewed-path denial**:' docs/harness-glossary.md; then
  pass "glossary carries the reviewed-path denial term"
else
  bad "docs/harness-glossary.md has no **reviewed-path denial** entry"
fi

exit "$fail"
