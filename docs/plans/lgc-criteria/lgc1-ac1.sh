#!/usr/bin/env bash
# lgc1-ac1.sh: the guard still FAILs a real leak. Three stub suites each
# misuse the CLAUDE_PROJECT_DIR the guard hands them: (a) write a
# fixture-named marker (unitC.blocked, a gh425 F3 name) with no mkdir,
# (b) overwrite-style write of a name the project already has (old.pass,
# gh425 F4), (c) remove the marker directory itself. Each must exit 1 and
# name what it found. Prints nothing and exits 0 on success.
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
check() { # <label> <stub-body> <expected-substring>
  local t; t=$(mktree "$1" "$2"); runguard "$t"
  [ "$RC" = 1 ] || { echo "$1: guard exit $RC, want 1"; printf '%s\n' "$OUT"; exit 1; }
  case "$OUT" in *"$3"*) ;; *) echo "$1: output does not name $3"; printf '%s\n' "$OUT"; exit 1;; esac
}
check fixture 'printf "BLOCKED unitC x\n" > "$CLAUDE_PROJECT_DIR/.claude/reviewed/unitC.blocked"' unitC.blocked
check overwrite 'printf "PASS old x\n" > "$CLAUDE_PROJECT_DIR/.claude/reviewed/old.pass"' old.pass
check removal 'rm -rf "$CLAUDE_PROJECT_DIR/.claude/reviewed"' FAIL
