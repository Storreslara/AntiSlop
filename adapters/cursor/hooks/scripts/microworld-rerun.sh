#!/usr/bin/env bash
# CURSOR entry point over the shared microworld-rerun decision logic
# (generated from hooks/scripts/lib/microworld-rerun-core.sh - node
# bin/cli.js --update --force-render). Registered on `afterFileEdit`. Sets
# cursor's payload contract then sources the port-invariant core.
#
# Cursor payload differences: project dir from `.workspace_roots[0]`; the
# edited path is a TOP-LEVEL `.file_path` (not under `.tool_input`); the audit
# log lives under `.cursor/`. jq must be available just to extract
# project_dir/paths from the payload, so a missing jq exits here, before the
# core's own jq-availability log branch is ever reached.
set -euo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
audit="${project_dir}/.cursor/microworld-audit.log"
paths="$(echo "$input" | jq -r '.file_path // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/audit-log.sh"
source "${lib_dir}/microworld-rerun-core.sh"
