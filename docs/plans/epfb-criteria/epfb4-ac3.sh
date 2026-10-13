#!/usr/bin/env bash
# epfb-4 AC4.3 (item g): mutation proof in a scratch worktree of HEAD.
# (a) the old opener regex fails F4; (b) the old closer regex fails F4;
# (c) rendering is unchanged: --update --dry-run exits 0; (d) an opener that
# needs a later closer (so an unclosed fence opens nothing) fails F4 case 3;
# (e) a tilde opener that rejects backticks in its info string fails F4 case 4.
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
( cd "$wt" && git checkout -q -- bin/cli.js )
perl -0pi -e 's/for \(const line of text\.split\(\x27\\n\x27\)\) \{/for (const [li, line] of text.split(\x27\\n\x27).entries()) {/; s/if \(open\) fence =/if (open && \/^ {0,3}(`{3,}|~{3,})[ \\t\\r]*\$\/m.test(text.split(\x27\\n\x27).slice(li + 1).join(\x27\\n\x27))) fence =/' "$wt/bin/cli.js"
grep -q 'const \[li, line\] of text.split' "$wt/bin/cli.js" || { echo "(d) loop index not added"; exit 1; }
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(d) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(d) unclosed-fence mutant survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F4 .*also swallowed' || { echo "(d) no FAIL F4 on case 3"; exit 1; }
( cd "$wt" && git checkout -q -- bin/cli.js )
perl -0pi -e 's/\(`\{3,\}\(\?=\[\^`\]\*\$\)\|~\{3,\}\)\/\.exec/((?:`{3,}|~{3,})(?=[^`]*\$))\/.exec/' "$wt/bin/cli.js"
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(e) changed nothing"; exit 1; }
out=$(cd "$wt" && node "$T" 2>&1) && { echo "(e) tilde-backtick mutant survived"; exit 1; }
printf '%s\n' "$out" | grep -q '^FAIL F4 .*tilde info may hold backticks' || { echo "(e) no FAIL F4 on case 4"; exit 1; }
echo "epfb-4 mutations killed"
