#!/usr/bin/env bash
# Fixture suite for bin/agent-memory-size-check.sh - the non-blocking
# agent-memory namespace size warning (item05-3-pruning-policy,
# docs/plans/2026-09-25-item05-agent-memory-dedup.md Step 3).
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

script=bin/agent-memory-size-check.sh

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

# --- case: a namespace over the threshold warns on stderr, exits 0 ---

proj="$tmproot/over"
mkdir -p "$proj/.claude/agent-memory/small-persona" "$proj/.claude/agent-memory/big-persona"
printf 'tiny\n' > "$proj/.claude/agent-memory/small-persona/note.md"
dd if=/dev/zero of="$proj/.claude/agent-memory/big-persona/big.md" bs=1024 count=20 status=none

out="$(bash "$script" --project-dir "$proj" --threshold-kb 10 2>"$tmproot/over.stderr")"
rc=$?
err="$(cat "$tmproot/over.stderr")"

if [ "$rc" -eq 0 ]; then
  echo "OK   over-threshold: exits 0"
else
  echo "FAIL over-threshold: exit code $rc, expected 0"
  fail=1
fi

if printf '%s' "$err" | grep -q 'WARN.*big-persona'; then
  echo "OK   over-threshold: warns about big-persona on stderr"
else
  echo "FAIL over-threshold: expected a WARN mentioning big-persona on stderr, got: $err"
  fail=1
fi

if printf '%s' "$err" | grep -q 'small-persona'; then
  echo "FAIL over-threshold: small-persona should not be warned about"
  fail=1
else
  echo "OK   over-threshold: small-persona not warned about"
fi

# --- case: P4 - no .claude/agent-memory directory at all -> exit 0, silent ---

proj_absent="$tmproot/absent"
mkdir -p "$proj_absent"

out="$(bash "$script" --project-dir "$proj_absent" --threshold-kb 10 2>"$tmproot/absent.stderr")"
rc=$?
err="$(cat "$tmproot/absent.stderr")"

if [ "$rc" -eq 0 ]; then
  echo "OK   absent namespace dir: exits 0"
else
  echo "FAIL absent namespace dir: exit code $rc, expected 0"
  fail=1
fi

if [ -z "$err" ]; then
  echo "OK   absent namespace dir: no warning printed"
else
  echo "FAIL absent namespace dir: expected no stderr, got: $err"
  fail=1
fi

# --- case: every namespace under threshold -> exit 0, silent ---

proj_under="$tmproot/under"
mkdir -p "$proj_under/.claude/agent-memory/small-persona"
printf 'tiny\n' > "$proj_under/.claude/agent-memory/small-persona/note.md"

out="$(bash "$script" --project-dir "$proj_under" --threshold-kb 10000 2>"$tmproot/under.stderr")"
rc=$?
err="$(cat "$tmproot/under.stderr")"

if [ "$rc" -eq 0 ] && [ -z "$err" ]; then
  echo "OK   under-threshold: exits 0, silent"
else
  echo "FAIL under-threshold: exit code $rc, stderr: $err"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "All agent-memory-size-check cases passed."
else
  echo "One or more agent-memory-size-check cases FAILED."
fi
exit "$fail"
