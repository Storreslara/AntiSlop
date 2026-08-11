#!/usr/bin/env bash
# Fixture-driven test for the reviewer-SubagentStop branch of
# hooks/scripts/stop-gate.sh keeping pending-review flags standing while a
# .claude/reviewed/*.escalated marker is active (the ESCALATE-TO-HUMAN
# verdict), including the deliberate NON-handling of .directed. Canned
# hook-input JSON piped to each script - no real claude/agent dependency.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  # $1 = case name -> echoes a fresh project dir seeded with persona-config.json
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
    > "$dir/.claude/persona-config.json"
  echo "$dir"
}

reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'

run_reviewer_stop() {
  # $1 = project dir, $2 = script (default: the real hook)
  local rc=0
  printf '%s' "$reviewer_stop" \
    | CLAUDE_PROJECT_DIR="$1" bash "${2:-hooks/scripts/stop-gate.sh}" || rc=$?
  return "$rc"
}

# (a) reviewer SubagentStop WITH an active .escalated marker -> flag kept + audit
dir="$(make_project escalated)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
printf 'ESCALATE-TO-HUMAN task-a 2026-08-10T00:00:00Z trigger: security-sensitive microworld: none\n' \
  > "$dir/.claude/reviewed/task-a.escalated"
rc=0
run_reviewer_stop "$dir" || rc=$?
if [ "$rc" = 0 ] && [ -f "$dir/.claude/.pending-review.lp-1" ] \
   && grep -q 'verdict=escalated flags-kept' "$dir/.claude/review-audit.log"; then
  echo "OK   (a) active .escalated marker keeps pending-review flag standing + audit logged"
else
  echo "FAIL (a) flag removed or 'verdict=escalated flags-kept' audit line missing (rc=$rc)"
  fail=1
fi

# (b) BOTH markers present -> BOTH tokens logged (neither masks the other)
dir="$(make_project both)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
printf 'BLOCKED task-b 2026-08-10T00:00:00Z missing: constraint X\n' \
  > "$dir/.claude/reviewed/task-b.blocked"
printf 'ESCALATE-TO-HUMAN task-c 2026-08-10T00:00:00Z trigger: security-sensitive microworld: none\n' \
  > "$dir/.claude/reviewed/task-c.escalated"
rc=0
run_reviewer_stop "$dir" || rc=$?
if [ "$rc" = 0 ] && [ -f "$dir/.claude/.pending-review.lp-1" ] \
   && grep -q 'verdict=blocked flags-kept' "$dir/.claude/review-audit.log" \
   && grep -q 'verdict=escalated flags-kept' "$dir/.claude/review-audit.log"; then
  echo "OK   (b) .blocked and .escalated together log both tokens, flags kept"
else
  echo "FAIL (b) expected both verdict tokens in the audit log, flags kept (rc=$rc)"
  fail=1
fi

# (c) NO markers -> flag cleared, cleared-by=reviewer (existing behaviour)
dir="$(make_project cleared)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
rc=0
run_reviewer_stop "$dir" || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-1" ] \
   && grep -q 'cleared-by=reviewer' "$dir/.claude/review-audit.log"; then
  echo "OK   (c) no markers -> flag cleared (existing behaviour preserved)"
else
  echo "FAIL (c) flag not cleared or 'cleared-by=reviewer' audit line missing (rc=$rc)"
  fail=1
fi

# (d) with an .escalated marker standing, the NEXT gated dispatch is still
#     blocked - reviewer-route-gate.sh needs no change, it keys off the flag
dir="$(make_project route)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
printf 'ESCALATE-TO-HUMAN task-d 2026-08-10T00:00:00Z trigger: security-sensitive microworld: none\n' \
  > "$dir/.claude/reviewed/task-d.escalated"
run_reviewer_stop "$dir" || true
rc=0
printf '%s' '{"agent_type":"orchestrator","tool_input":{"subagent_type":"lead-programmer"}}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/reviewer-route-gate.sh 2>/dev/null || rc=$?
if [ "$rc" = 2 ]; then
  echo "OK   (d) reviewer-route-gate.sh (unchanged) still blocks the next gated dispatch while .escalated stands"
else
  echo "FAIL (d) expected exit 2 from reviewer-route-gate.sh, got rc=$rc"
  fail=1
fi

# (e) ONLY a .directed marker -> flags CLEARED. Its absence from the globs is
#     deliberate: it is what lets the human-directed fix be dispatched.
dir="$(make_project directed)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
printf 'DIRECTED task-e 2026-08-10T00:00:00Z decision: proceed as written\n' \
  > "$dir/.claude/reviewed/task-e.directed"
rc=0
run_reviewer_stop "$dir" || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-1" ] \
   && grep -q 'cleared-by=reviewer' "$dir/.claude/review-audit.log"; then
  echo "OK   (e) a .directed marker alone does NOT keep flags standing (deliberate omission)"
else
  echo "FAIL (e) .directed marker kept the flags standing or nothing was cleared (rc=$rc)"
  fail=1
fi

# (f) MUTATION CONTROL for (a): neutralize the .escalated glob in a throwaway
#     copy - the flag must then clear, proving (a) binds to the new branch.
mutant="$tmproot/mutant"
mkdir -p "$mutant"
cp hooks/scripts/stop-gate.sh "$mutant/stop-gate.sh"
cp -R hooks/scripts/lib "$mutant/lib"
glob='escalated_markers=( "${project_dir}"/.claude/reviewed/*.escalated )'
before_n="$(grep -cF "$glob" "$mutant/stop-gate.sh" || true)"
sed -i 's/^\( *\)escalated_markers=(.*$/\1escalated_markers=( )/' "$mutant/stop-gate.sh"
after_n="$(grep -cF "$glob" "$mutant/stop-gate.sh" || true)"
parses=yes
bash -n "$mutant/stop-gate.sh" 2>/dev/null || parses=no

dir="$(make_project mutation)"
printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.lp-1"
printf 'ESCALATE-TO-HUMAN task-f 2026-08-10T00:00:00Z trigger: security-sensitive microworld: none\n' \
  > "$dir/.claude/reviewed/task-f.escalated"
rc=0
run_reviewer_stop "$dir" "$mutant/stop-gate.sh" || rc=$?
if [ "${before_n:-0}" = 1 ] && [ "${after_n:-0}" = 0 ] && [ "$parses" = yes ] \
   && [ "$rc" = 0 ] && [ ! -e "$dir/.claude/.pending-review.lp-1" ]; then
  echo "OK   (f) mutation control: without the .escalated glob the flag clears, so (a) is binding"
else
  echo "FAIL (f) mutation not applied or did not change behaviour (glob before=$before_n after=$after_n parses=$parses rc=$rc flag-exists=$([ -e "$dir/.claude/.pending-review.lp-1" ] && echo yes || echo no))"
  fail=1
fi

# (g) the two hand-adapted ports carry the same branch: an .escalated marker in
#     that port's own dot-dir keeps its flags standing and logs the same token.
for port in codex cursor; do
  case "$port" in
    codex)  dot=.codex;  script=adapters/codex/hooks/scripts/stop-gate.sh ;;
    cursor) dot=.cursor; script=adapters/cursor/hooks/scripts/stop-gate.sh ;;
  esac
  dir="$tmproot/port-$port"
  mkdir -p "$dir/$dot/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true"}\n' \
    > "$dir/$dot/persona-config.json"
  printf 'lead-programmer flag\n' > "$dir/$dot/.pending-review.lp-1"
  printf 'ESCALATE-TO-HUMAN task-g 2026-08-10T00:00:00Z trigger: security-sensitive microworld: none\n' \
    > "$dir/$dot/reviewed/task-g.escalated"
  rc=0
  if [ "$port" = codex ]; then
    printf '{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1","cwd":"%s"}' "$dir" \
      | bash "$script" || rc=$?
  else
    printf '{"hook_event_name":"subagentStop","subagent_type":"reviewer","conversation_id":"s1","workspace_roots":["%s"]}' "$dir" \
      | bash "$script" || rc=$?
  fi
  if [ "$rc" = 0 ] && [ -f "$dir/$dot/.pending-review.lp-1" ] \
     && grep -q 'verdict=escalated flags-kept' "$dir/$dot/review-audit.log"; then
    echo "OK   (g) $port port: active .escalated marker keeps flags standing + audit logged"
  else
    echo "FAIL (g) $port port: flag removed or 'verdict=escalated flags-kept' missing (rc=$rc)"
    fail=1
  fi
done

exit "$fail"
