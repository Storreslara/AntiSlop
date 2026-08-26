#!/usr/bin/env bash
# Fixture-driven test for stop-gate.sh's Unit A "deferred result surfacing"
# block (hooks/scripts/lib/stop-gate-core.sh) - the PRIMARY channel that
# reports what microworld-rerun.sh's async enqueue deferred (AC-A3). Canned
# hook-input JSON piped to the real script - no real claude/agent dependency.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  # $1 = case name -> a fresh, otherwise-clean project (no other stop-gate
  # check should fire): no gatedAgents match, so only the deferred-reporting
  # block (which runs unconditionally) is under test.
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
    > "$dir/.claude/persona-config.json"
  echo "$dir"
}

run_stop() {
  # $1 = project dir -> a main-session Stop; stderr captured to stderr.txt
  local rc=0
  printf '%s' '{"hook_event_name":"Stop","session_id":"main"}' \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/stop-gate.sh 2>"$tmproot/stderr.txt" || rc=$?
  return "$rc"
}

# (a) AC-A3: an unreported result=fail audit line -> Stop blocks (exit 2),
#     stderr names the same unit slug the synchronous hook used to name.
dir="$(make_project fail)"
printf '2026-08-26T00:00:00Z unit=widget result=fail file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
rc=0
run_stop "$dir" || rc=$?
if [ "$rc" = 2 ] && grep -q 'widget' "$tmproot/stderr.txt"; then
  echo "OK   (a) AC-A3: an unreported deferred failure blocks Stop (exit 2) and names the unit"
else
  echo "FAIL (a) expected exit 2 naming 'widget' (rc=$rc stderr=[$(cat "$tmproot/stderr.txt")])"
  fail=1
fi

# (b) an audit log with only result=pass lines -> does not block
dir="$(make_project pass)"
printf '2026-08-26T00:00:00Z unit=widget result=pass file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
rc=0
run_stop "$dir" || rc=$?
if [ "$rc" = 0 ]; then
  echo "OK   (b) an all-pass audit log does not block Stop"
else
  echo "FAIL (b) expected exit 0 for an all-pass audit log (rc=$rc)"
  fail=1
fi

# (c) REPORTED ONCE: after (a) already blocked and advanced the watermark,
#     a second Stop with no NEW audit lines does not re-block for the same
#     failure (the agent must be able to end its turn once it has SEEN the
#     report - re-blocking forever on stale news would be a different bug).
dir="$(make_project once)"
printf '2026-08-26T00:00:00Z unit=widget result=fail file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
run_stop "$dir" > /dev/null 2>&1 || true
rc=0
run_stop "$dir" || rc=$?
if [ "$rc" = 0 ]; then
  echo "OK   (c) the same failure is not re-reported (does not re-block) on a second Stop"
else
  echo "FAIL (c) expected exit 0 on the second Stop (rc=$rc stderr=[$(cat "$tmproot/stderr.txt")])"
  fail=1
fi

# (d) a NEW failure appended after the watermark blocks again
dir="$(make_project newfail)"
printf '2026-08-26T00:00:00Z unit=widget result=pass file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
run_stop "$dir" > /dev/null 2>&1 || true
printf '2026-08-26T00:01:00Z unit=gadget result=fail file=src/other.js\n' \
  >> "$dir/.claude/microworld-audit.log"
rc=0
run_stop "$dir" || rc=$?
if [ "$rc" = 2 ] && grep -q 'gadget' "$tmproot/stderr.txt"; then
  echo "OK   (d) a new failure appended after the watermark blocks again and is named"
else
  echo "FAIL (d) expected exit 2 naming 'gadget' (rc=$rc stderr=[$(cat "$tmproot/stderr.txt")])"
  fail=1
fi

# (e) MUTATION CONTROL: with the deferred-reporting block's block() call
#     removed, case (a)'s scenario must NOT block - proving (a) is
#     non-vacuous (it fails without the real check, not just "always exit 2").
mutant_lib="$tmproot/mutant-lib"
mkdir -p "$mutant_lib"
cp hooks/scripts/lib/stop-gate-core.sh "$mutant_lib/stop-gate-core.sh"
# Disable the deferred-block guard (the check under test) - the surrounding
# watermark-advance logic stays intact, so only the blocking half is mutated.
sed -i 's/if \[ -n "\$broken" \]; then/if false \&\& [ -n "$broken" ]; then/' \
  "$mutant_lib/stop-gate-core.sh"

cp hooks/scripts/stop-gate.sh "$tmproot/entry.sh"
mkdir -p "$tmproot/lib"
cp hooks/scripts/lib/agent-identity.sh "$tmproot/lib/agent-identity.sh"
python3 - "$tmproot/entry.sh" "$mutant_lib" <<'PYEOF'
import sys
path, mutant_lib = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
content = content.replace(
    'lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"\nsource "${lib_dir}/stop-gate-core.sh"',
    f'lib_dir="{mutant_lib}"\nsource "${{lib_dir}}/stop-gate-core.sh"'
)
with open(path, 'w') as f:
    f.write(content)
PYEOF

dir="$(make_project mutant)"
printf '2026-08-26T00:00:00Z unit=widget result=fail file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
rc=0
printf '%s' '{"hook_event_name":"Stop","session_id":"main"}' \
  | CLAUDE_PROJECT_DIR="$dir" bash "$tmproot/entry.sh" 2>"$tmproot/mutant-stderr.txt" || rc=$?
if [ "$rc" = 0 ]; then
  echo "OK   (e) mutation control: disabling the deferred-block check makes (a)'s scenario NOT block, proving (a) is non-vacuous"
else
  echo "FAIL (e) mutation control did not discriminate (rc=$rc stderr=[$(cat "$tmproot/mutant-stderr.txt")])"
  fail=1
fi

# --- Dirty-git fixtures (spec2-unitA FAIL D1 regression) -------------------
# Every case above uses a clean, non-git project, so stop-gate-core.sh's
# "tree clean AND no commits since baseline" early exit `allow`s out long
# before the end of the script - a leftover duplicate reporting block that
# used to sit AFTER that early exit (and after the testAndLintCommand check)
# was therefore never reached by any of them, and shipped silently corrupting
# the watermark file whenever a gated agent's SubagentStop DID reach the end
# of the script. These cases use a dirty git tree + testAndLintCommand:"true"
# so execution reaches all the way to the bottom of the file, the same as a
# real lead-programmer SubagentStop with uncommitted work.
make_dirty_git_project() {
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude"
  git -C "$dir" init -q
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
    > "$dir/.claude/persona-config.json"
  echo x > "$dir/dirty.txt"
  echo "$dir"
}

run_subagent_stop() {
  # $1 = project dir, $2 = entry script (default: the real stop-gate.sh)
  local entry="${2:-hooks/scripts/stop-gate.sh}"
  local rc=0
  printf '%s' '{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","session_id":"s","agent_id":"a"}' \
    | CLAUDE_PROJECT_DIR="$1" bash "$entry" 2>"$tmproot/stderr.txt" || rc=$?
  return "$rc"
}

# (f) PRIMARY channel, dirty-git fixture: an all-pass first Stop establishes
#     the watermark without blocking; a fail line appended afterward must
#     block the NEXT SubagentStop and name the unit (this is exactly AC-A3's
#     required-subsection scenario from the FAIL repro).
dir="$(make_dirty_git_project dirtyfail)"
printf '2026-08-26T00:00:00Z unit=widget result=pass file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
run_subagent_stop "$dir" > /dev/null 2>&1 || true
rm -f "$dir"/.claude/.pending-review.*
printf '2026-08-26T00:01:00Z unit=gadget result=fail file=src/other.js\n' \
  >> "$dir/.claude/microworld-audit.log"
rc=0
run_subagent_stop "$dir" || rc=$?
if [ "$rc" = 2 ] && grep -q 'gadget' "$tmproot/stderr.txt"; then
  echo "OK   (f) dirty-git fixture: a deferred failure after an established watermark still blocks SubagentStop (exit 2) and names the unit"
else
  echo "FAIL (f) expected exit 2 naming 'gadget' on a dirty-git fixture (rc=$rc stderr=[$(cat "$tmproot/stderr.txt")])"
  fail=1
fi

# (g) BACKSTOP channel (AC-A9), same dirty-git fixture: session-start.sh must
#     surface the SAME deferred failure when no Stop/SubagentStop reported it
#     this session (only the first SubagentStop above ran, on an all-pass log).
dir="$(make_dirty_git_project dirtybackstop)"
printf '2026-08-26T00:00:00Z unit=widget result=pass file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
run_subagent_stop "$dir" > /dev/null 2>&1 || true
printf '2026-08-26T00:01:00Z unit=gadget result=fail file=src/other.js\n' \
  >> "$dir/.claude/microworld-audit.log"
session_out="$(printf '%s' '{"hook_event_name":"SessionStart","source":"startup"}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/session-start.sh)"
if printf '%s' "$session_out" | grep -q 'gadget'; then
  echo "OK   (g) AC-A9 backstop: session-start.sh surfaces the deferred failure when no Stop already reported it"
else
  echo "FAIL (g) expected 'gadget' in SessionStart additionalContext (got: $session_out)"
  fail=1
fi

# (h) STALE RE-ANNOUNCE must not regress: a correctly-set line-count cursor
#     (not corrupted into an epoch) does not re-report already-reported units.
dir="$(make_dirty_git_project dirtystale)"
printf '2026-08-26T00:00:00Z unit=one result=fail file=a.js\n2026-08-26T00:01:00Z unit=two result=fail file=b.js\n' \
  > "$dir/.claude/microworld-audit.log"
printf '2\n' > "$dir/.claude/.microworld-results-reported"
rc=0
run_subagent_stop "$dir" || rc=$?
if [ "$rc" = 0 ]; then
  echo "OK   (h) a correctly-set watermark cursor does not re-announce already-reported units"
else
  echo "FAIL (h) expected exit 0 for an already-reported audit log (rc=$rc stderr=[$(cat "$tmproot/stderr.txt")])"
  fail=1
fi

# (i) MUTATION CONTROL: reintroducing the leftover duplicate block that D1
#     found (a second, LIVE copy of the deferred-reporting logic, appended
#     after the testAndLintCommand check, which treats the watermark file as
#     a UNIX EPOCH instead of a line count) must make case (f) regress -
#     proving (f)/(g) are non-vacuous against exactly this bug, not just
#     "always exit 2".
mutant_dup_lib="$tmproot/mutant-dup-lib"
mkdir -p "$mutant_dup_lib"
# Strip the real file's trailing "allow" so the reintroduced block lands
# BEFORE it (matching the FAIL record's D1 placement, live and reachable),
# then restore "allow" as the new last line.
head -n -1 hooks/scripts/lib/stop-gate-core.sh > "$mutant_dup_lib/stop-gate-core.sh"
cat >> "$mutant_dup_lib/stop-gate-core.sh" <<'DUPEOF'
# --- reintroduced leftover duplicate (mutation control only) ---------------
if [ "$hook_event" = "Stop" ] || [ "$hook_event" = "SubagentStop" ]; then
  microworld_audit="${dot}/microworld-audit.log"
  microworld_reported="${dot}/.microworld-results-reported"
  if [ -f "$microworld_audit" ]; then
    last_reported="0"
    if [ -f "$microworld_reported" ]; then
      last_reported="$(cat "$microworld_reported" 2>/dev/null || echo 0)"
    fi
    printf '%s\n' "$(date +%s)" > "$microworld_reported" 2>/dev/null || true
  fi
fi

allow
DUPEOF

mutant_entry="$tmproot/mutant-entry.sh"
cp hooks/scripts/stop-gate.sh "$mutant_entry"
[ -f "$tmproot/lib/agent-identity.sh" ] || {
  mkdir -p "$tmproot/lib"
  cp hooks/scripts/lib/agent-identity.sh "$tmproot/lib/agent-identity.sh"
}
python3 - "$mutant_entry" "$mutant_dup_lib" <<'PYEOF'
import sys
path, mutant_lib = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
content = content.replace(
    'lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"\nsource "${lib_dir}/stop-gate-core.sh"',
    f'lib_dir="{mutant_lib}"\nsource "${{lib_dir}}/stop-gate-core.sh"'
)
with open(path, 'w') as f:
    f.write(content)
PYEOF

dir="$(make_dirty_git_project dirtymutant)"
printf '2026-08-26T00:00:00Z unit=widget result=pass file=src/app.js\n' \
  > "$dir/.claude/microworld-audit.log"
run_subagent_stop "$dir" "$mutant_entry" > /dev/null 2>&1 || true
rm -f "$dir"/.claude/.pending-review.*
printf '2026-08-26T00:01:00Z unit=gadget result=fail file=src/other.js\n' \
  >> "$dir/.claude/microworld-audit.log"
rc=0
run_subagent_stop "$dir" "$mutant_entry" || rc=$?
if [ "$rc" = 0 ]; then
  echo "OK   (i) mutation control: reintroducing the leftover epoch-watermark duplicate makes (f)'s scenario silently pass (rc=0), proving (f) is non-vacuous"
else
  echo "FAIL (i) mutation control did not discriminate (rc=$rc stderr=[$(cat "$tmproot/stderr.txt")])"
  fail=1
fi

exit "$fail"
