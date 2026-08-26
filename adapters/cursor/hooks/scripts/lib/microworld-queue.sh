#!/usr/bin/env bash
# Queue management for async microworld rerun. Sourced (never executed).
# Simpler approach: store pending files per bundle, use process spawning.
set -euo pipefail

# enqueue_bundle <project_dir> <slug> <rel_path>
# Enqueues a bundle for async execution, coalescing pending requests.
enqueue_bundle() {
  local project_dir="$1" slug="$2" rel_path="$3"
  local queue_dir pending_file

  queue_dir="${project_dir}/.claude/microworld-queue"
  pending_file="${queue_dir}/${slug}.pending"

  mkdir -p "$queue_dir" 2>/dev/null || return 0

  # Coalesce: replace pending (to avoid queue unbounded growth)
  printf '%s\n' "$rel_path" > "$pending_file" 2>/dev/null || return 0
}

# start_async_runner <project_dir>
# Spawns a background runner if not already running.
start_async_runner() {
  local project_dir="$1"
  local queue_dir lock_file

  queue_dir="${project_dir}/.claude/microworld-queue"
  lock_file="${queue_dir}/.runner.lock"

  mkdir -p "$queue_dir" 2>/dev/null || return 0

  # Try to acquire lock
  if ! mkdir "$lock_file" 2>/dev/null; then
    # Runner already starting, don't spawn another
    return 0
  fi

  # Run the async executor in background
  (
    trap 'rmdir "$lock_file" 2>/dev/null || true' EXIT
    run_async_executor "$project_dir"
  ) >/dev/null 2>&1 &
}

# run_async_executor <project_dir>
# Processes all pending bundles in the queue and writes results to audit log.
run_async_executor() {
  local project_dir="$1"
  local queue_dir pending_file bundle_dir manifest slug audit

  queue_dir="${project_dir}/.claude/microworld-queue"
  audit="${project_dir}/.claude/microworld-audit.log"

  [ -d "$queue_dir" ] || return 0

  # Process each pending bundle
  for pending_file in "$queue_dir"/*.pending; do
    [ -f "$pending_file" ] || continue

    slug="$(basename "$pending_file" .pending)"
    bundle_dir="${project_dir}/microworlds/${slug}"
    manifest="${bundle_dir}/manifest.json"

    [ -f "$manifest" ] || continue
    [ -f "${bundle_dir}/run.sh" ] || continue

    # Read the pending file (the file that matched)
    rel_path=""
    if [ -s "$pending_file" ]; then
      rel_path="$(head -n1 "$pending_file")"
    fi

    [ -n "$rel_path" ] || continue
    [ -e "${project_dir}/${rel_path}" ] || continue

    # Run the bundle
    secs="$(jq -r '.timeoutSeconds // 60' "$manifest" 2>/dev/null || echo 60)"
    case "$secs" in ''|*[!0-9]*) secs=60 ;; esac

    rc=0
    ( cd "$project_dir" && timeout "$secs" bash "./microworlds/${slug}/run.sh" "$rel_path" ) \
      >/dev/null 2>&1 || rc=$?

    # Log result
    case "$rc" in
      0)
        printf '%s unit=%s result=pass file=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$slug" "$rel_path" >> "$audit" 2>/dev/null || true
        ;;
      124)
        printf '%s unit=%s result=timeout file=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$slug" "$rel_path" >> "$audit" 2>/dev/null || true
        ;;
      *)
        printf '%s unit=%s result=fail file=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$slug" "$rel_path" >> "$audit" 2>/dev/null || true
        ;;
    esac

    # Clean up pending file
    rm -f "$pending_file" 2>/dev/null || true
  done
}
