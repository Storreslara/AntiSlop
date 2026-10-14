# Shared helpers for the vln-1..vln-4 acceptance scripts (source this file).
# Never touches the checkout's own marker directory. Every run builds throwaway
# trees under a private root VLN_ROOT (removed on exit) and runs a COPY of the
# script under test there, next to a stub tests/validate.sh. The scripts under
# test cd to their own parent's parent, so they run against the throwaway tree.
cd "$(git rev-parse --show-toplevel)" || exit 99
REPO="$(pwd)"
VLN_ROOT="$(mktemp -d)" || exit 99
REAL_TAR="$(command -v tar)" || { echo "lib: no tar on PATH"; exit 99; }

# Every pid a stub records goes into $VLN_ROOT/<name>.pids (one or more pids
# per line). On exit they are all killed, so a red run (survivors) never
# leaves sleeps behind; then VLN_ROOT is removed.
reap() {
  local p
  for p in $(cat "$VLN_ROOT"/*.pids 2>/dev/null); do kill -KILL "$p" 2>/dev/null; done
}
trap 'reap; rm -rf "$VLN_ROOT"' EXIT

# mono: monotonic seconds (/proc/uptime), never the wall clock (on WSL the
# wall clock was observed to jump back 2 s during a 12 s run, 2026-10-14).
mono() { cut -d' ' -f1 /proc/uptime; }
# past <start> <secs>: true once <secs> monotonic seconds have passed since <start>.
past() { awk -v a="$1" -v b="$(mono)" -v s="$2" 'BEGIN { exit !(b - a >= s) }'; }

# alive <pid>: the pid exists and is not a zombie.
alive() {
  local st
  st="$(ps -o stat= -p "$1" 2>/dev/null)" || return 1
  case "$st" in Z*|'') return 1 ;; esac
  return 0
}

# ltree <name> <validate-body>: tree T=$VLN_ROOT/<name> for the lane runner: a
# git repository (one commit) holding a copy of tests/validate-lanes.sh, a
# stub tests/validate.sh made of the standard preamble, <validate-body> and
# the standard closing summary block, a marker directory with old.pass, a
# private TMPDIR T/tmp and an empty T/bin (put on PATH by runlanes). Prints T.
# On git setup failure it prints why on stderr and exits 99: call it as
# `t=$(ltree ...) || exit 1`, since exit inside $(...) ends only the subshell.
ltree() {
  local t="$VLN_ROOT/$1"
  mkdir -p "$t/tests" "$t/.claude/reviewed" "$t/tmp" "$t/bin"
  cp "$REPO/tests/validate-lanes.sh" "$t/tests/"
  { printf '#!/usr/bin/env bash\nset -uo pipefail\ncd "$(dirname "$0")/.."\nfail=0\n'
    printf '%s\n' "$2"
    printf 'echo\nif [ "$fail" -eq 0 ]; then\n  echo "All checks passed."\nelse\n  echo "One or more checks FAILED."\nfi\nexit "$fail"\n'
  } > "$t/tests/validate.sh"
  printf 'PASS old 2026-01-01T00:00:00Z commit: none criteria: none\n' > "$t/.claude/reviewed/old.pass"
  (cd "$t" && git init -q && git add tests && \
    git -c user.name=t -c user.email=t@t commit -qm init) >/dev/null 2>&1 || { echo "ltree: git setup failed" >&2; exit 99; }
  printf '%s\n' "$t"
}

# sec <n> [body]: one stub section with header `== s<n> ==`.
sec() { printf 'echo\necho "== s%s =="\n%s\n' "$1" "${2:-echo \"OK   s$1\"}"; }

# runlanes <T> [args...]: run T's lane-runner copy in the foreground with
# CLAUDE_PROJECT_DIR=T, TMPDIR=T/tmp, T/bin first on PATH and stdin from
# T/stdin.txt (a regular file, never /dev/null). Sets RC and OUT.
runlanes() {
  local t="$1"; shift
  : > "$t/stdin.txt"
  OUT="$(cd "$t" && env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
    TMPDIR="$t/tmp" CLAUDE_PROJECT_DIR="$t" PATH="$t/bin:$PATH" \
    bash tests/validate-lanes.sh "$@" < "$t/stdin.txt" 2>&1)"
  RC=$?
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

# tmpclean <label> <T>: T/tmp holds nothing (the script under test removed
# everything it created there).
tmpclean() {
  [ -z "$(find "$2/tmp" -mindepth 1 -print -quit)" ] || { echo "$1: files were left in TMPDIR"; find "$2/tmp" -mindepth 1 -maxdepth 2; exit 1; }
}

# gtree <name> <stub-body>: tree T=$VLN_ROOT/<name> holding a copy of the leak
# guard, a stub tests/validate.sh whose body is <stub-body> VERBATIM, T's own
# marker directory with old.pass and a private TMPDIR T/tmp. Prints T.
gtree() {
  local t="$VLN_ROOT/$1"
  mkdir -p "$t/tests" "$t/.claude/reviewed" "$t/tmp"
  cp "$REPO/tests/reviewed-dir-leak-guard.test.sh" "$t/tests/"
  printf '#!/usr/bin/env bash\ncd "$(dirname "$0")/.."\n%s\n' "$2" > "$t/tests/validate.sh"
  printf 'PASS old 2026-01-01T00:00:00Z commit: none criteria: none\n' > "$t/.claude/reviewed/old.pass"
  printf '%s\n' "$t"
}

# runguard <T>: run T's guard copy as the harness would (CLAUDE_PROJECT_DIR=T,
# TMPDIR=T/tmp), with neither recursion nor wrapper variable inherited.
# Sets RC and OUT.
runguard() {
  OUT="$(cd "$1" && env -u REVIEWED_DIR_LEAK_GUARD_NESTED -u ANTISLOP_VALIDATE_INNER \
    TMPDIR="$1/tmp" CLAUDE_PROJECT_DIR="$1" bash tests/reviewed-dir-leak-guard.test.sh 2>&1)"
  RC=$?
}
