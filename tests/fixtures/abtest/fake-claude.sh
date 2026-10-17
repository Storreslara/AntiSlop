#!/usr/bin/env bash
# Test double for the claude CLI. Records its argv and a few env vars under
# FAKE_CLAUDE_LOG, then prints canned output. No network, no usage.
# Env: FAKE_CLAUDE_LOG (dir, required), FAKE_CLAUDE_STREAM (file to print as
#      stdout), FAKE_CLAUDE_STDERR (text for stderr), FAKE_CLAUDE_SLEEP
#      (seconds), FAKE_CLAUDE_EXIT (exit code, default 0), FAKE_CLAUDE_TOUCH
#      (a file name to create in the working directory, to mimic an edit),
#      FAKE_CLAUDE_READ (a file whose text is printed as the result, to mimic an arm that read it).
set -u
log="${FAKE_CLAUDE_LOG:?FAKE_CLAUDE_LOG required}"
mkdir -p "$log"
n=$(( $(ls "$log" | grep -c '^argv\.') + 1 ))
printf '%s\0' "$@" > "$log/argv.$n"
{
  printf 'CLAUDE_CONFIG_DIR=%s\n' "${CLAUDE_CONFIG_DIR:-}"
  printf 'CLAUDE_CODE_SUBAGENT_MODEL=%s\n' "${CLAUDE_CODE_SUBAGENT_MODEL:-}"
  printf 'PWD=%s\n' "$PWD"
  printf 'HOME=%s\n' "${HOME:-}"
  printf 'GIT_CONFIG_GLOBAL=%s\n' "${GIT_CONFIG_GLOBAL:-}"
} > "$log/env.$n"
# The files of the plugin directory the arm passed, as seen at run time (the arm removes its copy afterwards).
[ -n "${GIT_CONFIG_GLOBAL:-}" ] && [ -f "$GIT_CONFIG_GLOBAL" ] && cp "$GIT_CONFIG_GLOBAL" "$log/gitconfig.$n"
prev=""
for a in "$@"; do
  if [ "$prev" = "--plugin-dir" ] && [ -d "$a" ]; then ( cd "$a" && find . -type f | sed 's|^\./||' | sort ) > "$log/plugin-files.$n"; fi
  prev="$a"
done
if [ -n "${FAKE_CLAUDE_SLEEP:-}" ]; then sleep "$FAKE_CLAUDE_SLEEP"; fi
if [ -n "${FAKE_CLAUDE_TOUCH:-}" ]; then printf 'x\n' > "$FAKE_CLAUDE_TOUCH"; fi
if [ -n "${FAKE_CLAUDE_STDERR:-}" ]; then printf '%s\n' "$FAKE_CLAUDE_STDERR" >&2; fi
if [ -n "${FAKE_CLAUDE_READ:-}" ]; then
  # Mimic an arm that reads a file: print its text as the result, or "unreadable".
  python3 -I -c 'import json,sys
try:
    t = open(sys.argv[1]).read()
except OSError:
    t = "unreadable"
print(json.dumps({"type": "result", "subtype": "success", "is_error": False, "num_turns": 1, "result": t}))' "$FAKE_CLAUDE_READ"
  exit "${FAKE_CLAUDE_EXIT:-0}"
fi
if [ -n "${FAKE_CLAUDE_STREAM:-}" ]; then
  cat "$FAKE_CLAUDE_STREAM"
else
  printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"num_turns":1,"result":"ok","usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"modelUsage":{"fable-test":{"inputTokens":1,"outputTokens":1,"cacheReadInputTokens":0,"cacheCreationInputTokens":0}}}'
fi
exit "${FAKE_CLAUDE_EXIT:-0}"
