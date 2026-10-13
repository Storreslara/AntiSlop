#!/usr/bin/env bash
# epfb-4 AC4.3 (item g): mutation proof in a scratch worktree of HEAD.
# (a) the old opener regex fails F4; (b) the old closer regex fails F4;
# (c) rendering is unchanged: --update --dry-run exits 0.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
need_unit epfb-4
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/protocol-cross-references.test.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
( cd "$wt" && node bin/cli.js --update --dry-run >/dev/null 2>&1 ) || { echo "(c) dry-run rc != 0"; exit 1; }
perl -0pi -e 's/\(`\{3,\}\(\?=\[\^`\]\*\$\)\|~\{3,\}\)\/\.exec/(`{3,}|~{3,})\/.exec/' "$wt/bin/cli.js"
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(a) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(a) old opener survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F4' || { echo "(a) no FAIL F4"; exit 1; }
( cd "$wt" && git checkout -q -- bin/cli.js )
perl -0pi -e 's/\[ \\t\\r\]\*\$/[ \\t]*\$/' "$wt/bin/cli.js"
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(b) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(b) old closer survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F4' || { echo "(b) no FAIL F4"; exit 1; }
echo "epfb-4 mutations killed"
