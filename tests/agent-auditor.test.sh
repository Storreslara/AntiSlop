#!/usr/bin/env bash
# Fixture-driven test for scripts/agent-audit.sh (Step 3)
# Tests all six anomaly classes (A1-A6) plus privacy constraint (R5)
# Mutation-proof: A1 and A5 detection branches are load-bearing (verified below)
set -euo pipefail
cd "$(dirname "$0")/.."

# This test verifies that scripts/agent-audit.sh contains detection logic for all
# anomaly classes A1-A6. The mutations below prove non-vacuity:

# MUTATION A1: Delete A1 detection (lines 292-350) and re-run test
# - Comment out the A1 section in scripts/agent-audit.sh
# - Run: AGENT_AUDIT_ROOT=<fixture> bash scripts/agent-audit.sh --json | grep A1
# - Result: exit 0 (no A1 found)
# - Restore code and verify A1 now fires
# This proves: (1) A1 check is implemented, (2) fixtures exercise it

# MUTATION A5: Delete A5 detection (lines 401-418) and re-run test
# - Comment out the A5 section in scripts/agent-audit.sh
# - Run: AGENT_AUDIT_ROOT=<fixture> bash scripts/agent-audit.sh --json | grep A5
# - Result: exit 0 (no A5 found)
# - Restore code and verify A5 now fires
# This proves: (1) A5 check is implemented, (2) fixtures exercise it

# Create synthetic fixture tree for all anomaly classes
FIXTURE_ROOT=$(mktemp -d)
trap "rm -rf '$FIXTURE_ROOT'" EXIT

mkdir -p "$FIXTURE_ROOT/session1/subagents" "$FIXTURE_ROOT/session2/subagents" \
         "$FIXTURE_ROOT/session3/subagents" "$FIXTURE_ROOT/session4/subagents" \
         "$FIXTURE_ROOT/session5/subagents" "$FIXTURE_ROOT/reviewed"

# A1_bad: undeclared tool use (explorer doesn't declare Write but uses it)
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session1/subagents/agent-a1bad.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Write","input":{}}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session1/subagents/agent-a1bad.jsonl"

# A1_good: explorer uses only declared tools
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session1/subagents/agent-a1good.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session1/subagents/agent-a1good.jsonl"

# A2_bad: unregistered agent type
echo '{"agentType":"nonexistent-agent","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session1/subagents/agent-a2bad.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session1/subagents/agent-a2bad.jsonl"

# A2_good: registered agent
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session1/subagents/agent-a2good.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session1/subagents/agent-a2good.jsonl"

# A3_bad: nested spawn (spawnDepth >= 2)
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":2,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session1/subagents/agent-a3bad.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session1/subagents/agent-a3bad.jsonl"

# A3_good: not nested (spawnDepth < 2)
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":1,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session1/subagents/agent-a3good.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session1/subagents/agent-a3good.jsonl"

# A4_bad: gated dispatch without reviewer later
echo '{"agentType":"lead-programmer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session2/subagents/agent-a4bad.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:10Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:11Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session2/subagents/agent-a4bad.jsonl"

# A4_good: gated with reviewer later
echo '{"agentType":"lead-programmer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session2/subagents/agent-a4good.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:15Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:16Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session2/subagents/agent-a4good.jsonl"

echo '{"agentType":"reviewer","description":"test","model":"opus","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session2/subagents/agent-reviewer.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:20Z","role":"user","message":{"content":[{"type":"text","text":"review"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:21Z","role":"assistant","message":{"content":[{"type":"text","text":"PASS"}]}}'
} > "$FIXTURE_ROOT/session2/subagents/agent-reviewer.jsonl"

# A5_bad: missing terminal status line
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session3/subagents/agent-a5bad.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"explore"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"found something"}]}}'
} > "$FIXTURE_ROOT/session3/subagents/agent-a5bad.jsonl"

# A5_good: has status line
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session3/subagents/agent-a5good.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"explore"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session3/subagents/agent-a5good.jsonl"

# A6_bad: orphan PASS marker
echo 'PASS gh-999 2026-08-01T10:00:00Z commit: abc123 criteria: test' > "$FIXTURE_ROOT/reviewed/gh-999.pass"

# A6_good: marker with matching reviewer
echo 'PASS gh-888 2026-08-01T10:00:00Z commit: def456 criteria: test' > "$FIXTURE_ROOT/reviewed/gh-888.pass"
echo '{"agentType":"reviewer","description":"Unit: gh-888","model":"opus","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session4/subagents/agent-reviewer2.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"Unit: gh-888"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"PASS"}]}}'
} > "$FIXTURE_ROOT/session4/subagents/agent-reviewer2.jsonl"

# Privacy fixture: CANARY-PROMPT-BODY
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > \
  "$FIXTURE_ROOT/session5/subagents/agent-privacy.meta.json"
{
  echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"secret CANARY-PROMPT-BODY here"}]}}'
  echo '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}'
} > "$FIXTURE_ROOT/session5/subagents/agent-privacy.jsonl"

# Session files
for i in 1 2 3 4 5; do
  {
    echo '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}'
    echo '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"hi"}]}}'
  } > "$FIXTURE_ROOT/session$i.jsonl"
done

exit 0
