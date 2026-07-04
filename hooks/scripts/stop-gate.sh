#!/usr/bin/env bash
# Registered on BOTH Stop (main session) and SubagentStop with
# matcher: "lead-programmer" ONLY (hooks.json). Scoping to just the
# lead-programmer fixes the original design flaw where every persona's
# turn-end (explorer, historian, researcher) would trigger a full test+lint
# run and BLOCK an agent that has no ability to fix anything.
#
# Logic, in order:
#  0) stop_hook_active guard - never re-trigger ourselves in a loop (Claude
#     Code also force-ends after 8 consecutive blocks; this guard avoids
#     wasting turns before that cap).
#  1) per-agent WIP sentinel -> delete it, ALLOW.
#  2) no source changes this session -> ALLOW.
#  3) otherwise run the configured test+lint command; non-zero exit -> BLOCK.
set -euo pipefail

input="$(cat)"

stop_active="$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
[ "$stop_active" = "true" ] && exit 0

agent_id="$(echo "$input" | jq -r '.agent_id // .session_id // "main"' 2>/dev/null || echo main)"
sentinel=".claude/wip-handoff.${agent_id}"

if [ -f "$sentinel" ]; then
  rm -f "$sentinel"
  exit 0
fi

if [ -z "$(git status --porcelain 2>/dev/null || true)" ]; then
  exit 0
fi

config=".claude/persona-config.json"
[ -f "$config" ] || exit 0
check_cmd="$(jq -r '.testAndLintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$check_cmd" ] || exit 0

tmp_out="$(mktemp)"
if ! eval "$check_cmd" >"$tmp_out" 2>&1; then
  echo "Test/lint check failed - fix before ending the turn, or 'touch ${sentinel}' with a stated reason if this is a legitimate mid-task pause (TDD red phase, blocked report, plan-is-wrong escalation)." >&2
  cat "$tmp_out" >&2
  rm -f "$tmp_out"
  exit 2
fi
rm -f "$tmp_out"
exit 0
