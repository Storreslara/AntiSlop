Unit: l2-ttl

## Objective
Plan unit 1 (D1, item 2). In `agents/reviewer.md` delete the frontmatter lines `experimental:` and `  cacheTtl: 1h`; change nothing else in it. In `tests/validate.sh`, replace the block headed `== reviewer: cacheTtl nested under experimental:, not top-level ==` with one headed `== reviewer: no cacheTtl (5m default, l2-ttl) ==` that, for `agents/reviewer.md`, prints `FAIL agents/reviewer.md (cacheTtl present - l2-ttl dropped it)` and sets `fail=1` when `grep -qE '^[[:space:]]*cacheTtl:'` matches, else `OK   agents/reviewer.md`. One `[Unreleased]` CHANGELOG bullet naming `l2-ttl` with D1's figures (about $6.0 of $10.1 over 25 runs; 14 cross-run hits lost). No version bump.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 1.

## Affected files
- `agents/reviewer.md`
- `tests/validate.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `adapters/`, `bin/`, `hooks/`, `templates/`, `.claude-plugin/plugin.json`, `skills/`, `eval/`

## Acceptance criteria
1. run: `cat agents/reviewer.md .claude/agents/reviewer.md | grep -c 'cacheTtl' || true`
   exit: 0
   stdout: `0`
   mutation: skip the mirror refresh → stdout `1`.
2. run: `for f in agents/reviewer.md .claude/agents/reviewer.md; do awk 'NR==1{next} /^---$/{exit} /^(experimental|model|effort|tools|skills|maxTurns):/{print $1}' "$f" | tr '\n' ' '; echo; done`
   exit: 0
   stdout: `model: effort: tools: skills: maxTurns: ` then `model: effort: tools: skills: maxTurns: `
   mutation: delete `effort: high` as well → both lines lose `effort:`.
3. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-ttl'`
   exit: 0
   stdout: `1`
   mutation: put the bullet under 0.33.0 → stdout `0`, exit 1.
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/agents/reviewer.md` uncommitted after the refresh → exit 1.
5. run: `grep -cE 'no cacheTtl \(5m default, l2-ttl\)|cacheTtl present - l2-ttl dropped it' tests/validate.sh`
   exit: 0
   stdout: `2`
   mutation: remove the `no cacheTtl` guard block from `tests/validate.sh` → stdout `0`, exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (long, deferred; Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
   mutation: put `  cacheTtl: 1h` back under `model:` in `agents/reviewer.md` → the guard sets `fail=1`, exit 1.
