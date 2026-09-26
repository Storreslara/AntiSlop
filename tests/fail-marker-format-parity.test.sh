#!/usr/bin/env bash
# Behavioral suite proving format parity between the two .fail write paths
# (item12-4, C4.6): the reviewer's documented sanctioned-heredoc literal, and
# hooks/scripts/marker-write.sh (item12-1). Both must produce a
# bin/fail-count.sh-countable, chronologically-appended .fail record with the
# same block shape.
#
# Per ADR-0028, every fixture lives under a scratch mktemp -d "dot", never
# the real .claude/reviewed - reviewed-path-gate.sh blocks lead-programmer
# from that path on both the Bash and Write/Edit routes, and
# tests/marker-write.test.sh has leaked fixtures into the real directory once
# already.
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$(pwd)"
writer="$repo/hooks/scripts/marker-write.sh"
counter="$repo/bin/fail-count.sh"
fail=0

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

proj="$tmproot/proj1"
mkdir -p "$proj/.claude/reviewed"

# unit A: apply the documented reviewer heredoc literal (agents/reviewer.md's
# "On FAIL" bullet) twice.
( cd "$proj" && cat >> .claude/reviewed/unitA.fail <<'EOF'
FAIL unitA 2026-01-01T00:00:00Z
Defect one

EOF
)
( cd "$proj" && cat >> .claude/reviewed/unitA.fail <<'EOF'
FAIL unitA 2026-01-02T00:00:00Z
Defect two

EOF
)

# unit B: apply marker-write.sh (item12-1's helper) twice.
run_writer() { ( cd "$proj" && CLAUDE_PROJECT_DIR="$proj" "$writer" "$@" ); }
run_writer FAIL unitB - 'Defect one' .claude/reviewed/unitB.fail
run_writer FAIL unitB - 'Defect two' .claude/reviewed/unitB.fail

fileA="$proj/.claude/reviewed/unitA.fail"
fileB="$proj/.claude/reviewed/unitB.fail"

countA="$("$counter" unitA "$proj")"
countB="$("$counter" unitB "$proj")"
[ "$countA" = "2" ] && pass "heredoc path: fail-count.sh prints 2" \
  || bad "heredoc path: expected 2, got [$countA]"
[ "$countB" = "2" ] && pass "marker-write.sh path: fail-count.sh prints 2" \
  || bad "marker-write.sh path: expected 2, got [$countB]"

blanksA="$(grep -c '^$' "$fileA")"
blanksB="$(grep -c '^$' "$fileB")"
[ "$blanksA" = "$blanksB" ] \
  && pass "blank-line block separators match ($blanksA)" \
  || bad "blank-line counts differ: heredoc=$blanksA marker-write.sh=$blanksB"

firstA="$(head -n1 "$fileA")"
firstB="$(head -n1 "$fileB")"
case "$firstA" in
  "FAIL unitA "*) pass "heredoc path: line 1 is still the first block's anchor" ;;
  *) bad "heredoc path: line 1 changed after second append: [$firstA]" ;;
esac
case "$firstB" in
  "FAIL unitB "*) pass "marker-write.sh path: line 1 is still the first block's anchor" ;;
  *) bad "marker-write.sh path: line 1 changed after second append: [$firstB]" ;;
esac

exit "$fail"
