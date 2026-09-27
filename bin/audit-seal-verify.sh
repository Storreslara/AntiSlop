#!/usr/bin/env bash
# Seal-verification consumer (docs/plans/2026-09-25-item15-seal-sidecars.md
# Step 2, item15-2) - closes the write-only gap item15-1 found: audit_seal_
# verify's result was computed by bin/harness-integrity.sh but never checked
# by anything. Reads that script's logs= field and turns it into a real exit
# code: 0 when every sealed log verifies ok, non-zero naming each bad file
# otherwise.
#
# Usage: audit-seal-verify.sh [project-dir]
set -euo pipefail

project_dir="${1:-.}"
script_dir="$(cd "$(dirname "$0")" && pwd)"

report="$("${script_dir}/harness-integrity.sh" "$project_dir")"
logs_field="${report##*logs=}"

if [ "$logs_field" = ok ]; then
  echo "audit-seal-verify: ok"
  exit 0
fi

echo "audit-seal-verify: FAIL - ${logs_field}" >&2
exit 1
