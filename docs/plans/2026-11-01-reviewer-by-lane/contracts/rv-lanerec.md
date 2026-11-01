Unit: rv-lanerec

## Objective
At every gated writer dispatch that already gets a dispatch-baseline record, `dispatch-hygiene.sh` also appends `<ts> tool_use_id=<tu> prompt=<sha256> unit=<id|none> lane=<small|medium|full|none>` to `.claude/reviewed/dispatch-lane.log` (plan decision D3, unit 2). The unit comes from H3's first-non-blank-line `Unit:` regex. The lane is `full` when `.claude/reviewed/<unit>.fail` exists; otherwise it is the word after `lane: ` on the first line of `.claude/bookkeeping/<unit>.lane` when that word is small, medium or full; otherwise it is `none`. Guard it like the baseline block: it never blocks and never changes a verdict. The `dispatch-baseline.log` format does not change. Add one `[Unreleased]` CHANGELOG bullet. No version bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 2. This file is the contract of record.

## Affected files
- `hooks/scripts/dispatch-hygiene.sh`
- `tests/dispatch-hygiene.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/writer-scope-gate.sh`, `tests/writer-scope-gate.test.sh`, `hooks/scripts/stop-gate.sh`, `eval/`, `tests/abtest-arms.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/dispatch-hygiene.test.sh); r=$?; grep -oE '^OK   \(rv-l[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `5`
   mutation: delete the `.fail` override → `(rv-l2)` FAILs, exit 1.
2. run: `bash tests/writer-scope-gate.test.sh >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: append ` lane=x` to the dispatch-baseline line → exit 1.
3. run: `grep -q 'dispatch-lane.log' hooks/scripts/dispatch-hygiene.sh && cmp -s hooks/scripts/dispatch-hygiene.sh .claude/hooks/scripts/dispatch-hygiene.sh && echo ok`
   exit: 0
   stdout: `ok`
   mutation: skip the mirror refresh → `cmp` differs, exit 1.
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `.claude/hooks/scripts/dispatch-hygiene.sh` to HEAD~1 → exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
