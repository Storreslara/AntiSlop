#!/usr/bin/env bash
# Port-invariant decision logic for lint-on-edit.sh, shared byte-for-byte by
# all three ports (Claude/codex/cursor) — hand-edit only here;
# adapters/*/hooks/scripts/lib/lint-on-edit-core.sh are generated copies
# (node bin/cli.js --update --force-render). Sourced, never executed.
#
# Caller contract (set before sourcing): config (absolute path to
# persona-config.json), paths (newline-separated candidate file path(s),
# already extracted from the port's own payload shape — zero, one, or many).
set -euo pipefail

[ -f "$config" ] || exit 0

lint_cmd="$(jq -r '.lintCommand // empty' "$config" 2>/dev/null || true)"
[ -n "$lint_cmd" ] || exit 0

[ -n "$paths" ] || exit 0

while IFS= read -r file_path; do
  [ -n "$file_path" ] || continue
  [ -e "$file_path" ] || continue
  # See graph-update-core.sh: file path is a positional parameter, never
  # string-interpolated into eval, so a crafted filename can't inject
  # commands.
  bash -c "$lint_cmd \"\$1\"" _ "$file_path" >/dev/null 2>&1 || true
done <<< "$paths"
exit 0
