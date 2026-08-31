#!/usr/bin/env bash
# Capability-regression fixture test (A22).
# With humanReviewMode: "all" in a fixture, verify the escalation path still
# works end to end by driving the REAL hooks (not writing+grepping the
# test's own fixture text, which would notice nothing if the capability
# rotted away entirely).
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

fixture_dot="$fixture_dir/.claude"
unit_id="fixture-test-unit"
escalated_ts="2026-08-27T10:00:00Z"
mkdir -p "$fixture_dot/reviewed" "$fixture_dot/human-review/${unit_id}"

cat > "$fixture_dot/persona-config.json" << 'CFGEOF'
{
  "gatedAgents": ["lead-programmer"],
  "humanReviewMode": "all",
  "markerCommitCheck": { "mode": "on" },
  "dispatchHygiene": { "mode": "on" },
  "testAndLintCommand": "true",
  "pluginVersion": "0.13.15",
  "fileHashes": {}
}
CFGEOF

printf 'ESCALATE-TO-HUMAN %s %s trigger: capability-regression-test microworld: none\n' "$unit_id" "$escalated_ts" \
  > "$fixture_dot/reviewed/${unit_id}.escalated"
printf 'lead-programmer flag\n' > "$fixture_dot/.pending-review.lp-1"

test_escalation_path() {
  # (1) real stop-gate.sh reviewer SubagentStop: an .escalated marker must
  # log verdict=escalated AND keep pending-review flags standing (unlike a
  # clean SubagentStop, which would clear them).
  local reviewer_stop='{"hook_event_name":"SubagentStop","agent_type":"reviewer","agent_id":"rev-1","session_id":"s1"}'
  local rc=0
  printf '%s' "$reviewer_stop" | CLAUDE_PROJECT_DIR="$fixture_dir" bash hooks/scripts/stop-gate.sh || rc=$?
  if [ "$rc" = 0 ] && [ -f "$fixture_dot/.pending-review.lp-1" ] \
     && grep -q 'verdict=escalated flags-kept' "$fixture_dot/review-audit.log"; then
    pass "capability: real stop-gate.sh logs the escalation and keeps flags standing"
  else
    bad "capability: stop-gate.sh did not produce the escalated verdict/flags-kept artifacts (rc=$rc)"
  fi

  # (2) real human-decision-gate.sh: no agent identity, reviewer included, may
  # write DECISION for this escalated unit - the only route to resolution is
  # a human.
  local decision_path=".claude/human-review/${unit_id}/DECISION"
  local hdg_err="${fixture_dir}/c9-hdg-err"
  rc=0
  printf '%s' "$(jq -n --arg a antislop:reviewer --arg p "$decision_path" \
    '{tool_name:"Write",agent_type:$a,tool_input:{file_path:$p}}')" \
    | CLAUDE_PROJECT_DIR="$fixture_dir" bash hooks/scripts/human-decision-gate.sh >/dev/null 2>"$hdg_err" || rc=$?
  if [ "$rc" = 2 ] && [ -s "$hdg_err" ]; then
    pass "capability: real human-decision-gate.sh still blocks every identity from writing DECISION"
  else
    bad "capability: human-decision-gate.sh did not block the DECISION write (rc=$rc)"
  fi

  # (3) real dashboard decision/arm route: a human's resolution channel for
  # this escalated unit still functions end to end (matching timestamp arms
  # successfully).
  local script="${fixture_dir}/c9-check.js"
  cat > "$script" <<'NODEEOF'
'use strict';
const http = require('http');
const { startServer } = require(process.env.C9_SERVER_PATH);

function httpPost(url, token, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = http.request({
      hostname: u.hostname, port: u.port, path: u.pathname, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Antislop-Token': token },
    }, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    req.write(JSON.stringify(body));
    req.end();
  });
}

async function main() {
  const { server, token } = startServer(process.env.C9_PROJECT_DIR, 0, { ttyWrite: { write: () => {} } });
  await new Promise((r) => setTimeout(r, 100));
  const url = `http://127.0.0.1:${server.address().port}/api/decision/arm`;
  const result = await httpPost(url, token, {
    taskId: process.env.C9_TASK_ID, route: 'approve',
    escalationTimestamp: process.env.C9_TS, by: 'c9', reason: 'test', examples: 'skipped',
  });
  server.close();
  if (result.status === 200) { console.log('C9-ARM-OK'); process.exit(0); }
  console.log(`C9-ARM-FAIL status=${result.status} body=${result.body}`);
  process.exit(1);
}
main().catch((err) => { console.log(`C9-ARM-FAIL error=${err.message}`); process.exit(1); });
NODEEOF
  local server_path
  server_path="$(pwd)/bin/microworld-dashboard/server.js"
  if C9_SERVER_PATH="$server_path" C9_PROJECT_DIR="$fixture_dir" C9_TASK_ID="$unit_id" C9_TS="$escalated_ts" \
       node "$script" 2>&1 | grep -q '^C9-ARM-OK$'; then
    pass "capability: real dashboard decision/arm route still resolves this escalation"
  else
    bad "capability: dashboard decision/arm route did not produce armed:true"
  fi
}

test_escalation_path
exit "$fail"
