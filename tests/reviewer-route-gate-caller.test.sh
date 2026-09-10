#!/usr/bin/env bash
# Fixture-driven test for reviewer-route-gate.sh's CALLER ALLOWLIST (issue #347
# Step 1: docs/plans/2026-08-12-reviewer-dispatch-caller-allowlist.md). Canned
# PreToolUse(Agent) JSON piped to the real script. Only the main session (empty
# agent_type, or `orchestrator`) may spawn the reviewer; every other caller is
# refused, which is why this one site fails CLOSED.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

# Overridable so a mutation-control run can point the whole suite at a mutated
# scratch copy (with lib/ copied alongside it) without editing the gate in
# place. Defaults to the real one. See the mutation-control recipe below.
gate="${GATE_UNDER_TEST:-hooks/scripts/reviewer-route-gate.sh}"

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

payload_named() {
  # $1 = target subagent_type, $2 = tool_input.name (omitted entirely if "")
  if [ -n "$2" ]; then
    jq -n --arg t "$1" --arg n "$2" \
      '{hook_event_name:"PreToolUse",tool_name:"Agent",tool_input:{subagent_type:$t,name:$n,prompt:"Unit: 910\n\nReview this."}}'
  else
    jq -n --arg t "$1" \
      '{hook_event_name:"PreToolUse",tool_name:"Agent",tool_input:{subagent_type:$t,prompt:"Unit: 910\n\nReview this."}}'
  fi
}

last_stderr=""

check_exit() {
  # $1 = case slug, $2 = caller agent_type, $3 = target, $4 = expected exit
  local dir rc=0
  dir="$(make_project "$1")"
  payload "$2" "$3" | CLAUDE_PROJECT_DIR="$dir" \
    bash "$gate" >/dev/null 2>"$dir/stderr" || rc=$?
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
  | CLAUDE_PROJECT_DIR="$dir" bash "$gate" >/dev/null 2>&1 || rc=$?
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

check_name_exit() {
  # $1 = case slug, $2 = target subagent_type, $3 = tool_input.name ("" = omit),
  # $4 = expected exit
  local dir rc=0
  dir="$(make_project "$1")"
  payload_named "$2" "$3" | CLAUDE_PROJECT_DIR="$dir" \
    bash "$gate" >/dev/null 2>"$dir/stderr" || rc=$?
  last_stderr="$dir/stderr"
  if [ "$rc" = "$4" ]; then
    echo "OK   ($1) target=$2 name='$3' -> exit $rc"
  else
    echo "FAIL ($1) target=$2 name='$3' -> exit $rc (expected $4)"
    fail=1
  fi
}

# --- C1: a dispatch's `name:` field must not forge a privileged persona
# (reviewer/orchestrator) that its actual `subagent_type` does not match ---

# Bypass reproduction, now denied (docs/plans/2026-09-09-fable-gate-audit-
# remediation.md Step 1, acceptance criterion 1).
check_name_exit name-forges-reviewer     explorer reviewer     2
check_name_exit name-forges-orchestrator explorer orchestrator 2

# No over-block (criterion 3).
check_name_exit name-matches-target-reviewer        reviewer            reviewer               0
check_name_exit target-reviewer-no-name             reviewer            ""                     0
check_name_exit name-non-privileged-on-lead-programmer lead-programmer  lp-2                   0
check_name_exit target-explorer-no-name             explorer            ""                     0
check_name_exit namespaced-name-matches-namespaced-target antislop:reviewer antislop:reviewer  0

# Namespace handling: persona names are compared, not raw identities
# (criterion 4).
check_name_exit namespaced-name-forges-reviewer explorer antislop:reviewer 2

# --- derivation test: PRIVILEGED_PERSONAS must equal the union of (a) every
# bare literal in a persona_matches_grant call anywhere under hooks/scripts/,
# and (b) every bare literal in a NEGATED persona_matches_gate("$agent_type",
# X) call (a caller-allowlist position) in reviewer-route-gate.sh. A
# non-negated caller-position call is a denylist, not an allowlist, and is
# excluded. See Step 1's Pre-resolved context for why a naive grep (one that
# does not distinguish the negation) gets this wrong. ---
derive_grant_literals() {
  grep -rhoE 'persona_matches_grant[[:space:]]+"?\$[A-Za-z_]+"?[[:space:]]+"?[A-Za-z0-9_-]+"?' hooks/scripts/ \
    | sed -E 's/.*persona_matches_grant[[:space:]]+"?\$[A-Za-z_]+"?[[:space:]]+"?([A-Za-z0-9_-]+)"?.*/\1/'
}

derive_caller_allowlist_literals() {
  # $1 = source file to scan (a real path or a mutant copy of it)
  local joined
  joined="$(sed -E ':a;N;$!ba;s/\\\n[[:space:]]*/ /g' "$1")"
  printf '%s\n' "$joined" \
    | grep -oE '(![[:space:]]*)?persona_matches_gate[[:space:]]+"\$agent_type"[[:space:]]+"[A-Za-z0-9_-]+"' \
    | grep '^!' \
    | sed -E 's/.*"([A-Za-z0-9_-]+)"$/\1/'
}

# Each `|| true` below tolerates a stage legitimately matching nothing (e.g. a
# hypothetically-empty array) without `set -e`/`pipefail` aborting the whole
# suite - an empty result is then reported as a named FAIL by the comparison
# below, not an unrelated crash.
derived_union="$( { (derive_grant_literals; derive_caller_allowlist_literals hooks/scripts/reviewer-route-gate.sh) \
  | sort -u | grep -v '^$'; } || true)"
actual_privileged="$( { grep -oE 'PRIVILEGED_PERSONAS=\([^)]*\)' hooks/scripts/lib/reviewer-route-gate-core.sh \
  | sed -E 's/PRIVILEGED_PERSONAS=\(([^)]*)\)/\1/' | tr -s ' ' '\n' | sort -u | grep -v '^$'; } || true)"

if [ "$derived_union" = "$actual_privileged" ]; then
  echo "OK   (derivation-privileged-personas) PRIVILEGED_PERSONAS matches the derived union: $(echo "$actual_privileged" | tr '\n' ' ')"
else
  echo "FAIL (derivation-privileged-personas) mismatch: derived='$(echo "$derived_union" | tr '\n' ' ')' actual='$(echo "$actual_privileged" | tr '\n' ' ')'"
  fail=1
fi

# The derivation test must be able to fail, or it is vacuous: removing
# `orchestrator` from the actual array must make the comparison disagree.
shrunk="$( { printf '%s\n' "$actual_privileged" | grep -v '^orchestrator$'; } || true)"
if [ "$derived_union" != "$shrunk" ]; then
  echo "OK   (derivation-negative-check) removing orchestrator from the array makes the comparison disagree"
else
  echo "FAIL (derivation-negative-check) comparison did not change when orchestrator was removed - vacuous test"
  fail=1
fi

# --- MUTATION CONTROL (reviewer-run). Reintroduce the pre-fix state - the
# new unconditional name-forgery block removed, the existing narrower
# reviewer-targeted `name:` check (:54-61 as of 915acec) left intact - in a
# scratch copy, and point this suite at it. Copy lib/ alongside it: the gate
# sources lib/agent-identity.sh relative to its OWN path, so a bare copy into
# an empty directory dies at startup and every case "fails" with rc=1, which
# looks like a kill but proves nothing.
#
#   d="$(mktemp -d)"; cp -r hooks/scripts/lib "$d/"
#   sed '/^PRIVILEGED_PERSONAS=/,/^fi$/d' hooks/scripts/lib/reviewer-route-gate-core.sh \
#     > "$d/lib/reviewer-route-gate-core.sh"
#   cp hooks/scripts/reviewer-route-gate.sh "$d/reviewer-route-gate.sh"
#   GATE_UNDER_TEST="$d/reviewer-route-gate.sh" bash tests/reviewer-route-gate-caller.test.sh; echo $?
#
# Expected (measured): exit 1, with exactly the three bypass-reproduction
# cases (name-forges-reviewer, name-forges-orchestrator,
# namespaced-name-forges-reviewer) reporting FAIL at exit 0 instead of 2 -
# proving the new block is the sole denier for those cases. Every other case
# is unaffected, including the derivation test, which reads the un-mutated
# core file's source text directly, not $gate.

exit "$fail"
