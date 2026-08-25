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
if [ "$(id -u)" = "0" ]; then
  echo "SKIP root ignores permission bits; mode-000 unreadable-DECISION test skipped"
else
  dir="$(mk_project unreadable)"
  # Named to sort BEFORE "resolved-task" in glob order, so the sibling
  # assertion below is only satisfied if the sweep actually keeps going
  # past this malformed entry (not merely because glob order already
  # deleted resolved-task first).
  mkdir -p "$dir/.claude/human-review/0-unreadable-decision-task"
  printf 'DECISION 0-unreadable-decision-task 2026-08-24T00:00:00Z route: approve escalation: 2026-08-20T00:00:00Z\nby: human\n' \
    > "$dir/.claude/human-review/0-unreadable-decision-task/DECISION"
  chmod 000 "$dir/.claude/human-review/0-unreadable-decision-task/DECISION"
  rc=0
  out="$("$script" --project-dir "$dir" --apply)" || rc=$?
  chmod 644 "$dir/.claude/human-review/0-unreadable-decision-task/DECISION" 2>/dev/null || true
  if [ "$rc" = 0 ]; then
    pass "sweep does not abort when a DECISION file is unreadable"
  else
    bad "sweep aborted (rc=$rc) when a DECISION file is unreadable (out=[$out])"
  fi
  if [ -d "$dir/.claude/human-review/0-unreadable-decision-task" ]; then
    pass "malformed entry with unreadable DECISION is left in place"
  else
    bad "malformed entry with unreadable DECISION was deleted"
  fi
  if [ ! -e "$dir/.claude/human-review/resolved-task" ]; then
    pass "sibling resolved packet still deleted despite the unreadable DECISION"
  else
    bad "sibling resolved packet was NOT deleted (sweep likely aborted early)"
  fi
fi

echo
echo "-- DECISION is a FIFO: [ -f ] rejects it, sweep completes without hanging --"
dir="$(mk_project fifo)"
mkdir -p "$dir/.claude/human-review/fifo-decision-task"
mkfifo "$dir/.claude/human-review/fifo-decision-task/DECISION"
rc=0
out="$(timeout 5 "$script" --project-dir "$dir" --apply)" || rc=$?
if [ "$rc" = 0 ]; then
  pass "sweep completes (does not hang) when DECISION is a FIFO"
else
  bad "sweep did not complete cleanly with a FIFO DECISION (rc=$rc, out=[$out])"
fi
if [ -d "$dir/.claude/human-review/fifo-decision-task" ]; then
  pass "FIFO entry treated as pending/skipped, not deleted"
else
  bad "FIFO entry was deleted"
fi

echo
echo "-- marker sweep: dry-run reports, --apply deletes, respects retention window --"
dir="$(mk_project marker-sweep)"
mkdir -p "$dir/.claude/reviewed"
# Marker older than retention window (set timestamp to 40 days ago)
old_time=$(( $(date +%s) - 40 * 86400 ))
printf 'PASS 100 2026-07-20T00:00:00Z commit: abc123 criteria: test\n' > "$dir/.claude/reviewed/100.pass"
touch -t "$(date -d @$old_time +%Y%m%d%H%M.%S)" "$dir/.claude/reviewed/100.pass"
# Recent marker (within retention window)
printf 'PASS 101 2026-08-24T00:00:00Z commit: def456 criteria: test\n' > "$dir/.claude/reviewed/101.pass"
# Marker with fail (also old)
printf 'FAIL 102 2026-07-15T00:00:00Z\ndefect: test\n' > "$dir/.claude/reviewed/102.fail"
touch -t "$(date -d @$old_time +%Y%m%d%H%M.%S)" "$dir/.claude/reviewed/102.fail"

out="$("$script" --project-dir "$dir" --retention-days 30)"
if echo "$out" | grep -qF '[dry-run] would delete:'; then
  pass "marker dry-run reports deletions"
else
  bad "marker dry-run did not report deletions (out=[$out])"
fi
if [ -f "$dir/.claude/reviewed/100.pass" ] && [ -f "$dir/.claude/reviewed/101.pass" ] && [ -f "$dir/.claude/reviewed/102.fail" ]; then
  pass "marker dry-run deletes nothing"
else
  bad "marker dry-run deleted files"
fi

# Now test --apply
"$script" --project-dir "$dir" --retention-days 30 --apply >/dev/null
if [ ! -f "$dir/.claude/reviewed/100.pass" ] && [ ! -f "$dir/.claude/reviewed/102.fail" ]; then
  pass "old markers deleted under --apply with retention window"
else
  bad "old markers not deleted (100.pass exists=$([ -f "$dir/.claude/reviewed/100.pass" ] && echo yes || echo no), 102.fail exists=$([ -f "$dir/.claude/reviewed/102.fail" ] && echo yes || echo no))"
fi
if [ -f "$dir/.claude/reviewed/101.pass" ]; then
  pass "recent marker (within retention window) preserved"
else
  bad "recent marker was deleted"
fi

echo
echo "-- marker sweep: marker NOT deleted if review-join stamp exists --"
dir="$(mk_project marker-review-join)"
mkdir -p "$dir/.claude/reviewed"
old_time=$(( $(date +%s) - 40 * 86400 ))
printf 'PASS 150 2026-07-01T00:00:00Z commit: abc123 criteria: test\n' > "$dir/.claude/reviewed/150.pass"
touch -t "$(date -d @$old_time +%Y%m%d%H%M.%S)" "$dir/.claude/reviewed/150.pass"
# Create review-join stamp for this unit
touch "$dir/.claude/.review-join.150"
# Same-age control marker with no stamp -> must still be deleted, proving
# the aged-150.pass survival above is actually due to the stamp and not
# just retention leaving everything alone.
printf 'PASS 151 2026-07-01T00:00:00Z commit: def456 criteria: test\n' > "$dir/.claude/reviewed/151.pass"
touch -t "$(date -d @$old_time +%Y%m%d%H%M.%S)" "$dir/.claude/reviewed/151.pass"

"$script" --project-dir "$dir" --retention-days 30 --apply >/dev/null
if [ -f "$dir/.claude/reviewed/150.pass" ]; then
  pass "marker with active review-join stamp is not deleted"
else
  bad "marker was deleted even with review-join stamp"
fi
if [ ! -f "$dir/.claude/reviewed/151.pass" ]; then
  pass "same-age unstamped control marker is deleted (proves stamp path is exercised)"
else
  bad "unstamped control marker was not deleted"
fi

echo
echo "-- session-baseline sweep: dry-run reports, --apply deletes --"
dir="$(mk_project session-baseline)"
mkdir -p "$dir/.claude"
old_time=$(( $(date +%s) - 40 * 86400 ))
# Old baseline
printf '{}' > "$dir/.claude/.session-baseline.old-id-from-2026-07"
touch -t "$(date -d @$old_time +%Y%m%d%H%M.%S)" "$dir/.claude/.session-baseline.old-id-from-2026-07"
# Recent baseline
printf '{}' > "$dir/.claude/.session-baseline.recent-id-from-2026-08"

out="$("$script" --project-dir "$dir" --retention-days 30)"
if echo "$out" | grep -qF '[dry-run] would delete: .claude/.session-baseline.old-id-from-2026-07'; then
  pass "session-baseline dry-run reports the old fixture as a delete candidate"
else
  bad "session-baseline dry-run did not report a delete line (out=[$out])"
fi
if [ -f "$dir/.claude/.session-baseline.old-id-from-2026-07" ] && [ -f "$dir/.claude/.session-baseline.recent-id-from-2026-08" ]; then
  pass "session-baseline dry-run deletes nothing"
else
  bad "session-baseline dry-run deleted files"
fi

"$script" --project-dir "$dir" --retention-days 30 --apply >/dev/null
if [ ! -f "$dir/.claude/.session-baseline.old-id-from-2026-07" ]; then
  pass "old session-baseline deleted under --apply"
else
  bad "old session-baseline not deleted under --apply"
fi
if [ -f "$dir/.claude/.session-baseline.recent-id-from-2026-08" ]; then
  pass "recent session-baseline preserved under --apply"
else
  bad "recent session-baseline was deleted under --apply"
fi

echo
echo "-- wip-handoff sweep: dry-run reports, --apply deletes --"
dir="$(mk_project wip-handoff)"
mkdir -p "$dir/.claude"
old_time=$(( $(date +%s) - 40 * 86400 ))
# Old handoff
printf 'reason: test' > "$dir/.claude/wip-handoff.old-id"
touch -t "$(date -d @$old_time +%Y%m%d%H%M.%S)" "$dir/.claude/wip-handoff.old-id"
# Recent handoff
printf 'reason: test' > "$dir/.claude/wip-handoff.recent-id"

out="$("$script" --project-dir "$dir" --retention-days 30)"
if echo "$out" | grep -qF '[dry-run] would delete: .claude/wip-handoff.old-id'; then
  pass "wip-handoff dry-run reports the old fixture as a delete candidate"
else
  bad "wip-handoff dry-run did not report a delete line (out=[$out])"
fi
if [ -f "$dir/.claude/wip-handoff.old-id" ] && [ -f "$dir/.claude/wip-handoff.recent-id" ]; then
  pass "wip-handoff dry-run deletes nothing"
else
  bad "wip-handoff dry-run deleted files"
fi

"$script" --project-dir "$dir" --retention-days 30 --apply >/dev/null
if [ ! -f "$dir/.claude/wip-handoff.old-id" ]; then
  pass "old wip-handoff deleted under --apply"
else
  bad "old wip-handoff not deleted under --apply"
fi
if [ -f "$dir/.claude/wip-handoff.recent-id" ]; then
  pass "recent wip-handoff preserved under --apply"
else
  bad "recent wip-handoff was deleted under --apply"
fi

echo
echo "-- log rotation preserves tail for defer: dedup --"
dir="$(mk_project log-rotation)"
mkdir -p "$dir/.claude"
# Create a log with multiple lines including a defer: at the end
printf '2026-08-20T10:00:00Z cleared-by=reviewer unit=100\n' > "$dir/.claude/review-audit.log"
printf '2026-08-21T10:00:00Z defer: unit=101 reason=test\n' >> "$dir/.claude/review-audit.log"

# Make the log old enough to be rotated (40 days ago)
old_time=$(( $(date +%s) - 40 * 86400 ))
touch -t "$(date -d @$old_time +%Y%m%d%H%M.%S)" "$dir/.claude/review-audit.log"

# Get the last line before rotation
last_before="$(tail -n 1 "$dir/.claude/review-audit.log")"
# Extract the content part (after timestamp) like stop-gate.sh does
last_content_before="$(tail -n 1 "$dir/.claude/review-audit.log" | cut -d' ' -f2-)"

# Run the sweeper which should rotate the log
"$script" --project-dir "$dir" --retention-days 30 --apply >/dev/null 2>&1

# Check that active log still exists
if [ -f "$dir/.claude/review-audit.log" ]; then
  pass "review-audit.log exists after rotation"
else
  bad "review-audit.log was deleted after rotation"
fi

# Check that the tail is preserved (for the dedup logic)
last_content_after="$(tail -n 1 "$dir/.claude/review-audit.log" 2>/dev/null | cut -d' ' -f2- || true)"
if [ "$last_content_before" = "$last_content_after" ]; then
  pass "rotation preserves tail content for defer dedup"
else
  bad "rotation did not preserve tail (before=[$last_content_before], after=[$last_content_after])"
fi

# Verify archive exists (look for any file starting with review-audit.log.)
archive_count=$(find "$dir/.claude" -name "review-audit.log.*" -type f 2>/dev/null | wc -l)
if [ "$archive_count" -gt 0 ]; then
  pass "rotated log archive created"
else
  bad "rotated log archive not found"
fi

# Verify archive CONTENT (not just existence) matches the original pre-rotation log.
archive_path="$(find "$dir/.claude" -name "review-audit.log.*" -type f 2>/dev/null | head -n1)"
archive_content="$(cat "$archive_path" 2>/dev/null)"
original_content="$(printf '2026-08-20T10:00:00Z cleared-by=reviewer unit=100\n2026-08-21T10:00:00Z defer: unit=101 reason=test')"
if [ "$archive_content" = "$original_content" ]; then
  pass "archive content matches original pre-rotation log"
else
  bad "archive content does not match original log (archive=[$archive_content])"
fi

echo
echo "-- log rotation fires on a fresh (non-backdated) log -- regression for rotation-unreachable fix --"
dir="$(mk_project fresh-rotation)"
mkdir -p "$dir/.claude"
printf '2026-08-22T10:00:00Z cleared-by=reviewer unit=200\n' > "$dir/.claude/review-audit.log"
printf '2026-08-22T10:00:01Z cleared-by=reviewer unit=201\n' >> "$dir/.claude/review-audit.log"
# No backdating: mtime is "now", well within the default 30-day retention window.
"$script" --project-dir "$dir" --apply >/dev/null 2>&1
fresh_archive_count=$(find "$dir/.claude" -name "review-audit.log.*" -type f 2>/dev/null | wc -l)
if [ "$fresh_archive_count" -gt 0 ]; then
  pass "fresh log rotates unconditionally (not retention-gated)"
else
  bad "fresh log did not rotate -- rotation regressed to being retention-gated"
fi

echo
echo "-- log rotation is collision-safe within the same second (regression for gh409) --"
dir="$(mk_project collision)"
mkdir -p "$dir/.claude"
for i in $(seq 1 200); do printf 'line %s\n' "$i" >> "$dir/.claude/review-audit.log"; done

# Stub `date` so both --apply runs below compute the identical archive
# timestamp, deterministically forcing the same-second collision instead of
# relying on a real timing race.
stubdir="$tmproot/stub-date-collision"
mkdir -p "$stubdir"
cat > "$stubdir/date" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-u" ] && [ "$2" = "+%Y%m%dT%H%M%SZ" ]; then
  echo "20260101T000000Z"
  exit 0
fi
exec /usr/bin/date "$@"
EOF
chmod +x "$stubdir/date"

PATH="$stubdir:$PATH" "$script" --project-dir "$dir" --apply >/dev/null 2>&1
for i in $(seq 201 210); do printf 'line %s\n' "$i" >> "$dir/.claude/review-audit.log"; done
PATH="$stubdir:$PATH" "$script" --project-dir "$dir" --apply >/dev/null 2>&1

first_archive_lines=$(wc -l < "$dir/.claude/review-audit.log.20260101T000000Z" 2>/dev/null || echo 0)
if [ "$first_archive_lines" -eq 200 ]; then
  pass "first archive (200 lines) survives a same-second rotation, not clobbered"
else
  bad "first archive was clobbered by the same-second collision (expected 200 lines, got $first_archive_lines)"
fi

if [ -f "$dir/.claude/review-audit.log.20260101T000000Z.1" ]; then
  pass "second same-second rotation used a collision-safe counter-suffixed archive name"
else
  bad "second same-second rotation did not create a counter-suffixed archive"
fi

exit "$fail"
