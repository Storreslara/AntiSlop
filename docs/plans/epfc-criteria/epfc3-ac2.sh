#!/usr/bin/env bash
# epfc-3 AC3.2 (note 3): mutation proof in a scratch worktree of HEAD.
# (a) a parser that returns a null preamble for no-preamble text fails F5;
# (b) a live template that opens with a `## ` line fails F5.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/protocol-cross-references.test.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
perl -0pi -e "s/return \{ preamble: preamble\.join\('\\\\n'\),/return { preamble: preamble.length ? preamble.join('\\\\n') : null,/" "$wt/bin/cli.js"
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(a) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(a) null preamble survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F5 ' || { echo "(a) no FAIL F5"; exit 1; }
( cd "$wt" && git checkout -q -- bin/cli.js )
perl -0pi -e 's/\A/## Opening header\n/' "$wt/templates/persona-protocol-slim.md"
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(b) header-first template survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F5 .*opens with a ## line' || { echo "(b) no FAIL F5"; exit 1; }
echo "epfc-3 mutations killed"
