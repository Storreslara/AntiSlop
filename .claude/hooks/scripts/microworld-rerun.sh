#!/usr/bin/env bash
# PostToolUse (Edit|Write). Re-runs every microworld bundle whose manifest
# `watch` globs match the edited file, so breakage surfaces on the fly instead
# of only at review. This is a REPORTER, not a gate: exit 2 (stderr surfaced to
# the model) means a matched bundle's run.sh actually failed or timed out; every
# infrastructure problem - no jq, malformed manifest.json, missing run.sh - is
# logged and exits 0. The edit has already happened either way.
#
# The audit log line format (<timestamp> unit=<slug> result=<pass|fail|timeout|error> file=<path>)
# is a consumed interface with a Node.js parser (bin/dashboard/audit-log.js) on the other side.
# Contract test: tests/microworld-audit-contract.test.js. Do not change the separator or format
# without updating the parser and re-running the contract test.
set -euo pipefail

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
[ -d "${project_dir}/microworlds" ] || exit 0

audit="${project_dir}/.claude/microworld-audit.log"
log() {
  # $1 = unit slug, $2 = result, $3 = file, $4 = optional reason
  local line
  line="$(date -u +%Y-%m-%dT%H:%M:%SZ) unit=$1 result=$2 file=$3"
  if [ "$#" -ge 4 ]; then line="$line reason=$4"; fi
  mkdir -p "$(dirname "$audit")" 2>/dev/null || true
  printf '%s\n' "$line" >> "$audit" 2>/dev/null || true
}

command -v jq >/dev/null 2>&1 || { log - error - no-jq; exit 0; }

file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0
[ -e "$file_path" ] || exit 0

# `watch` globs are project-root-relative; the tool's file_path is typically
# absolute, so normalize before matching. rel_path is also what run.sh receives
# and what the audit log records - run.sh's cwd is the project root.
rel_path="$file_path"
case "$rel_path" in
  "$project_dir"/*) rel_path="${rel_path#"$project_dir"/}" ;;
esac

broken=""
for manifest in "${project_dir}"/microworlds/*/manifest.json; do
  [ -f "$manifest" ] || continue
  slug="$(basename "$(dirname "$manifest")")"

  globs="$(jq -r '.watch[]? // empty' "$manifest" 2>/dev/null)" || {
    log "$slug" error "$rel_path" malformed-manifest
    continue
  }

  matched=false
  while IFS= read -r glob; do
    [ -n "$glob" ] || continue
    case "$rel_path" in
      $glob) matched=true ;;
    esac
  done <<< "$globs"
  [ "$matched" = true ] || continue

  if [ ! -f "${project_dir}/microworlds/${slug}/run.sh" ]; then
    log "$slug" error "$rel_path" missing-run-sh
    continue
  fi

  secs="$(jq -r '.timeoutSeconds // 60' "$manifest" 2>/dev/null || echo 60)"
  case "$secs" in ''|*[!0-9]*) secs=60 ;; esac

  # run.sh is invoked directly with the edited path as a positional parameter -
  # never string-interpolated into an eval'd command - so a crafted filename
  # cannot inject shell. cwd is the project root, per the bundle contract.
  rc=0
  ( cd "$project_dir" && timeout "$secs" bash "./microworlds/${slug}/run.sh" "$rel_path" ) \
    >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0)   log "$slug" pass "$rel_path" ;;
    124) log "$slug" timeout "$rel_path"; broken="$broken $slug(timeout)" ;;
    *)   log "$slug" fail "$rel_path"; broken="$broken $slug" ;;
  esac
done

if [ -n "$broken" ]; then
  printf 'microworld: bundle(s) broken by this edit:%s\n' "$broken" >&2
  printf 'see %s\n' "$audit" >&2
  exit 2
fi
exit 0
