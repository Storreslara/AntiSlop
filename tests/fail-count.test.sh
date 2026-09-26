#!/usr/bin/env bash
# Behavioral suite for bin/fail-count.sh (item12-2): a deterministic FAIL
# block count for a unit, given item12-1's append-not-truncate .fail format.
#
# Given a task-id, the command prints the integer FAIL-block count and
# exits 0: 0 for a unit with no .fail record, 1 for a single-block fixture,
# 2 for a two-block fixture.
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$(pwd)"
helper="$repo/bin/fail-count.sh"
writer="$repo/hooks/scripts/marker-write.sh"
fail=0

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

proj="$tmproot/proj1"
mkdir -p "$proj"
run_writer() { ( cd "$proj" && CLAUDE_PROJECT_DIR="$proj" "$writer" "$@" ); }

echo "-- no record ------------------------------------------------------------"
out="$("$helper" no-such-unit "$proj")"
if [ "$out" = "0" ]; then
  pass "no .fail record: prints 0"
else
  bad "no .fail record: expected 0, got [$out]"
fi

echo "-- one-block fixture ------------------------------------------------------"
run_writer FAIL unitA - 'Defect one' .claude/reviewed/unitA.fail
out="$("$helper" unitA "$proj")"
if [ "$out" = "1" ]; then
  pass "one-block fixture: prints 1"
else
  bad "one-block fixture: expected 1, got [$out]"
fi

echo "-- two-block fixture ------------------------------------------------------"
run_writer FAIL unitB - 'Defect one' .claude/reviewed/unitB.fail
run_writer FAIL unitB - 'Defect two' .claude/reviewed/unitB.fail
out="$("$helper" unitB "$proj")"
if [ "$out" = "2" ]; then
  pass "two-block fixture: prints 2"
else
  bad "two-block fixture: expected 2, got [$out]"
fi

exit "$fail"
