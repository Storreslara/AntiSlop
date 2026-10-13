#!/usr/bin/env bash
# epfd-1 AC1.1 (item 1): mutant (d) in epfb4-ac3.sh finds the opener line by its
# position, not by its text. Its mutation block (the lines after the last
# `git checkout -q -- bin/cli.js` line before the `(d) changed nothing` line)
# is applied to a scratch worktree of HEAD and run on two texts whose opener
# line repeats another line: one repeats an EARLIER line (indexOf gets it
# wrong), one repeats a LATER line (lastIndexOf gets it wrong).
D=$(cd "$(dirname "$0")" && pwd); . "$D/../epf-criteria/lib.sh"
S=docs/plans/epfb-criteria/epfb4-ac3.sh
blk=$(awk '/git checkout -q -- bin\/cli\.js/{b=""; next} /"\(d\) changed nothing"/{printf "%s", b; f=1; exit} {b=b $0 "\n"} END{if(!f) exit 1}' "$S") \
  || { echo "(d) block not found in $S"; exit 1; }
[ -n "$blk" ] || { echo "(d) block is empty"; exit 1; }
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
wt="$wt" bash -c "$blk" || { echo "(d) block exited non-zero"; exit 1; }
( cd "$wt" && git diff --quiet -- bin/cli.js ) && { echo "(d) block changed nothing"; exit 1; }
got=$(cd "$wt" && node -e '
const p = require("./bin/cli.js").parseProtocolSections;
const h = (t) => JSON.stringify(p(t).sections.map((s) => s.header));
const F = "```";
console.log(h(["pre", "## H1", F, "x", F, "## H2", F, "## H3"].join("\n")));
console.log(h(["pre", "## H1", F, "## H2", F, "## H3"].join("\n")));
' 2>&1) || { echo "(d) mutated cli.js does not load: $(printf '%s' "$got" | head -1)"; exit 1; }
one=$(printf '%s\n' "$got" | sed -n 1p); two=$(printf '%s\n' "$got" | sed -n 2p)
[ "$one" = '["H1","H2","H3"]' ] || { echo "(d) mislocates an opener that repeats an earlier line: got $one"; exit 1; }
[ "$two" = '["H1","H3"]' ] || { echo "(d) mislocates an opener that repeats a later line: got $two"; exit 1; }
exit 0
