Unit: l2-slim

## Objective
Plan unit 2 (highest risk). `bin/cli.js`: the lead-programmer (LP) row drops Structural questions and Continuing after a FAIL (name its other universal sections, no spread); the reviewer row drops Teammate Write/Edit fallback and Pending-review flag. `agents/reviewer.md`: `skills: antislop:roast-work`; the ubiquitous-language bullet turns on-demand and advisory: "invoke `antislop:ubiquitous-language` in diff mode when the range adds or renames a domain term, or changes `CONTEXT.md` or a docs page."; the stop-gate bullet gains "Rewording a command so that a gate's scan misses it is the same bypass." Pin the four drops in the cross-references test; fix the stale reviewer-row comment in `tests/cli-backfill.test.js`. In `tests/persona-prose-pins.test.sh`, line 48 becomes `hasnot .claude/agents/lead-programmer.md '## Structural questions'` and line 50 drops the reviewer. One `[Unreleased]` bullet naming `l2-slim`.

## Retrieval
`docs/plans/2026-11-02-lean-pipeline-2.md`, unit 2.

## Affected files
- `bin/cli.js`
- `agents/reviewer.md`
- `tests/protocol-cross-references.test.js`
- `tests/cli-backfill.test.js`
- `tests/persona-prose-pins.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, via `--update --force-render` only

## Do NOT touch
- `templates/persona-protocol.md`, `agents/lead-programmer.md`, `adapters/`

## Acceptance criteria
1. run: `echo $(grep -cE '^## (Structural|Continuing after)' .claude/agents/lead-programmer.md) $(grep -cE '^## (Teammate|Pending-review)' .claude/agents/reviewer.md)`
   exit: 0
   stdout: `0 0`
   mutation: reviewer row unchanged → `0 2`.
2. run: `echo $(grep -c '^## ' .claude/agents/lead-programmer.md) $(grep -c '^## ' .claude/agents/reviewer.md)`
   exit: 0
   stdout: `14 12`
   mutation: drop the LP memory note → `13 12`.
3. run: `[ "$(wc -c < .claude/agents/lead-programmer.md)" -le 25200 ] && [ "$(wc -c < .claude/agents/reviewer.md)" -le 42500 ] && echo ok`
   exit: 0
   stdout: `ok`
   mutation: skip the LP row edit → exit 1.
4. run: `for f in agents/reviewer.md .claude/agents/reviewer.md; do grep -qx 'skills: antislop:roast-work' "$f" && tr -s ' \n' ' ' <"$f" | grep -F 'in diff mode when' | grep -qF 'is the same bypass.' || echo "$f"; done`
   exit: 0
   stdout: empty
   mutation: old skills line → both paths.
5. run: `node tests/protocol-cross-references.test.js >/dev/null 2>&1 && node tests/cli-backfill.test.js >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: LP row keeps Continuing after a FAIL → exit 1.
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: bodies uncommitted → exit 1.
7. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
8. run: `bash tests/persona-prose-pins.test.sh >/dev/null && grep -c '## Structural questions' tests/persona-prose-pins.test.sh`
   exit: 0
   stdout: `1`
   mutation: keep the reviewer on line 50 → exit 1.
