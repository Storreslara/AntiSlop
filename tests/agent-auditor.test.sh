#!/usr/bin/env bash
# Fixture-driven test for scripts/agent-audit.sh (Step 3 of
# docs/plans/2026-08-09-agent-auditor-persona.md).
#
# Builds a synthetic AGENT_AUDIT_ROOT tree with one known-good and one
# known-bad fixture per anomaly class (A1-A6), plus an R5 privacy fixture,
# then actually invokes scripts/agent-audit.sh against it and asserts on the
# real --json output. Non-vacuity for A1 and A5 is proven by mutation
# testing: the detection call is neutralized in a scratch COPY of the script
# (never the tracked file itself - matching the mutation-control pattern
# already used by tests/stop-gate-blocked.test.sh) and the same assertions
# are shown to fail against the mutant.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

FIXTURE_ROOT="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

mkdir -p \
  "$FIXTURE_ROOT/s1/subagents" \
  "$FIXTURE_ROOT/s2/subagents" \
  "$FIXTURE_ROOT/s3/subagents" \
  "$FIXTURE_ROOT/s4/subagents" \
  "$FIXTURE_ROOT/s5/subagents" \
  "$FIXTURE_ROOT/s6/subagents" \
  "$FIXTURE_ROOT/reviewed"

# --- s1: A1 (undeclared tool use), A2 (unregistered agent), A3 (nested spawn) ---
# explorer declares tools: Read, Grep, Glob, Bash, Skill, SendMessage (no Write).

# A1_bad: uses an undeclared tool (Write)
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s1/subagents/agent-a1bad.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T10:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T10:00:01Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Write","input":{}}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T10:00:06Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s1/subagents/agent-a1bad.jsonl"

# A1_good: uses only a declared tool (Read)
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s1/subagents/agent-a1good.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T10:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T10:00:01Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T10:00:06Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s1/subagents/agent-a1good.jsonl"

# A2_bad: agentType has no resolvable persona source file
echo '{"agentType":"nonexistent-agent","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s1/subagents/agent-a2bad.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T10:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T10:00:06Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s1/subagents/agent-a2bad.jsonl"

# A2_good: agentType resolves to agents/explorer.md
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s1/subagents/agent-a2good.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T10:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T10:00:06Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s1/subagents/agent-a2good.jsonl"

# A3_bad: spawnDepth >= 2
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":2,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s1/subagents/agent-a3bad.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T10:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T10:00:06Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s1/subagents/agent-a3bad.jsonl"

# A3_good: spawnDepth < 2
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":1,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s1/subagents/agent-a3good.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T10:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T10:00:06Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s1/subagents/agent-a3good.jsonl"

echo '{"type":"user","timestamp":"2026-08-01T10:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$FIXTURE_ROOT/s1.jsonl"

# --- s2: A4_bad - gated persona (lead-programmer) dispatched, NO reviewer at
# all in this session. Kept in its own session so no other session's
# reviewer can accidentally satisfy it. ---

echo '{"agentType":"lead-programmer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s2/subagents/agent-a4bad.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T11:00:10Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T11:00:11Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s2/subagents/agent-a4bad.jsonl"

echo '{"type":"user","timestamp":"2026-08-01T11:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$FIXTURE_ROOT/s2.jsonl"

# --- s3: A4_good - gated persona dispatched, reviewer dispatched LATER in
# the same session. ---

echo '{"agentType":"lead-programmer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s3/subagents/agent-a4good.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T12:00:10Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T12:00:11Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s3/subagents/agent-a4good.jsonl"

echo '{"agentType":"reviewer","description":"Unit: gh-a4good","model":"opus","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s3/subagents/agent-reviewer-a4.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T12:00:20Z","message":{"content":[{"type":"text","text":"review"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T12:00:21Z","message":{"content":[{"type":"text","text":"PASS"}]}}'
} > "$FIXTURE_ROOT/s3/subagents/agent-reviewer-a4.jsonl"

echo '{"type":"user","timestamp":"2026-08-01T12:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$FIXTURE_ROOT/s3.jsonl"

# --- s4: A5_bad (no terminal STATUS line), A5_good (has one) ---

echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s4/subagents/agent-a5bad.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T13:00:00Z","message":{"content":[{"type":"text","text":"explore"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T13:00:01Z","message":{"content":[{"type":"text","text":"found something"}]}}'
} > "$FIXTURE_ROOT/s4/subagents/agent-a5bad.jsonl"

echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s4/subagents/agent-a5good.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T13:00:00Z","message":{"content":[{"type":"text","text":"explore"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T13:00:01Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s4/subagents/agent-a5good.jsonl"

echo '{"type":"user","timestamp":"2026-08-01T13:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$FIXTURE_ROOT/s4.jsonl"

# --- s5: reviewer whose description matches the A6_good marker's task id ---

echo '{"agentType":"reviewer","description":"Unit: gh-888","model":"opus","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s5/subagents/agent-reviewer-a6.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T14:00:00Z","message":{"content":[{"type":"text","text":"Unit: gh-888"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T14:00:01Z","message":{"content":[{"type":"text","text":"PASS"}]}}'
} > "$FIXTURE_ROOT/s5/subagents/agent-reviewer-a6.jsonl"

echo '{"type":"user","timestamp":"2026-08-01T14:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$FIXTURE_ROOT/s5.jsonl"

# A6_bad: orphan marker, no reviewer dispatch anywhere in the window mentions it.
echo 'PASS gh-999 2026-08-01T10:00:00Z commit: abc123 criteria: test' > "$FIXTURE_ROOT/reviewed/gh-999.pass"
# A6_good: marker with a matching reviewer dispatch (s5, above).
echo 'PASS gh-888 2026-08-01T10:00:00Z commit: def456 criteria: test' > "$FIXTURE_ROOT/reviewed/gh-888.pass"

# --- s6: R5 privacy fixture - prompt body must never be echoed in the report ---

echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s6/subagents/agent-privacy.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T15:00:00Z","message":{"content":[{"type":"text","text":"secret CANARY-PROMPT-BODY here"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T15:00:01Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s6/subagents/agent-privacy.jsonl"

echo '{"type":"user","timestamp":"2026-08-01T15:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$FIXTURE_ROOT/s6.jsonl"

# --- run the real script against the fixture tree, for real ---

JSON_OUTPUT="$(AGENT_AUDIT_ROOT="$FIXTURE_ROOT" bash scripts/agent-audit.sh --all --json)"

assert_agent_finding() {
  # $1 = anomaly id, $2 = agent id, $3 = present|absent
  local id="$1" agent="$2" want="$3" count
  count="$(printf '%s' "$JSON_OUTPUT" | jq --arg id "$id" --arg agent "$agent" \
    '[.findings[] | select(.id==$id and .agent==$agent)] | length')"
  if [ "$want" = present ]; then
    if [ "$count" -gt 0 ]; then
      echo "OK   $id fires for agent=$agent (count=$count)"
    else
      echo "FAIL $id did not fire for agent=$agent (expected present)"
      fail=1
    fi
  else
    if [ "$count" -eq 0 ]; then
      echo "OK   $id does not fire for agent=$agent"
    else
      echo "FAIL $id fired for agent=$agent (expected absent, count=$count)"
      fail=1
    fi
  fi
}

assert_task_finding() {
  # $1 = anomaly id, $2 = task id, $3 = present|absent
  local id="$1" task="$2" want="$3" count
  count="$(printf '%s' "$JSON_OUTPUT" | jq --arg id "$id" --arg task "$task" \
    '[.findings[] | select(.id==$id and .task==$task)] | length')"
  if [ "$want" = present ]; then
    if [ "$count" -gt 0 ]; then
      echo "OK   $id fires for task=$task (count=$count)"
    else
      echo "FAIL $id did not fire for task=$task (expected present)"
      fail=1
    fi
  else
    if [ "$count" -eq 0 ]; then
      echo "OK   $id does not fire for task=$task"
    else
      echo "FAIL $id fired for task=$task (expected absent, count=$count)"
      fail=1
    fi
  fi
}

echo "== A1: undeclared tool use =="
assert_agent_finding A1 a1bad present
assert_agent_finding A1 a1good absent

echo "== A2: unregistered agent type =="
assert_agent_finding A2 a2bad present
assert_agent_finding A2 a2good absent

echo "== A3: nested spawn =="
assert_agent_finding A3 a3bad present
assert_agent_finding A3 a3good absent

echo "== A4: gated dispatch without review =="
assert_agent_finding A4 a4bad present
assert_agent_finding A4 a4good absent

echo "== A5: missing terminal status line =="
assert_agent_finding A5 a5bad present
assert_agent_finding A5 a5good absent

echo "== A6: orphan PASS marker =="
assert_task_finding A6 gh-999 present
assert_task_finding A6 gh-888 absent

echo "== R5: privacy - prompt body must never appear in output =="
if printf '%s' "$JSON_OUTPUT" | grep -q "CANARY-PROMPT-BODY"; then
  echo "FAIL --json output leaked the privacy canary string"
  fail=1
else
  echo "OK   --json output does not contain the privacy canary string"
fi

PLAIN_OUTPUT="$(AGENT_AUDIT_ROOT="$FIXTURE_ROOT" bash scripts/agent-audit.sh --all)"
if printf '%s' "$PLAIN_OUTPUT" | grep -q "CANARY-PROMPT-BODY"; then
  echo "FAIL plain-text output leaked the privacy canary string"
  fail=1
else
  echo "OK   plain-text output does not contain the privacy canary string"
fi

# --- mutation proof (non-vacuity): A1 and A5 -------------------------------
# Neutralizes the anomaly's emit_finding call in a scratch COPY of the
# script (never the tracked scripts/agent-audit.sh - matching the
# mutation-control pattern in tests/stop-gate-blocked.test.sh), symlinking
# in the unmutated lib/agents/.claude dirs the script also needs to resolve
# personas and the gated-agents list. Re-runs the SAME fixtures/assertions
# against the mutant and requires detection to have genuinely disappeared.

MUTANT_DIR="$FIXTURE_ROOT/mutant"
mkdir -p "$MUTANT_DIR/scripts"
cp scripts/agent-audit.sh "$MUTANT_DIR/scripts/agent-audit.sh"
ln -s "$(pwd)/hooks" "$MUTANT_DIR/hooks"
ln -s "$(pwd)/agents" "$MUTANT_DIR/agents"
ln -s "$(pwd)/.claude" "$MUTANT_DIR/.claude"
ln -s "$(pwd)/templates" "$MUTANT_DIR/templates"

mutation_proof() {
  # $1 = anomaly id, $2 = agent id whose fixture should stop firing once mutated
  local id="$1" agent="$2" before after count

  before="$(grep -c "emit_finding ${id} " "$MUTANT_DIR/scripts/agent-audit.sh" || true)"
  if [ "$before" -eq 0 ]; then
    echo "FAIL mutation proof for $id: no emit_finding ${id} call sites found to neutralize"
    fail=1
    return
  fi

  sed -i "s/emit_finding ${id} /true # MUTATED-${id} /" "$MUTANT_DIR/scripts/agent-audit.sh"
  after="$(grep -c "emit_finding ${id} " "$MUTANT_DIR/scripts/agent-audit.sh" || true)"

  count="$(AGENT_AUDIT_ROOT="$FIXTURE_ROOT" bash "$MUTANT_DIR/scripts/agent-audit.sh" --all --json | \
    jq --arg id "$id" --arg agent "$agent" '[.findings[] | select(.id==$id and .agent==$agent)] | length')"

  if [ "$after" -eq 0 ] && [ "$count" -eq 0 ]; then
    echo "OK   mutation proof for $id: neutralizing $before call site(s) makes agent=$agent's finding disappear (count=$count) - detection was load-bearing"
  else
    echo "FAIL mutation proof for $id: still detected after mutation (call sites remaining=$after, count=$count) - suite would not catch a regression here"
    fail=1
  fi
}

echo "== mutation proof: A1 =="
mutation_proof A1 a1bad

echo "== mutation proof: A5 =="
mutation_proof A5 a5bad

echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks FAILED."
fi
exit "$fail"
