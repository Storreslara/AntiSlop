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
echo "-- sanctioned marker-write template: allowed (N1-N5) --"
bash_case "N1 template writes .pass, body quotes the DECISION path" allowed antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF'
PASS u1 2026-08-12T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: approved, quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N2 same via >> append" allowed antislop:reviewer \
  "cat >> .claude/reviewed/u1.pass <<'EOF'
human: approved, quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N3 body carries \$(), backticks, > and ; as inert data" allowed antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION verbatim:
\$(id) \`id\` > /tmp/x ; rm -rf /
EOF"
bash_case "N4 .fail target" allowed antislop:reviewer \
  "cat > .claude/reviewed/u1.fail <<'EOF'
FAIL u1 - see .claude/human-review/u1/DECISION
EOF"
bash_case "N5 .directed target" allowed antislop:reviewer \
  "cat > .claude/reviewed/u1.directed <<'EOF'
DIRECTED u1 - fix per .claude/human-review/u1/DECISION
EOF"

echo
echo "-- the invariant: DECISION-targeting shapes stay denied (N6-N20) --"
bash_case "N6 P7 early terminator, second command writes the DECISION path" blocked \
  antislop:reviewer "cat > .claude/reviewed/u1.pass <<'EOF'
PASS u1 quoting .claude/human-review/u1/DECISION
EOF
printf approved > .claude/human-review/u1/DECISION"
# N6 above is denied by the last-line rule alone (its final line is the second
# command, not the delimiter), so it does NOT exercise the early-terminator
# guard. N6b does: the delimiter is repeated at the end so the last line still
# looks like a terminator, and only "the FIRST line equal to the delimiter must
# be the last" rejects it. Deleting that guard flips N6b to allowed - verified
# by mutation, which is the whole reason this case exists.
bash_case "N6b early terminator WITH a trailing delimiter line (binds the guard)" \
  blocked antislop:reviewer "cat > .claude/reviewed/u1.pass <<'EOF'
PASS u1 quoting .claude/human-review/u1/DECISION
EOF
printf approved > .claude/human-review/u1/DECISION
EOF"
bash_case "N7 template whose target IS the DECISION path" blocked antislop:reviewer \
  "cat > .claude/human-review/u1/DECISION <<'EOF'
approved
EOF"
bash_case "N8 unquoted heredoc delimiter" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<EOF
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N9 double-quoted heredoc delimiter" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<\"EOF\"
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N10 command substitution in the target" blocked antislop:reviewer \
  "cat > \$(echo .claude/reviewed)/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N11 shell variable in the target" blocked antislop:reviewer \
  "cat > \$M/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N12 quoted target" blocked antislop:reviewer \
  "cat > '.claude/reviewed/u1.pass' <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N13 target escapes the reviewed dir via .." blocked antislop:reviewer \
  "cat > .claude/reviewed/../human-review/u1/DECISION <<'EOF'
approved
EOF"
bash_case "N14 non-sanctioned suffix (.txt)" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.txt <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N15 a command precedes cat" blocked antislop:reviewer \
  "printf x; cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N16 pipeline into the template" blocked antislop:reviewer \
  "printf x | cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N17 extra redirection on the command line" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF' 2> .claude/human-review/u1/DECISION
PASS u1
EOF"
bash_case "N18 tee in place of cat" blocked antislop:reviewer \
  "tee .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF"
bash_case "N19 unterminated heredoc" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION"
bash_case "N20 terminator only as a substring of a longer line" blocked antislop:reviewer \
  "cat > .claude/reviewed/u1.pass <<'EOF'
quoting .claude/human-review/u1/DECISION
EOF and then some"

echo
echo "-- pinned residual R-2: split-variable target stays ALLOWED, deliberately --"
bash_case "N21 split-variable write to the DECISION path (documented residual)" allowed \
  antislop:reviewer "d=human-rev; e=iew; printf x > .claude/\$d\$e/u1/DECISION"

echo
echo "-- the deny message is instructional (N22-N23) --"
bash_case "N22/N23 setup: a denied DECISION-targeting write" blocked antislop:reviewer \
  "cat > .claude/human-review/u1/DECISION <<'EOF'
approved
EOF"
if grep -qF "cat > .claude/reviewed/<task-id>.pass <<'EOF'" "$errf"; then
  pass "N22 deny message prints the sanctioned template literally"
else
  bad "N22 deny message does not print the sanctioned template line"
fi
if grep -qF 'self-authorized bypass' "$errf"; then
  pass "N23 deny message names the self-authorized bypass class"
else
  bad "N23 deny message does not name 'self-authorized bypass'"
fi
if grep -qF 'rm -rf .claude/human-review/<task-id>' "$errf"; then
  pass "N23b deny message keeps the rm -rf packet-discard guidance"
else
  bad "N23b deny message dropped the rm -rf guidance"
fi

echo
echo "-- widened charclass: dots and hashes in id (N24-N27) --"
bash_case "N24 id with a dot (e.g. gh345.1)" allowed antislop:reviewer \
  "cat > .claude/reviewed/gh345.1.pass <<'EOF'
PASS gh345.1 2026-08-13T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N25 id with a hash (e.g. gh#348)" allowed antislop:reviewer \
  "cat > .claude/reviewed/gh#348.pass <<'EOF'
PASS gh#348 2026-08-13T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N26 leading-dot id rejected (.gh345)" blocked antislop:reviewer \
  "cat > .claude/reviewed/.gh345.pass <<'EOF'
PASS .gh345 2026-08-13T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: quoting .claude/human-review/u1/DECISION verbatim:
EOF"
bash_case "N27 traversal with leading dots rejected (..345)" blocked antislop:reviewer \
  "cat > .claude/reviewed/..345.pass <<'EOF'
PASS ..345 2026-08-13T00:00:00Z commit: abc123 criteria: bash tests/validate.sh
human: quoting .claude/human-review/u1/DECISION verbatim:
EOF"

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
