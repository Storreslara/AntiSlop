#!/usr/bin/env bash
# One-off top-up runner: adds more reps to specific variants without
# re-running the ones that already have enough data. Unlike pilot.sh (which
# always starts at rep 1), this takes an explicit rep range so new rows
# append cleanly next to existing ones in eval/results.jsonl instead of
# colliding on rep numbers.
#
# Usage: VARIANTS="v1 v2" REP_START=3 REP_END=5 more-reps.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
read -ra VARIANTS <<< "${VARIANTS:?set VARIANTS="v1 v2"}"
REP_START="${REP_START:?set REP_START}"
REP_END="${REP_END:?set REP_END}"

for variant in "${VARIANTS[@]}"; do
  for rep in $(seq "$REP_START" "$REP_END"); do
    DEST="$REPO_ROOT/eval/.runs/${variant}-${rep}"
    echo "=== variant=$variant rep=$rep ==="
    PROJECT_NAME="$(bash "$REPO_ROOT/eval/harness/scaffold.sh" "$DEST" --force | tail -n1)"
    bash "$REPO_ROOT/eval/harness/apply-variant.sh" "$DEST" "$variant"
    bash "$REPO_ROOT/eval/harness/run.sh" "$DEST" feature-task "$variant" "$rep" "$PROJECT_NAME"
    bash "$REPO_ROOT/eval/harness/cleanup.sh" "$DEST"
  done
done

echo "=== more-reps complete ==="
