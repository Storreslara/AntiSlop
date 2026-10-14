# Shared helpers for the lgc-1 acceptance scripts (source this file).
# Never touches the checkout's own marker directory: every run builds a
# throwaway project tree T under a private TMPDIR, copies the guard into
# T/tests/, and puts a stub T/tests/validate.sh next to it. The guard cds to
# its own parent's parent, so it runs against T, never against the checkout.
cd "$(git rev-parse --show-toplevel)" || exit 99
GUARD_SRC="$(pwd)/tests/reviewed-dir-leak-guard.test.sh"
[ -f "$GUARD_SRC" ] || { echo "guard missing: $GUARD_SRC"; exit 99; }

LGC_ROOT="$(mktemp -d)" || exit 99
trap 'rm -rf "$LGC_ROOT"' EXIT

# mktree <name> <stub-body>: make T=$LGC_ROOT/<name> with the guard, a stub
# validate.sh holding <stub-body>, and T's own marker dir holding one
# pre-existing entry (old.pass), as a live project's would. Prints T.
mktree() {
  local t="$LGC_ROOT/$1"
  mkdir -p "$t/tests" "$t/.claude/reviewed" "$t/tmp"
  cp "$GUARD_SRC" "$t/tests/reviewed-dir-leak-guard.test.sh"
  printf '#!/usr/bin/env bash\ncd "$(dirname "$0")/.."\n%s\n' "$2" > "$t/tests/validate.sh"
  printf 'PASS old 2026-01-01T00:00:00Z commit: none criteria: none\n' > "$t/.claude/reviewed/old.pass"
  printf '%s\n' "$t"
}

# runguard <T>: run T's guard copy with TMPDIR=T/tmp and the caller's
# CLAUDE_PROJECT_DIR pointed at T (as the harness does). Sets RC and OUT.
runguard() {
  OUT="$(cd "$1" && env -u REVIEWED_DIR_LEAK_GUARD_NESTED TMPDIR="$1/tmp" \
    CLAUDE_PROJECT_DIR="$1" bash tests/reviewed-dir-leak-guard.test.sh 2>&1)"
  RC=$?
}
