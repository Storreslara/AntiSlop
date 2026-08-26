#!/bin/bash
# AC-E2: protected-paths.sh correctly blocks protected paths and allows unprotected ones
# AC-E3: no scope creep - Bash payloads still exit 0 (Write/Edit only)

set -euo pipefail

export CLAUDE_PROJECT_DIR="."

# Test 1: Protected path should be blocked (exit 2)
echo "Test 1: Protected path (hooks/scripts/stop-gate.sh) should exit 2"
if echo '{"tool_input":{"file_path":"hooks/scripts/stop-gate.sh"}}' | bash hooks/scripts/protected-paths.sh >/dev/null 2>&1; then
  echo "  ✗ Failed: expected exit 2, got exit 0"
  exit 1
else
  exit_code=$?
  if [ $exit_code -eq 2 ]; then
    echo "  ✓ Correctly blocked with exit 2"
  else
    echo "  ✗ Failed: expected exit 2, got exit $exit_code"
    exit 1
  fi
fi

# Test 2: Another protected path
echo "Test 2: Protected path (hooks/scripts/task-gate.sh) should exit 2"
if echo '{"tool_input":{"file_path":"hooks/scripts/task-gate.sh"}}' | bash hooks/scripts/protected-paths.sh >/dev/null 2>&1; then
  echo "  ✗ Failed: expected exit 2, got exit 0"
  exit 1
else
  exit_code=$?
  if [ $exit_code -eq 2 ]; then
    echo "  ✓ Correctly blocked with exit 2"
  else
    echo "  ✗ Failed: expected exit 2, got exit $exit_code"
    exit 1
  fi
fi

# Test 3: Unprotected path should exit 0
echo "Test 3: Unprotected path (bin/cli.js) should exit 0"
if echo '{"tool_input":{"file_path":"bin/cli.js"}}' | bash hooks/scripts/protected-paths.sh >/dev/null 2>&1; then
  echo "  ✓ Correctly allowed with exit 0"
else
  exit_code=$?
  echo "  ✗ Failed: expected exit 0, got exit $exit_code"
  exit 1
fi

# Test 4: Pattern matching with wildcards
echo "Test 4: Protected pattern (.github/workflows/*) should match .github/workflows/validate.yml"
if echo '{"tool_input":{"file_path":".github/workflows/validate.yml"}}' | bash hooks/scripts/protected-paths.sh >/dev/null 2>&1; then
  echo "  ✗ Failed: expected exit 2, got exit 0"
  exit 1
else
  exit_code=$?
  if [ $exit_code -eq 2 ]; then
    echo "  ✓ Correctly blocked with exit 2"
  else
    echo "  ✗ Failed: expected exit 2, got exit $exit_code"
    exit 1
  fi
fi

# Test 5 (AC-E3): a Bash-shaped payload naming a protected path (no
# tool_input.file_path field) must exit 0 - the gate stays Write|Edit-only
# by matcher, not by an in-script tool-name filter.
echo "Test 5: Bash payload naming a protected path in its command should exit 0"
if echo '{"tool_input":{"command":"cat hooks/scripts/stop-gate.sh"}}' | bash hooks/scripts/protected-paths.sh >/dev/null 2>&1; then
  echo "  ✓ Correctly allowed with exit 0 (no scope creep into Bash)"
else
  exit_code=$?
  echo "  ✗ Failed: expected exit 0, got exit $exit_code"
  exit 1
fi

# Test 6: legacy string-shaped protectedPaths entries (pre-object-shape
# configs, still shipped by every already-adapted downstream project since
# --update preserves the field verbatim) must still deny.
echo "Test 6: legacy string-shaped protectedPaths config should still exit 2"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/.claude"
printf '{"protectedPaths":[".github/workflows/*","hooks/scripts/stop-gate.sh"]}' \
  > "$fixture_dir/.claude/persona-config.json"
if echo '{"tool_input":{"file_path":"hooks/scripts/stop-gate.sh"}}' \
  | CLAUDE_PROJECT_DIR="$fixture_dir" bash hooks/scripts/protected-paths.sh >/dev/null 2>&1; then
  echo "  ✗ Failed: expected exit 2, got exit 0"
  exit 1
else
  exit_code=$?
  if [ $exit_code -eq 2 ]; then
    echo "  ✓ Correctly blocked with exit 2"
  else
    echo "  ✗ Failed: expected exit 2, got exit $exit_code"
    exit 1
  fi
fi

echo ""
echo "✓ All AC-E2/AC-E3 tests passed"
