#!/usr/bin/env bash
# Fixture-driven test for scripts/agent-audit.sh (Step 3 of
# docs/plans/2026-08-09-agent-auditor-persona.md).
#
# Builds a synthetic AGENT_AUDIT_ROOT tree with one known-good and one
# known-bad fixture per anomaly class (A1-A4, A6), plus an R5 privacy fixture,
# then actually invokes scripts/agent-audit.sh against it and asserts on the
# real --json output. Non-vacuity for A1 is proven by mutation
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
  "$FIXTURE_ROOT/s7/subagents" \
  "$FIXTURE_ROOT/s8/subagents" \
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

# --- s7: A7 (hook block events) ---
# A7_bad: has tool_result errors matching the PreToolUse hook error pattern
echo '{"agentType":"lead-programmer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s7/subagents/agent-a7bad.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T16:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T16:00:01Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"ls"}}]}}'
  echo '{"type":"tool_result","id":"t1","name":"Bash","content":"error","is_error":true,"timestamp":"2026-08-01T16:00:02Z","text":"PreToolUse:Bash hook error: [hooks/scripts/reviewed-path-gate.sh]: BLOCKED: A7CANARY-BASH-BLOCK extra text"}'
  echo '{"type":"assistant","timestamp":"2026-08-01T16:00:03Z","message":{"content":[{"type":"tool_use","id":"t2","name":"Write","input":{"file_path":"/home/proj/.claude/reviewed/test.txt","content":"data"}}]}}'
  echo '{"type":"tool_result","id":"t2","name":"Write","content":"error","is_error":true,"timestamp":"2026-08-01T16:00:04Z","text":"PreToolUse:Write hook error: [hooks/scripts/reviewed-path-gate.sh]: BLOCKED: A7CANARY-WRITE-BLOCK"}'
  echo '{"type":"assistant","timestamp":"2026-08-01T16:00:05Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s7/subagents/agent-a7bad.jsonl"

# A7_good: no hook block errors
echo '{"agentType":"lead-programmer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s7/subagents/agent-a7good.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T16:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T16:00:01Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}'
  echo '{"type":"tool_result","id":"t1","name":"Read","content":"success","timestamp":"2026-08-01T16:00:02Z","text":"file contents"}'
  echo '{"type":"assistant","timestamp":"2026-08-01T16:00:03Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s7/subagents/agent-a7good.jsonl"

echo '{"type":"user","timestamp":"2026-08-01T16:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$FIXTURE_ROOT/s7.jsonl"

# --- s8: A8 (agent-memory writes) ---
# A8_bad: has Write/Edit tool_use entries under .claude/agent-memory/ or .claude/projects/*/memory/
echo '{"agentType":"spec-master","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s8/subagents/agent-a8bad.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T17:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T17:00:01Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Write","input":{"file_path":".claude/agent-memory/spec-master/A8CANARY-DIR/feedback_test.md","content":"A8CANARY-CONTENT-BODY here"}}]}}'
  echo '{"type":"tool_result","id":"t1","name":"Write","timestamp":"2026-08-01T17:00:02Z","text":"written"}'
  echo '{"type":"assistant","timestamp":"2026-08-01T17:00:03Z","message":{"content":[{"type":"tool_use","id":"t2","name":"Edit","input":{"file_path":".claude/projects/test/memory/feedback_other.md","content":"more data"}}]}}'
  echo '{"type":"tool_result","id":"t2","name":"Edit","timestamp":"2026-08-01T17:00:04Z","text":"edited"}'
  echo '{"type":"assistant","timestamp":"2026-08-01T17:00:05Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s8/subagents/agent-a8bad.jsonl"

# A8_good: no agent-memory writes
echo '{"agentType":"spec-master","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/s8/subagents/agent-a8good.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T17:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T17:00:01Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Write","input":{"file_path":"docs/test.md","content":"some content"}}]}}'
  echo '{"type":"tool_result","id":"t1","name":"Write","timestamp":"2026-08-01T17:00:02Z","text":"written"}'
  echo '{"type":"assistant","timestamp":"2026-08-01T17:00:03Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/s8/subagents/agent-a8good.jsonl"

echo '{"type":"user","timestamp":"2026-08-01T17:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$FIXTURE_ROOT/s8.jsonl"

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

echo "== A6: orphan PASS marker =="
assert_task_finding A6 gh-999 present
assert_task_finding A6 gh-888 absent

echo "== A7: hook block events =="
assert_agent_finding A7 a7bad present
assert_agent_finding A7 a7good absent

echo "== A8: agent-memory writes =="
assert_agent_finding A8 a8bad present
assert_agent_finding A8 a8good absent

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

echo "== C1.5: A7 row distinguishes Bash and Write blocks on same dispatch =="
a7_bash_count="$(printf '%s' "$JSON_OUTPUT" | jq '[.findings[] | select(.id=="A7" and .agent=="a7bad" and .tool=="Bash")] | length')"
a7_write_count="$(printf '%s' "$JSON_OUTPUT" | jq '[.findings[] | select(.id=="A7" and .agent=="a7bad" and .tool=="Write")] | length')"
if [ "$a7_bash_count" -gt 0 ] && [ "$a7_write_count" -gt 0 ]; then
  echo "OK   A7 produces distinct rows for Bash (n=$a7_bash_count) and Write (n=$a7_write_count) on same dispatch"
else
  echo "FAIL A7 did not distinguish tools: bash=$a7_bash_count write=$a7_write_count"
  fail=1
fi

echo "== C1.5: A7 row has hook field equal to reviewed-path-gate =="
a7_hook_count="$(printf '%s' "$JSON_OUTPUT" | jq '[.findings[] | select(.id=="A7" and .agent=="a7bad" and .hook=="reviewed-path-gate")] | length')"
if [ "$a7_hook_count" -gt 0 ]; then
  echo "OK   A7 row carries hook==reviewed-path-gate (n=$a7_hook_count)"
else
  echo "FAIL A7 row missing hook field or hook!=reviewed-path-gate"
  fail=1
fi

echo "== C1.6: A8 bad produces no A1 row (A1 exclusion survived) =="
a1_a8bad_count="$(printf '%s' "$JSON_OUTPUT" | jq '[.findings[] | select(.id=="A1" and .agent=="a8bad")] | length')"
if [ "$a1_a8bad_count" -eq 0 ]; then
  echo "OK   a8bad produces no A1 row (memory-write exclusion survived)"
else
  echo "FAIL a8bad produced an A1 row (A1 exclusion was broken, count=$a1_a8bad_count)"
  fail=1
fi

echo "== C1.8: A7/A8 privacy - canaries not in --json output =="
if printf '%s' "$JSON_OUTPUT" | grep -qE "A7CANARY|A8CANARY"; then
  echo "FAIL --json output leaked A7/A8 privacy canaries"
  fail=1
else
  echo "OK   --json output does not leak A7/A8 privacy canaries"
fi

echo "== C1.8: A7/A8 privacy - canaries not in --all output =="
if printf '%s' "$PLAIN_OUTPUT" | grep -qE "A7CANARY|A8CANARY"; then
  echo "FAIL --all output leaked A7/A8 privacy canaries"
  fail=1
else
  echo "OK   --all output does not leak A7/A8 privacy canaries"
fi

echo "== C1.9: A7 and A8 lines are marked informational =="
a7_plain_line="$(printf '%s' "$PLAIN_OUTPUT" | grep "^A7 ")"
a8_plain_line="$(printf '%s' "$PLAIN_OUTPUT" | grep "^A8 ")"
if printf '%s' "$a7_plain_line" | grep -qi informational && printf '%s' "$a8_plain_line" | grep -qi informational; then
  echo "OK   A7 and A8 plain-output lines contain 'informational'"
else
  echo "FAIL A7 or A8 lines missing 'informational' marker"
  echo "  A7 line: $a7_plain_line"
  echo "  A8 line: $a8_plain_line"
  fail=1
fi

echo "== C1.10: format-change tolerance - is_error true but no BLOCKED text =="
tolerance_test_root="$FIXTURE_ROOT/tolerance-test"
mkdir -p "$tolerance_test_root/tol/subagents"
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$tolerance_test_root/tol/subagents/agent-tol.meta.json"
{
  echo '{"type":"user","timestamp":"2026-08-01T18:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"assistant","timestamp":"2026-08-01T18:00:01Z","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"ls"}}]}}'
  echo '{"type":"tool_result","id":"t1","name":"Bash","content":"error","is_error":true,"timestamp":"2026-08-01T18:00:02Z","text":"Some other error message not matching the hook pattern"}'
  echo '{"type":"assistant","timestamp":"2026-08-01T18:00:03Z","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$tolerance_test_root/tol/subagents/agent-tol.jsonl"
echo '{"type":"user","timestamp":"2026-08-01T18:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$tolerance_test_root/tol.jsonl"

tol_output="$(AGENT_AUDIT_ROOT="$tolerance_test_root" bash scripts/agent-audit.sh --all --json)"
tol_a7_count="$(printf '%s' "$tol_output" | jq '[.findings[] | select(.id=="A7")] | length')"
if [ "$tol_a7_count" -eq 0 ]; then
  echo "OK   format-change tolerance: non-matching is_error=true produces no A7 row"
else
  echo "FAIL format-change tolerance: A7 emitted rows for non-matching format (count=$tol_a7_count)"
  fail=1
fi

# --- mutation proof (non-vacuity): A1 -----------------------------------------------
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

echo "== mutation proof: A7 (hook block events) =="
# For A7, neutralize the jq query that detects BLOCKED patterns by replacing
# the test condition with false, so the query matches nothing.
before_a7="$(grep -c 'test("PreToolUse:.*hook error:.*BLOCKED:")' "$MUTANT_DIR/scripts/agent-audit.sh" || true)"
if [ "$before_a7" -eq 0 ]; then
  echo "FAIL mutation proof for A7: no BLOCKED pattern test found to neutralize"
  fail=1
else
  # Replace the BLOCKED test with false to neutralize A7 detection. No trailing
  # `#` comment here - this line lives inside a single-line jq program string,
  # where `#` starts a jq comment and would swallow the rest of the pipeline.
  sed -i 's/test("PreToolUse:\.\*hook error:\.\*BLOCKED:")/false/' "$MUTANT_DIR/scripts/agent-audit.sh"

  mutant_a7_count="$(AGENT_AUDIT_ROOT="$FIXTURE_ROOT" bash "$MUTANT_DIR/scripts/agent-audit.sh" --all --json 2>/dev/null | \
    jq '[.findings[] | select(.id=="A7" and .agent=="a7bad")] | length')"

  if [ "$mutant_a7_count" -eq 0 ]; then
    echo "OK   mutation proof for A7: neutralizing hook-block detection makes a7bad's A7 findings disappear (count=$mutant_a7_count) - detection was load-bearing"
  else
    echo "FAIL mutation proof for A7: still detected after attempted mutation (count=$mutant_a7_count) - suite may not catch a regression"
    fail=1
  fi
fi

echo "== mutation proof: A8 (agent-memory writes) =="
# For A8, we neutralize the logic that detects writes under .claude/agent-memory/ and .claude/projects/*/memory/
before_a8="$(grep -c 'claude/agent-memory\|claude/projects.*memory' "$MUTANT_DIR/scripts/agent-audit.sh" || true)"
if [ "$before_a8" -eq 0 ]; then
  echo "FAIL mutation proof for A8: no memory path patterns found to neutralize"
  fail=1
else
  # Neutralize the A8 detection by rewriting the case-pattern label so it can
  # never match a real path. Targets only the case-label line itself (by its
  # exact alternation text, ending in the pattern's closing paren) so the
  # replacement stays valid `case` syntax and the surrounding comment line is
  # left untouched.
  sed -i 's/\.claude\/agent-memory\/\*|\*\/\.claude\/agent-memory\/\*|\.claude\/projects\/\*\/memory\/\*|\*\/\.claude\/projects\/\*\/memory\/\*)/NEVER-MATCHES-A8-MUTANT)/' \
    "$MUTANT_DIR/scripts/agent-audit.sh"

  mutant_a8_count="$(AGENT_AUDIT_ROOT="$FIXTURE_ROOT" bash "$MUTANT_DIR/scripts/agent-audit.sh" --all --json 2>/dev/null | \
    jq '[.findings[] | select(.id=="A8" and .agent=="a8bad")] | length')"

  if [ "$mutant_a8_count" -eq 0 ]; then
    echo "OK   mutation proof for A8: neutralizing memory-path detection makes a8bad's A8 findings disappear (count=$mutant_a8_count) - detection was load-bearing"
  else
    echo "FAIL mutation proof for A8: still detected after attempted mutation (count=$mutant_a8_count) - suite may not catch a regression"
    fail=1
  fi
fi

# --- format-probe state discrimination (Step 10, F3) ------------------------
# Five fixture roots, five expected states. LIVE reuses FIXTURE_ROOT itself
# (already has parseable sessions and dispatches from s1-s6 above); the other
# four are purpose-built subdirectories of it so the existing top-level trap
# cleans them up too. None of these subdirectories has its own "subagents"
# child, so they cannot pollute FIXTURE_ROOT's own */subagents/* glob match
# for the LIVE case.

PROBE_LIVE="$FIXTURE_ROOT"
PROBE_NODISP="$FIXTURE_ROOT/probe-nodisp"
PROBE_EMPTY="$FIXTURE_ROOT/probe-empty"
PROBE_NOSTORE="$FIXTURE_ROOT/probe-nostore"
PROBE_MALFORMED="$FIXTURE_ROOT/probe-malformed"

mkdir -p "$PROBE_NODISP" "$PROBE_EMPTY" "$PROBE_MALFORMED"
# PROBE_NOSTORE is deliberately never created.
# PROBE_EMPTY is deliberately left with zero files.

echo '{"type":"user","timestamp":"2026-08-01T16:00:00Z","message":{"content":[{"type":"text","text":"hello"}]}}' \
  > "$PROBE_NODISP/s.jsonl"

echo 'not valid json' > "$PROBE_MALFORMED/s.jsonl"

echo "== format-probe: five conditions render five distinct outputs =="
n="$(for r in "$PROBE_LIVE" "$PROBE_NODISP" "$PROBE_EMPTY" "$PROBE_NOSTORE" "$PROBE_MALFORMED"; do
      AGENT_AUDIT_ROOT="$r" bash scripts/agent-audit.sh --format-probe
    done | sort -u | wc -l)"
if [ "$n" -eq 5 ]; then
  echo "OK   five distinct probe outputs across five store conditions"
else
  echo "FAIL expected 5 distinct probe outputs, got $n"
  fail=1
fi

live_state="$(AGENT_AUDIT_ROOT="$PROBE_LIVE" bash scripts/agent-audit.sh --format-probe)"
nodisp_state="$(AGENT_AUDIT_ROOT="$PROBE_NODISP" bash scripts/agent-audit.sh --format-probe)"
empty_state="$(AGENT_AUDIT_ROOT="$PROBE_EMPTY" bash scripts/agent-audit.sh --format-probe)"
nostore_state="$(AGENT_AUDIT_ROOT="$PROBE_NOSTORE" bash scripts/agent-audit.sh --format-probe)"
malformed_state="$(AGENT_AUDIT_ROOT="$PROBE_MALFORMED" bash scripts/agent-audit.sh --format-probe)"

assert_probe_state() {
  # $1 = fixture label, $2 = actual state, $3 = expected state
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    echo "OK   $label reports $want"
  else
    echo "FAIL $label reports $got, expected $want"
    fail=1
  fi
}

echo "== format-probe: each fixture reports its named state =="
assert_probe_state LIVE "$live_state" FORMAT-OK
assert_probe_state NODISP "$nodisp_state" FORMAT-OK-NO-DISPATCHES
assert_probe_state EMPTY "$empty_state" FORMAT-EMPTY
assert_probe_state NOSTORE "$nostore_state" FORMAT-NO-STORE
assert_probe_state MALFORMED "$malformed_state" FORMAT-UNRECOGNIZED

echo "== format-probe: R1 pair - empty vs malformed must render differently =="
if [ "$empty_state" != "$malformed_state" ]; then
  echo "OK   FORMAT-EMPTY and FORMAT-UNRECOGNIZED render differently"
else
  echo "FAIL FORMAT-EMPTY and FORMAT-UNRECOGNIZED render identically"
  fail=1
fi

echo "== format-probe: no false alarm on a readable store with zero dispatches =="
if printf '%s' "$nodisp_state" | grep -q FORMAT-UNRECOGNIZED; then
  echo "FAIL NODISP falsely reports FORMAT-UNRECOGNIZED"
  fail=1
else
  echo "OK   NODISP does not report FORMAT-UNRECOGNIZED"
fi

echo "== format-probe: --all is loud on a malformed store =="
malformed_all="$(AGENT_AUDIT_ROOT="$PROBE_MALFORMED" bash scripts/agent-audit.sh --all)"
if printf '%s' "$malformed_all" | grep -q FORMAT-UNRECOGNIZED; then
  echo "OK   --all surfaces FORMAT-UNRECOGNIZED for a malformed store"
else
  echo "FAIL --all did not surface FORMAT-UNRECOGNIZED for a malformed store"
  fail=1
fi

echo "== format-probe: empty-store --all render is unchanged =="
empty_all="$(AGENT_AUDIT_ROOT="$PROBE_EMPTY" bash scripts/agent-audit.sh --all)"
empty_all_json="$(AGENT_AUDIT_ROOT="$PROBE_EMPTY" bash scripts/agent-audit.sh --all --json)"
if [ "$empty_all" = "no data for window" ] && [ "$empty_all_json" = "no data for window" ]; then
  echo "OK   empty-store --all/--all --json render exactly 'no data for window'"
else
  echo "FAIL empty-store render changed (plain=[$empty_all] json=[$empty_all_json])"
  fail=1
fi

echo "== format-probe: exit codes stay 0 across all five conditions and both modes =="
probe_exit_ok=1
for r in "$PROBE_LIVE" "$PROBE_NODISP" "$PROBE_EMPTY" "$PROBE_NOSTORE" "$PROBE_MALFORMED"; do
  AGENT_AUDIT_ROOT="$r" bash scripts/agent-audit.sh --format-probe >/dev/null || probe_exit_ok=0
  AGENT_AUDIT_ROOT="$r" bash scripts/agent-audit.sh --all          >/dev/null || probe_exit_ok=0
done
if [ "$probe_exit_ok" -eq 1 ]; then
  echo "OK   exit code 0 in every mode across all five store conditions"
else
  echo "FAIL a non-zero exit code was observed in some mode/condition"
  fail=1
fi

# --- mutation proof (non-vacuity): FORMAT-EMPTY collapsed into
# FORMAT-UNRECOGNIZED ---------------------------------------------------
# Reuses the MUTANT_DIR scratch copy set up above for the A1 mutation
# proofs (never the tracked scripts/agent-audit.sh itself).

echo "== mutation proof: FORMAT-EMPTY collapsed into FORMAT-UNRECOGNIZED =="
before="$(grep -c 'echo "FORMAT-EMPTY"' "$MUTANT_DIR/scripts/agent-audit.sh" || true)"
if [ "$before" -eq 0 ]; then
  echo "FAIL mutation proof for FORMAT-EMPTY: no echo \"FORMAT-EMPTY\" call site found to neutralize"
  fail=1
else
  sed -i 's/echo "FORMAT-EMPTY"/echo "FORMAT-UNRECOGNIZED" # MUTATED-FORMAT-EMPTY/' "$MUTANT_DIR/scripts/agent-audit.sh"
  mutant_empty_state="$(AGENT_AUDIT_ROOT="$PROBE_EMPTY" bash "$MUTANT_DIR/scripts/agent-audit.sh" --format-probe)"
  if [ "$mutant_empty_state" = "FORMAT-UNRECOGNIZED" ]; then
    echo "OK   mutation proof: collapsing FORMAT-EMPTY into FORMAT-UNRECOGNIZED is detected (mutant now reports $mutant_empty_state, colliding with the malformed state) - detection was load-bearing"
  else
    echo "FAIL mutation proof: mutant still reports $mutant_empty_state; suite would not catch this regression"
    fail=1
  fi
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks FAILED."
fi
exit "$fail"
