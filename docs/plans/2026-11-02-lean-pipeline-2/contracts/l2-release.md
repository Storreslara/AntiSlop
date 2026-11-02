Unit: l2-release

## Objective
Release 0.34.0 (plan unit 16; constitution P3). One commit bumps `version` in `.claude-plugin/plugin.json` and `package.json` from 0.33.0 to 0.34.0 and adds, directly below `## [Unreleased]`, the heading `## [0.34.0] - <today>` and one summary bullet naming lean-pipeline-2. Every bullet now under `[Unreleased]` becomes 0.34.0 content. `node bin/cli.js --update` re-stamps the `.claude/` mirrors and `pluginVersion`; they go in the same commit. Message: `chore(l2-release): release 0.34.0`. No other change.

## Retrieval
No tracker issue; plan `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 16. Dispatch after l2-scribe has passed; it is the plan's last unit.

## Affected files
- `.claude-plugin/plugin.json`
- `package.json`
- `CHANGELOG.md`
- `.claude/` tracked files, written only by `node bin/cli.js --update`

## Do NOT touch
- `agents/`, `templates/`, `skills/`, `adapters/`, `hooks/`, `bin/`, `tests/`, `docs/`, `eval/`, `.claude-plugin/marketplace.json`

## Acceptance criteria
1. run: `cat .claude-plugin/plugin.json package.json | grep -c '"version": "0.34.0",'`
   exit: 0
   stdout: `2`
   mutation: leave `package.json` at 0.33.0 → `1`.
2. run: `grep -nE '^## \[' CHANGELOG.md | head -2 | sed -E 's/ - [0-9]{4}-[0-9]{2}-[0-9]{2}$/ - DATE/'`
   exit: 0
   stdout: `3:## [Unreleased]` then `5:## [0.34.0] - DATE`
   mutation: skip the heading → second line `5:## [0.33.0] - DATE`.
3. run: `s=$(sed -n '/^## \[0\.34\.0\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md); n=0; for u in ttl slim bkhdr prebr revprose orch abfix h4 gatemsg ports sg1 sg2 ckhard scope retired tests; do grep -qw "l2-$u" <<<"$s" && n=$((n+1)); done; echo $n`
   exit: 0
   stdout: `16`
   mutation: heading placed below the first bullet → `15`.
4. run: `c=$(git log --format=%H -F --grep='(l2-release)' | head -1); [ -n "$c" ] || exit 1; bash hooks/scripts/version-stamp-check.sh "$c^..$c" | cut -d' ' -f1,2`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: commit the bump without the CHANGELOG heading → `version-stamp-check: violation`.
5. run: `git grep -lE 'antislop v0\.33\.|"pluginVersion": "0\.33\.' -- .claude | wc -l | tr -d ' '`
   exit: 0
   stdout: `0`
   mutation: skip `node bin/cli.js --update` → 13.
6. run: `cs=$(git log --format=%H -F --grep='(l2-release)'); [ -n "$cs" ] || exit 1; echo "commits=$(echo "$cs" | wc -l | tr -d ' ') other=$(for c in $cs; do git show --name-only --format= $c; done | sort -u | grep -vxE '\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md|\.claude/.+' | wc -l | tr -d ' ')"`
   exit: 0
   stdout: `commits=1 other=0`
   mutation: also stage `agents/scribe.md` in the release commit → `other=1`.
7. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave the re-stamped `.claude/` files unstaged → exit 1.
8. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
