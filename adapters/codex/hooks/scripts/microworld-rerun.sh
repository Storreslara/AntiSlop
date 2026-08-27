#!/usr/bin/env bash
# CODEX entry point over the shared microworld-rerun decision logic
# (generated from hooks/scripts/lib/microworld-rerun-core.sh - node
# bin/cli.js --update --force-render). Registered on PostToolUse. Sets
# codex's payload contract then sources the port-invariant core.
#
# Codex payload differences: see graph-update.sh's header comment - project dir
# from `.cwd`, and the same UNVERIFIED file-path extraction (single-file keys,
# falling back to parsing apply_patch's patch-header format for potentially
# MULTIPLE paths per invocation). The audit log lives under `.codex/`. jq must
# be available just to extract project_dir/paths from the payload, so a
# missing jq exits here, before the core's own jq-availability log branch is
# ever reached.
#
# A bundle result line may additionally carry an optional trailing
# `authority=reviewer|self` field (never self-declarable), derived in
# lib/microworld-queue.sh from a matching, hash-verified
# .codex/reviewed/<slug>.countersign marker.
set -euo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
project_dir="$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo .)"
audit="${project_dir}/.codex/microworld-audit.log"

tool_name_lc="$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"

paths="$(echo "$input" | jq -r '[.tool_input.file_path, .tool_input.path, .tool_input.target_file, .tool_input.filePath] | map(select(. != null and . != "")) | .[]' 2>/dev/null || true)"
if [ -z "$paths" ]; then
  case "$tool_name_lc" in
    *apply*patch*)
      patch_text="$(echo "$input" | jq -r '.tool_input.input // .tool_input.patch // .tool_input.diff // .tool_input.content // empty' 2>/dev/null || true)"
      if [ -n "$patch_text" ]; then
        paths="$(printf '%s\n' "$patch_text" | grep -oE '^\*\*\* (Add|Update|Delete) File: .+' | sed -E 's/^\*\*\* (Add|Update|Delete) File: //' || true)"
      fi
      ;;
  esac
fi

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/audit-log.sh"
source "${lib_dir}/microworld-rerun-core.sh"
