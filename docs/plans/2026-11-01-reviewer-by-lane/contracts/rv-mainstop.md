Unit: rv-mainstop

## Objective
Three changes in `hooks/scripts/lib/stop-gate-core.sh` (plan unit 5; D5, D6). (a) Rule 3: a flag whose first line starts with `review-dispatched: ` lets the main Stop through, is kept, logs nothing; any other flag without `defer: `/`skip: ` still blocks. (b) When `${dot}/bin/unit-bookkeeping.sh` exists, the rule-3 block message names `bash ${dot_label}/bin/unit-bookkeeping.sh flag <defer|skip> <reason>`, no `printf`; absent, the old message stays byte-for-byte. (c) Rule 6, fail-closed: when `writer_lane` is `small` and the D6 marker check trips, write the flag and log `<ts> small-lane d6-trip agent=<id> flag` (no `no-flag` line) before the block; untripped small stops still write no flag. Update header rules 3 and 6. Keep every string `tests/state-distinctions-manifest.test.sh` pins. Tests in `tests/stop-gate.test.sh`: `(rv-m1)` review-dispatched flag: main Stop rc 0, flag kept; `(rv-m2)` plus a plain flag: blocks; `(rv-m3)` script present: text names `unit-bookkeeping.sh flag`, no `printf`; `(rv-m4)` absent: old text; `(rv-m5)` small record + marker newer than stamp: writer rc 2, flag written, d6-trip line logged, then main Stop rc 2. One `[Unreleased]` CHANGELOG bullet, no version bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 5, D4-D6. Contract of record. Depends on rv-tools and rv-stopgate.

## Affected files
- `hooks/scripts/lib/stop-gate-core.sh`
- `tests/stop-gate.test.sh`
- `CHANGELOG.md`
- `adapters/codex/hooks/scripts/lib/stop-gate-core.sh`, `adapters/cursor/hooks/scripts/lib/stop-gate-core.sh` and the `.claude/` copies, only via `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/stop-gate.sh`, both adapter `stop-gate.sh` entries, `hooks/scripts/lib/reviewer-route-gate-core.sh`, `eval/`, `tests/abtest-arms.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/stop-gate.test.sh); r=$?; grep -oE '^OK   \(rv-m[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `5`
   mutation: delete the `review-dispatched: ` case → `(rv-m1)` FAILs, exit 1; drop the script-present branch → `(rv-m3)` FAILs; skip the flag write on a small D6 trip → `(rv-m5)` FAILs.
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
