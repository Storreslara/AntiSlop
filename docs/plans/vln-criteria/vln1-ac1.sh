#!/usr/bin/env bash
# vln1-ac1.sh: an interrupted tests/validate-lanes.sh takes its whole process
# tree with it. Each case is a stub tree run with --lanes 2 in the background
# (job control on, so SIGINT is not ignored), signalled once the stub has
# recorded its pids:
#   section-TERM, section-INT: a section's bash waits on a child `sleep 300`;
#     the section bash and the sleep are recorded.
#   copy-TERM: a `tar` wrapper first on PATH sleeps inside the create side of
#     every lane's copy; each wrapper and its sleep are recorded.
# Each case wants the runner to exit 143 (TERM) or 130 (INT) within 20 s,
# every recorded pid (runner included) gone within 10 s of that, and T/tmp
# empty. Case stdin: a section's stdin is /dev/null although the runner's own
# stdin is a regular file (a lane in its own process group must never read
# the terminal). Times are monotonic (/proc/uptime).
# Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# intr <label> <signal> <want-rc> <words-wanted> <validate-body> [tar-wrapper]
intr() {
  local label=$1 sig=$2 want=$3 n=$4 t rp s rc p pids="$VLN_ROOT/$1.pids"
  t=$(ltree "$label" "$5") || exit 1
  if [ -n "${6:-}" ]; then printf '%s\n' "$6" > "$t/bin/tar"; chmod +x "$t/bin/tar"; fi
  : > "$t/stdin.txt"
  set -m
  (cd "$t" && exec env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
    TMPDIR="$t/tmp" CLAUDE_PROJECT_DIR="$t" PATH="$t/bin:$PATH" \
    bash tests/validate-lanes.sh --lanes 2 < "$t/stdin.txt") > "$t.out" 2>&1 &
  rp=$!
  set +m
  s=$(mono)
  until [ "$(cat "$pids" 2>/dev/null | wc -w)" -ge "$n" ]; do
    past "$s" 20 && { echo "$label: the stub recorded fewer than $n pids in 20 s"; cat "$t.out"; echo "$rp" >> "$pids"; exit 1; }
    sleep 0.1
  done
  echo "$rp" >> "$pids"
  kill -"$sig" "$rp"
  s=$(mono)
  while alive "$rp"; do
    past "$s" 20 && { echo "$label: the runner did not exit within 20 s of SIG$sig"; exit 1; }
    sleep 0.1
  done
  wait "$rp"; rc=$?
  [ "$rc" = "$want" ] || { echo "$label: runner exit $rc, want $want"; cat "$t.out"; exit 1; }
  s=$(mono)
  for p in $(cat "$pids"); do
    while alive "$p"; do
      past "$s" 10 && { echo "$label: pid $p ($(ps -o comm= -p "$p")) survived SIG$sig"; exit 1; }
      sleep 0.1
    done
  done
  tmpclean "$label" "$t"
}

body='sleep 300 & echo "$$ $!" >> "PIDS"; wait; echo "OK   s1"'
intr section-TERM TERM 143 2 "$(sec 1 "${body/PIDS/$VLN_ROOT/section-TERM.pids}"; sec 2)"
intr section-INT INT 130 2 "$(sec 1 "${body/PIDS/$VLN_ROOT/section-INT.pids}"; sec 2)"

wrap="#!/usr/bin/env bash
case \" \$* \" in *\" -cf \"*) sleep 300 & echo \"\$\$ \$!\" >> \"$VLN_ROOT/copy-TERM.pids\"; wait ;; esac
exec \"$REAL_TAR\" \"\$@\""
intr copy-TERM TERM 143 4 "$(sec 1; sec 2)" "$wrap"

t=$(ltree stdin "$(sec 1 'echo "STDIN=$(readlink "/proc/$$/fd/0")"')") || exit 1
runlanes "$t" --lanes 2
expect stdin 0 'STDIN=/dev/null' 'All checks passed.'
exit 0
