#!/usr/bin/env bash
# Re-runs the criteria a .pass marker claims it ran, or enumerates its
# non-blocking notes. --list (default) only parses and counts criteria;
# --execute actually runs them, checked out into a throwaway git worktree at
# the marker's cited commit, so a dirty live tree cannot contaminate the
# result; --notes enumerates the marker's non-blocking notes and never
# touches its criteria. Advisory only - always exits 0, never decides policy
# for its caller, and MUST NEVER be registered in any hook (RD1's safety
# property - see docs/plans/2026-08-25-harness-trust-gaps.md Step 6).
#
# Usage: marker-verify.sh <task-id> [project-dir] [--execute|--notes]
# Output:
#   --list:    one line: marker-verify=listed unit=<id> criteria=<n>
#   --execute: one line: marker-verify=<ok|mismatch|unverifiable> unit=<id> ran=<n> failed=<n> [failing=<i,j>]
#   --notes:   zero or more `marker-note=<spec|code|untagged> unit=<id> <text>`
#              lines, then one `marker-notes=<n> unit=<id> spec=<a> code=<b>
#              untagged=<c>` summary line
#   unverifiable (list/execute): marker-verify=unverifiable unit=<id>
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"

task_id="${1:-}"
shift || true
project_dir="."
execute=0
notes=0
for arg in "$@"; do
  case "$arg" in
    --execute) execute=1 ;;
    --notes) notes=1 ;;
    *) project_dir="$arg" ;;
  esac
done
dot="${project_dir}/.claude"

emit() {
  printf '%s\n' "$1"
  exit 0
}

unverifiable() {
  emit "marker-verify=unverifiable unit=${task_id}"
}

[ -n "$task_id" ] || unverifiable

state_unit_marker_exists "$task_id" pass || unverifiable

# --notes: three-tier anchor search (exact -> loosened -> fallback), never
# touches criteria/commit fields. See
# docs/plans/2026-09-01-advisory-note-channel-gh295.md Step 1.
find_anchor_line() {
  local body="$1" n=0 line loose_re='^[#> -]{0,4}[Nn]on-blocking [Nn]ote'
  while IFS= read -r line; do
    n=$((n + 1))
    [ "$line" = "Non-blocking notes:" ] && { printf '%d\n' "$n"; return 0; }
  done <<< "$body"
  n=0
  while IFS= read -r line; do
    n=$((n + 1))
    [[ $line =~ $loose_re ]] && { printf '%d\n' "$n"; return 0; }
  done <<< "$body"
  return 1
}

trim() {
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

extract_notes() {
  local body="$1" start_line="$2"
  local n=0 line have=0 cur="" tag="" stripped
  NOTE_TAG=(); NOTE_TEXT=()
  while IFS= read -r line; do
    n=$((n + 1))
    [ "$n" -ge "$start_line" ] || continue
    [ -n "$(trim "$line")" ] || continue
    if [ "$have" -eq 1 ] && [[ $line =~ ^[[:space:]] ]]; then
      cur="$cur $(trim "$line")"
      continue
    fi
    [ "$have" -eq 1 ] && { NOTE_TAG+=("$tag"); NOTE_TEXT+=("$cur"); }
    have=1
    cur="$(trim "$line")"
    stripped="$(printf '%s' "$cur" | sed -E 's/^(-|\*|[0-9]+[.)]|[A-Za-z][0-9]+)[[:space:]]*//')"
    case "$stripped" in
      NOTE\[spec\]:*) tag=spec ;;
      NOTE\[code\]:*) tag=code ;;
      *) tag=untagged ;;
    esac
  done <<< "$body"
  [ "$have" -eq 1 ] && { NOTE_TAG+=("$tag"); NOTE_TEXT+=("$cur"); }
  return 0
}

run_notes_mode() {
  local body anchor_line start_line spec=0 code=0 untagged=0 i
  body="$(state_read_unit_marker "$task_id" "pass" 2>/dev/null || true)"
  anchor_line="$(find_anchor_line "$body" || true)"
  start_line=$(( anchor_line > 0 ? anchor_line + 1 : 2 ))
  extract_notes "$body" "$start_line"
  for i in "${!NOTE_TAG[@]}"; do
    printf 'marker-note=%s unit=%s %s\n' "${NOTE_TAG[$i]}" "$task_id" "${NOTE_TEXT[$i]}"
    case "${NOTE_TAG[$i]}" in
      spec) spec=$((spec + 1)) ;;
      code) code=$((code + 1)) ;;
      *) untagged=$((untagged + 1)) ;;
    esac
  done
  emit "marker-notes=${#NOTE_TAG[@]} unit=${task_id} spec=${spec} code=${code} untagged=${untagged}"
}

[ "$notes" -eq 1 ] && run_notes_mode

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
