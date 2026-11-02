Unit: l2-release

## Objective
Plan unit 16. Release 0.34.0 (P3), one commit `chore(l2-release): release 0.34.0`: `version` 0.34.0 in `.claude-plugin/plugin.json` and `package.json`; `## [0.34.0] - <today>` below `## [Unreleased]` with one lean-pipeline-2 bullet; `node bin/cli.js --update`'s `.claude/` output.
Fix two bullets, no others:
- l2-ttl: `it cost about $6.0 of $10.1 ... were lost` becomes `dropping it saves about $6.0 net over 25 runs ($10.1 gross less $4.1 for 14 lost cross-run cache hits; about 4.7% of Arm B)`.
- l2-slim: `24,850` and `42,160` become `wc -c` of `.claude/agents/lead-programmer.md` and `reviewer.md` after `--update`, with commas.

## Affected files
- `.claude-plugin/plugin.json`
- `package.json`
- `CHANGELOG.md`
- `.claude/` files written by `--update`

## Do NOT touch
- `agents/`, `templates/`, `skills/`, `adapters/`, `hooks/`, `bin/`, `tests/`, `docs/`, `eval/`, `.claude-plugin/marketplace.json`

## Acceptance criteria
1. run: `cat .claude-plugin/plugin.json package.json | grep -c '"version": "0.34.0",'`
   exit: 0
   stdout: `2`
   mutation: `package.json` unbumped → `1`.
2. run: `grep -nE '^## \[' CHANGELOG.md | head -2 | sed -E 's/ - [0-9-]{10}$/ - D/'`
   exit: 0
   stdout: `3:## [Unreleased]` then `5:## [0.34.0] - D`
   mutation: no heading → `[0.33.0]` second.
3. run: `s=$(sed -n '/^## \[0\.34/,/^## \[0\.33/p' CHANGELOG.md); n=0; for u in ttl slim bkhdr prebr revprose orch abfix h4 gatemsg ports sg1 sg2 ckhard scope retired tests; do grep -qw "l2-$u" <<<"$s" && n=$((n+1)); done; echo $n`
   exit: 0
   stdout: `16`
   mutation: heading below one bullet → `15`.
4. run: `c=$(git log -1 --format=%H -F --grep='(l2-release)'); [ -n "$c" ] || exit 1; bash hooks/scripts/version-stamp-check.sh "$c^..$c" | cut -d' ' -f1,2`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: no heading → `version-stamp-check: violation`.
5. run: `git grep -lE 'antislop v0\.33\.|"pluginVersion": "0\.33\.' -- .claude | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip `--update` → 13.
6. run: `g="-F --grep=(l2-release)"; echo $(git log --oneline $g | wc -l) $(git log --format= --name-only $g | grep -vxcE '\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md|\.claude/.+|')`
   exit: 0
   stdout: `1 0`
   mutation: also commit `agents/scribe.md` → `1 1`.
7. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: re-stamps uncommitted → exit 1.
8. run: `echo $(grep -cF '$6.0 net over 25 runs ($10.1 gross less $4.1' CHANGELOG.md) $(grep -cF '$6.0 of $10.1' CHANGELOG.md)`
   exit: 0
   stdout: `1 0`
   mutation: old l2-ttl text → `0 1`.
9. run: `grep -F '(l2-slim)' CHANGELOG.md | tr -d , | (cd .claude/agents; grep -c "29325 to $(wc -c <lead-programmer.md).*45770 to $(wc -c <reviewer.md)")`
   exit: 0
   stdout: `1`
   mutation: `24,850` kept → exit 1.
10. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms)
   exit: 0
   stdout: empty
