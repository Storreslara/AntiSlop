#!/usr/bin/env bash
# Fixture test: session-start.sh plugin-version message depends on version direction.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
hook="$PWD/hooks/scripts/session-start.sh"
tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

run_case() {
  # $1 = case name, $2 = installed version, $3 = adapted version
  local root="$tmproot/$1/plugin" proj="$tmproot/$1/proj"
  mkdir -p "$root/.claude-plugin" "$proj/.claude"
  printf '{"version":"%s"}\n' "$2" > "$root/.claude-plugin/plugin.json"
  printf '{"gatedAgents":["lead-programmer"],"testAndLintCommand":"true","pluginVersion":"%s"}\n' "$3" > "$proj/.claude/persona-config.json"
  printf '{"hook_event_name":"SessionStart","session_id":"t","source":"startup"}' \
    | CLAUDE_PROJECT_DIR="$proj" CLAUDE_PLUGIN_ROOT="$root" bash "$hook"
}

check() {
  # $1 = label, $2 = 1 if pattern must appear / 0 if absent, $3 = pattern, $4 = output
  if echo "$4" | grep -q -- "$3"; then found=1; else found=0; fi
  if [ "$found" = "$2" ]; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi
}

out="$(run_case newer 0.31.104 0.31.63)"
check "installed newer: suggests update-antislop" 1 "update-antislop" "$out"

out="$(run_case older 0.31.63 0.31.104)"
check "installed older: names claude plugin update" 1 "claude plugin update" "$out"
check "installed older: omits update-antislop" 0 "update-antislop" "$out"

out="$(run_case equal 0.31.104 0.31.104)"
check "equal: no update-antislop" 0 "update-antislop" "$out"
check "equal: no claude plugin update" 0 "claude plugin update" "$out"

exit "$fail"
