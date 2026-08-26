#!/usr/bin/env bash
# Async queue for microworld-rerun.sh (Unit A). Sourced, never executed.
# Port-invariant - hand-edit only here; adapters/*/hooks/scripts/lib/
# microworld-queue.sh are generated copies (node bin/cli.js --update
# --force-render).
#
# State under "<project_dir>/.claude/microworld-queue/":
#   <slug>.pending       - bundle rel_path awaiting a run (coalesced: a new
#                          enqueue just overwrites this file)
#   .wm.<id>.pending      - watch-map entry rel_path awaiting a run (same
#                          coalescing rule)
#   .runner.lock          - mkdir-lock; presence means a drain loop is active
#
# A SINGLE global drain loop processes every pending entry each time it is
# started. This is a stronger guarantee than "one worker per bundle" but
# still satisfies "at most one in-flight and one queued run per bundle"
# (AC-A5): only one drain loop can ever hold the lock, so a bundle is
# in-flight only while that loop is actively running it, and its pending
# file is a single coalesced slot. It also gives suite-level dedup (AC-A4)
# for free: every bundle enqueued from the same edit is drained by the same
# loop instance, sharing one memoizing-bash wrapper (see _memo_setup), so
# `bash tests/X.test.sh` invoked identically by several bundles' run.sh
# scripts actually executes once.
set -euo pipefail

# queue_dir <audit> - queue state lives alongside the port's OWN audit log
# (sibling "microworld-queue" dir under the same dot-dir: .claude/, .cursor/,
# or .codex/), never hardcoded to one port, since all three ports share this
# file byte-for-byte.
queue_dir() { echo "$(dirname "$1")/microworld-queue"; }

# enqueue_bundle <project_dir> <slug> <rel_path> <audit>
enqueue_bundle() {
  local qd; qd="$(queue_dir "$4")"
  mkdir -p "$qd" 2>/dev/null || return 0
  printf '%s\n' "$3" > "${qd}/${2}.pending" 2>/dev/null || return 0
}

# enqueue_watchmap <project_dir> <id> <rel_path> <audit>
enqueue_watchmap() {
  local qd; qd="$(queue_dir "$4")"
  mkdir -p "$qd" 2>/dev/null || return 0
  printf '%s\n' "$3" > "${qd}/.wm.${2}.pending" 2>/dev/null || return 0
}

# _memo_setup <memo_dir> - defines and exports a `bash` shell FUNCTION (per
# bash's documented lookup order, a function shadows the external command for
# a bare "bash ..." invocation, and `export -f` makes it visible to child
# bash processes too - this is how run.sh's own nested `bash tests/X.test.sh`
# calls get intercepted without ever touching PATH). Only that exact
# convention (every bundle's run.sh shells out to a suite this way) is
# memoized; every other invocation passes through via `command bash`, which
# bypasses function lookup entirely, so there is no recursion risk. A prior
# PATH-file-wrapper implementation of this same idea caused a real
# multi-minute hang under this repo's sandboxed shell (stale command-hash
# caching in forked subshells); the exported-function form was verified not
# to reproduce that failure mode before landing.
_memo_setup() {
  local memo_dir="$1"
  export MICROWORLD_MEMO_DIR="$memo_dir"
  mkdir -p "${memo_dir}/results"
  bash() {
    case "$1" in
      tests/*.test.sh)
        local key rc_file rc
        key="$(printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_')"
        rc_file="${MICROWORLD_MEMO_DIR}/results/${key}.rc"
        if [ -f "$rc_file" ]; then
          return "$(cat "$rc_file")"
        fi
        command bash "$@"
        rc=$?
        echo "$rc" > "$rc_file"
        return "$rc"
        ;;
    esac
    command bash "$@"
  }
  export -f bash
}

# _log_result <audit> <unit> <result> <rel_path>
_log_result() {
  printf '%s unit=%s result=%s file=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$2" "$3" "$4" >> "$1" 2>/dev/null || true
}

# _run_bundle <project_dir> <slug> <rel_path> <memo_dir> <audit>
_run_bundle() {
  local project_dir="$1" slug="$2" rel_path="$3" memo_dir="$4" audit="$5"
  local manifest="${project_dir}/microworlds/${slug}/manifest.json" secs rc
  [ -f "$manifest" ] || return 0
  [ -f "${project_dir}/microworlds/${slug}/run.sh" ] || return 0
  [ -e "${project_dir}/${rel_path}" ] || return 0
  secs="$(jq -r '.timeoutSeconds // 60' "$manifest" 2>/dev/null || echo 60)"
  case "$secs" in ''|*[!0-9]*) secs=60 ;; esac
  rc=0
  ( cd "$project_dir" && timeout "$secs" \
      bash "./microworlds/${slug}/run.sh" "$rel_path" ) >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0)   _log_result "$audit" "$slug" pass "$rel_path" ;;
    124) _log_result "$audit" "$slug" timeout "$rel_path" ;;
    *)   _log_result "$audit" "$slug" fail "$rel_path" ;;
  esac
}

# _run_watchmap <project_dir> <id> <rel_path> <audit>
_run_watchmap() {
  local project_dir="$1" id="$2" rel_path="$3" audit="$4"
  local watchmap="${project_dir}/tests/watch-map.json" entry_json secs run_commands rc
  [ -f "$watchmap" ] || return 0
  [ -e "${project_dir}/${rel_path}" ] || return 0
  entry_json="$(jq -c --arg id "$id" '.entries[]? | select(.id == $id)' "$watchmap" 2>/dev/null)" || return 0
  [ -n "$entry_json" ] || return 0
  secs="$(echo "$entry_json" | jq -r '.timeoutSeconds // 60' 2>/dev/null || echo 60)"
  case "$secs" in ''|*[!0-9]*) secs=60 ;; esac
  run_commands="$(echo "$entry_json" | jq -r '.run[]? // empty' 2>/dev/null)"
  rc=0
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    ( cd "$project_dir" && timeout "$secs" bash -c "$cmd" ) >/dev/null 2>&1 || rc=$?
    [ "$rc" = 0 ] || break
  done <<< "$run_commands"
  case "$rc" in
    0)   _log_result "$audit" "$id" pass "$rel_path" ;;
    124) _log_result "$audit" "$id" timeout "$rel_path" ;;
    *)   _log_result "$audit" "$id" fail "$rel_path" ;;
  esac
}

# _drain_loop <project_dir> <audit> - the detached background loop body.
_drain_loop() {
  local project_dir="$1" audit="$2" qd memo_dir found pending rel_path base id slug iterations
  qd="$(queue_dir "$audit")"
  memo_dir="$(mktemp -d)"
  _memo_setup "$memo_dir"
  iterations=0
  # Defensive cap - guards against an unforeseen bug turning this into an
  # infinite loop in a detached background process no one is watching. 1000
  # outer passes is far beyond any real coalescing scenario.
  while [ "$iterations" -lt 1000 ]; do
    iterations=$((iterations + 1))
    found=false
    # dotglob: watch-map pending files are named ".wm.<id>.pending" - a bare
    # "*.pending" glob does not match dotfiles by default and would silently
    # strand them (the glob expands once, before the loop body runs, so
    # disabling dotglob immediately below does not affect this iteration).
    shopt -s dotglob
    for pending in "$qd"/*.pending; do
      shopt -u dotglob
      [ -f "$pending" ] || continue
      found=true
      base="$(basename "$pending")"
      rel_path="$(head -n1 "$pending" 2>/dev/null || true)"
      rm -f "$pending" 2>/dev/null || true
      [ -n "$rel_path" ] || continue
      case "$base" in
        .wm.*.pending)
          id="${base#.wm.}"; id="${id%.pending}"
          _run_watchmap "$project_dir" "$id" "$rel_path" "$audit"
          ;;
        *)
          slug="${base%.pending}"
          _run_bundle "$project_dir" "$slug" "$rel_path" "$memo_dir" "$audit"
          ;;
      esac
    done
    [ "$found" = true ] || break
  done
  rm -rf "$memo_dir" 2>/dev/null || true
  rmdir "${qd}/.runner.lock" 2>/dev/null || true
}

# start_async_runner <project_dir> <audit> - idempotent: a no-op if a drain
# loop already holds the lock (it will pick up freshly-written pending files
# on its next pass, since it re-globs each outer iteration).
start_async_runner() {
  local project_dir="$1" audit="$2" qd
  qd="$(queue_dir "$audit")"
  mkdir -p "$qd" 2>/dev/null || return 0
  mkdir "${qd}/.runner.lock" 2>/dev/null || return 0
  ( _drain_loop "$project_dir" "$audit" ) >/dev/null 2>&1 &
}
