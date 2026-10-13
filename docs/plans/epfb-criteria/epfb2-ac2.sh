#!/usr/bin/env bash
# epfb-2 AC2.2 (item d): mutation proof in a scratch worktree of HEAD.
# (a) an em-dash skip token in reviewer.md fails EB1; (b) a column-0 paragraph
# after the card fails EB2.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
need_unit epfb-2
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/adapter-protocol-parity.test.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
perl -CSD -0pi -e 's/examples: none - <one-line reason>/examples: none \x{2014} <one-line reason>/' "$wt/agents/reviewer.md"
( cd "$wt" && git diff --quiet -- agents/reviewer.md ) && { echo "(a) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(a) em dash survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL EB1 ' || { echo "(a) no FAIL EB1"; exit 1; }
( cd "$wt" && git checkout -q -- agents/reviewer.md )
perl -0pi -e 's/^- \*\*Durable escalation packet\*\*: in/In/m' "$wt/agents/reviewer.md"
( cd "$wt" && git diff --quiet -- agents/reviewer.md ) && { echo "(b) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(b) column-0 paragraph survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL EB2 ' || { echo "(b) no FAIL EB2"; exit 1; }
echo "epfb-2 mutations killed"
