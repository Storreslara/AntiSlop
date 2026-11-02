Unit: l2-orch

## Objective
Plan unit 6 (D4, item 5) is the spec: apply its four old → new texts and its two cuts to `agents/orchestrator.md` exactly as quoted there. Commit 29a20135 made two older cuts that tests pin; restore both verbatim from `29a20135^` (the "provided it is unchanged." sentence and the "Review markers and gate mechanics" pointer line). Keep `docs/orchestrator-rationale.md`'s N21 section and append the two new cut sentences to it verbatim. `tests/unit-size.test.sh` `(k)` adds `(l2-o1)`: the new medium sentence in both copies. One `[Unreleased]` CHANGELOG bullet naming `l2-orch`.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 6.

## Affected files
- `agents/orchestrator.md`
- `docs/orchestrator-rationale.md`
- `tests/unit-size.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `bin/`, `templates/`, `hooks/`, `agents/reviewer.md`, any other test file

## Acceptance criteria
1. run: `o=$(bash tests/unit-size.test.sh 2>&1); r=$?; grep -cE '^OK +\(l2-o1\)' <<<"$o"; exit $r`
   exit: 0
   stdout: `2`
   mutation: leave the medium sentence out → stdout `0`, exit 1.
2. run: `for f in agents/orchestrator.md .claude/agents/orchestrator.md; do t=$(tr -s ' \n' ' ' <"$f"); echo "$(grep -oF -e 'no explorer either, as in small (N21).' -e 'no contract and no `repo: small`, outside the small lane' -e 'when the explorer ran, its blast radius.' -e '(N1-N21)' -e 'provided it is unchanged.' -e 'section lists the rest.' <<<"$t" | wc -l) $(grep -oF -e '(N1-N20)' -e "the explorer's blast radius" -e 'Every re-dispatch carries the defect' -e 'You have no Write/Edit tool' <<<"$t" | wc -l)"; done`
   exit: 0
   stdout: `6 0` then `6 0`
   mutation: keep 29a20135's cuts, skip the new ones → `4 2` then `4 2`.
3. run: `awk '/^## N21: /{f=1} f' docs/orchestrator-rationale.md | grep -oF -e 'unit-bookkeeping.sh repo' -e '$0.60' -e '33 s' -e '1,000' -e 'Every re-dispatch carries the defect history or the fix contract.' -e 'You have no Write/Edit tool: every file change goes to the lead-programmer.' | sort -u | wc -l | tr -d ' '`
   exit: 0
   stdout: `6`
   mutation: leave the cut sentences out → stdout `4`.
4. run: `[ "$(wc -c < agents/orchestrator.md)" -le 16384 ] && [ "$(wc -c < .claude/agents/orchestrator.md)" -le 40960 ] && echo ok`
   exit: 0
   stdout: `ok`
   mutation: restore the two texts but skip the two cuts → exit 1.
5. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-orch'`
   exit: 0
   stdout: `1`
   mutation: put the bullet under 0.33.0 → stdout `0`, exit 1.
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/agents/orchestrator.md` stale → exit 1.
7. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
