#!/usr/bin/env bash
# Re-runs the criteria a .pass marker claims it ran. --list (default) only
# parses and counts them; --execute actually runs them, checked out into a
# throwaway git worktree at the marker's cited commit, so a dirty live tree
# cannot contaminate the result. Advisory only - always exits 0, prints
# exactly one output line, never decides policy for its caller, and MUST
# NEVER be registered in any hook (RD1's safety property - see
# docs/plans/2026-08-25-harness-trust-gaps.md Step 6).
#
# Usage: marker-verify.sh <task-id> [project-dir] [--execute]
# Output (always one line):
#   --list:    marker-verify=listed unit=<id> criteria=<n>
#   --execute: marker-verify=<ok|mismatch|unverifiable> unit=<id> ran=<n> failed=<n> [failing=<i,j>]
#   unverifiable (either mode): marker-verify=unverifiable unit=<id>
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"

task_id="${1:-}"
shift || true
project_dir="."
execute=0
for arg in "$@"; do
  case "$arg" in
    --execute) execute=1 ;;
    *) project_dir="$arg" ;;
  esac
done

emit() {
  printf '%s\n' "$1"
  exit 0
}

unverifiable() {
  emit "marker-verify=unverifiable unit=${task_id}"
}

[ -n "$task_id" ] || unverifiable

state_unit_marker_exists "$task_id" pass || unverifiable

first_line="$(state_read_unit_marker "$task_id" "pass" 2>/dev/null | head -n 1 || true)"

criteria_text=""
if [[ $first_line =~ criteria:[[:space:]]+(.*)$ ]]; then
  criteria_text="${BASH_REMATCH[1]}"
fi
[ -n "$criteria_text" ] || unverifiable

criteria=()
IFS=';' read -ra raw_criteria <<< "$criteria_text"
for raw in "${raw_criteria[@]}"; do
  trimmed="$(printf '%s' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -n "$trimmed" ] && criteria+=("$trimmed")
done
n="${#criteria[@]}"
[ "$n" -gt 0 ] || unverifiable

if [ "$execute" -eq 0 ]; then
  emit "marker-verify=listed unit=${task_id} criteria=${n}"
fi

commit_sha=""
if [[ $first_line =~ commit:[[:space:]]+([0-9a-f]{7,40}|none)([[:space:]]|$) ]]; then
  commit_sha="${BASH_REMATCH[1]}"
fi
[ -n "$commit_sha" ] && [ "$commit_sha" != none ] || unverifiable

git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || unverifiable
git -C "$project_dir" cat-file -e "${commit_sha}^{commit}" >/dev/null 2>&1 || unverifiable

worktree_dir=""
cleanup() {
  [ -n "$worktree_dir" ] || return 0
  git -C "$project_dir" worktree remove --force "$worktree_dir" >/dev/null 2>&1
  rm -rf "$worktree_dir" 2>/dev/null
}
trap cleanup EXIT

worktree_dir="$(mktemp -d)" || unverifiable
if ! git -C "$project_dir" worktree add --detach --force "$worktree_dir" "$commit_sha" >/dev/null 2>&1; then
  unverifiable
fi

ran=0
failed=0
failing=""
for i in "${!criteria[@]}"; do
  idx=$((i + 1))
  ran=$((ran + 1))
  if ! ( cd "$worktree_dir" && eval "${criteria[$i]}" ) >/dev/null 2>&1; then
    failed=$((failed + 1))
    failing="${failing:+$failing,}$idx"
  fi
done

state=ok
[ "$failed" -eq 0 ] || state=mismatch
line="marker-verify=${state} unit=${task_id} ran=${ran} failed=${failed}"
[ -n "$failing" ] && line="$line failing=${failing}"
emit "$line"
