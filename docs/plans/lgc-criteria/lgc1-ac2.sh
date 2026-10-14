#!/usr/bin/env bash
# lgc1-ac2.sh: a legitimate concurrent marker write no longer FAILs the guard.
# The stub suite stands in for a reviewer working while the nested run is in
# flight: it adds gh999-1.pass to and removes old.pass from the project's OWN
# marker directory (T/.claude/reviewed, by path, not via CLAUDE_PROJECT_DIR).
# The guard must exit 0 and leave nothing behind in TMPDIR. Prints nothing
# and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
t=$(mktree concurrent "T=\"$LGC_ROOT/concurrent\"
printf 'PASS gh999-1 x\n' > \"\$T/.claude/reviewed/gh999-1.pass\"
rm -f \"\$T/.claude/reviewed/old.pass\"")
runguard "$t"
[ "$RC" = 0 ] || { echo "concurrent: guard exit $RC, want 0"; printf '%s\n' "$OUT"; exit 1; }
[ -f "$t/.claude/reviewed/gh999-1.pass" ] || { echo "concurrent: stub did not run (no gh999-1.pass)"; exit 1; }
left=$(ls -A "$t/tmp")
[ -z "$left" ] || { echo "TMPDIR not cleaned: $left"; exit 1; }
