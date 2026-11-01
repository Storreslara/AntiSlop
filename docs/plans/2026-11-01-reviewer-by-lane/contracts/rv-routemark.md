Unit: rv-routemark

## Objective
A reviewer dispatch marks the open flags (plan unit 6, D5). In `hooks/scripts/lib/reviewer-route-gate-core.sh`, at the end of the reviewer-target block, after the `name:` check passes, and only when `reviewGating.mode` is not `off`: every `${dot}/.pending-review.*` whose first line starts with none of `defer: `, `skip: ` or `review-dispatched: ` is rewritten so its first line is `review-dispatched: <UTC ts>` and its old content follows. When n flags were rewritten (n ≥ 1), append `<ts> review-dispatched flags=<n>` to `review-audit.log`. The dispatch is still allowed (exit 0); the existing block on the next gated dispatch is unchanged. Tests `(rv-r1)`-`(rv-r5)` in `tests/reviewer-route-gate-caller.test.sh`: a plain flag is marked; a `defer:` flag is left alone; under mode off nothing is touched; a reviewer dispatch refused by the name check touches nothing; after marking, a gated lead-programmer dispatch is still blocked and `hooks/scripts/stop-gate.sh` lets a main Stop through. One `[Unreleased]` CHANGELOG bullet, no version bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 6, D5. This file is the contract of record. Depends on rv-mainstop (`(rv-r5)` needs its rule-3 case).

## Affected files
- `hooks/scripts/lib/reviewer-route-gate-core.sh`
- `tests/reviewer-route-gate-caller.test.sh`
- `CHANGELOG.md`
- `adapters/codex/hooks/scripts/lib/reviewer-route-gate-core.sh`, `adapters/cursor/hooks/scripts/lib/reviewer-route-gate-core.sh` and the `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/reviewer-route-gate.sh`, `hooks/scripts/lib/stop-gate-core.sh`, `hooks/scripts/lib/state-access.sh`, `eval/`, `tests/abtest-arms.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/reviewer-route-gate-caller.test.sh); r=$?; grep -oE '^OK   \(rv-r[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `5`
   mutation: drop the mode-off condition on the rewrite → `(rv-r3)` FAILs, exit 1; move the rewrite before the name check → `(rv-r4)` FAILs.
2. run: `{ bash tests/stop-gate.test.sh && bash tests/adapter-stop-gate-parity.test.sh && bash tests/state-access-constraints.test.sh && bash tests/state-distinctions-manifest.test.sh && bash tests/self-report-tally.test.sh && bash tests/review-gating-off.test.sh; } >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: drop the mode-off condition on the existing flag block that blocks gated dispatches → `tests/review-gating-off.test.sh` exits 1.
3. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `adapters/cursor/hooks/scripts/lib/reviewer-route-gate-core.sh` to HEAD~1 → exit 1.
4. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
