Unit: l2-slim

## Objective
Plan unit 2 is the spec (D2, D3; highest risk). In `bin/cli.js`, the lead-programmer row drops Structural questions and Continuing after a FAIL (name its other universal sections, no spread); the reviewer row drops Teammate Write/Edit fallback and Pending-review flag. `agents/reviewer.md`: `skills: antislop:roast-work`; the ubiquitous-language bullet opens "- **`ubiquitous-language` is on-demand and advisory, never gating**: invoke `antislop:ubiquitous-language` in diff mode when the range adds or renames a domain term, or changes `CONTEXT.md` or a docs page." and keeps the rest; the stop-gate bullet gains "Rewording a command so that a gate's scan misses it is the same bypass." The cross-references test pins the four drops; fix the stale reviewer-row comment in `tests/cli-backfill.test.js`. One `[Unreleased]` bullet naming `l2-slim`.

## Retrieval
`docs/plans/2026-11-02-lean-pipeline-2.md`, unit 2.

## Affected files
- `bin/cli.js`
- `agents/reviewer.md`
- `tests/protocol-cross-references.test.js`
- `tests/cli-backfill.test.js`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `templates/persona-protocol.md`, `agents/lead-programmer.md`, `adapters/`

## Acceptance criteria
1. run: `n=0; for p in 'lead-programmer|## Structural questions' 'lead-programmer|## Continuing after a FAIL' 'reviewer|## Teammate Write/Edit' 'reviewer|## Pending-review flag'; do grep -qF -- "${p#*|}" ".claude/agents/${p%%|*}.md" && n=$((n+1)); done; echo $n`
   exit: 0
   stdout: `0`
   mutation: leave the reviewer row unchanged → stdout `2`.
2. run: `echo $(grep -c '^## ' .claude/agents/lead-programmer.md) $(grep -c '^## ' .claude/agents/reviewer.md)`
   exit: 0
   stdout: `14 12`
   mutation: also drop the memory note for lead-programmer → `13 12`.
3. run: `[ "$(wc -c < .claude/agents/lead-programmer.md)" -le 25200 ] && [ "$(wc -c < .claude/agents/reviewer.md)" -le 42500 ] && echo ok`
   exit: 0
   stdout: `ok`
   mutation: skip the lead-programmer row edit → exit 1.
4. run: `for f in agents/reviewer.md .claude/agents/reviewer.md; do t=$(tr -s ' \n' ' ' <"$f"); grep -qx 'skills: antislop:roast-work' "$f" || echo "skills $f"; for p in 'invoke `antislop:ubiquitous-language` in diff mode when' 'is the same bypass.'; do grep -qF -- "$p" <<<"$t" || echo "no $f: $p"; done; done`
   exit: 0
   stdout: empty
   mutation: keep the old skills line → names both copies.
5. run: `node tests/protocol-cross-references.test.js >/dev/null 2>&1 && node tests/cli-backfill.test.js >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: move `Continuing after a FAIL verdict` back to the lead-programmer `include` → exit 1.
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave the bodies uncommitted → exit 1.
7. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
