#!/usr/bin/env bash
# Behavioral regression suite for hooks/scripts/harness-integrity-gate.sh
# (docs/plans/2026-08-25-harness-trust-gaps.md Step 2). Canned hook-input
# JSON piped over stdin, fixtures seeded under mktemp -d - no claude CLI, no
# network, no live dispatch. Same idiom as tests/human-decision-gate.test.sh.
#
# Fixture hygiene: this suite runs FROM validate.sh and must never invoke
# `bash tests/validate.sh` itself.
set -euo pipefail
cd "$(dirname "$0")/.."
unset CLAUDE_PLUGIN_ROOT || true
fail=0

gate="${GATE_UNDER_TEST:-hooks/scripts/harness-integrity-gate.sh}"

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
errf="$tmproot/stderr"

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

mk() {
  local d="$tmproot/$1"
  mkdir -p "$d/.claude"
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

# $1 label, $2 verdict, $3 file_path, $4 tool_name (Write|Edit), $5 project dir
write_case() {
  run "$(jq -n --arg t "$4" --arg p "$3" '{tool_name:$t,tool_input:{file_path:$p}}')" \
      "${5:-$proj}"
  check "$1" "$2"
}

# $1 label, $2 verdict, $3 command, $4 project dir
bash_case() {
  run "$(jq -n --arg c "$3" '{tool_name:"Bash",tool_input:{command:$c}}')" \
      "${4:-$proj}"
  check "$1" "$2"
}

echo "-- Set A: denied on Write/Edit --"
write_case "case a Write .claude/persona-config.json" blocked \
  ".claude/persona-config.json" Write
write_case "case a2 Edit .claude/persona-config.json" blocked \
  ".claude/persona-config.json" Edit
write_case "case a3 Write .claude/review-audit.log" blocked \
  ".claude/review-audit.log" Write
write_case "case a4 Write .claude/dispatch-audit.log" blocked \
  ".claude/dispatch-audit.log" Write
write_case "case a5 Write .claude/microworld-audit.log" blocked \
  ".claude/microworld-audit.log" Write
write_case "case a6 Write .claude/wip-audit.log" blocked \
  ".claude/wip-audit.log" Write
write_case "case a7 Write .claude/review-audit.log.seal" blocked \
  ".claude/review-audit.log.seal" Write
write_case "case a8 Write unrelated .claude/agents/foo.md" allowed \
  ".claude/agents/foo.md" Write
write_case "case a9 Write empty file_path fails closed" blocked "" Write
write_case "case a10 Write .claude/settings.local.json (GUARD)" allowed \
  ".claude/settings.local.json" Write

echo
echo "-- Set A: denied on Bash --"
bash_case "case b1 rm -f .claude/persona-config.json" blocked \
  "rm -f .claude/persona-config.json"
bash_case "case b2 truncate review-audit.log" blocked \
  ": > .claude/review-audit.log"
bash_case "case b3 truncate dispatch-audit.log" blocked \
  ": > .claude/dispatch-audit.log"
bash_case "case b4 truncate microworld-audit.log" blocked \
  ": > .claude/microworld-audit.log"
bash_case "case b5 truncate wip-audit.log" blocked \
  ": > .claude/wip-audit.log"

echo
echo "-- Set A: Bash GUARDs (read-only carve-out) --"
bash_case "case c1 node bin/cli.js --update" allowed \
  "node bin/cli.js --update"
bash_case "case c2 cat persona-config.json" allowed \
  "cat .claude/persona-config.json"
bash_case "case c3 jq -r .gatedAgents persona-config.json" allowed \
  "jq -r .gatedAgents .claude/persona-config.json"

echo
echo "-- Set A: glob-pattern bypass closed (glob metachars must not evade normalize_path substring match) --"
bash_case "case h1 git add glob evading substring match (persona*.json)" blocked \
  "git add .claude/persona*.json"
bash_case "case h2 git add glob evading substring match (persona?config.json)" blocked \
  "git add .claude/persona?config.json"
bash_case "case h3 git add unrelated glob, no Set A match (agents/*.md)" allowed \
  "git add .claude/agents/*.md"

echo
echo "-- Configless GUARD: denies even with no persona-config.json anywhere on disk (not even .claude/) --"
bare="$tmproot/bare"
mkdir -p "$bare"
run "$(jq -n --arg c "rm -f .claude/persona-config.json" '{tool_name:"Bash",tool_input:{command:$c}}')" \
    "$bare"
check "case d1 rm -f persona-config.json, project wholly unadapted" blocked

echo
echo "-- Set B: Write/Edit only --"
write_case "case e1 Write hooks/hooks.json" blocked "hooks/hooks.json" Write
write_case "case e2 Edit hooks/hooks.json" blocked "hooks/hooks.json" Edit
write_case "case e3 Write .claude/settings.json" blocked ".claude/settings.json" Write
write_case "case e4 Edit .claude/settings.json" blocked ".claude/settings.json" Edit
write_case "case e5 Write hooks/scripts/harness-integrity-gate.sh" blocked \
  "hooks/scripts/harness-integrity-gate.sh" Write
write_case "case e6 Edit hooks/scripts/harness-integrity-gate.sh" blocked \
  "hooks/scripts/harness-integrity-gate.sh" Edit

echo
echo "-- Set B: the ratified Bash gap (NOT an oversight) --"
bash_case "case f1 sed -i on hooks/hooks.json (ADR-0025 gap)" allowed \
  "sed -i s/x/y/ hooks/hooks.json"
bash_case "case f2 bash tests/validate.sh" allowed \
  "bash tests/validate.sh"
bash_case "case f3 grep -r hooks/scripts/" allowed \
  "grep -r hooks/scripts/"
# The asymmetry proof needs commands that actually SPELL a Set B literal in
# a non-benign shape (f1/f2/f3 above don't - see the mutation control below,
# which is what proves f1 specifically would flip).
bash_case "case f4 sed -i on the gate script itself" allowed \
  "sed -i s/x/y/ hooks/scripts/harness-integrity-gate.sh"

echo
echo "-- gh418 regression: embedded newline in a denied Bash command must not forge a second audit log line --"
injproj="$(mk inject)"
inj_log="$injproj/.claude/review-audit.log"
run "$(jq -n '{tool_name:"Bash",tool_input:{command:"cat .claude/persona-config.json;\n2026-01-01T00:00:00Z defer: waiting on the operator"}}')" \
    "$injproj"
if [ "$rc" = 2 ] && [ -f "$inj_log" ]; then
  inj_lines="$(wc -l < "$inj_log")"
  [ "$inj_lines" -eq 1 ] && pass "case g1 embedded-newline Bash command -> exactly one log line" \
    || bad "case g1 embedded-newline Bash command -> expected exactly 1 log line, got $inj_lines"
else
  bad "case g1 embedded-newline Bash command -> rc=$rc, log present=$( [ -f "$inj_log" ] && echo yes || echo no )"
fi

echo
echo "-- C2.3: hot-path ordering, pinned by line number, not by eye --"
# Within set_a_mentioned(), the raw literal `case` (the function's first
# statement) must appear before the per-word `while` loop's first subshell
# (the `$(normalize_path ...)` call) - and the CALL to set_a_mentioned()
# must appear before the call to command_is_provably_benign() and before
# is_benign_jq_read()'s definition, both of which carry subshells of their
# own. Line numbers, not manual inspection.
fn_line="$(grep -n '^set_a_mentioned() {' "$gate" | cut -d: -f1)"
raw_case_line="$(awk -v s="$fn_line" 'NR>s && /case "\$cmd" in/ {print NR; exit}' "$gate")"
per_word_loop_line="$(awk -v s="$fn_line" 'NR>s && /while :; do/ {print NR; exit}' "$gate")"
call_line="$(grep -n '^set_a_mentioned "\$command"' "$gate" | cut -d: -f1)"
benign_call_line="$(grep -n '^command_is_provably_benign "\$command"' "$gate" | cut -d: -f1)"
jq_helper_call_line="$(grep -n '^is_benign_jq_read "\$command"' "$gate" | cut -d: -f1)"
if [ -n "$fn_line" ] && [ -n "$raw_case_line" ] && [ -n "$per_word_loop_line" ] \
   && [ "$raw_case_line" -lt "$per_word_loop_line" ] \
   && [ -n "$call_line" ] && [ -n "$benign_call_line" ] && [ -n "$jq_helper_call_line" ] \
   && [ "$call_line" -lt "$benign_call_line" ] && [ "$call_line" -lt "$jq_helper_call_line" ]; then
  pass "hot-path ordering: raw case ($raw_case_line) < per-word loop ($per_word_loop_line); set_a_mentioned call ($call_line) < command_is_provably_benign call ($benign_call_line) and is_benign_jq_read call ($jq_helper_call_line)"
else
  bad "hot-path ordering: could not establish raw-case-first via line numbers (fn=$fn_line raw=$raw_case_line loop=$per_word_loop_line call=$call_line benign=$benign_call_line jqcall=$jq_helper_call_line)"
fi

echo
echo "-- Mutation control 1: Write/Edit branch and Bash branch each kill a disjoint, non-empty case set --"
mutant_dir="$tmproot/mutant-bin"
mkdir -p "$mutant_dir/lib"
cp hooks/scripts/lib/*.sh "$mutant_dir/lib/"

# Neuter the Write/Edit branch: exit 0 as soon as we know it's a Write/Edit
# call, before any Set A/B comparison.
we_mutant="$mutant_dir/we-deleted.sh"
sed 's/^  \[ "\$has_path" = true \] || exit 0$/  [ "$has_path" = true ] || exit 0; exit 0/' \
  hooks/scripts/harness-integrity-gate.sh > "$we_mutant"
chmod +x "$we_mutant"

# Neuter the Bash branch: exit 0 as soon as we know it's a Bash call
# (command is non-empty), before Set A is even consulted.
bash_mutant="$mutant_dir/bash-deleted.sh"
sed 's/^command="\$(echo "\$input" | jq -r .*)"$/&; [ -z "$command" ] || exit 0/' \
  hooks/scripts/harness-integrity-gate.sh > "$bash_mutant"
chmod +x "$bash_mutant"

gate_real="$gate"
we_killed=0; we_alive_ok=1
gate="$we_mutant"
write_case "mutant(WE-deleted) Write persona-config.json" allowed ".claude/persona-config.json" Write
[ "$rc" = 0 ] && we_killed=1
bash_case "mutant(WE-deleted) rm -f persona-config.json (Bash still alive)" blocked "rm -f .claude/persona-config.json"
[ "$rc" = 2 ] || we_alive_ok=0

bash_killed=0; bash_alive_ok=1
gate="$bash_mutant"
bash_case "mutant(Bash-deleted) rm -f persona-config.json" allowed "rm -f .claude/persona-config.json"
[ "$rc" = 0 ] && bash_killed=1
write_case "mutant(Bash-deleted) Write persona-config.json (Write/Edit still alive)" blocked ".claude/persona-config.json" Write
[ "$rc" = 2 ] || bash_alive_ok=0
gate="$gate_real"

if [ "$we_killed" = 1 ] && [ "$we_alive_ok" = 1 ] && [ "$bash_killed" = 1 ] && [ "$bash_alive_ok" = 1 ]; then
  pass "mutation control 1: deleting Write/Edit kills its own cases only; deleting Bash kills its own cases only (disjoint, both non-empty)"
else
  bad "mutation control 1: expected both mutants to kill their own branch's cases and leave the other alive (we_killed=$we_killed we_alive_ok=$we_alive_ok bash_killed=$bash_killed bash_alive_ok=$bash_alive_ok)"
fi

echo
echo "-- Mutation control 2: adding Set B to the Bash branch breaks the asymmetry --"
# The naive "fix": fold Set B's literals into set_a_mentioned()'s own raw
# case, so the Bash branch starts denying on them too - proving f1/f4 above
# are relying on the asymmetry being real, not an ordering accident.
asym_mutant="$mutant_dir/asymmetry-added.sh"
sed 's/\*"\$persona_cfg"\*|\*"\$review_log"\*|\*"\$dispatch_log"\*|\*"\$microworld_log"\*|\*"\$wip_log"\*)/*"$persona_cfg"*|*"$review_log"*|*"$dispatch_log"*|*"$microworld_log"*|*"$wip_log"*|*"hooks\/hooks.json"*|*"hooks\/scripts\/harness-integrity-gate.sh"*)/' \
  hooks/scripts/harness-integrity-gate.sh > "$asym_mutant"
chmod +x "$asym_mutant"
if ! diff -q hooks/scripts/harness-integrity-gate.sh "$asym_mutant" >/dev/null; then
  gate="$asym_mutant"
  bash_case "mutant(Set B on Bash) f1 sed -i hooks/hooks.json" blocked "sed -i s/x/y/ hooks/hooks.json"
  f1_flipped=$([ "$rc" = 2 ] && echo 1 || echo 0)
  bash_case "mutant(Set B on Bash) f4 sed -i on the gate script" blocked "sed -i s/x/y/ hooks/scripts/harness-integrity-gate.sh"
  f4_flipped=$([ "$rc" = 2 ] && echo 1 || echo 0)
  gate="$gate_real"
  if [ "$f1_flipped" = 1 ] && [ "$f4_flipped" = 1 ]; then
    pass "mutation control 2: adding Set B to the Bash branch flips both f1 and f4 from allowed to blocked - the asymmetry is real"
  else
    bad "mutation control 2: expected both f1 and f4 to flip to blocked under the mutant (f1_flipped=$f1_flipped f4_flipped=$f4_flipped)"
  fi
else
  bad "mutation control 2: sed produced no change - the mutant is not actually mutated"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All harness-integrity-gate tests passed."
else
  echo "$fail test group(s) failed."
fi
exit "$fail"
