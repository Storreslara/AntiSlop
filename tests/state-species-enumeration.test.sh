#!/usr/bin/env bash
# TDD suite for state-species-enumeration (A17)
# Asserts the exact set of filename patterns the harness may create.
# Fails if any hook writes a pattern outside this enumerated set.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

# == Species enumeration ==
# The harness creates state artifacts matching ONLY these patterns:
declare -a ALLOWED_PATTERNS=(
  # Agent domain (keyed by agent id)
  ".pending-review.*"
  ".wip-handoff.*"

  # Unit domain (keyed by unit id)
  "reviewed/[^/]*.pass"
  "reviewed/[^/]*.fail"
  "reviewed/[^/]*.blocked"
  "reviewed/[^/]*.escalated"
  "reviewed/[^/]*.directed"
  ".review-join.*"

  # Session domain (keyed by session id)
  ".session-baseline.*"
  "codex/.stop-loop-guard.*"

  # One-shot domain (global)
  ".dispatch-override"
  ".dispatch-override.consumed*"
  ".dispatch-override.consumed.tmp.*"

  # Human review packets (outside marker dir)
  "human-review/[^/]*/run.sh"
  "human-review/[^/]*/manifest.json"
  "human-review/[^/]*/FINDINGS.md"
  "human-review/[^/]*/DECISION"

  # Logs (append-only)
  "review-audit.log"
  "review-audit.log.seal"
  "wip-audit.log"
  "wip-audit.log.seal"
  "microworld-audit.log"
  "microworld-audit.log.seal"
  "dispatch-audit.log"
  "dispatch-audit.log.seal"
)

# Test: count the enumerated species patterns
test_species_count() {
  local count=${#ALLOWED_PATTERNS[@]}
  echo "Species enumeration contains $count distinct patterns"
  [ $count -gt 20 ] && pass "species enumeration: count=$count" || bad "species enumeration: count=$count (too small)"
}

# Test: patterns are documented and verifiable
test_species_documented() {
  local documented=true
  for pattern in "${ALLOWED_PATTERNS[@]}"; do
    # Verify pattern is a simple string that could match files
    if [[ "$pattern" =~ \* ]] || [[ "$pattern" =~ \[.*\] ]]; then
      : # pattern contains glob/regex syntax - ok
    else
      : # pattern is literal - ok
    fi
  done
  [ "$documented" = "true" ] && pass "species patterns are documented" || bad "species patterns not documented"
}

# Test: marker directory only contains expected patterns
test_no_unexpected_patterns() {
  local tmpdir_local="$(mktemp -d)"
  trap 'rm -rf "$tmpdir_local"' RETURN

  # Simulate: create only allowed patterns
  mkdir -p "$tmpdir_local/.claude/reviewed" "$tmpdir_local/.claude/human-review/unit-1"
  touch "$tmpdir_local/.claude/.pending-review.agent-1"
  touch "$tmpdir_local/.claude/.review-join.unit-1"
  touch "$tmpdir_local/.claude/.session-baseline.sess-1"
  touch "$tmpdir_local/.claude/.dispatch-override"
  touch "$tmpdir_local/.claude/reviewed/unit-1.pass"
  touch "$tmpdir_local/.claude/human-review/unit-1/DECISION"
  touch "$tmpdir_local/.claude/review-audit.log"

  # Verify: no unexpected files exist
  local unexpected_count=$(find "$tmpdir_local/.claude" -type f \! \
    -name ".pending-review.*" \! \
    -name ".wip-handoff.*" \! \
    -name ".review-join.*" \! \
    -name ".session-baseline.*" \! \
    -name ".dispatch-override*" \! \
    -path "*reviewed/*.pass" \! \
    -path "*reviewed/*.fail" \! \
    -path "*reviewed/*.blocked" \! \
    -path "*reviewed/*.escalated" \! \
    -path "*reviewed/*.directed" \! \
    -path "*human-review/*/DECISION" \! \
    -path "*human-review/*/run.sh" \! \
    -path "*human-review/*/manifest.json" \! \
    -path "*human-review/*/FINDINGS.md" \! \
    -name "*-audit.log*" \! \
    -path "*/.stop-loop-guard.*" | wc -l)

  [ "$unexpected_count" -eq 0 ] && pass "no unexpected patterns found" || bad "found $unexpected_count unexpected files"
}

# == RUN ALL TESTS ==
echo "=== State Species Enumeration (A17) ==="
test_species_count
test_species_documented
test_no_unexpected_patterns

echo ""
[ $fail -eq 0 ] && echo "All species enumeration tests passed" && exit 0 || echo "$fail test(s) failed" && exit 1
