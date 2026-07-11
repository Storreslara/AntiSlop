#!/usr/bin/env bash
# Drives the full pilot matrix: for each variant (including "baseline", the
# unmodified control), scaffold a fresh fixture, apply the variant, run the
# feature task REPS times. Appends one row per run to eval/results.jsonl via
# run.sh. Each run gets its own disposable scratch dir under eval/.runs/.
#
# Env overrides: REPS (default 2), VARIANTS (space-separated, default the
# full candidate list in docs/experiments/pilot-2026-07-11.md).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPS="${REPS:-2}"
read -ra VARIANTS <<< "${VARIANTS:-baseline lead-programmer-maxturns terse-reviewer trim-reviewer-comment review-packet explorer-maxturns-tight}"

for variant in "${VARIANTS[@]}"; do
  for rep in $(seq 1 "$REPS"); do
    DEST="$REPO_ROOT/eval/.runs/${variant}-${rep}"
    echo "=== variant=$variant rep=$rep/$REPS ==="
    PROJECT_NAME="$(bash "$REPO_ROOT/eval/harness/scaffold.sh" "$DEST" --force | tail -n1)"
    bash "$REPO_ROOT/eval/harness/apply-variant.sh" "$DEST" "$variant"
    bash "$REPO_ROOT/eval/harness/run.sh" "$DEST" feature-task "$variant" "$rep" "$PROJECT_NAME"
  done
done

echo "=== pilot matrix complete ==="
