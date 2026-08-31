#!/usr/bin/env bash
# PostToolUse (Edit|Write). Claude entry point over the shared microworld-
# rerun decision logic (hooks/scripts/lib/microworld-rerun-core.sh) — sets
# Claude's payload contract (project dir from $CLAUDE_PROJECT_DIR, dot-dir
# .claude/, single tool_input.file_path) then sources the port-invariant
# core. REPORTER, not a gate: see the core's own header for the exit-code
# contract (2 only on a real bundle failure/timeout, 0 on infrastructure
# problems and on success).
#
# The audit log line format (<timestamp> unit=<slug> result=<pass|fail|timeout|error> file=<path>)
# is a consumed interface with a Node.js parser (bin/dashboard/audit-log.js) on the other side.
# Contract test: tests/microworld-audit-contract.test.js. Do not change the separator or format
# without updating the parser and re-running the contract test.
#
# A bundle result line may additionally carry an optional trailing
# `authority=reviewer|self` field (never self-declarable), derived in
# lib/microworld-queue.sh from a matching, hash-verified
# .claude/reviewed/<slug>.countersign marker.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/state-access.sh"

input="$(cat)"
project_dir="${CLAUDE_PROJECT_DIR:-.}"
audit="${project_dir}/.claude/microworld-audit.log"
paths="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "${lib_dir}/audit-log.sh"
source "${lib_dir}/microworld-rerun-core.sh"
