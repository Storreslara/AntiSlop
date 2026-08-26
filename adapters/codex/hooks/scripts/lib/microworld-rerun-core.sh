#!/usr/bin/env bash
# Port-invariant decision logic for microworld-rerun.sh, shared byte-for-byte
# by all three ports (Claude/codex/cursor) — hand-edit only here;
# adapters/*/hooks/scripts/lib/microworld-rerun-core.sh are generated copies
# (node bin/cli.js --update --force-render). Sourced, never executed.
#
# CONTRACT (Unit A — async rerun): "run and report" became "enqueue and
# return". Matching a file against watch globs (cheap, no subprocess) stays
# inline and synchronous; actually running a bundle/watch-map entry is
# deferred to hooks/scripts/lib/microworld-queue.sh's detached drain loop.
# Results are surfaced at the next Stop/SubagentStop by stop-gate.sh, with
# session-start.sh as a backstop. This hook itself always exits 0 now - it
# no longer knows the result at return time, so it cannot report broken vs.
# clean (see the header's own prior claim, "This is a REPORTER, not a
# gate" - the deferred reporting further downstream is what still gates).
#
# Caller contract (set before sourcing): project_dir, audit (absolute path to
# the port's own microworld-audit.log), paths (newline-separated candidate
# file path(s), already extracted from the port's own payload shape — zero,
# one, or many). On codex/cursor, project_dir extraction itself needs jq - a
# port whose payload can't be parsed exits in its own entry script, before
# this core (and before the jq-availability log line below could ever fire)
# is ever reached, matching that port's own current fail-open behavior.
set -euo pipefail

# Proceed if either microworlds/ or tests/watch-map.json exists
[ -d "${project_dir}/microworlds" ] || [ -f "${project_dir}/tests/watch-map.json" ] || exit 0

log() {
  # $1 = unit slug, $2 = result, $3 = file, $4 = optional reason
  local line
  line="$(date -u +%Y-%m-%dT%H:%M:%SZ) unit=$1 result=$2 file=$3"
  if [ "$#" -ge 4 ]; then line="$line reason=$4"; fi
  mkdir -p "$(dirname "$audit")" 2>/dev/null || true
  audit_append "$audit" "$line"
}

command -v jq >/dev/null 2>&1 || { log - error - no-jq; exit 0; }

[ -n "$paths" ] || exit 0

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${lib_dir}/microworld-queue.sh"

queue_dir_path="$(queue_dir "$audit")"
mkdir -p "$queue_dir_path" 2>/dev/null || { log - error - queue-unwritable; exit 0; }

any_enqueued=false

while IFS= read -r file_path; do
  [ -n "$file_path" ] || continue
  [ -e "$file_path" ] || continue

  # `watch` globs are project-root-relative; file_path is typically absolute,
  # so normalize before matching. rel_path is also what run.sh receives and
  # what the audit log records - run.sh's cwd is the project root.
  rel_path="$file_path"
  case "$rel_path" in
    "$project_dir"/*) rel_path="${rel_path#"$project_dir"/}" ;;
  esac

  # Check bundles (tier B)
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

    # Defer execution - dedup (coalescing) happens inside enqueue_bundle.
    enqueue_bundle "$project_dir" "$slug" "$rel_path" "$audit"
    any_enqueued=true
  done

  # Check watch-map (tier A) entries
  watchmap="${project_dir}/tests/watch-map.json"
  if [ -f "$watchmap" ]; then
    entries="$(jq -c '.entries[]? // empty' "$watchmap" 2>/dev/null)" || {
      log - error "$rel_path" malformed-watch-map
      continue
    }

    while IFS= read -r entry_json; do
      [ -n "$entry_json" ] || continue

      id="$(echo "$entry_json" | jq -r '.id // empty' 2>/dev/null)" || {
        log - error "$rel_path" malformed-watch-map
        continue
      }
      [ -n "$id" ] || continue

      globs="$(echo "$entry_json" | jq -r '.watch[]? // empty' 2>/dev/null)" || {
        log "$id" error "$rel_path" malformed-watch-map
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

      enqueue_watchmap "$project_dir" "$id" "$rel_path" "$audit"
      any_enqueued=true
    done <<< "$entries"
  fi
done <<< "$paths"

if [ "$any_enqueued" = true ]; then
  start_async_runner "$project_dir" "$audit"
fi

exit 0
