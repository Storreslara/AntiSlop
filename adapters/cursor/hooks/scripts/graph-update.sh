#!/usr/bin/env bash
# CURSOR entry point over the shared graph-update decision logic (generated
# from hooks/scripts/lib/graph-update-core.sh - node bin/cli.js --update
# --force-render). Registered on `afterFileEdit`. Sets cursor's payload
# contract then sources the port-invariant core.
#
# Cursor payload differences: project dir from `.workspace_roots[0]`; the
# edited path is a TOP-LEVEL `.file_path` on the afterFileEdit payload (not
# nested under `.tool_input`).
set -euo pipefail

input="$(cat)"
project_dir="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // "."' 2>/dev/null || echo .)"
config="${project_dir}/.cursor/persona-config.json"
paths="$(echo "$input" | jq -r '.file_path // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/graph-update-core.sh"
