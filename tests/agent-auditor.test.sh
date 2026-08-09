#!/usr/bin/env bash
# Fixture-driven test for scripts/agent-audit.sh
# Tests all six anomaly classes (A1-A6) plus privacy constraint (R5)
# Mutation-proof runs: A1 and A5 require the respective detection code in scripts/agent-audit.sh
set -euo pipefail
cd "$(dirname "$0")/.."

FIXTURE_ROOT=$(mktemp -d)
trap "rm -rf '$FIXTURE_ROOT'" EXIT

mkdir -p "$FIXTURE_ROOT/session1/subagents" "$FIXTURE_ROOT/session2/subagents" \
         "$FIXTURE_ROOT/session3/subagents" "$FIXTURE_ROOT/session4/subagents" \
         "$FIXTURE_ROOT/session5/subagents" "$FIXTURE_ROOT/reviewed"

# A1_bad_fixture - explorer doesn't declare Write but uses it
mkdir -p "$FIXTURE_ROOT/a1_bad"
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/a1_bad/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Write","input":{}}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/a1_bad/transcripts.jsonl"

# A1_good_fixture - explorer uses only declared tools
mkdir -p "$FIXTURE_ROOT/a1_good"
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/a1_good/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/a1_good/transcripts.jsonl"

# A2_bad_fixture - unregistered agent type
mkdir -p "$FIXTURE_ROOT/a2_bad"
echo '{"agentType":"nonexistent-agent","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/a2_bad/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/a2_bad/transcripts.jsonl"

# A2_good_fixture - registered agent
mkdir -p "$FIXTURE_ROOT/a2_good"
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/a2_good/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/a2_good/transcripts.jsonl"

# A3_bad_fixture - spawnDepth >= 2
mkdir -p "$FIXTURE_ROOT/a3_bad"
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":2,"taskKind":"normal"}' > "$FIXTURE_ROOT/a3_bad/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/a3_bad/transcripts.jsonl"

# A3_good_fixture - spawnDepth < 2
mkdir -p "$FIXTURE_ROOT/a3_good"
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":1,"taskKind":"normal"}' > "$FIXTURE_ROOT/a3_good/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:06Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/a3_good/transcripts.jsonl"

# A4_bad_fixture - gated without reviewer
mkdir -p "$FIXTURE_ROOT/a4_bad"
echo '{"agentType":"lead-programmer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/a4_bad/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:10Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:11Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/a4_bad/transcripts.jsonl"

# A4_good_fixture - gated with reviewer
mkdir -p "$FIXTURE_ROOT/a4_good"
echo '{"agentType":"lead-programmer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/a4_good/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:15Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:16Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/a4_good/transcripts.jsonl"

mkdir -p "$FIXTURE_ROOT/reviewer"
echo '{"agentType":"reviewer","description":"test","model":"opus","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/reviewer/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:20Z","role":"user","message":{"content":[{"type":"text","text":"review"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:21Z","role":"assistant","message":{"content":[{"type":"text","text":"PASS"}]}}' \
  > "$FIXTURE_ROOT/reviewer/transcripts.jsonl"

# A5_bad_fixture - missing status line
mkdir -p "$FIXTURE_ROOT/a5_bad"
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/a5_bad/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"explore"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"found something"}]}}' \
  > "$FIXTURE_ROOT/a5_bad/transcripts.jsonl"

# A5_good_fixture - has status line
mkdir -p "$FIXTURE_ROOT/a5_good"
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/a5_good/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"explore"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/a5_good/transcripts.jsonl"

# A6_bad_fixture - orphan marker
echo 'PASS gh-999 2026-08-01T10:00:00Z commit: abc123 criteria: test' > "$FIXTURE_ROOT/reviewed/gh-999.pass"

# A6_good_fixture - marker with reviewer
echo 'PASS gh-888 2026-08-01T10:00:00Z commit: def456 criteria: test' > "$FIXTURE_ROOT/reviewed/gh-888.pass"
mkdir -p "$FIXTURE_ROOT/reviewer2"
echo '{"agentType":"reviewer","description":"Unit: gh-888","model":"opus","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/reviewer2/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"Unit: gh-888"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"PASS"}]}}' \
  > "$FIXTURE_ROOT/reviewer2/transcripts.jsonl"

# Privacy fixture - CANARY-PROMPT-BODY
mkdir -p "$FIXTURE_ROOT/privacy"
echo '{"agentType":"explorer","description":"test","model":"sonnet","spawnDepth":0,"taskKind":"normal"}' > "$FIXTURE_ROOT/privacy/meta.json"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"secret CANARY-PROMPT-BODY here"}]}}' \
  '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"STATUS: complete"}]}}' \
  > "$FIXTURE_ROOT/privacy/transcripts.jsonl"

# Session files
for dir in a1_bad a1_good a2_bad a2_good a3_bad a3_good a4_bad a4_good reviewer a5_bad a5_good reviewer2 privacy; do
  [ -d "$FIXTURE_ROOT/$dir/subagents" ] && continue
  mkdir -p "$FIXTURE_ROOT/$dir/subagents"
  mv "$FIXTURE_ROOT/$dir/meta.json" "$FIXTURE_ROOT/$dir/subagents/agent-test.meta.json"
  mv "$FIXTURE_ROOT/$dir/transcripts.jsonl" "$FIXTURE_ROOT/$dir/subagents/agent-test.jsonl"
  printf '%s\n' \
    '{"type":"message","timestamp":"2026-08-01T10:00:00Z","role":"user","message":{"content":[{"type":"text","text":"hello"}]}}' \
    '{"type":"message","timestamp":"2026-08-01T10:00:01Z","role":"assistant","message":{"content":[{"type":"text","text":"hi"}]}}' \
    > "$FIXTURE_ROOT/$dir.jsonl"
done

exit 0
