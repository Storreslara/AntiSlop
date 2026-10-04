#!/usr/bin/env bash
# Differential sweep for human-decision-gate.sh (esc-left-3 review tool, not
# wired into validate.sh). Usage:
#   bash tests/hdg-differential-sweep.sh <old-gate> <new-gate> <corpus.jsonl>
# The corpus holds one JSON string (a Bash command) per line. Each gate path
# must sit beside a lib/ directory, since the gate sources lib/ relative to
# itself. Prints "<old> <new> <command-json>" per command, then
# `total=N new_denials=D new_allowances=A`. A verdict is deny (rc 2), ask (rc 0
# with a permissionDecision "ask"), allow (rc 0) or err<rc>; Claude Code treats
# any other rc as a non-blocking error, so err ranks with allow.
set -euo pipefail
[ "$#" = 3 ] || { echo "usage: $0 <old-gate> <new-gate> <corpus.jsonl>" >&2; exit 64; }
old="$(realpath "$1")"
new="$(realpath "$2")"
corpus="$(realpath "$3")"
jobs="${HDG_SWEEP_JOBS:-8}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/proj/.claude/human-review/u1"

verdict() { # $1 gate, $2 hook input
  local out rc=0
  out="$(printf '%s' "$2" | (cd "$work/proj" && CLAUDE_PROJECT_DIR="$work/proj" bash "$1" 2>/dev/null))" || rc=$?
  case "$rc" in
    0) case "$out" in *'"ask"'*) echo ask ;; *) echo allow ;; esac ;;
    2) echo deny ;;
    *) echo "err$rc" ;;
  esac
}

worker() { # $1 chunk file
  local line input
  while IFS= read -r line || [ -n "$line" ]; do
    input="$(jq -cn --argjson c "$line" \
      '{tool_name:"Bash",agent_type:"antislop:lead-programmer",tool_input:{command:$c}}' 2>/dev/null)" || continue
    printf '%s %s %s\n' "$(verdict "$old" "$input")" "$(verdict "$new" "$input")" "$line"
  done < "$1"
}

split -n "l/$jobs" -d "$corpus" "$work/chunk."
for chunk in "$work"/chunk.*; do
  worker "$chunk" > "$chunk.out" &
done
wait

declare -A rank=([deny]=2 [ask]=1)
total=0 denials=0 allowances=0
for chunk in "$work"/chunk.*[0-9]; do
  while read -r o n rest; do
    printf '%s %s %s\n' "$o" "$n" "$rest"
    total=$((total + 1))
    ro="${rank[$o]:-0}" rn="${rank[$n]:-0}"
    [ "$rn" -le "$ro" ] || denials=$((denials + 1))
    [ "$rn" -ge "$ro" ] || allowances=$((allowances + 1))
  done < "$chunk.out"
done
echo "total=$total new_denials=$denials new_allowances=$allowances"
