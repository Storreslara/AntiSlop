#!/usr/bin/env bash
# Tests for bin/marker-commit-audit.sh — enumerate .pass markers and report
# per-state counts and mismatches. Read-only inspection only; no writes to
# .claude/reviewed/ under any circumstance.

set -uo pipefail

# Helpers
setup_fixture() {
  # Create a temporary project with:
  # - a git repo with 3 commits, each naming a different unit
  # - a temporary .claude/reviewed/ fixture with markers citing various commits

  local tmpdir="$1"
  local git_dir="$tmpdir/project"
  local reviewed_dir="$tmpdir/project/.claude/reviewed"

  mkdir -p "$git_dir" "$reviewed_dir"
  cd "$git_dir"

  # Initialize git repo
  git init
  git config user.email "test@example.com"
  git config user.name "Test"

  # Commit 1: unit-1's work
  echo "stub" > file.txt
  git add file.txt
  git commit -m "feat(gh100): implement unit-1"
  local sha1=$(git rev-parse HEAD)

  # Commit 2: unit-2's work
  echo "stub2" > file2.txt
  git add file2.txt
  git commit -m "feat(gh101): implement unit-2"
  local sha2=$(git rev-parse HEAD)

  # Commit 3: unit-3's work
  echo "stub3" > file3.txt
  git add file3.txt
  git commit -m "feat(gh102): implement unit-3"
  local sha3=$(git rev-parse HEAD)

  # Create markers:
  # - unit-1.pass: correctly cites sha1 (ok)
  printf 'PASS unit-1 2026-08-16T12:00:00Z commit: %s criteria: test\n' "$sha1" > "$reviewed_dir/unit-1.pass"

  # - unit-2.pass: cites sha1 instead of sha2 (mismatch)
  printf 'PASS unit-2 2026-08-16T12:00:00Z commit: %s criteria: test\n' "$sha1" > "$reviewed_dir/unit-2.pass"

  # - unit-3.pass: cites sha3 (ok)
  printf 'PASS unit-3 2026-08-16T12:00:00Z commit: %s criteria: test\n' "$sha3" > "$reviewed_dir/unit-3.pass"

  # - unit-4.pass: cites commit: none (unverifiable)
  printf 'PASS unit-4 2026-08-16T12:00:00Z commit: none criteria: test\n' > "$reviewed_dir/unit-4.pass"

  # - no-commit.pass: no commit: field (unverifiable)
  printf 'PASS no-commit 2026-08-16T12:00:00Z criteria: test\n' > "$reviewed_dir/no-commit.pass"

  echo "$tmpdir"
}

# Test 1: audit output has correct counts
test_counts_output() {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  setup_fixture "$tmpdir"
  local output
  output=$("$PROJECT_ROOT/bin/marker-commit-audit.sh" "$tmpdir/project")

  # First line should be the summary counts
  local summary_line
  summary_line=$(echo "$output" | head -1)

  # Extract counts
  local ok_count mismatch_count unverifiable_count
  ok_count=$(echo "$summary_line" | grep -oP 'ok=\K[0-9]+')
  mismatch_count=$(echo "$summary_line" | grep -oP 'mismatch=\K[0-9]+')
  unverifiable_count=$(echo "$summary_line" | grep -oP 'unverifiable=\K[0-9]+')

  # Verify counts match expectations
  test "$ok_count" = "2" || {
    echo "FAIL: expected ok=2, got ok=$ok_count"
    echo "Output: $output"
    return 1
  }
  test "$mismatch_count" = "1" || {
    echo "FAIL: expected mismatch=1, got mismatch=$mismatch_count"
    echo "Output: $output"
    return 1
  }
  test "$unverifiable_count" = "2" || {
    echo "FAIL: expected unverifiable=2, got unverifiable=$unverifiable_count"
    echo "Output: $output"
    return 1
  }

  echo "✓ counts output test passed"
}

# Test 2: audit reports mismatch lines
test_mismatch_reporting() {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  setup_fixture "$tmpdir"
  local output
  output=$("$PROJECT_ROOT/bin/marker-commit-audit.sh" "$tmpdir/project")

  # Output should contain a line about unit-2 (the mismatch)
  echo "$output" | grep -q "unit-2" || {
    echo "FAIL: expected mismatch line for unit-2"
    echo "Output: $output"
    return 1
  }

  echo "✓ mismatch reporting test passed"
}

# Test 3: audit performs NO writes to .claude/reviewed/
test_no_writes() {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  setup_fixture "$tmpdir"
  local reviewed_dir="$tmpdir/project/.claude/reviewed"

  # Create sentinel file before audit
  local sentinel="$tmpdir/sentinel"
  touch "$sentinel"

  # Run audit
  "$PROJECT_ROOT/bin/marker-commit-audit.sh" "$tmpdir/project" > /dev/null

  # Check if any file under .claude/reviewed/ is newer than sentinel
  local newer_files
  newer_files=$(find "$reviewed_dir" -newer "$sentinel" 2>/dev/null || true)

  test -z "$newer_files" || {
    echo "FAIL: audit wrote to .claude/reviewed/"
    echo "Files newer than sentinel: $newer_files"
    return 1
  }

  echo "✓ no-writes test passed"
}

# Main
PROJECT_ROOT="${1:-.}"
test "$PROJECT_ROOT" != "." || PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Running marker-commit-audit tests..."
test_counts_output || exit 1
test_mismatch_reporting || exit 1
test_no_writes || exit 1

echo "All tests passed"
exit 0
