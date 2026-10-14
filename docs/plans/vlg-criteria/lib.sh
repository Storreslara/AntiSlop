# Shared helpers for the vlg-1..vlg-3 acceptance scripts (source this file).
# Never touches the checkout's own marker directory. Every run builds throwaway
# trees under a private root VLG_ROOT (removed on exit) and runs a COPY of the
# script under test there, next to a stub tests/validate.sh. The scripts under
# test cd to their own parent's parent, so they run against the throwaway tree.
cd "$(git rev-parse --show-toplevel)" || exit 99
REPO="$(pwd)"
VLG_ROOT="$(mktemp -d)" || exit 99
trap 'rm -rf "$VLG_ROOT"' EXIT

# gtree <name> <stub-body>: tree T=$VLG_ROOT/<name> holding a copy of the leak
# guard, a stub tests/validate.sh whose body is <stub-body> VERBATIM (the stub
# must print its own closing summary line if it wants one), T's own marker
# directory with one entry (old.pass) and a private TMPDIR T/tmp. Prints T.
gtree() {
  local t="$VLG_ROOT/$1"
  mkdir -p "$t/tests" "$t/.claude/reviewed" "$t/tmp"
  cp "$REPO/tests/reviewed-dir-leak-guard.test.sh" "$t/tests/"
  printf '#!/usr/bin/env bash\ncd "$(dirname "$0")/.."\n%s\n' "$2" > "$t/tests/validate.sh"
  printf 'PASS old 2026-01-01T00:00:00Z commit: none criteria: none\n' > "$t/.claude/reviewed/old.pass"
  printf '%s\n' "$t"
}

# runguard <T>: run T's guard copy as the harness would (CLAUDE_PROJECT_DIR=T),
# with neither recursion nor wrapper variable inherited. Sets RC and OUT.
runguard() {
  OUT="$(cd "$1" && env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
    TMPDIR="$1/tmp" CLAUDE_PROJECT_DIR="$1" bash tests/reviewed-dir-leak-guard.test.sh 2>&1)"
  RC=$?
}

# ltree <name> <validate-body>: tree T=$VLG_ROOT/<name> for the lane runner: a
# git repository (one commit) holding a copy of tests/validate-lanes.sh, a
# stub tests/validate.sh made of the standard preamble, <validate-body> and
# the standard closing summary block, and a marker directory with old.pass.
# Prints T.
ltree() {
  local t="$VLG_ROOT/$1"
  mkdir -p "$t/tests" "$t/.claude/reviewed" "$t/tmp"
  cp "$REPO/tests/validate-lanes.sh" "$t/tests/"
  { printf '#!/usr/bin/env bash\nset -uo pipefail\ncd "$(dirname "$0")/.."\nfail=0\n'
    printf '%s\n' "$2"
    printf 'echo\nif [ "$fail" -eq 0 ]; then\n  echo "All checks passed."\nelse\n  echo "One or more checks FAILED."\nfi\nexit "$fail"\n'
  } > "$t/tests/validate.sh"
  printf 'PASS old 2026-01-01T00:00:00Z commit: none criteria: none\n' > "$t/.claude/reviewed/old.pass"
  (cd "$t" && git init -q && git add tests && \
    git -c user.name=t -c user.email=t@t commit -qm init) >/dev/null 2>&1 || { echo "ltree: git setup failed"; exit 99; }
  printf '%s\n' "$t"
}

# mono: monotonic seconds (/proc/uptime). The wall clock is not used: on WSL
# it was observed to jump back 2 s during a 12 s run (2026-10-14).
mono() { cut -d' ' -f1 /proc/uptime; }

# runlanes <T> [args...]: run T's lane-runner copy with CLAUDE_PROJECT_DIR
# pointed at T (the runner must override it per lane). Sets RC, OUT, and
# SECS (whole monotonic seconds, rounded down).
runlanes() {
  local t="$1" s; shift; s=$(mono)
  OUT="$(cd "$t" && env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
    TMPDIR="$t/tmp" CLAUDE_PROJECT_DIR="$t" bash tests/validate-lanes.sh "$@" 2>&1)"
  RC=$?; SECS=$(awk -v a="$s" -v b="$(mono)" 'BEGIN { printf "%d", b - a }')
}

# expect <label> <want-rc> <substring>...: check RC and that OUT holds each
# substring. A substring starting with '!' must be ABSENT.
expect() {
  local label="$1" want="$2" s; shift 2
  [ "$RC" = "$want" ] || { echo "$label: exit $RC, want $want"; printf '%s\n' "$OUT"; exit 1; }
  for s in "$@"; do
    case "$s" in
      '!'*) case "$OUT" in *"${s#!}"*) echo "$label: output must not contain ${s#!}"; printf '%s\n' "$OUT"; exit 1;; esac ;;
      *) case "$OUT" in *"$s"*) ;; *) echo "$label: output does not contain $s"; printf '%s\n' "$OUT"; exit 1;; esac ;;
    esac
  done
}
