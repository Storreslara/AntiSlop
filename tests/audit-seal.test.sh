#!/usr/bin/env bash
# TDD suite for hooks/scripts/lib/audit-log.sh - audit_append, audit_seal_verify,
# audit_rotate. See docs/plans/2026-08-25-harness-trust-gaps.md Step 3, C3.3.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

source hooks/scripts/lib/audit-log.sh

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

# -- seal, append, verify -> ok --
log="$tmproot/a.log"
audit_append "$log" "line one"
audit_append "$log" "line two"
result="$(audit_seal_verify "$log")"
[ "$result" = ok ] && pass "seal, append, verify -> ok" || bad "expected ok, got $result"

# -- seal, truncate to 0 bytes, verify -> truncated --
log="$tmproot/b.log"
audit_append "$log" "line one"
: > "$log"
result="$(audit_seal_verify "$log")"
[ "$result" = truncated ] && pass "truncate to 0 bytes -> truncated" || bad "expected truncated, got $result"

# -- seal, delete the log, verify -> absent --
log="$tmproot/c.log"
audit_append "$log" "line one"
rm -f "$log"
result="$(audit_seal_verify "$log")"
[ "$result" = absent ] && pass "deleted log -> absent" || bad "expected absent, got $result"

# -- seal, delete the .seal, log non-empty -> missing-seal --
log="$tmproot/d.log"
audit_append "$log" "line one"
rm -f "${log}.seal"
result="$(audit_seal_verify "$log")"
[ "$result" = missing-seal ] && pass "deleted seal -> missing-seal" || bad "expected missing-seal, got $result"

# -- seal, rewrite line 1 in place, verify -> truncated --
log="$tmproot/e.log"
audit_append "$log" "line one"
audit_append "$log" "line two"
printf 'REWRITTEN\nline two\n' > "$log"
result="$(audit_seal_verify "$log")"
[ "$result" = truncated ] && pass "mid-file rewrite -> truncated" || bad "expected truncated, got $result"

# -- seal, append 10 lines without resealing -> ok (GUARD) --
log="$tmproot/f.log"
audit_append "$log" "line one"
for i in $(seq 1 10); do printf 'unsealed line %s\n' "$i" >> "$log"; done
result="$(audit_seal_verify "$log")"
[ "$result" = ok ] && pass "append without reseal -> ok (GUARD)" || bad "expected ok, got $result"

# -- audit_rotate, then verify -> ok, and new log's line 1 names the archive's sha256 --
log="$tmproot/rotate/review-audit.log"
mkdir -p "$(dirname "$log")"
audit_append "$log" "line one"
audit_append "$log" "line two"
old_hash="$(sha256sum "$log" | cut -d' ' -f1)"
audit_rotate "$log"
result="$(audit_seal_verify "$log")"
[ "$result" = ok ] && pass "audit_rotate, then verify -> ok (GUARD)" || bad "expected ok, got $result"
first_line="$(head -n 1 "$log")"
case "$first_line" in
  *"$old_hash"*) pass "rotated log's line 1 names the archive's sha256" ;;
  *) bad "rotated log's line 1 does not name the archive's sha256 (got: $first_line)" ;;
esac

# -- a log that never existed -> absent, not a crash --
result="$(audit_seal_verify "$tmproot/never-existed.log")"
[ "$result" = absent ] && pass "never-existed log -> absent" || bad "expected absent, got $result"

# -- a malformed .seal sidecar -> unverifiable --
log="$tmproot/g.log"
audit_append "$log" "line one"
printf 'not a seal\n' > "${log}.seal"
result="$(audit_seal_verify "$log")"
[ "$result" = unverifiable ] && pass "malformed seal -> unverifiable" || bad "expected unverifiable, got $result"

exit "$fail"
