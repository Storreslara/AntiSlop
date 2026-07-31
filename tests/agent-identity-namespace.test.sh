#!/usr/bin/env bash
# Behavioral regression suite for agent-identity namespacing across every
# comparison site S1-S13 of the 2026-07-28 blast-radius table, under three
# identity forms each: bare, this plugin's namespace (antislop:) and a foreign
# one (otherplugin:). Canned hook-input JSON piped to each script - no claude
# CLI, no network, no live agent dispatch (that is Probe C / Step 9).
#
# Matcher per site is the spec's normative Matcher column, never re-derived:
#   GRANT (conservative, miss fails CLOSED): S1, S3, S8, S11
#   GATE  (liberal,      miss fails OPEN):   S2, S4-S7, S9, S10, S12, S13
#
# Cases whose expectation inverts if Open Question 1 resolves to option (b)
# (S3/S8/S11 becoming liberal) are labelled [OQ1-a] - flipping the spec means
# editing exactly those, nothing else.
#
# Fixture hygiene (CHK15): every fixture sets testAndLintCommand to a trivial
# command, NEVER this repo's `bash tests/validate.sh` - this suite runs FROM
# validate.sh, so inheriting it would recurse validate -> stop-gate -> validate.
# Adapter sites are exercised against a SCAFFOLDED copy under the fixture's own
# .cursor/.codex, not against adapters/** in this repo: the library resolves its
# recognized namespace from its own on-disk location, so the in-repo adapter
# copies resolve "antislop-cursor"/"antislop-codex" while a deployed one
# resolves "antislop" - the GRANT sites give opposite verdicts in the two places.
set -euo pipefail
cd "$(dirname "$0")/.."
unset CLAUDE_PLUGIN_ROOT || true
fail=0

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT
errf="$tmproot/stderr"

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

# $1 form (bare|antislop|otherplugin), $2 persona name -> agent identity
id() {
  case "$1" in
    bare) printf '%s' "$2" ;;
    *)    printf '%s:%s' "$1" "$2" ;;
  esac
}

# $1 script, $2 json payload, $3 CLAUDE_PROJECT_DIR ("" when the payload carries it)
rc=0
run() {
  rc=0
  : > "$errf"
  if [ -n "$3" ]; then
    printf '%s' "$2" | CLAUDE_PROJECT_DIR="$3" bash "$1" >/dev/null 2>"$errf" || rc=$?
  else
    printf '%s' "$2" | bash "$1" >/dev/null 2>"$errf" || rc=$?
  fi
}

drift_ns()  { grep -q 'identity-drift class=unrecognized-namespace' "$1" 2>/dev/null; }
no_drift()  { ! grep -q 'identity-drift' "$1" 2>/dev/null; }
any_flag()  { compgen -G "$1" >/dev/null 2>&1; }

default_cfg='{"gatedAgents":["lead-programmer"],"personaSelection":["reviewer"],"testAndLintCommand":"true"}'

# $1 case name, $2 optional persona-config.json body -> echoes the project dir
mk_claude() {
  local d="$tmproot/claude-$1"
  mkdir -p "$d/.claude/reviewed"
  printf '%s\n' "${2:-$default_cfg}" > "$d/.claude/persona-config.json"
  printf '%s' "$d"
}

# $1 platform (cursor|codex), $2 case name, $3 optional config body
mk_adapter() {
  local d="$tmproot/$1-$2"
  mkdir -p "$d/.$1/reviewed" "$d/.$1/hooks"
  cp -r "adapters/$1/hooks/scripts" "$d/.$1/hooks/scripts"
  printf '%s\n' "${3:-$default_cfg}" > "$d/.$1/persona-config.json"
  printf '%s' "$d"
}

marker_payload() { printf '{"agent_type":"%s","tool_input":{"command":"printf x > .claude/reviewed/9.pass"}}' "$1"; }
substop()        { printf '{"hook_event_name":"SubagentStop","agent_type":"%s","agent_id":"%s","session_id":"s1"}' "$1" "$2"; }
route()          { printf '{"agent_type":"%s","tool_input":{"subagent_type":"%s"}}' "$1" "$2"; }

echo "-- S1 reviewed-path-gate.sh: reviewer may write PASS markers (GRANT) --"
for form in bare antislop; do
  d="$(mk_claude "s1-$form")"
  run hooks/scripts/reviewed-path-gate.sh "$(marker_payload "$(id "$form" reviewer)")" "$d"
  [ "$rc" = 0 ] && pass "S1 $form reviewer may touch the PASS-marker dir (rc=0)" \
                || bad "S1 $form reviewer was blocked (rc=$rc, expected 0)"
done
d="$(mk_claude s1-otherplugin)"
run hooks/scripts/reviewed-path-gate.sh "$(marker_payload otherplugin:reviewer)" "$d"
if [ "$rc" = 2 ] && drift_ns "$d/.claude/review-audit.log"; then
  pass "S1 [OQ1-a] otherplugin:reviewer blocked (rc=2) + unrecognized-namespace drift logged"
else
  bad "S1 [OQ1-a] otherplugin:reviewer rc=$rc (expected 2) or drift line missing"
fi
d="$(mk_claude s1-neg)"
run hooks/scripts/reviewed-path-gate.sh "$(marker_payload antislop:lead-programmer)" "$d"
[ "$rc" = 2 ] && pass "S1 antislop:lead-programmer still blocked (the grant stays a grant)" \
              || bad "S1 antislop:lead-programmer rc=$rc (expected 2)"
d="$(mk_claude s1-hot)"
run hooks/scripts/reviewed-path-gate.sh '{"agent_type":"otherplugin:reviewer","tool_input":{"command":"ls -la"}}' "$d"
if [ "$rc" = 0 ] && no_drift "$d/.claude/review-audit.log"; then
  pass "S1 non-marker command exits 0 and logs no drift (hot-path placement preserved)"
else
  bad "S1 non-marker command rc=$rc (expected 0) or a drift line was written on the hot path"
fi

echo
echo "-- S2 reviewed-path-gate.sh: personaSelection contains reviewer (GATE) --"
for form in bare antislop otherplugin; do
  cfg="$(printf '{"gatedAgents":["lead-programmer"],"personaSelection":["%s"],"testAndLintCommand":"true"}' "$(id "$form" reviewer)")"
  d="$(mk_claude "s2-$form" "$cfg")"
  run hooks/scripts/reviewed-path-gate.sh "$(marker_payload '')" "$d"
  [ "$rc" = 2 ] && pass "S2 personaSelection [$(id "$form" reviewer)] blocks the main session (rc=2)" \
                || bad "S2 personaSelection [$(id "$form" reviewer)] rc=$rc (expected 2)"
done
d="$(mk_claude s2-p4 '{"gatedAgents":["lead-programmer"],"personaSelection":["explorer"],"testAndLintCommand":"true"}')"
run hooks/scripts/reviewed-path-gate.sh "$(marker_payload '')" "$d"
[ "$rc" = 0 ] && pass "S2 P4 no-reviewer fallback still allows the main session (rc=0)" \
              || bad "S2 P4 no-reviewer fallback rc=$rc (expected 0)"

echo
echo "-- S3 stop-gate.sh: reviewer stop clears pending flags (GRANT) --"
for form in bare antislop; do
  d="$(mk_claude "s3-$form")"
  printf 'lead-programmer flag\n' > "$d/.claude/.pending-review.lp-1"
  run hooks/scripts/stop-gate.sh "$(substop "$(id "$form" reviewer)" rev-1)" "$d"
  if [ "$rc" = 0 ] && [ ! -e "$d/.claude/.pending-review.lp-1" ] \
     && grep -q 'cleared-by=reviewer' "$d/.claude/review-audit.log"; then
    pass "S3 $form reviewer clears the pending-review flag + logs cleared-by=reviewer"
  else
    bad "S3 $form reviewer rc=$rc, flag still present or cleared-by=reviewer not logged"
  fi
done
d="$(mk_claude s3-otherplugin)"
printf 'lead-programmer flag\n' > "$d/.claude/.pending-review.lp-1"
run hooks/scripts/stop-gate.sh "$(substop otherplugin:reviewer rev-1)" "$d"
if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp-1" ] && [ -s "$errf" ] \
   && grep -qE 'defer:|skip:' "$errf" && drift_ns "$d/.claude/review-audit.log"; then
  pass "S3 [OQ1-a] otherplugin:reviewer keeps the flag + names the recovery on stderr + drift logged"
else
  bad "S3 [OQ1-a] otherplugin:reviewer rc=$rc, flag cleared, stderr lacks defer:/skip:, or drift line missing"
fi
for form in bare antislop; do
  d="$(mk_claude "s3-blocked-$form")"
  printf 'lead-programmer flag\n' > "$d/.claude/.pending-review.lp-1"
  printf 'BLOCKED t 2026-07-28T00:00:00Z missing: x\n' > "$d/.claude/reviewed/t.blocked"
  run hooks/scripts/stop-gate.sh "$(substop "$(id "$form" reviewer)" rev-1)" "$d"
  if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp-1" ] \
     && grep -q 'verdict=blocked flags-kept' "$d/.claude/review-audit.log"; then
    pass "S3 $form reviewer + .blocked marker keeps the flag (INSUFFICIENT-CONTEXT invariant)"
  else
    bad "S3 $form reviewer + .blocked marker rc=$rc, flag cleared or flags-kept not logged"
  fi
done

echo
echo "-- S4 stop-gate.sh: gatedAgents flag creation (GATE) --"
for form in bare antislop otherplugin; do
  d="$(mk_claude "s4-$form")"
  run hooks/scripts/stop-gate.sh "$(substop "$(id "$form" lead-programmer)" lp1)" "$d"
  if [ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp1" ]; then
    pass "S4 $(id "$form" lead-programmer) SubagentStop creates .pending-review.lp1"
  else
    bad "S4 $(id "$form" lead-programmer) rc=$rc or .pending-review.lp1 was not created"
  fi
done
d="$(mk_claude s4-config-namespaced '{"gatedAgents":["antislop:lead-programmer"],"personaSelection":["reviewer"],"testAndLintCommand":"true"}')"
run hooks/scripts/stop-gate.sh "$(substop lead-programmer lp1)" "$d"
[ "$rc" = 0 ] && [ -f "$d/.claude/.pending-review.lp1" ] \
  && pass "S4 gatedAgents written namespaced still matches a bare payload (both-sides canonicalization)" \
  || bad "S4 namespaced gatedAgents vs bare payload rc=$rc or no flag created"
d="$(mk_claude s4-neg)"
run hooks/scripts/stop-gate.sh "$(substop antislop:explorer ex1)" "$d"
if [ "$rc" = 0 ] && ! any_flag "$d/.claude/.pending-review.*" && no_drift "$d/.claude/review-audit.log"; then
  pass "S4 antislop:explorer stays non-gated: no flag, no drift line"
else
  bad "S4 antislop:explorer rc=$rc, created a flag, or logged drift for a recognized namespace"
fi

echo
echo "-- S5 stop-gate.sh: main-agent identity from settings.json .agent (GATE) --"
mk_s5() {
  local d="$tmproot/claude-s5-$1"
  mkdir -p "$d/.claude/reviewed"
  printf '{"gatedAgents":["lead-programmer"],"personaSelection":["reviewer"],"testAndLintCommand":"false"}\n' \
    > "$d/.claude/persona-config.json"
  printf '{"agent":"%s"}\n' "$2" > "$d/.claude/settings.json"
  git -C "$d" init -q
  printf 'dirty\n' > "$d/dirty.txt"
  printf '%s' "$d"
}
for form in bare antislop otherplugin; do
  d="$(mk_s5 "$form" "$(id "$form" lead-programmer)")"
  run hooks/scripts/stop-gate.sh '{"hook_event_name":"Stop","session_id":"s5"}' "$d"
  [ "$rc" = 2 ] && pass "S5 settings.json .agent=$(id "$form" lead-programmer) reaches the gated check (rc=2)" \
                || bad "S5 .agent=$(id "$form" lead-programmer) rc=$rc (expected 2 - it early-exited ungated)"
done
d="$(mk_s5 neg orchestrator)"
run hooks/scripts/stop-gate.sh '{"hook_event_name":"Stop","session_id":"s5"}' "$d"
[ "$rc" = 0 ] && pass "S5 non-gated main agent still early-exits (rc=0)" \
              || bad "S5 non-gated main agent rc=$rc (expected 0)"

echo
echo "-- S6 reviewer-route-gate.sh: lead-programmer may not spawn the reviewer (GATE) --"
d="$(mk_claude s6)"
for caller in bare antislop otherplugin; do
  for target in bare antislop otherplugin; do
    run hooks/scripts/reviewer-route-gate.sh \
      "$(route "$(id "$caller" lead-programmer)" "$(id "$target" reviewer)")" "$d"
    [ "$rc" = 2 ] && pass "S6 $(id "$caller" lead-programmer) -> $(id "$target" reviewer) blocked (rc=2)" \
                  || bad "S6 $(id "$caller" lead-programmer) -> $(id "$target" reviewer) rc=$rc (expected 2)"
  done
done
run hooks/scripts/reviewer-route-gate.sh "$(route antislop:orchestrator antislop:reviewer)" "$d"
[ "$rc" = 0 ] && pass "S6 antislop:orchestrator -> antislop:reviewer still allowed (rc=0)" \
              || bad "S6 antislop:orchestrator -> antislop:reviewer rc=$rc (expected 0)"

echo
echo "-- S7 reviewer-route-gate.sh: next gated dispatch blocked while a flag stands (GATE) --"
for form in bare antislop otherplugin; do
  d="$(mk_claude "s7-$form")"
  printf 'lead-programmer flag\n' > "$d/.claude/.pending-review.lp-1"
  run hooks/scripts/reviewer-route-gate.sh "$(route orchestrator "$(id "$form" lead-programmer)")" "$d"
  [ "$rc" = 2 ] && pass "S7 dispatch of $(id "$form" lead-programmer) blocked while a flag stands (rc=2)" \
                || bad "S7 dispatch of $(id "$form" lead-programmer) rc=$rc (expected 2)"
done
d="$(mk_claude s7-neg)"
printf 'lead-programmer flag\n' > "$d/.claude/.pending-review.lp-1"
run hooks/scripts/reviewer-route-gate.sh "$(route antislop:orchestrator antislop:explorer)" "$d"
if [ "$rc" = 0 ] && no_drift "$d/.claude/review-audit.log"; then
  pass "S7 non-gated antislop:explorer still dispatchable with a flag standing, no drift logged"
else
  bad "S7 antislop:explorer rc=$rc (expected 0) or a drift line was logged for a recognized namespace"
fi

echo
echo "-- S8 cursor stop-gate.sh: reviewer stop clears flags (GRANT) --"
cursor_substop() { printf '{"hook_event_name":"subagentStop","subagent_type":"%s","workspace_roots":["%s"],"conversation_id":"c1"}' "$1" "$2"; }
for form in bare antislop; do
  d="$(mk_adapter cursor "s8-$form")"
  printf 'lp flag\n' > "$d/.cursor/.pending-review.lp-1"
  run "$d/.cursor/hooks/scripts/stop-gate.sh" "$(cursor_substop "$(id "$form" reviewer)" "$d")" ""
  if [ "$rc" = 0 ] && [ ! -e "$d/.cursor/.pending-review.lp-1" ] \
     && grep -q 'cleared-by=reviewer' "$d/.cursor/review-audit.log"; then
    pass "S8 cursor $form reviewer clears the flag + logs cleared-by=reviewer"
  else
    bad "S8 cursor $form reviewer rc=$rc, flag still present or cleared-by=reviewer not logged"
  fi
done
d="$(mk_adapter cursor s8-otherplugin)"
printf 'lp flag\n' > "$d/.cursor/.pending-review.lp-1"
run "$d/.cursor/hooks/scripts/stop-gate.sh" "$(cursor_substop otherplugin:reviewer "$d")" ""
if [ "$rc" = 0 ] && [ -f "$d/.cursor/.pending-review.lp-1" ] && [ -s "$errf" ] \
   && grep -qE 'defer:|skip:' "$errf" && drift_ns "$d/.cursor/review-audit.log"; then
  pass "S8 [OQ1-a] cursor otherplugin:reviewer keeps the flag + recovery note + drift logged"
else
  bad "S8 [OQ1-a] cursor otherplugin:reviewer rc=$rc, flag cleared, stderr lacks defer:/skip:, or drift missing"
fi

echo
echo "-- S9 cursor stop-gate.sh: gatedAgents flag creation (GATE) --"
for form in bare antislop otherplugin; do
  d="$(mk_adapter cursor "s9-$form")"
  run "$d/.cursor/hooks/scripts/stop-gate.sh" "$(cursor_substop "$(id "$form" lead-programmer)" "$d")" ""
  if [ "$rc" = 0 ] && any_flag "$d/.cursor/.pending-review.*"; then
    pass "S9 cursor $(id "$form" lead-programmer) subagentStop creates a pending-review flag"
  else
    bad "S9 cursor $(id "$form" lead-programmer) rc=$rc or no .cursor/.pending-review.* was created"
  fi
done
d="$(mk_adapter cursor s9-neg)"
run "$d/.cursor/hooks/scripts/stop-gate.sh" "$(cursor_substop antislop:explorer "$d")" ""
if [ "$rc" = 0 ] && ! any_flag "$d/.cursor/.pending-review.*" && no_drift "$d/.cursor/review-audit.log"; then
  pass "S9 cursor antislop:explorer stays non-gated: no flag, no drift line"
else
  bad "S9 cursor antislop:explorer rc=$rc, created a flag, or logged drift for a recognized namespace"
fi

echo
echo "-- S10 cursor reviewer-route-gate.sh: block next gated dispatch (GATE) --"
for form in bare antislop otherplugin; do
  d="$(mk_adapter cursor "s10-$form")"
  printf 'lp flag\n' > "$d/.cursor/.pending-review.lp-1"
  run "$d/.cursor/hooks/scripts/reviewer-route-gate.sh" \
    "$(printf '{"subagent_type":"%s","workspace_roots":["%s"]}' "$(id "$form" lead-programmer)" "$d")" ""
  [ "$rc" = 2 ] && pass "S10 cursor dispatch of $(id "$form" lead-programmer) blocked (rc=2)" \
                || bad "S10 cursor dispatch of $(id "$form" lead-programmer) rc=$rc (expected 2)"
done
d="$(mk_adapter cursor s10-neg)"
printf 'lp flag\n' > "$d/.cursor/.pending-review.lp-1"
run "$d/.cursor/hooks/scripts/reviewer-route-gate.sh" \
  "$(printf '{"subagent_type":"antislop:explorer","workspace_roots":["%s"]}' "$d")" ""
if [ "$rc" = 0 ] && no_drift "$d/.cursor/review-audit.log"; then
  pass "S10 cursor antislop:explorer still dispatchable, no drift logged"
else
  bad "S10 cursor antislop:explorer rc=$rc (expected 0) or a drift line was logged"
fi

echo
echo "-- S11 codex stop-gate.sh: reviewer stop clears flags (GRANT) --"
codex_substop() { printf '{"hook_event_name":"SubagentStop","agent_type":"%s","agent_id":"%s","session_id":"s1","cwd":"%s"}' "$1" "$2" "$3"; }
for form in bare antislop; do
  d="$(mk_adapter codex "s11-$form")"
  printf 'lp flag\n' > "$d/.codex/.pending-review.lp-1"
  run "$d/.codex/hooks/scripts/stop-gate.sh" "$(codex_substop "$(id "$form" reviewer)" rev-1 "$d")" ""
  if [ "$rc" = 0 ] && [ ! -e "$d/.codex/.pending-review.lp-1" ] \
     && grep -q 'cleared-by=reviewer' "$d/.codex/review-audit.log"; then
    pass "S11 codex $form reviewer clears the flag + logs cleared-by=reviewer"
  else
    bad "S11 codex $form reviewer rc=$rc, flag still present or cleared-by=reviewer not logged"
  fi
done
d="$(mk_adapter codex s11-otherplugin)"
printf 'lp flag\n' > "$d/.codex/.pending-review.lp-1"
run "$d/.codex/hooks/scripts/stop-gate.sh" "$(codex_substop otherplugin:reviewer rev-1 "$d")" ""
if [ "$rc" = 0 ] && [ -f "$d/.codex/.pending-review.lp-1" ] && [ -s "$errf" ] \
   && grep -qE 'defer:|skip:' "$errf" && drift_ns "$d/.codex/review-audit.log"; then
  pass "S11 [OQ1-a] codex otherplugin:reviewer keeps the flag + recovery note + drift logged"
else
  bad "S11 [OQ1-a] codex otherplugin:reviewer rc=$rc, flag cleared, stderr lacks defer:/skip:, or drift missing"
fi

echo
echo "-- S12 codex stop-gate.sh: gatedAgents flag creation (GATE) --"
for form in bare antislop otherplugin; do
  d="$(mk_adapter codex "s12-$form")"
  run "$d/.codex/hooks/scripts/stop-gate.sh" "$(codex_substop "$(id "$form" lead-programmer)" lp1 "$d")" ""
  if [ "$rc" = 0 ] && [ -f "$d/.codex/.pending-review.lp1" ]; then
    pass "S12 codex $(id "$form" lead-programmer) SubagentStop creates .pending-review.lp1"
  else
    bad "S12 codex $(id "$form" lead-programmer) rc=$rc or .codex/.pending-review.lp1 was not created"
  fi
done
d="$(mk_adapter codex s12-neg)"
run "$d/.codex/hooks/scripts/stop-gate.sh" "$(codex_substop antislop:explorer ex1 "$d")" ""
if [ "$rc" = 0 ] && ! any_flag "$d/.codex/.pending-review.*" && no_drift "$d/.codex/review-audit.log"; then
  pass "S12 codex antislop:explorer stays non-gated: no flag, no drift line"
else
  bad "S12 codex antislop:explorer rc=$rc, created a flag, or logged drift for a recognized namespace"
fi

echo
echo "-- S13 codex reviewer-route-gate.sh: block next gated dispatch (GATE) --"
for form in bare antislop otherplugin; do
  d="$(mk_adapter codex "s13-$form")"
  printf 'lp flag\n' > "$d/.codex/.pending-review.lp-1"
  run "$d/.codex/hooks/scripts/reviewer-route-gate.sh" \
    "$(printf '{"agent_type":"%s","cwd":"%s"}' "$(id "$form" lead-programmer)" "$d")" ""
  [ "$rc" = 2 ] && pass "S13 codex dispatch of $(id "$form" lead-programmer) blocked (rc=2)" \
                || bad "S13 codex dispatch of $(id "$form" lead-programmer) rc=$rc (expected 2)"
done
d="$(mk_adapter codex s13-neg)"
printf 'lp flag\n' > "$d/.codex/.pending-review.lp-1"
run "$d/.codex/hooks/scripts/reviewer-route-gate.sh" \
  "$(printf '{"agent_type":"antislop:explorer","cwd":"%s"}' "$d")" ""
if [ "$rc" = 0 ] && no_drift "$d/.codex/review-audit.log"; then
  pass "S13 codex antislop:explorer still dispatchable, no drift logged"
else
  bad "S13 codex antislop:explorer rc=$rc (expected 0) or a drift line was logged"
fi

echo
exit "$fail"
