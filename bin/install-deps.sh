#!/usr/bin/env bash
# Idempotent installer for AntiSlop's optional third-party dependency.
# Safe to re-run: each step no-ops if already satisfied.
# Usage: install-deps.sh [--only-graph]
set -euo pipefail

mode="${1:-}"
failed=0

install_graph() {
  echo "== code-review-graph (explorer's blast-radius/dependency MCP) =="
  if command -v code-review-graph >/dev/null 2>&1; then
    echo "  Already installed ($(command -v code-review-graph)) — skipping."
  elif ! command -v pipx >/dev/null 2>&1; then
    echo "  pipx not found. Install pipx first (e.g. 'sudo apt install pipx' or" >&2
    echo "  'python3 -m pip install --user pipx'), then re-run this script." >&2
    failed=1
  else
    echo "  Running: pipx install code-review-graph"
    pipx install code-review-graph
    echo "  Running: code-review-graph install --platform claude-code"
    code-review-graph install --platform claude-code
    echo "  Installed. Note: it registers PROJECT-WIDE in .mcp.json by default —"
    echo "  /install-antislop step 4 rescopes it to explorer.md; don't skip that."
  fi
}

case "$mode" in
  --only-graph)
    install_graph
    ;;
  "")
    install_graph
    ;;
  *)
    echo "Unknown argument: $mode (expected --only-graph or nothing)" >&2
    exit 1
    ;;
esac

echo ""
if [ "$failed" -ne 0 ]; then
  echo "Done, with failures above — fix those and re-run (already-satisfied steps are skipped)."
  exit 1
fi
echo "Done."
