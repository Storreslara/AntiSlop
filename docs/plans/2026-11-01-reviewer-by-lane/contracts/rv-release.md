Unit: rv-release

## Objective
Release 0.33.0 (plan unit 9, D9; constitution P3). One commit bumps `version` in `.claude-plugin/plugin.json` and `package.json` from 0.32.0 to 0.33.0 and adds, directly below `## [Unreleased]`, the heading `## [0.33.0] - <today>` followed by one summary bullet naming the reviewer-by-lane release (ADR-0045). Everything already under `[Unreleased]` becomes 0.33.0 content. `node bin/cli.js --update` re-stamps the `.claude/` mirrors and `pluginVersion`; they go in the same commit. Message: `chore(rv-release): release 0.33.0`. No other change.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 9. This file is the contract of record. Dispatch after rv-scribe has passed; it is the plan's last unit.

## Affected files
- `.claude-plugin/plugin.json`
- `package.json`
- `CHANGELOG.md`
- `.claude/` tracked files, written only by `node bin/cli.js --update`

## Do NOT touch
- `agents/`, `templates/`, `skills/`, `adapters/`, `hooks/`, `bin/`, `tests/`, `docs/`, `.claude-plugin/marketplace.json`, `eval/`

## Acceptance criteria
1. run: `cat .claude-plugin/plugin.json package.json | grep -c '"version": "0.33.0",'`
   exit: 0
   stdout: `2`
   mutation: leave `package.json` at 0.32.0 → stdout `1`.
2. run: `grep -nE '^## \[' CHANGELOG.md | head -2 | sed -E 's/ - [0-9]{4}-[0-9]{2}-[0-9]{2}$/ - DATE/'`
   exit: 0
   stdout: `3:## [Unreleased]` then `5:## [0.33.0] - DATE`
   mutation: skip the heading → second line `5:## [0.32.0] - DATE`.
3. run: `c=$(git log --format=%H -F --grep='(rv-release)' | head -1); [ -n "$c" ] || exit 1; bash hooks/scripts/version-stamp-check.sh "$c^..$c" | cut -d' ' -f1,2`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: commit the bump without the CHANGELOG heading → `version-stamp-check: violation`.
4. run: `git grep -lE 'antislop v0\.32\.|"pluginVersion": "0\.32\.' -- .claude | wc -l | tr -d ' '`
   exit: 0
   stdout: `0`
   mutation: skip `node bin/cli.js --update` → 13 or more.
5. run: `cs=$(git log --format=%H -F --grep='(rv-release)'); [ -n "$cs" ] || exit 1; echo "commits=$(echo "$cs" | wc -l | tr -d ' ') other=$(for c in $cs; do git show --name-only --format= $c; done | sort -u | grep -vxE '\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md|\.claude/.+' | wc -l | tr -d ' ')"`
   exit: 0
   stdout: `commits=1 other=0`
   mutation: also stage `agents/scribe.md` in the release commit → `commits=1 other=1`.
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave the re-stamped `.claude/` files unstaged → exit 1.
7. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
