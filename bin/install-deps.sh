#!/usr/bin/env bash
# Idempotent installer for AntiSlop's two optional third-party dependencies.
# Safe to re-run: each step no-ops if already satisfied.
# Usage: install-deps.sh [--only-graph|--only-mattpocock]
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
    echo "  /setup-personas step 4 rescopes it to explorer.md; don't skip that."
  fi
}

install_mattpocock() {
  echo "== mattpocock/skills (grill/TDD/diagnose/tracker skills some personas use) =="
  lockfile="$HOME/.agents/.skill-lock.json"
  if [ -f "$lockfile" ] && grep -q '"source":[[:space:]]*"mattpocock/skills"' "$lockfile"; then
    echo "  Already installed (found mattpocock/skills entries in $lockfile) — skipping."
  elif ! command -v npx >/dev/null 2>&1; then
    echo "  npx not found. Install Node.js >= 18, then re-run this script." >&2
    failed=1
  else
    echo "  Running: npx skills@latest add mattpocock/skills (interactive — you pick the skills)"
    if ! npx skills@latest add mattpocock/skills; then
      echo "  skills installer exited non-zero — re-run this script if that was unintended." >&2
      failed=1
    fi
  fi
}

case "$mode" in
  --only-graph)
    install_graph
    ;;
  --only-mattpocock)
    install_mattpocock
    ;;
  "")
    install_graph
    echo ""
    install_mattpocock
    ;;
  *)
    echo "Unknown argument: $mode (expected --only-graph, --only-mattpocock, or nothing)" >&2
    exit 1
    ;;
esac

echo ""
if [ "$failed" -ne 0 ]; then
  echo "Done, with failures above — fix those and re-run (already-satisfied steps are skipped)."
  exit 1
fi
echo "Done. Next: /setup-personas still records which skills you picked and"
echo "substitutes the <MATTPOCOCK:*> placeholders — run it in your project."
