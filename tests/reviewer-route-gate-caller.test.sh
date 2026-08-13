#!/usr/bin/env bash
# Fixture-driven test for reviewer-route-gate.sh's CALLER ALLOWLIST (issue #347
# Step 1: docs/plans/2026-08-12-reviewer-dispatch-caller-allowlist.md). Canned
# PreToolUse(Agent) JSON piped to the real script. Only the main session (empty
# agent_type, or `orchestrator`) may spawn the reviewer; every other caller is
# refused, which is why this one site fails CLOSED.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

make_project() {
  # $1 = case slug -> fresh project dir, never the real repo tree
  local dir="$tmproot/$1"
  mkdir -p "$dir/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"]}\n' > "$dir/.claude/persona-config.json"
  echo "$dir"
}

payload() {
  # $1 = caller agent_type, $2 = target subagent_type
  jq -n --arg a "$1" --arg t "$2" \
    '{hook_event_name:"PreToolUse",tool_name:"Agent",agent_type:$a,tool_input:{subagent_type:$t,prompt:"Unit: 900\n\nReview this."}}'
}

last_stderr=""

check_exit() {
  # $1 = case slug, $2 = caller agent_type, $3 = target, $4 = expected exit
  local dir rc=0
  dir="$(make_project "$1")"
  payload "$2" "$3" | CLAUDE_PROJECT_DIR="$dir" \
    bash hooks/scripts/reviewer-route-gate.sh >/dev/null 2>"$dir/stderr" || rc=$?
  last_stderr="$dir/stderr"
  if [ "$rc" = "$4" ]; then
    echo "OK   ($1) caller='$2' target=$3 -> exit $rc"
  else
    echo "FAIL ($1) caller='$2' target=$3 -> exit $rc (expected $4)"
    fail=1
  fi
}

# --- the eight-row allowlist table, target `reviewer` in every row ---
check_exit caller-general-purpose            general-purpose            reviewer 2
gp_stderr="$last_stderr"
check_exit caller-namespaced-general-purpose antislop:general-purpose   reviewer 2
check_exit caller-spec-master                spec-master                reviewer 2
check_exit caller-reviewer                   reviewer                   reviewer 2
check_exit caller-lead-programmer            lead-programmer            reviewer 2
lp_stderr="$last_stderr"
check_exit caller-orchestrator               orchestrator               reviewer 0
check_exit caller-namespaced-orchestrator    antislop:orchestrator      reviewer 0
check_exit caller-empty                      ""                         reviewer 0

# --- caller-absent-agent-type: the shipped main-session shape - no agent_type
#     key at all - must be allowed too, or the review path deadlocks (R1) ---
dir="$(make_project caller-absent-agent-type)"
rc=0
jq -n '{hook_event_name:"PreToolUse",tool_name:"Agent",tool_input:{subagent_type:"reviewer",prompt:"Unit: 901\n\nReview this."}}' \
  | CLAUDE_PROJECT_DIR="$dir" bash hooks/scripts/reviewer-route-gate.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ]; then
  echo "OK   (caller-absent-agent-type) no agent_type key -> exit 0"
else
  echo "FAIL (caller-absent-agent-type) no agent_type key -> exit $rc (expected 0)"
  fail=1
fi

# --- non-reviewer-target-unaffected: the allowlist must not touch any other target ---
check_exit non-reviewer-target-unaffected general-purpose lead-programmer 0

# --- lead-programmer-message-preserved: the original branch's tailored text survives ---
if grep -q 'lead-programmer may not spawn the reviewer directly' "$lp_stderr"; then
  echo "OK   (lead-programmer-message-preserved) original refusal text intact"
else
  echo "FAIL (lead-programmer-message-preserved) original refusal text missing"
  fail=1
fi

# --- allowlist-message-instructional: names the violation class and the root cause ---
if grep -q 'self-authorized bypass' "$gp_stderr" && grep -q 'subagent_type' "$gp_stderr"; then
  echo "OK   (allowlist-message-instructional) names 'self-authorized bypass' and 'subagent_type'"
else
  echo "FAIL (allowlist-message-instructional) refusal message is missing one of the required strings"
  fail=1
fi

# --- review-join-regression: every payload in that suite calls as `orchestrator`,
#     which the allowlist permits - so it must still pass unchanged ---
rc=0
bash tests/review-join.test.sh >/dev/null 2>&1 || rc=$?
if [ "$rc" = 0 ]; then
  echo "OK   (review-join-regression) tests/review-join.test.sh still exits 0"
else
  echo "FAIL (review-join-regression) tests/review-join.test.sh exits $rc"
  fail=1
fi

exit "$fail"
