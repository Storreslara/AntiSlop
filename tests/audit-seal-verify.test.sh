#!/usr/bin/env bash
# TDD suite for bin/audit-seal-verify.sh - the seal verification consumer
# added by docs/plans/2026-09-25-item15-seal-sidecars.md Step 2 (item15-2),
# closing the write-only gap item15-1 found in audit_seal_verify.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

source hooks/scripts/lib/audit-log.sh

verify_bin="$(pwd)/bin/audit-seal-verify.sh"
tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

# seed_project <dir> - four sealed logs, mirroring the real four names, but
# entirely inside a scratch tmpdir - never the live .claude/ logs.
seed_project() {
  local dir="$1"
  mkdir -p "$dir/.claude"
  for name in review-audit dispatch-audit microworld-audit wip-audit; do
    audit_append "$dir/.claude/${name}.log" "seeded line"
  done
}

# -- intact logs -> exit 0 --
proj="$tmproot/intact"
seed_project "$proj"
if out="$(bash "$verify_bin" "$proj" 2>&1)"; then
  pass "intact logs -> exit 0"
else
  bad "expected exit 0 on intact logs, got: $out"
fi

# -- mutate one log copy out-of-band (rewrite its sealed line, no reseal) --
# A plain append is intentionally NOT flagged - audit_seal_verify only hashes
# the first N sealed lines, so a writer that appends and has not yet
# resealed reads as ok by design (tests/audit-seal.test.sh's own GUARD case).
# A real mutation has to change content within the sealed region instead.
proj="$tmproot/mutated"
seed_project "$proj"
target="$proj/.claude/dispatch-audit.log"
original="$(cat "$target")"
printf 'TAMPERED LINE\n' > "$target"
if out="$(bash "$verify_bin" "$proj" 2>&1)"; then
  bad "expected non-zero on mutated log, got exit 0: $out"
else
  case "$out" in
    *dispatch-audit.log*) pass "mutated log -> non-zero, names the file" ;;
    *) bad "non-zero but did not name the file: $out" ;;
  esac
fi

# -- restore that same log -> exit 0 again --
printf '%s\n' "$original" > "$target"
_audit_reseal "$target"
if out="$(bash "$verify_bin" "$proj" 2>&1)"; then
  pass "restored log -> exit 0 again"
else
  bad "expected exit 0 after restore, got: $out"
fi

# -- a legitimate rotation round-trip must not false-positive --
proj="$tmproot/rotated"
seed_project "$proj"
audit_rotate "$proj/.claude/wip-audit.log"
if out="$(bash "$verify_bin" "$proj" 2>&1)"; then
  pass "rotation round-trip -> exit 0 (no false positive)"
else
  bad "expected exit 0 after legitimate rotation, got: $out"
fi

# -- a missing .seal on an existing, non-empty log copy is caught too --
proj="$tmproot/missingseal"
seed_project "$proj"
target="$proj/.claude/microworld-audit.log"
rm -f "${target}.seal"
if out="$(bash "$verify_bin" "$proj" 2>&1)"; then
  bad "expected non-zero when a .seal is missing, got exit 0: $out"
else
  case "$out" in
    *microworld-audit.log*) pass "missing seal -> non-zero, names the file" ;;
    *) bad "non-zero but did not name the file: $out" ;;
  esac
fi

exit "$fail"
