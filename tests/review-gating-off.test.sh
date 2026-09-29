#!/usr/bin/env bash
# Fixture-driven test for persona-config.json's reviewGating.mode: only the
# exact string "off" makes stop-gate's and reviewer-route-gate's
# review-enforcement branches inert; "enforce", an absent key and junk all
# keep today's blocking behaviour. Canned hook-input JSON, no real agents.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  # $1 = case name, $2 = mode JSON fragment ("" = key absent), $3 = test cmd
  local dir="$tmproot/$1" mode_json=""
  mkdir -p "$dir/.claude/reviewed"
  [ -n "$2" ] && mode_json=",\"reviewGating\":{\"mode\":$2}"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"%s"%s}\n' \
    "${3:-true}" "$mode_json" > "$dir/.claude/persona-config.json"
  echo "$dir"
}

stop_hook() {
  # $1 = project dir, $2 = payload JSON
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/stop-gate.sh 2>/dev/null
}

route_hook() {
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/reviewer-route-gate.sh 2>/dev/null
}

check() {
  # $1 = label, $2 = "pass"/"fail" condition result
  if [ "$2" = pass ]; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi
}

lp_stop='{"hook_event_name":"SubagentStop","agent_type":"lead-programmer","agent_id":"lp-1","session_id":"s1"}'
main_stop='{"hook_event_name":"Stop","session_id":"s1"}'
rev_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'
lp_dispatch='{"agent_type":"orchestrator","tool_input":{"subagent_type":"lead-programmer","prompt":"Unit: u1"}}'
rev_dispatch='{"agent_type":"orchestrator","tool_input":{"subagent_type":"reviewer","prompt":"Unit: u1\nreview it"}}'

# run_matrix_case <case> <mode-json> <label> -> sets rc and dir
run_case() {
  local c="$1" mode="$2" label="$3"
  dir="$(make_project "$c-$label" "$mode")"
  rc=0
  case "$c" in
    a) stop_hook "$dir" "$lp_stop" || rc=$? ;;
    b) printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.x"
       stop_hook "$dir" "$main_stop" || rc=$? ;;
    c) printf '2026-09-29T00:00:00Z unit=u1 prior=none prior_mtime=-\n' > "$dir/.claude/.review-join.u1"
       stop_hook "$dir" "$rev_stop" || rc=$? ;;
    d) printf 'lead-programmer flag\n' > "$dir/.claude/.pending-review.x"
       route_hook "$dir" "$lp_dispatch" || rc=$? ;;
    s) route_hook "$dir" "$rev_dispatch" || rc=$? ;;
  esac
}

flag_written() { compgen -G "$1/.claude/.pending-review.*" >/dev/null; }
stamp_written() { compgen -G "$1/.claude/.review-join.*" >/dev/null; }

# (a)-(d) and the reviewer-dispatch stamp case (s) under "off": inert.
run_case a '"off"' off
r=fail; [ "$rc" = 0 ] && ! flag_written "$dir" && r=pass
check "(a) off: gated lead-programmer SubagentStop writes no pending-review flag (rc=$rc)" "$r"

run_case b '"off"' off
r=fail; [ "$rc" = 0 ] && r=pass
check "(b) off: main Stop with a standing flag exits 0 (rc=$rc)" "$r"

run_case c '"off"' off
r=fail; [ "$rc" = 0 ] && r=pass
check "(c) off: reviewer SubagentStop with a stamp and no marker exits 0 (rc=$rc)" "$r"

run_case d '"off"' off
r=fail; [ "$rc" = 0 ] && ! stamp_written "$dir" && r=pass
check "(d) off: lead-programmer dispatch with a standing flag exits 0, no stamp (rc=$rc)" "$r"

run_case s '"off"' off
r=fail; [ "$rc" = 0 ] && ! stamp_written "$dir" && r=pass
check "(d') off: reviewer dispatch with a Unit: line writes no .review-join.* (rc=$rc)" "$r"

# (e) identity guard kept under "off".
dir="$(make_project e-off '"off"')"
rc=0
route_hook "$dir" '{"agent_type":"lead-programmer","tool_input":{"subagent_type":"reviewer","prompt":"Unit: u1"}}' || rc=$?
r=fail; [ "$rc" = 2 ] && r=pass
check "(e) off: lead-programmer dispatching the reviewer still exits 2 (rc=$rc)" "$r"

# (f) enforce, absent and junk ("OFF ") all reproduce today's blocking.
for pair in 'enforce|"enforce"' 'absent|' 'junk|"OFF "'; do
  label="${pair%%|*}" mode="${pair#*|}"

  run_case a "$mode" "$label"
  r=fail; [ "$rc" = 0 ] && flag_written "$dir" && r=pass
  check "(f/a) $label: gated SubagentStop writes a pending-review flag (rc=$rc)" "$r"

  run_case b "$mode" "$label"
  r=fail; [ "$rc" = 2 ] && r=pass
  check "(f/b) $label: main Stop with a standing flag exits 2 (rc=$rc)" "$r"

  run_case c "$mode" "$label"
  r=fail; [ "$rc" = 2 ] && r=pass
  check "(f/c) $label: reviewer SubagentStop with a stamp and no marker exits 2 (rc=$rc)" "$r"

  run_case d "$mode" "$label"
  r=fail; [ "$rc" = 2 ] && r=pass
  check "(f/d) $label: lead-programmer dispatch with a standing flag exits 2 (rc=$rc)" "$r"

  run_case s "$mode" "$label"
  r=fail; [ "$rc" = 0 ] && [ -f "$dir/.claude/.review-join.u1" ] && r=pass
  check "(f/d') $label: reviewer dispatch with a Unit: line writes .review-join.u1 (rc=$rc)" "$r"
done

# (g) test+lint kept under "off": a dirty git fixture with a failing command.
dir="$(make_project g-off '"off"' false)"
git -C "$dir" init -q
printf 'dirt\n' > "$dir/untracked.txt"
rc=0
stop_hook "$dir" "$lp_stop" || rc=$?
r=fail; [ "$rc" = 2 ] && r=pass
check "(g) off: gated SubagentStop with a failing testAndLintCommand still exits 2 (rc=$rc)" "$r"

# (h)-(k): task-gate, dispatch-hygiene H3, human-decision-gate.
task_hook() {
  printf '%s' "$(jq -n '{task:{subject:"impl:x",id:"x"}}')" \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/task-gate.sh 2>/dev/null
}

hygiene_hook() {
  # $1 = project dir, $2 = requireContract (true|false)
  jq -n '{tool_name:"Agent",tool_input:{subagent_type:"lead-programmer",prompt:"Unit: u1"}}' \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/dispatch-hygiene.sh 2>/dev/null
}

hygiene_project() {
  # $1 = label, $2 = mode JSON ("" = absent), $3 = requireContract
  local d mode_json=""
  d="$tmproot/hyg-$1-$3"
  mkdir -p "$d/.claude/reviewed"
  [ -n "$2" ] && mode_json=",\"reviewGating\":{\"mode\":$2}"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true","dispatchHygiene":{"mode":"block","requireContract":%s}%s}\n' \
    "$3" "$mode_json" > "$d/.claude/persona-config.json"
  printf 'PASS u1 2026-09-29T00:00:00Z commit: none criteria: true\n' > "$d/.claude/reviewed/u1.pass"
  echo "$d"
}

decision_hook() {
  jq -n --arg c 'printf approve > .claude/human-review/u1/DECISION' \
    '{tool_name:"Bash",agent_type:"lead-programmer",tool_input:{command:$c}}' \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/human-decision-gate.sh 2>/dev/null
}

decision_write_hook() {
  jq -n --arg p '.claude/human-review/u1/DECISION' \
    '{tool_name:"Write",agent_type:"lead-programmer",tool_input:{file_path:$p,content:"approve"}}' \
    | CLAUDE_PROJECT_DIR="$1" bash hooks/scripts/human-decision-gate.sh 2>/dev/null
}

audit_has() { grep -q "$2" "$1/.claude/dispatch-audit.log" 2>/dev/null; }

for pair in 'off|"off"' 'enforce|"enforce"' 'absent|' 'junk|"OFF "'; do
  label="${pair%%|*}" mode="${pair#*|}"
  want=2; [ "$label" = off ] && want=0

  dir="$(make_project "h-$label" "$mode")"
  rc=0; task_hook "$dir" || rc=$?
  r=fail; [ "$rc" = "$want" ] && r=pass
  check "(h) $label: TaskCompleted impl:x with no marker exits $want (rc=$rc)" "$r"

  dir="$(hygiene_project "$label" "$mode" false)"
  rc=0; hygiene_hook "$dir" || rc=$?
  r=fail
  if [ "$label" = off ]; then
    [ "$rc" = 0 ] && ! audit_has "$dir" 'blocked=H3' && r=pass
  else
    [ "$rc" = 2 ] && audit_has "$dir" 'blocked=H3' && r=pass
  fi
  check "(i) $label: re-dispatch of passed unit u1 under dispatchHygiene block exits $want (rc=$rc)" "$r"

  dir="$(make_project "k-$label" "$mode")"
  rc=0; decision_hook "$dir" || rc=$?
  r=fail; [ "$rc" = "$want" ] && r=pass
  check "(k) $label: Bash write to a human-review DECISION file exits $want (rc=$rc)" "$r"

  rc=0; decision_write_hook "$dir" || rc=$?
  r=fail; [ "$rc" = "$want" ] && r=pass
  check "(k) $label: Write-tool write to a human-review DECISION file exits $want (rc=$rc)" "$r"
done

# (j) under "off" the audit line still lands: H4 (kept) fires on the same
# contract-less dispatch and is logged, while H3 stays silent.
dir="$(hygiene_project j-off '"off"' true)"
rc=0; hygiene_hook "$dir" || rc=$?
r=fail
[ "$rc" = 2 ] && audit_has "$dir" 'blocked=H4 target=lead-programmer' && ! audit_has "$dir" 'blocked=H3' && r=pass
check "(j) off: dispatch-audit.log line still appended (H4 kept, H3 absent) (rc=$rc)" "$r"

# (l) session-start banner: printed only under "off".
for spec in 'off|"off"|0' 'enforce|"enforce"|1' 'absent||1' 'junk|"OFF "|1'; do
  IFS='|' read -r label mode want <<<"$spec"
  dir="$(make_project "l-$label" "$mode")"
  out="$(printf '{"session_id":"s1","source":"startup"}' | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/session-start.sh 2>/dev/null || true)"
  r=fail
  if printf '%s' "$out" | grep -q 'review gating: off'; then got=0; else got=1; fi
  [ "$got" = "$want" ] && r=pass
  check "(l) $label: session-start banner 'review gating: off' present=$((1-got))" "$r"
done

# (m) a non-object reviewGating makes jq error; the fallback is enforce, so no banner.
dir="$tmproot/m-string"
mkdir -p "$dir/.claude"
printf '{"gatedAgents":["lead-programmer"],"reviewGating":"off"}\n' > "$dir/.claude/persona-config.json"
out="$(printf '{"session_id":"s1","source":"startup"}' | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/session-start.sh 2>/dev/null || true)"
r=pass; printf '%s' "$out" | grep -q 'review gating: off' && r=fail
check "(m) string reviewGating: session-start banner absent" "$r"

# (n) /antislop:gate edits only via the Edit tool: no CLI or Bash-redirect route.
r=pass; grep -qE 'bin/cli\.js|>>? *[^ ]*persona-config' commands/gate.md && r=fail
check "(n) commands/gate.md names no bin/cli.js or Bash-redirect write route" "$r"

exit "$fail"
