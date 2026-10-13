#!/usr/bin/env bash
# epfd-3 AC3.2 (item 3): mutation proof in a scratch worktree of HEAD. Each
# mutant of the test file's local splitFences must fail SF1 on its own case:
# (a) no backtick opener; (b) no tilde opener; (c) an opener with an info
# string is not an opener; (d) an unclosed fence's lines count as prose;
# (e) a closer of the other fence character closes; (f) a shorter closer closes.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/adapter-protocol-parity.test.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
mut() { # mut <tag> <from> <to> <SF1 case name>
  ( cd "$wt" && git checkout -q -- "$T" )
  FROM="$2" TO="$3" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$wt/$T"
  ( cd "$wt" && git diff --quiet -- "$T" ) && { echo "($1) changed nothing"; exit 1; }
  out=$(cd "$wt" && node "$T" 2>&1)
  printf '%s\n' "$out" | grep '^FAIL SF1 ' | grep -qF "$4: " \
    || { echo "($1) mutant not caught by SF1 case: $4"; exit 1; }
}
mut a '(`{3,}(?=[^`]*$)|~{3,})' '(~{3,})' 'backtick fence'
mut b '(`{3,}(?=[^`]*$)|~{3,})' '(`{3,}(?=[^`]*$))' 'tilde fence'
mut c '|~{3,})/.exec(line)' '|~{3,})[ \t\r]*$/.exec(line)' 'info string'
mut d 'return { prose, fenced };' 'return fence ? { prose: prose.concat(fenced), fenced: [] } : { prose, fenced };' 'unclosed fence runs to the end'
mut e 'close[1][0] === fence.ch && ' '' 'a tilde line does not close a backtick fence'
mut f ' && close[1].length >= fence.len' '' 'a shorter closer does not close'
echo "epfd-3 mutations killed"
