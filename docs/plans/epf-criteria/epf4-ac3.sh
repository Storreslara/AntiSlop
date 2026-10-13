#!/usr/bin/env bash
# epf-4 AC4.3: mutation proof in a scratch worktree of HEAD.
# (a) the pre-epf-4 renderer fails the new test at TB1; (b) a renderer whose
# cells skip renderInline fails with a `table body cell` context failure.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
need_unit epf-4
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
M=bin/microworld-dashboard/markdown-lite.js; T=tests/microworld/dashboard-markdown-lite.test.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
git show "$F^:$M" > "$wt/$M"
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(a) old renderer survived"; exit 1; }
printf '%s\n' "$out" | grep -B1 '✗' | grep -q '^Test TB1 ' || { echo "(a) TB1 did not fail"; exit 1; }
( cd "$wt" && git checkout -q -- "$M" )
perl -pi -e "s/'<(t[hd])>' \+ renderInline\(([^)]*)\)/'<\$1>' + \$2/g" "$wt/$M"
( cd "$wt" && git diff --quiet -- "$M" ) && { echo "(b) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(b) raw-cell renderer survived"; exit 1; }
printf '%s\n' "$out" | grep -q 'in table body cell' || { echo "(b) no table body cell failure"; exit 1; }
echo "epf-4 mutations killed"
