Unit: rs-check

## Objective
Plan unit 3 (item 2, D4). In `bin/unit-bookkeeping.sh` `check_tree`, right after the `index-flags` rule (:122), add: `git -C "$CK_TOP" ls-files -s` failing, or listing a mode-160000 entry (a gitlink) → `finish escalate submodule`. Never scan inside a submodule: a submodule repo loses the small lane, never the review. Extend the C1-C2c comment (:113) to name the submodule rule. Test `(rs-k1)` in `tests/unit-bookkeeping.test.sh`: a fixture whose HEAD commits a gitlink (`git update-index --add --cacheinfo 160000,<sha>,sub`) → `check: escalate unit=ue reason=submodule`; `(l2-k3)` still passes. One `[Unreleased]` CHANGELOG bullet naming `rs-check`.

## Retrieval
No tracker issue; plan unit 3 in `docs/plans/2026-11-03-residuals.md`.

## Affected files
- `bin/unit-bookkeeping.sh`
- `tests/unit-bookkeeping.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/`, `bin/review-precheck.sh`, `agents/`

## Acceptance criteria
1. run: `o=$(bash tests/unit-bookkeeping.test.sh 2>&1); r=$?; grep -c '^OK   (rs-k1)' <<<"$o"; grep -c '^OK   (l2-k3)' <<<"$o"; exit $r`
   exit: 0
   stdout: `1` then `1`
   mutation: drop the submodule rule → `(rs-k1)` FAIL, first line `0`, exit 1.
2. run: `grep -c 'finish escalate submodule' bin/unit-bookkeeping.sh .claude/bin/unit-bookkeeping.sh`
   exit: 0
   stdout: `bin/unit-bookkeeping.sh:1` then `.claude/bin/unit-bookkeeping.sh:1`
   mutation: mirror stale → `.claude/bin/unit-bookkeeping.sh:0`.
3. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.34\.0\]/p' CHANGELOG.md | grep -c 'rs-check'`
   exit: 0
   stdout: `1`
   mutation: no bullet → `0`, exit 1.
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/bin/unit-bookkeeping.sh` stale → exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
   mutation: any suite failure → exit 1.
