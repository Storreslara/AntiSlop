#!/usr/bin/env bash
# epfc-1 AC1.2 (note 1): mutation proof in a scratch worktree of HEAD.
# Deleting the `* ` branch of mdStartsBlock (and only that branch) fails TB18.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/microworld/dashboard-markdown-lite.test.js; M=bin/microworld-dashboard/markdown-lite.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
perl -0pi -e "s/ \|\| trimmed\.startsWith\('\* '\) \|\|/ ||/" "$wt/$M"
n=$(cd "$wt" && git diff -U0 -- "$M" | grep -c '^-[^-]')
[ "$n" = 1 ] || { echo "mutation changed $n lines, want 1"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "star branch deletion survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^  - TB18 ' || { echo "no TB18 failure"; exit 1; }
echo "epfc-1 mutation killed"
