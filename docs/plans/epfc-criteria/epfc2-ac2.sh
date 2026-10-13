#!/usr/bin/env bash
# epfc-2 AC2.2 (note 2): the extended epfb4-ac3.sh is itself mutation-proven.
# In a scratch worktree of HEAD, delete F4 case 3 (then, separately, case 4)
# from the test, commit it there, and run that worktree's epfb4-ac3.sh: it must
# exit non-zero and name mutant (d) (then (e)).
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/protocol-cross-references.test.js; S=docs/plans/epfb-criteria/epfb4-ac3.sh
G="git -c core.hooksPath=/dev/null -c user.name=epfc -c user.email=epfc@invalid"
for tag in d e; do
  ( cd "$wt" && git reset -q --hard HEAD && git clean -qfd ) || exit 1
  if [ "$tag" = d ]; then pat='## swallowed'; else pat='tilde info may hold backticks'; fi
  grep -q "^    \['pre.*$pat" "$wt/$T" || { echo "($tag) case line not found"; exit 1; }
  P="$pat" perl -ni -e 'print unless /^    \[\x27pre.*\Q$ENV{P}\E/' "$wt/$T"
  ( cd "$wt" && $G commit -qam "scratch: drop F4 case ($tag)" ) || { echo "($tag) scratch commit failed"; exit 1; }
  out=$(cd "$wt" && bash "$S" 2>&1) && { echo "($tag) case deletion not caught by epfb4-ac3.sh"; exit 1; }
  printf '%s\n' "$out" | grep -q "^($tag) " || { echo "($tag) epfb4-ac3.sh failed for another reason: $(printf '%s' "$out" | head -1)"; exit 1; }
  ( cd "$wt" && git reset -q --hard HEAD~1 ) || exit 1
done
echo "case 3 and case 4 deletions caught"
