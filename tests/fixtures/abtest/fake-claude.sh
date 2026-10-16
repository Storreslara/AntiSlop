#!/usr/bin/env bash
# Test double for the claude CLI. Records its argv and a few env vars under
# FAKE_CLAUDE_LOG, then prints canned output. No network, no usage.
# Env: FAKE_CLAUDE_LOG (dir, required), FAKE_CLAUDE_STREAM (file to print as
#      stdout), FAKE_CLAUDE_STDERR (text for stderr), FAKE_CLAUDE_SLEEP
#      (seconds), FAKE_CLAUDE_EXIT (exit code, default 0), FAKE_CLAUDE_TOUCH
#      (a file name to create in the working directory, to mimic an edit).
set -u
log="${FAKE_CLAUDE_LOG:?FAKE_CLAUDE_LOG required}"
mkdir -p "$log"
n=$(( $(ls "$log" | grep -c '^argv\.') + 1 ))
printf '%s\0' "$@" > "$log/argv.$n"
{
  printf 'CLAUDE_CONFIG_DIR=%s\n' "${CLAUDE_CONFIG_DIR:-}"
  printf 'CLAUDE_CODE_SUBAGENT_MODEL=%s\n' "${CLAUDE_CODE_SUBAGENT_MODEL:-}"
  printf 'PWD=%s\n' "$PWD"
} > "$log/env.$n"
if [ -n "${FAKE_CLAUDE_SLEEP:-}" ]; then sleep "$FAKE_CLAUDE_SLEEP"; fi
if [ -n "${FAKE_CLAUDE_TOUCH:-}" ]; then printf 'x\n' > "$FAKE_CLAUDE_TOUCH"; fi
if [ -n "${FAKE_CLAUDE_STDERR:-}" ]; then printf '%s\n' "$FAKE_CLAUDE_STDERR" >&2; fi
if [ -n "${FAKE_CLAUDE_STREAM:-}" ]; then
  cat "$FAKE_CLAUDE_STREAM"
else
  printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"num_turns":1,"result":"ok","usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"modelUsage":{"fable-test":{"inputTokens":1,"outputTokens":1,"cacheReadInputTokens":0,"cacheCreationInputTokens":0}}}'
fi
exit "${FAKE_CLAUDE_EXIT:-0}"
