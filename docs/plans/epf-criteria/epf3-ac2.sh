#!/usr/bin/env bash
# epf-3 AC3.2: mutation proof. Each mutation is applied to ALL SIX viewer copies in
# a scratch worktree of HEAD, T1 stays green, and the named case fails.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
set -u
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
copies="agents/reviewer.md templates/persona-protocol.md adapters/codex/agents-md-fragment.md adapters/cursor/rules/persona-protocol.mdc .claude/agents/reviewer.md .claude/persona-protocol.md"
mut() { ( cd "$wt" && git checkout -q -- $copies && for f in $copies; do perl -0pi -e "$2" "$f"; done
    git diff --quiet -- $copies && { echo "$1 changed nothing"; exit 1; }
    out=$(bash tests/packet-view-script.test.sh 2>&1) && { echo "$1 survived"; exit 1; }
    printf '%s\n' "$out" | grep -q "^FAIL $3" || { echo "$1: no FAIL $3"; exit 1; }
    printf '%s\n' "$out" | grep -q '^FAIL T1 ' && { echo "$1 not in all six"; exit 1; }
    echo "$1 killed by $3" ); }
( cd "$wt" && bash tests/packet-view-script.test.sh >/dev/null 2>&1 ) || { echo "unmutated fails"; exit 1; }
mut glow-bat    's/  if command -v glow( [^\n]*)\n  elif command -v bat( [^\n]*)\n/  if command -v bat$2\n  elif command -v glow$1\n/' O1 || exit 1
mut bat-batcat  's/  elif command -v bat( [^\n]*)\n  elif command -v batcat( [^\n]*)\n/  elif command -v batcat$2\n  elif command -v bat$1\n/' O2 || exit 1
mut batcat-rich 's/  elif command -v batcat( [^\n]*)\n  elif command -v rich( [^\n]*)\n/  elif command -v rich$2\n  elif command -v batcat$1\n/' O3 || exit 1
mut no-rich     's/  elif command -v rich [^\n]*\n//' O4 || exit 1
mut no-skip     's/  \[ -f "\$p" \] \|\| continue\n//' T8 || exit 1
mut comment     's/else prints them plain\. Read-only\./else prints them plain./' T1b || exit 1
