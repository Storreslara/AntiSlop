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

# --- case: index-size warning (cap 4096 B / 40 lines, warn-only) ---

# mk_index <dir> <line-count> <last-line-width>: N-1 lines of 102 bytes, then a last line of
# <width>+1 bytes, so 40 / 117 is exactly 4096 bytes and 40 / 118 is 4097 bytes.
mk_index() {
  mkdir -p "$1"
  awk -v n="$2" -v w="$3" 'BEGIN { for (i = 1; i < n; i++) printf "%s\n", sprintf("%0101d", i); printf "%s\n", sprintf("%0" w "d", n) }' > "$1/MEMORY.md"
}

# idx_result <project dir> [extra args] -> "<exit status> <WARN-line count>"
idx_result() {
  local p="$1" rc n
  shift
  bash "$script" --project-dir "$p" "$@" 2>"$tmproot/idx.stderr" >/dev/null
  rc=$?
  n="$(grep -c '^WARN agent-memory index' "$tmproot/idx.stderr")"
  echo "$rc $n"
}

mk_index "$tmproot/idx-at/.claude/agent-memory/p" 40 117
mk_index "$tmproot/idx-lines/.claude/agent-memory/p" 41 101
mk_index "$tmproot/idx-bytes/.claude/agent-memory/p" 40 118

at_file="$tmproot/idx-at/.claude/agent-memory/p/MEMORY.md"
if [ "$(wc -c < "$at_file" | tr -d ' ')" = "4096" ] && [ "$(wc -l < "$at_file" | tr -d ' ')" = "40" ]; then
  echo "OK   index fixture: at-cap index is exactly 4096 B / 40 lines"
else
  echo "FAIL index fixture: at-cap index is not 4096 B / 40 lines"
  fail=1
fi

res="$(idx_result "$tmproot/idx-at")"
if [ "$res" = "0 0" ]; then
  echo "OK   index at-cap: no warning, exits 0"
else
  echo "FAIL index at-cap: expected '0 0' (exit, WARN lines), got '$res'"
  fail=1
fi

res="$(idx_result "$tmproot/idx-lines")"
if [ "$res" = "0 1" ]; then
  echo "OK   index over-lines: exactly one warning, exits 0"
else
  echo "FAIL index over-lines: expected '0 1' (exit, WARN lines), got '$res'"
  fail=1
fi

res="$(idx_result "$tmproot/idx-bytes")"
if [ "$res" = "0 1" ]; then
  echo "OK   index over-bytes: exactly one warning, exits 0"
else
  echo "FAIL index over-bytes: expected '0 1' (exit, WARN lines), got '$res'"
  fail=1
fi

if grep -qF 'is 4097 B / 40 lines (cap 4096 B / 40 lines)' "$tmproot/idx.stderr"; then
  echo "OK   index message: names the measured size and the caps"
else
  echo "FAIL index message: expected 'is 4097 B / 40 lines (cap 4096 B / 40 lines)' on stderr"
  fail=1
fi

res="$(idx_result "$tmproot/idx-lines" --index-cap-bytes 100000 --index-cap-lines 100)"
if [ "$res" = "0 0" ]; then
  echo "OK   index override flags: raised caps silence the warning"
else
  echo "FAIL index override flags: expected '0 0' (exit, WARN lines), got '$res'"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "All agent-memory-size-check cases passed."
else
  echo "One or more agent-memory-size-check cases FAILED."
fi
exit "$fail"
