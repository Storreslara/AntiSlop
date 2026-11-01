Unit: rv-prose

## Objective
Plan unit 4 (D2, D7, D8). Orchestrator small bullet: on ready-for-review run `bash .claude/bin/unit-bookkeeping.sh check <task-id> <baseline>` (plus `--contract`) instead of the reviewer, report `unchecked-by-reviewer (small lane): precheck PASS`, and after `fail`/`escalate` run `unit-size.sh <task-id> --at-least medium --contract <file>`. "Every unit in every lane gets its reviewer." becomes "Medium and full units always get their reviewer (if present); in agent-teams mode every unit does." Protocol: small-lane exception in "Review ownership"; no flag for a small `dispatch-lane.log` record in "Pending-review flag". Rationale entry: 43 of 43 PASS, $46.6, 37%. For the scribe, `check: pass` is done and the issue stays on the `open:` line. Pins `(rv-o1)`-`(rv-o5)` ((k) block, both copies): check command, report string, new sentence (old gone), `--at-least medium --contract <file>`, `open:`. One `[Unreleased]` bullet, no bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 4. Depends on rv-tools, rv-harden and rv-stopgate.

## Affected files
- `agents/orchestrator.md`
- `templates/persona-protocol.md`
- `docs/orchestrator-rationale.md`
- `tests/unit-size.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `agents/reviewer.md`, `agents/scribe.md`, `hooks/`, `bin/`, `adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc`, `eval/`, `tests/abtest-arms.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/unit-size.test.sh); r=$?; grep -oE '^OK   \(rv-o[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `5`
   mutation: restore "Every unit in every lane gets its reviewer." → `(rv-o3)` FAILs, exit 1.
2. run: `! grep -qF 'Every unit in every lane gets its reviewer.' agents/orchestrator.md && grep -qF 'dispatch-lane.log' templates/persona-protocol.md && tr -s ' \n' ' ' < docs/orchestrator-rationale.md | grep -qF '43 of 43' && echo ok`
   exit: 0
   stdout: `ok`
   mutation: drop the rationale entry → exit 1.
3. run: `[ "$(wc -c < agents/orchestrator.md)" -le 16384 ] && [ "$(wc -c < .claude/agents/orchestrator.md)" -le 40960 ] && echo ok`
   exit: 0
   stdout: `ok`
   mutation: append 700 bytes to `agents/orchestrator.md` → exit 1.
4. run: `{ node tests/adapter-protocol-parity.test.js && node tests/protocol-doc-drift.test.js && node tests/protocol-cross-references.test.js && bash tests/persona-prose-pins.test.sh; } >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: rename the protocol heading "## Review ownership — one unit, one review, single owner" → exit 1.
5. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `.claude/agents/orchestrator.md` to HEAD~1 → exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
