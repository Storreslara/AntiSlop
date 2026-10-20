#!/usr/bin/env bash
# vsp-1 AC1.4 and vsp-2 AC2.4: one real default run of this checkout's tests/validate.sh.
# Passes when: exit 0, the last line of the full log is "All checks passed.", every section of
# tests/validate.sh ran (the lane runner's "sections: N" equals the header count), and the run
# took at most VSP_MAX_SECS seconds (default 360) by /proc/uptime. Prints a 4-line summary only.
# Run it with the Bash tool's timeout at 600000 ms, on a quiet tree (no other validate.sh run).
set -uo pipefail
repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
max="${VSP_MAX_SECS:-360}"
log="$(mktemp)" || exit 99
trap 'rm -f "$log"' EXIT
want="$(grep -c '^echo "== ' "$repo/tests/validate.sh")"
t0="$(cut -d' ' -f1 /proc/uptime)"
(cd "$repo" && env -u ANTISLOP_VALIDATE_INNER -u ANTISLOP_VALIDATE_SERIAL -u ANTISLOP_VALIDATE_LANES \
  -u REVIEWED_DIR_LEAK_GUARD_NESTED bash tests/validate.sh --verbose) > "$log" 2>&1
rc=$?
t1="$(cut -d' ' -f1 /proc/uptime)"
secs="$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.0f", b-a}')"
lanes_line="$(grep -E '^== lanes: [0-9]+, sections: [0-9]+,' "$log" | tail -n 1)"
got="$(printf '%s\n' "$lanes_line" | sed -nE 's/^== lanes: [0-9]+, sections: ([0-9]+),.*/\1/p')"
fails="$(grep -c '^FAIL' "$log")"
echo "exit=$rc secs=$secs max=$max"
echo "sections ran=${got:-none} headers=$want"
echo "FAIL lines=$fails"
grep '^FAIL' "$log" | head -n 5 | sed 's/^/  /'
ok=1
[ "$rc" = 0 ] || ok=0
[ "${got:-x}" = "$want" ] || ok=0
[ "$secs" -le "$max" ] || ok=0
grep -v '^[[:space:]]*$' "$log" | grep -v '^Skipped checks\|^     \|^== skipped checks' | tail -n 1 | grep -qx 'All checks passed.' || ok=0
if [ "$ok" = 1 ]; then echo "real-run: PASS"; exit 0; fi
echo "real-run: FAIL"; exit 1
