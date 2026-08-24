#!/usr/bin/env bash
# Fixture-driven test for bin/human-review-cleanup.sh - the manual sweep
# that deletes RESOLVED escalation packets under .claude/human-review/
# and never touches pending ones. Same idiom as tests/human-decision-gate.test.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

script="bin/human-review-cleanup.sh"

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

pass() { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }

# $1 = project dir name -> echoes path, seeds a pending and a resolved packet
mk_project() {
  local d="$tmproot/$1"
  mkdir -p "$d/.claude/human-review/pending-task"
  printf 'packet\n' > "$d/.claude/human-review/pending-task/PACKET.md"

  mkdir -p "$d/.claude/human-review/resolved-task"
  printf 'packet\n' > "$d/.claude/human-review/resolved-task/PACKET.md"
  printf 'DECISION resolved-task 2026-08-24T00:00:00Z route: approve escalation: 2026-08-20T00:00:00Z\nby: human\n' \
    > "$d/.claude/human-review/resolved-task/DECISION"

  echo "$d"
}

echo "-- apply mode: pending kept, resolved deleted --"
dir="$(mk_project apply)"
out="$("$script" --project-dir "$dir" --apply)"
if [ -d "$dir/.claude/human-review/pending-task" ]; then
  pass "pending packet not deleted under --apply"
else
  bad "pending packet was deleted under --apply"
fi
if [ ! -e "$dir/.claude/human-review/resolved-task" ]; then
  pass "resolved packet deleted under --apply"
else
  bad "resolved packet still exists after --apply"
fi
if echo "$out" | grep -qF 'deleted: .claude/human-review/resolved-task'; then
  pass "apply mode reports the deletion"
else
  bad "apply mode did not report the deletion (out=[$out])"
fi

echo
echo "-- dry-run (default): nothing deleted, resolved reported as candidate --"
dir="$(mk_project dryrun)"
out="$("$script" --project-dir "$dir")"
if [ -d "$dir/.claude/human-review/pending-task" ] && [ -d "$dir/.claude/human-review/resolved-task" ]; then
  pass "dry-run deletes nothing"
else
  bad "dry-run deleted a fixture packet"
fi
if echo "$out" | grep -qF '[dry-run] would delete: .claude/human-review/resolved-task'; then
  pass "dry-run reports the resolved packet as a delete candidate"
else
  bad "dry-run did not report the resolved packet (out=[$out])"
fi

echo
echo "-- grammar violation: skipped even with a valid-looking DECISION file --"
dir="$(mk_project badname)"
mkdir -p "$dir/.claude/human-review/..evil"
printf 'DECISION ..evil 2026-08-24T00:00:00Z route: approve escalation: 2026-08-20T00:00:00Z\nby: human\n' \
  > "$dir/.claude/human-review/..evil/DECISION"
"$script" --project-dir "$dir" --apply >/dev/null
if [ -d "$dir/.claude/human-review/..evil" ]; then
  pass "grammar-violating entry is skipped and never deleted"
else
  bad "grammar-violating entry was deleted"
fi

echo
echo "-- no .claude/human-review/ directory at all -> exit 0, no error --"
dir="$tmproot/nodir"
mkdir -p "$dir"
rc=0
"$script" --project-dir "$dir" --apply >/dev/null 2>"$tmproot/nodir.err" || rc=$?
if [ "$rc" = 0 ]; then
  pass "missing .claude/human-review/ exits 0"
else
  bad "missing .claude/human-review/ exited $rc (stderr=[$(cat "$tmproot/nodir.err")])"
fi

echo
echo "-- .claude/reviewed/<id>.escalated marker is untouched --"
dir="$(mk_project marker)"
mkdir -p "$dir/.claude/reviewed"
printf 'ESCALATED resolved-task 2026-08-20T00:00:00Z\n' > "$dir/.claude/reviewed/resolved-task.escalated"
"$script" --project-dir "$dir" --apply >/dev/null
if [ -f "$dir/.claude/reviewed/resolved-task.escalated" ]; then
  pass ".escalated marker untouched by cleanup"
else
  bad ".escalated marker was removed"
fi

echo
echo "-- DECISION is a directory: malformed entry skipped, sweep keeps going --"
dir="$(mk_project dirdecision)"
mkdir -p "$dir/.claude/human-review/dir-decision-task/DECISION"
rc=0
out="$("$script" --project-dir "$dir" --apply)" || rc=$?
if [ "$rc" = 0 ]; then
  pass "sweep does not abort when a DECISION path is a directory"
else
  bad "sweep aborted (rc=$rc) when a DECISION path is a directory (out=[$out])"
fi
if [ -d "$dir/.claude/human-review/dir-decision-task" ]; then
  pass "malformed entry with directory DECISION is left in place"
else
  bad "malformed entry with directory DECISION was deleted"
fi
if [ ! -e "$dir/.claude/human-review/resolved-task" ]; then
  pass "sibling resolved packet still deleted despite the malformed entry"
else
  bad "sibling resolved packet was NOT deleted (sweep likely aborted early)"
fi

echo
echo "-- DECISION is unreadable (mode 000): malformed entry skipped, sweep keeps going --"
dir="$(mk_project unreadable)"
mkdir -p "$dir/.claude/human-review/unreadable-decision-task"
printf 'DECISION unreadable-decision-task 2026-08-24T00:00:00Z route: approve escalation: 2026-08-20T00:00:00Z\nby: human\n' \
  > "$dir/.claude/human-review/unreadable-decision-task/DECISION"
chmod 000 "$dir/.claude/human-review/unreadable-decision-task/DECISION"
rc=0
out="$("$script" --project-dir "$dir" --apply)" || rc=$?
chmod 644 "$dir/.claude/human-review/unreadable-decision-task/DECISION" 2>/dev/null || true
if [ "$rc" = 0 ]; then
  pass "sweep does not abort when a DECISION file is unreadable"
else
  bad "sweep aborted (rc=$rc) when a DECISION file is unreadable (out=[$out])"
fi
if [ -d "$dir/.claude/human-review/unreadable-decision-task" ]; then
  pass "malformed entry with unreadable DECISION is left in place"
else
  bad "malformed entry with unreadable DECISION was deleted"
fi
if [ ! -e "$dir/.claude/human-review/resolved-task" ]; then
  pass "sibling resolved packet still deleted despite the unreadable DECISION"
else
  bad "sibling resolved packet was NOT deleted (sweep likely aborted early)"
fi

exit "$fail"
