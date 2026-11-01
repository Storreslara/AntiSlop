Unit: rv-mainstop

## Objective
Two changes in `hooks/scripts/lib/stop-gate-core.sh` (plan unit 5; D5 rule-3 case, D6 block message). (a) Rule 3: a flag whose first line starts with `review-dispatched: ` lets the main Stop through, is kept, and logs nothing; any other flag without `defer: `/`skip: ` still blocks. (b) When `${dot}/bin/unit-bookkeeping.sh` exists, the rule-3 block message names `bash ${dot_label}/bin/unit-bookkeeping.sh flag <defer|skip> <reason>` and contains no `printf`; when it is absent, the current message stays byte-for-byte. Update the header's rule 3. Keep every string `tests/state-distinctions-manifest.test.sh` pins. Tests `(rv-m1)`-`(rv-m4)` in `tests/stop-gate.test.sh`: a review-dispatched flag lets the main Stop through (rc 0) and is kept; with a plain flag as well, the Stop blocks; script present → block text names `unit-bookkeeping.sh flag` and has no `printf`; script absent → old text. One `[Unreleased]` CHANGELOG bullet, no version bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 5, D5 and D6. This file is the contract of record. Depends on rv-tools (the `flag` subcommand) and rv-stopgate.

## Affected files
- `hooks/scripts/lib/stop-gate-core.sh`
- `tests/stop-gate.test.sh`
- `CHANGELOG.md`
- `adapters/codex/hooks/scripts/lib/stop-gate-core.sh`, `adapters/cursor/hooks/scripts/lib/stop-gate-core.sh` and the `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/stop-gate.sh`, `adapters/codex/hooks/scripts/stop-gate.sh`, `adapters/cursor/hooks/scripts/stop-gate.sh`, `hooks/scripts/lib/reviewer-route-gate-core.sh`, `eval/`, `tests/abtest-arms.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/stop-gate.test.sh); r=$?; grep -oE '^OK   \(rv-m[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `4`
   mutation: delete the `review-dispatched: ` case → `(rv-m1)` FAILs, exit 1; drop the script-present branch → `(rv-m3)` FAILs.
2. run: `{ bash tests/adapter-stop-gate-parity.test.sh && bash tests/state-distinctions-manifest.test.sh && bash tests/state-access-constraints.test.sh && bash tests/self-report-tally.test.sh && bash tests/review-gating-off.test.sh; } >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: in the codex core copy only, delete the `defer: ` case → the parity test's case (a) exits 1.
3. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `adapters/codex/hooks/scripts/lib/stop-gate-core.sh` to HEAD~1 → exit 1.
4. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
