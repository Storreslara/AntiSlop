#!/usr/bin/env bash
# Fixture suite for stop-gate.sh's disarm-surface config-drift block (Step 4,
# RD3): a GATED agent's SubagentStop blocks under config=drift; the
# main-session Stop never does, whatever the config's gating.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# make_project <name> <baseline-json> -> git-init a project, commit
# <baseline-json> as persona-config.json, record that commit as the session
# baseline for session id "s1"; echoes the project dir.
make_project() {
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '%s' "$2" > "$dir/.claude/persona-config.json"
  git -C "$dir" init -q
  git -C "$dir" -c user.email=t@example.com -c user.name=t add -A
  git -C "$dir" -c user.email=t@example.com -c user.name=t commit -q -m baseline
  git -C "$dir" rev-parse HEAD > "$dir/.claude/.session-baseline.s1"
  echo "$dir"
}

subagent_stop='{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","agent_id":"lp-1","session_id":"s1"}'
main_stop='{"hook_event_name":"Stop","session_id":"s1"}'

# (a) a gated agent's SubagentStop with a weakened config blocks (exit 2)
dir="$(make_project a '{"gatedAgents":["lead-programmer"]}')"
printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
rc=0
out=$(printf '%s' "$subagent_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh 2>&1) || rc=$?
if [ "$rc" = 2 ] && echo "$out" | grep -qi 'config drift' && echo "$out" | grep -q 'gatedAgents'; then
  ok "(a) gated agent's SubagentStop blocks (exit 2) on config=drift, naming gatedAgents"
else
  bad "(a) expected exit 2 naming gatedAgents drift (rc=$rc out=$out)"
fi

# (b) the SAME drift does NOT block the main-session Stop (RD3)
dir="$(make_project b '{"gatedAgents":["lead-programmer"]}')"
printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
rc=0
printf '%s' "$main_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ]; then
  ok "(b) main-session Stop never blocks on the same config drift (RD3)"
else
  bad "(b) expected exit 0 for main-session Stop, got rc=$rc"
fi

# (c) GUARD: no drift -> SubagentStop allowed (exit 0)
dir="$(make_project c '{"gatedAgents":["lead-programmer"]}')"
rc=0
printf '%s' "$subagent_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ]; then
  ok "(c) GUARD: unchanged config -> gated SubagentStop is allowed"
else
  bad "(c) expected exit 0 with no drift, got rc=$rc"
fi

# (d) GUARD: an UNGATED agent's SubagentStop is unaffected by drift (allowed
# by the earlier gatedAgents check before the drift block is ever reached)
dir="$(make_project d '{"gatedAgents":["lead-programmer"]}')"
printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
rc=0
printf '%s' '{"hook_event_name":"SubagentStop","agent_type":"explorer","agent_id":"e-1","session_id":"s1"}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ]; then
  ok "(d) GUARD: an ungated agent's SubagentStop is unaffected by config drift"
else
  bad "(d) expected exit 0 for an ungated agent, got rc=$rc"
fi

# (e) 'defer:' override permits the Stop, keeps the override file (sticky),
# and does NOT pollute review-audit.log's own defer:/skip: self-report count
dir="$(make_project e '{"gatedAgents":["lead-programmer"]}')"
printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
override="$dir/.claude/.config-drift-override.lp-1"
printf 'defer: operator is aware, fixing separately\n' > "$override"
rc=0
printf '%s' "$subagent_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && [ -f "$override" ] \
   && grep -q 'config-drift-defer:' "$dir/.claude/review-audit.log" \
   && ! grep -qE '^[^ ]+ defer: ' "$dir/.claude/review-audit.log"; then
  ok "(e) 'defer:' override permits the Stop, keeps the file (sticky), logs distinctly from a review defer:"
else
  bad "(e) defer: override broken (rc=$rc override-exists=$([ -f "$override" ] && echo yes || echo no) audit=$(cat "$dir/.claude/review-audit.log" 2>/dev/null || echo MISSING))"
fi

# (f) 'skip:' override permits the Stop once, then deletes the override file
dir="$(make_project f '{"gatedAgents":["lead-programmer"]}')"
printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
override="$dir/.claude/.config-drift-override.lp-1"
printf 'skip: operator accepts the risk\n' > "$override"
rc=0
printf '%s' "$subagent_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ] && [ ! -e "$override" ] \
   && grep -q 'config-drift-skip:' "$dir/.claude/review-audit.log"; then
  ok "(f) 'skip:' override permits the Stop once and deletes the override file"
else
  bad "(f) skip: override broken (rc=$rc override-exists=$([ -e "$override" ] && echo yes || echo no))"
fi

# (g) an empty-after-colon override reason is rejected: still blocks
dir="$(make_project g '{"gatedAgents":["lead-programmer"]}')"
printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
override="$dir/.claude/.config-drift-override.lp-1"
printf 'defer: \n' > "$override"
rc=0
printf '%s' "$subagent_stop" | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/stop-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 2 ] && [ -f "$override" ]; then
  ok "(g) an empty-after-colon 'defer: ' override reason is rejected -> still blocks"
else
  bad "(g) expected exit 2 with an empty-reason override, got rc=$rc"
fi

# (h) MUTATION CONTROL: strip the drift block from a throwaway copy - (a)
# must then stop blocking, proving it is binding on that code.
mutant="$tmproot/mutant"
mkdir -p "$mutant"
cp hooks/scripts/stop-gate.sh "$mutant/stop-gate.sh"
cp -R hooks/scripts/lib "$mutant/lib"
mutant_core="$mutant/lib/stop-gate-core.sh"
marker_before="$(grep -cF 'Disarm-surface config drift detected' "$mutant_core" || true)"
python3 - "$mutant_core" <<'PY'
import re, sys
path = sys.argv[1]
with open(path) as f:
    text = f.read()
start = text.index('# Step 4 (disarm-surface config drift, RD3)')
end = text.index('\nif [ "$dirty" = false ]')
text = text[:start] + text[end + 1:]
with open(path, 'w') as f:
    f.write(text)
PY
marker_after="$(grep -cF 'Disarm-surface config drift detected' "$mutant_core" || true)"
bash -n "$mutant_core"

dir="$(make_project mutation '{"gatedAgents":["lead-programmer"]}')"
printf '{"gatedAgents":[]}' > "$dir/.claude/persona-config.json"
rc=0
printf '%s' "$subagent_stop" | CLAUDE_PROJECT_DIR="$dir" bash "$mutant/stop-gate.sh" >/dev/null 2>&1 || rc=$?
if [ "${marker_before:-0}" -ge 1 ] && [ "${marker_after:-0}" = 0 ] && [ "$rc" = 0 ]; then
  ok "(h) mutation control: without the drift block the same fixture is allowed, so (a) is binding"
else
  bad "(h) mutation not applied or mutant still blocks (before=$marker_before after=$marker_after rc=$rc)"
fi

exit "$fail"
