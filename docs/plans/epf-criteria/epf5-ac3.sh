#!/usr/bin/env bash
# epf-5 AC5.3: mutation proof in a scratch worktree of HEAD.
# (a) the pre-epf-5 parser (export kept) fails F1; (b) a fenced `## ` line in the
# template fails F3; (c) rendering is unchanged: --update --dry-run exits 0.
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
need_unit epf-5
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/protocol-cross-references.test.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
( cd "$wt" && node bin/cli.js --update --dry-run >/dev/null 2>&1 ) || { echo "(c) dry-run rc != 0"; exit 1; }
# (a) old parser body, export kept
git show "$F^:bin/cli.js" > "$wt/bin/cli.js"
perl -0pi -e 's/module\.exports = \{\n/module.exports = {\n  parseProtocolSections,\n/' "$wt/bin/cli.js"
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(a) old parser survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F1' || { echo "(a) no FAIL F1"; exit 1; }
( cd "$wt" && git checkout -q -- bin/cli.js )
# (b) a heading inside the card fence
perl -0pi -e 's/(<!-- escalated-card:begin -->\n```text\n)/$1## fenced heading\n/' "$wt/templates/persona-protocol.md"
( cd "$wt" && git diff --quiet -- templates/persona-protocol.md ) && { echo "(b) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(b) fenced heading survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F3' || { echo "(b) no FAIL F3"; exit 1; }
echo "epf-5 mutations killed"
