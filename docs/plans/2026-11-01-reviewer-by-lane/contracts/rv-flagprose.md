Unit: rv-flagprose

## Objective
The prose stops prescribing a Bash redirect into the flag (plan unit 7, D5, D6). In `agents/orchestrator.md`, replace "To end your turn during a background review, write `defer: <reason>` into the flag." with: a reviewer dispatch marks the flags `review-dispatched:`, so the turn may end; any other defer or skip goes through `bash .claude/bin/unit-bookkeeping.sh flag defer|skip <reason>`. The protocol's escape-hatch paragraph and the digest's flag line say the same. Sticky and abandon semantics do not change. Pins `(rv-p1)`-`(rv-p3)` in `tests/stop-gate.test.sh`: orchestrator, protocol, digest (deployed copies too). One `[Unreleased]` CHANGELOG bullet, no version bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 7, D5 and D6. This file is the contract of record. Depends on rv-routemark and rv-prose.

## Affected files
- `agents/orchestrator.md`
- `templates/persona-protocol.md`
- `templates/protocol-digest.md`
- `tests/stop-gate.test.sh`
- `CHANGELOG.md`
- `docs/orchestrator-rationale.md`, only to meet criterion 3
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc`, `agents/reviewer.md`, `hooks/`, `bin/`, `eval/`, `tests/abtest-arms.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/stop-gate.test.sh); r=$?; grep -oE '^OK   \(rv-p[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `3`
   mutation: restore the old orchestrator sentence → `(rv-p1)` FAILs, exit 1.
2. run: `for f in agents/orchestrator.md .claude/agents/orchestrator.md templates/persona-protocol.md templates/protocol-digest.md .claude/protocol-digest.md; do tr -s ' \n' ' ' < "$f" | grep -qF 'unit-bookkeeping.sh flag' || echo "missing $f"; done; tr -s ' \n' ' ' < agents/orchestrator.md | grep -qF 'To end your turn during a background review, write' && echo old; true`
   exit: 0
   stdout: empty
   mutation: skip the digest edit → stdout names both digest copies.
3. run: `[ "$(wc -c < agents/orchestrator.md)" -le 16384 ] && [ "$(wc -c < .claude/agents/orchestrator.md)" -le 40960 ] && echo ok`
   exit: 0
   stdout: `ok`
   mutation: append 1,000 bytes to `agents/orchestrator.md` → exit 1.
4. run: `{ node tests/adapter-protocol-parity.test.js && node tests/protocol-doc-drift.test.js && node tests/protocol-cross-references.test.js && bash tests/persona-prose-pins.test.sh; } >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: rename the heading "## Pending-review flag (default-mode review backstop)" → exit 1.
5. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `.claude/protocol-digest.md` to HEAD~1 → exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
