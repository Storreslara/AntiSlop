#!/usr/bin/env bash
# Blinded grading set for the judgment-graded item.
# Usage: blind.sh RESULTS_JSONL OUT_DIR [--eval ID]   build OUT_DIR/blind/<id>/ for each run
#        blind.sh --unseal OUT_DIR GRADES_CSV         print the per-arm tally after grading
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${1:-}" = "--unseal" ]; then
  shift
  exec python3 -I "$HERE/lib/blind.py" unseal "$@"
fi
exec python3 -I "$HERE/lib/blind.py" build "$@"
