Unit: rv-flagprose

## Objective
Plan unit 7 (D5, D6, finding 2026-11-01) gives the exact `agents/orchestrator.md` sentences and the
byte cuts and moves; make exactly those and change no other rule. The protocol escape-hatch paragraph and
the digest flag line name `unit-bookkeeping.sh flag`; sticky and abandon semantics stay. Pins
`(rv-p1)`-`(rv-p5)` in `tests/stop-gate.test.sh`. One `[Unreleased]` CHANGELOG bullet, no version bump.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 7.

## Affected files
- `agents/orchestrator.md`
- `templates/persona-protocol.md`
- `templates/protocol-digest.md`
- `tests/stop-gate.test.sh`
- `CHANGELOG.md`
- `docs/orchestrator-rationale.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `adapters/`, `agents/reviewer.md`, `hooks/`, `bin/`, `eval/`, `tests/abtest-arms.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/stop-gate.test.sh); r=$?; grep -oE '^OK   \(rv-p[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `5`
   mutation: restore "(2) spawn the reviewer (if present) with the" → `(rv-p4)` FAILs, exit 1.
2. run: `for f in agents/orchestrator.md .claude/agents/orchestrator.md; do t=$(tr -s ' \n' ' ' <"$f"); for p in 'marks open flags `review-dispatched:`, so your turn may end' 'flag defer|skip <reason>`' 'a small unit gets `check`, see "Lane routing")' "flag left by its writer's stop (it overrides"; do grep -qF -- "$p" <<<"$t" || echo "no $f: $p"; done; grep -qF 'into the flag.' <<<"$t" && echo "old $f"; done; true`
   exit: 0
   stdout: empty
   mutation: drop the flag clause, re-render → stdout names both copies.
3. run: `t=$(tr -s ' \n' ' ' <docs/orchestrator-rationale.md); for p in 'provided it is unchanged' 'holds the arithmetic' 'has the new lane' 'unnamed dispatch returns its result'; do grep -qF -- "$p" <<<"$t" || echo "no $p"; done; for f in templates/persona-protocol.md templates/protocol-digest.md .claude/protocol-digest.md; do tr -s ' \n' ' ' <"$f" | grep -qF 'unit-bookkeeping.sh flag' || echo "no $f"; done`
   exit: 0
   stdout: empty
   mutation: skip the N4 move → stdout `no unnamed dispatch returns its result`.
4. run: `[ "$(wc -c < agents/orchestrator.md)" -le 16384 ] && [ "$(wc -c < .claude/agents/orchestrator.md)" -le 40960 ] && echo ok`
   exit: 0
   stdout: `ok`
   mutation: append 200 bytes to `agents/orchestrator.md` → exit 1.
5. run: `{ bash tests/prompt-diet-pins.test.sh && bash tests/unit-size.test.sh && bash tests/persona-prose-pins.test.sh; } >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: delete "(see "Lane routing")" from the routing table → exit 1.
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `.claude/protocol-digest.md` to HEAD~1 → exit non-zero.
7. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
