#!/usr/bin/env bash
# epf-6 AC6.2: each corrected criterion fails under its own mutation (scratch
# worktree of HEAD; the run line is extracted from the worktree's own plan copy).
D=$(cd "$(dirname "$0")" && pwd); . "$D/lib.sh"
root=$(git rev-parse --show-toplevel); wt=$(mktemp -d)/wt
git -C "$root" worktree add -q --detach "$wt" HEAD || exit 1
trap 'git -C "$root" worktree remove --force "$wt"' EXIT
P=docs/plans/2026-10-12-escalation-packet-aesthetics.md
extract() { awk -v id="- **$1** " 'index($0,id)==1{f=1;next} f&&/^  - run: `/{sub(/^  - run: `/,""); sub(/`$/,""); print; exit}' "$wt/$P"; }
# kill <AC id> <unit> <file> <perl expression>
kill() {
  local cmd f l; cmd=$(extract "$1"); f=$(uF "$2"); l=$(uL "$2")
  [ -n "$cmd" ] && [ -n "$f" ] || { echo "$1: no run line or no $2 commits"; return 1; }
  ( cd "$wt" && git checkout -q -- . && F="$f" L="$l" bash -c "$cmd" >/dev/null 2>&1 ) || { echo "$1 unmutated run fails"; return 1; }
  perl -0pi -e "$4" "$wt/$3"
  ( cd "$wt" && git diff --quiet -- "$3" ) && { echo "$1 mutation changed nothing"; return 1; }
  ( cd "$wt" && F="$f" L="$l" bash -c "$cmd" >/dev/null 2>&1 ) && { echo "$1 survived its mutation"; return 1; }
  echo "$1 killed"
}
kill AC1.3 epa-1 agents/orchestrator.md 's/(3\. Read `EXAMPLES\.md`.*?), without the Read\s+tool.s line-number prefixes/$1/s' || exit 1
kill AC2.2 epa-2 agents/reviewer.md 's/one-line\s+consequence/consequence/' || exit 1
kill AC2.3 epa-2 templates/persona-protocol.md 's/\z/\nno new tool, no rendering\n/' || exit 1
kill AC3.2 epa-3 tests/validate.sh 's/^if bash tests\/packet-view-script\.test\.sh; then/if true; then/m' || exit 1
kill AC3.3 epa-3 adapters/cursor/rules/persona-protocol.mdc 's/`run\.sh` and `view\.sh` commands/`run.sh` command/' || exit 1
kill AC4.4 epa-4 templates/persona-protocol.md 's/under the exact `Non-blocking notes:` anchor/under the exact\n`Non-blocking notes:` anchor/' || exit 1
kill AC4.6 epa-4 agents/orchestrator.md 's/(6\. Make the \*\*prompt-confirmed decision write\*\*: run exactly one Bash) call/$1 command/' || exit 1
