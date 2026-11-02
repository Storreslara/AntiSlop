Unit: rs-corelib

## Objective
Plan unit 2 (items 5, 7, 9; D7). (a) `hooks/scripts/lib/stop-gate-core.sh:30` comment "at each gated dispatch" → "at each allowed gated dispatch". (b) D7: the no-script branch's `ns_tail` (:52, "write 'defer: <reason>' or 'skip: <reason>' into a flag that exists.") becomes "ask the user to add a first line 'defer: <reason>' or 'skip: <reason>' to a flag that exists."; the script branch and its pin `(l2-g1)` stay; pin `(l2-g2)` in `tests/stop-gate.test.sh` moves to the new text (its old-text grep is replaced, its id kept). (c) The comment above `state_replace_pending_review` in `hooks/scripts/lib/state-access.sh` ends "...with a 644 file; the fallback create after a mktemp or mv failure uses the umask." (d) `(rs-r1)` in `tests/reviewer-route-gate-caller.test.sh`: an allowed reviewer dispatch with `.claude` made read-only (`chmod a-w`; SKIP when root; restored for cleanup) leaves a plain flag's first line unchanged, rc 0, no `review-dispatched flags=` audit line. One `[Unreleased]` CHANGELOG bullet naming `rs-corelib`.

## Retrieval
No tracker issue; plan unit 2 in `docs/plans/2026-11-03-residuals.md`.

## Affected files
- `hooks/scripts/lib/stop-gate-core.sh`
- `hooks/scripts/lib/state-access.sh`
- `tests/stop-gate.test.sh`
- `tests/reviewer-route-gate-caller.test.sh`
- `CHANGELOG.md`
- `.claude/` and `adapters/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/*.sh` entry scripts, `hooks/scripts/lib/reviewer-route-gate-core.sh`, `bin/`, `agents/`

## Acceptance criteria
1. run: `for d in hooks/scripts/lib .claude/hooks/scripts/lib adapters/codex/hooks/scripts/lib adapters/cursor/hooks/scripts/lib; do echo $(grep -c 'at each allowed gated dispatch' $d/stop-gate-core.sh) $(grep -c 'into a flag that exists' $d/stop-gate-core.sh) $(grep -c 'uses the umask' $d/state-access.sh); done | sort -u`
   exit: 0
   stdout: `1 0 1`
   mutation: one copy stale → a second line `0 1 0` (baseline: `0 1 0` only).
2. run: `o=$(bash tests/stop-gate.test.sh 2>&1); r=$?; grep -c "^OK   (l2-g2)" <<<"$o"; grep -c 'ask the user to add a first line' tests/stop-gate.test.sh; exit $r`
   exit: 0
   stdout: `1` then `1`
   mutation: old message kept in the lib → `(l2-g2)` FAIL, exit 1.
3. run: `o=$(bash tests/reviewer-route-gate-caller.test.sh 2>&1); r=$?; grep -c '^OK   (rs-r1)' <<<"$o"; exit $r`
   exit: 0
   stdout: `1`
   mutation: on mktemp failure write the mark in place (`> "$flag"`) → FAIL, exit 1.
4. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.34\.0\]/p' CHANGELOG.md | grep -c 'rs-corelib'`
   exit: 0
   stdout: `1`
   mutation: no bullet → `0`, exit 1.
5. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave an `adapters/` lib copy stale → exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
   mutation: any suite failure → exit 1.
