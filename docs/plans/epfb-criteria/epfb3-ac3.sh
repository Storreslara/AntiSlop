#!/usr/bin/env bash
# epfb-3 AC3.3 (item f): mutation proof in a scratch worktree of HEAD.
# (a) the pre-epfb-3 renderer fails TB11 and TB16; (b) the body loop without the
# block-start stop fails TB11; (c) a `</script>` literal in the source fails VM1.
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
need_unit epfb-3
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
T=tests/microworld/dashboard-markdown-lite.test.js; M=bin/microworld-dashboard/markdown-lite.js
( cd "$wt" && node "$T" >/dev/null 2>&1 ) || { echo "unmutated test fails"; exit 1; }
git show "$F^:$M" > "$wt/$M"
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(a) old renderer survived"; exit 1; }
for n in TB11 TB16; do printf '%s\n' "$out" | grep -q "^  - $n " || { echo "(a) no $n failure"; exit 1; }; done
( cd "$wt" && git checkout -q -- "$M" )
perl -0pi -e 's/ && !mdStartsBlock\(lines\[i\]\.trim\(\)\)//' "$wt/$M"
( cd "$wt" && git diff --quiet -- "$M" ) && { echo "(b) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(b) unguarded body loop survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^  - TB11 ' || { echo "(b) no TB11 failure"; exit 1; }
( cd "$wt" && git checkout -q -- "$M" )
printf "const SCRIPT_END = '</script>';\n" >> "$wt/$M"
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(c) script-end literal survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^  - VM1 ' || { echo "(c) no VM1 failure"; exit 1; }
echo "epfb-3 mutations killed"
