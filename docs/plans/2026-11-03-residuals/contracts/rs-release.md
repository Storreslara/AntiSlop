Unit: rs-release

## Objective
Plan unit 7 (item 6; D9), last unit. One commit `chore(rs-release): release 0.35.0`: version 0.35.0 in `.claude-plugin/plugin.json` and `package.json`; `## [0.35.0] - <date>` right below an empty `## [Unreleased]`, with one residuals summary bullet above the six unit bullets. In the 0.34.0 section: "and retires `.escalated`" → "and finishes retiring the `.escalated` wording"; add a `(l2-scribe)` bullet (glossary entries, ADR-0046, wiki changelog, retired-name notes; commit d87cbc5d); the l2-abfix bullet's "`(l2-a1)` to `(l2-a4)`" → "`(l2-a1)` to `(l2-a7)`". Run `node bin/cli.js --update --force-render` and commit its `.claude/` re-stamps in the same commit.

## Retrieval
No tracker issue; plan unit 7 in `docs/plans/2026-11-03-residuals.md`.

## Affected files
- `.claude-plugin/plugin.json`
- `package.json`
- `CHANGELOG.md`
- `.claude/` re-stamps, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `agents/`, `hooks/`, `bin/`, `tests/`, `adapters/`, `docs/`

## Acceptance criteria
1. run: `cat .claude-plugin/plugin.json package.json | grep -c '"version": "0.35.0",'`
   exit: 0
   stdout: `2`
   mutation: one unbumped → `1`.
2. run: `grep -nE '^## \[' CHANGELOG.md | head -2 | sed -E 's/ - [0-9-]{10}$/ - D/'`
   exit: 0
   stdout: `3:## [Unreleased]` then `5:## [0.35.0] - D`
   mutation: no heading → second line names `[0.34.0]`.
3. run: `s=$(sed -n '/^## \[0\.35/,/^## \[0\.34/p' CHANGELOG.md); n=0; for u in stamp corelib check tokens prose docs; do grep -qw "rs-$u" <<<"$s" && n=$((n+1)); done; echo $n`
   exit: 0
   stdout: `6`
   mutation: heading below one unit bullet → `5`.
4. run: `c=$(git log -1 --format=%H -F --grep='(rs-release)'); [ -n "$c" ] || exit 1; bash hooks/scripts/version-stamp-check.sh "$c^..$c" | cut -d' ' -f1,2`
   exit: 0
   stdout: `version-stamp-check: ok`
   mutation: no 0.35.0 heading → `version-stamp-check: violation`.
5. run: `git grep -lE 'antislop v0\.34\.|"pluginVersion": "0\.34\.' -- .claude | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip `--update` → non-zero (baseline `13`).
6. run: `g="-F --grep=(rs-release)"; echo $(git log --oneline $g | wc -l) $(git log --format= --name-only $g | grep . | grep -vxcE '\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md|\.claude/.+')`
   exit: 0
   stdout: `1 0`
   mutation: also commit `agents/scribe.md` → `1 1`.
7. run: `s=$(sed -n '/^## \[0\.34/,/^## \[0\.33/p' CHANGELOG.md); echo $(grep -c 'and retires `.escalated`' <<<"$s") $(grep -c '(l2-scribe)' <<<"$s") $(grep -c '`(l2-a1)` to `(l2-a7)`' <<<"$s")`
   exit: 0
   stdout: `0 1 1`
   mutation: no l2-scribe bullet → `0 0 1` (baseline `1 0 0`).
8. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: re-stamps uncommitted → exit 1.
9. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms; after the final commit)
   exit: 0
   stdout: empty
   mutation: any suite failure → exit 1.
