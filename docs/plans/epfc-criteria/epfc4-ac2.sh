#!/usr/bin/env bash
# epfc-4 AC4.2 (note 4): mutation proof in a scratch worktree of HEAD.
# (a) dropping the prose skip token from agents/reviewer.md (the card copy
# stays) fails EB1; (b) dropping the card copy from the template (the prose
# copy stays) fails EB1. The pre-epfc-4 EB1 survives both.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/adapter-protocol-parity.test.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
perl -0pi -e 's/or `examples: none - <one-line reason>` when you did not/or a skip line when you did not/' "$wt/agents/reviewer.md"
( cd "$wt" && git diff --quiet -- agents/reviewer.md ) && { echo "(a) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1)
printf '%s\n' "$out" | grep -q '^FAIL EB1 .*agents/reviewer.md: no ASCII-hyphen skip token in prose' || { echo "(a) prose-token deletion survived EB1"; exit 1; }
( cd "$wt" && git checkout -q -- agents/reviewer.md )
perl -0pi -e 's/^examples: <count> \| examples: none - <one-line reason>$/examples: <count>/m' "$wt/templates/persona-protocol.md"
( cd "$wt" && git diff --quiet -- templates/persona-protocol.md ) && { echo "(b) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1)
printf '%s\n' "$out" | grep -q '^FAIL EB1 .*templates/persona-protocol.md: no ASCII-hyphen skip token in the card fence' || { echo "(b) card-token deletion survived EB1"; exit 1; }
echo "epfc-4 mutations killed"
