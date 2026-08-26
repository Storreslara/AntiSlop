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

exit "$fail"
