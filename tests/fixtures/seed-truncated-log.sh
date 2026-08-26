#!/usr/bin/env bash
# Seeds <dir>/.claude/review-audit.log: sealed, then truncated to 0 bytes, so
# audit_seal_verify reports it "truncated". Used by C3.4 (bin/harness-integrity.sh).
set -euo pipefail
dir="$1"
mkdir -p "$dir/.claude"

lib_dir="$(cd "$(dirname "$0")/../.." && pwd)/hooks/scripts/lib"
source "${lib_dir}/audit-log.sh"

log="$dir/.claude/review-audit.log"
audit_append "$log" "2026-08-01T00:00:00Z cleared-by=reviewer"
audit_append "$log" "2026-08-02T00:00:00Z cleared-by=reviewer"
: > "$log"
