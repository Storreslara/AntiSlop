#!/usr/bin/env bash
# Behavioral regression suite for hooks/scripts/human-decision-gate.sh: blocks
# every agent identity from writing .claude/human-review/<task-id>/DECISION,
# no grant branch, no fallback. Canned hook-input JSON piped over stdin,
# fixtures seeded under mktemp -d - no claude CLI, no network, no live
# dispatch. Same idiom as tests/reviewed-path-gate.test.sh.
#
# Fixture hygiene: testAndLintCommand is "true", NEVER this repo's
# `bash tests/validate.sh` - this suite runs FROM validate.sh and would recurse.
set -euo pipefail
cd "$(dirname "$0")/.."
unset CLAUDE_PLUGIN_ROOT || true
fail=0

gate="hooks/scripts/human-decision-gate.sh"

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
errf="$tmproot/stderr"

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

mk() {
  local d="$tmproot/$1"
  mkdir -p "$d/.claude/human-review/u1"
  printf '%s' "$d"
}
proj="$(mk proj)"

run() {
  rc=0
  : > "$errf"
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$2" bash "$gate" >/dev/null 2>"$errf" || rc=$?
}

check() {
  if [ "$2" = allowed ]; then
    [ "$rc" = 0 ] && pass "$1 -> allowed" || bad "$1 -> rc=$rc, expected 0 (allowed)"
  elif [ "$rc" = 2 ] && [ -s "$errf" ]; then
    pass "$1 -> blocked"
  else
    bad "$1 -> rc=$rc with $(wc -c < "$errf") bytes of stderr, expected rc=2 and a reason"
  fi
}

# $1 label, $2 verdict, $3 agent_type, $4 file_path, $5 project dir
write_case() {
  run "$(jq -n --arg a "$3" --arg p "$4" '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$p}}')" \
      "${5:-$proj}"
  check "$1" "$2"
}

# $1 label, $2 verdict, $3 agent_type, $4 command, $5 project dir (default $proj)
bash_case() {
  run "$(jq -n --arg a "$3" --arg c "$4" '{tool_name:"Bash",agent_type:$a,tool_input:{command:$c}}')" \
      "${5:-$proj}"
  check "$1" "$2"
}

echo "-- Write/Edit path: DECISION is unwritable, no grant branch --"
write_case "case a Write DECISION as reviewer" blocked antislop:reviewer \
  ".claude/human-review/u1/DECISION"
write_case "case b Write DECISION, empty agent_type (main session)" blocked "" \
  ".claude/human-review/u1/DECISION"
write_case "case c Write DECISION as orchestrator" blocked antislop:orchestrator \
  ".claude/human-review/u1/DECISION"
write_case "case g Write PACKET.md as reviewer (gate is DECISION-specific)" allowed \
  antislop:reviewer ".claude/human-review/u1/PACKET.md"
write_case "case h Write DECISION via dot-segments (normalization holds)" blocked \
  antislop:reviewer ".claude/human-review/u1/../u1/DECISION"

echo
echo "-- Bash path: substring early-exit, then command_is_provably_benign() --"
for id in antislop:reviewer "" antislop:orchestrator; do
  bash_case "case d printf > DECISION as '$id'" blocked "$id" \
    "printf 'DECISION u1 approved' > .claude/human-review/u1/DECISION"
done
bash_case "case e cat DECISION (reads allowed)" allowed antislop:reviewer \
  "cat .claude/human-review/u1/DECISION"
bash_case "case f heredoc mentioning both (lexer fails closed)" blocked antislop:reviewer \
  "cat <<EOF
human-review DECISION
EOF"
bash_case "case i rm -rf the whole packet dir (sanctioned deletion path)" allowed \
  antislop:reviewer "rm -rf .claude/human-review/u1"

echo
echo "-- every block logs decision-gate-denied, reviewer included --"
audit_log="$proj/.claude/review-audit.log"
: > "$audit_log"
write_case "case j audit: reviewer blocked Write logs decision-gate-denied" blocked \
  antislop:reviewer ".claude/human-review/u1/DECISION"
if grep -q "decision-gate-denied identity=antislop:reviewer" "$audit_log"; then
  pass "case j decision-gate-denied line logged for reviewer"
else
  bad "case j no decision-gate-denied line found in audit log"
fi

echo
exit "$fail"
