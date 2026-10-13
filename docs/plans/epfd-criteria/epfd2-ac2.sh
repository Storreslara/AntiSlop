#!/usr/bin/env bash
# epfd-2 AC2.2 (item 2): mutation proof in a scratch worktree of HEAD.
# (a) a parser that needs a non-space after `## ` (so a bare `## ` line is
# preamble) fails F5 on the bare input; nothing else in the suite catches it.
# (b) the reason no trailing-newline input is added: a parser that drops a
# trailing newline already fails F2.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/protocol-cross-references.test.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
FROM="else isHeader = line.startsWith('## ');" TO='else isHeader = /^## \S/.test(line);' \
  perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$wt/bin/cli.js"
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(a) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(a) bare-header mutant survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F5 .*bare ## line' || { echo "(a) no FAIL F5 on the bare ## input"; exit 1; }
( cd "$wt" && git checkout -q -- bin/cli.js )
FROM="for (const line of text.split('\\n')) {" TO="for (const line of text.replace(/\\n\$/, '').split('\\n')) {" \
  perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$wt/bin/cli.js"
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(b) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(b) trailing-newline mutant survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F2 ' || { echo "(b) no FAIL F2: a trailing-newline input is needed after all"; exit 1; }
echo "epfd-2 mutations killed"
