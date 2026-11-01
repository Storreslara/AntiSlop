Unit: rv-tools

## Objective
Add `unit-size.sh --at-least <medium|full>`, `unit-bookkeeping.sh check` (rules C1-C8) and `unit-bookkeeping.sh flag <defer|skip> <reason>`, exactly as specified in plan unit 1 and decisions D1, D2 and D6. Add the test cases named there. Add one `[Unreleased]` CHANGELOG bullet. No version bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 1. This file is the contract of record.

## Affected files
- `bin/unit-size.sh`
- `bin/unit-bookkeeping.sh`
- `tests/unit-size.test.sh`
- `tests/unit-bookkeeping.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `bin/review-precheck.sh`, `hooks/`, `agents/`, `eval/`, `tests/abtest-arms.test.sh`, `.claude/reviewed/`

## Acceptance criteria
1. run: `d=$(mktemp -d); cd "$d" && git init -q && CLAUDE_PROJECT_DIR="$d" bash "$OLDPWD/bin/unit-size.sh" u1 --at-least medium -- src/a.js`
   exit: 0
   stdout: `lane: medium files=1 reason=at-least`
   mutation: remove the `--at-least` handling → stdout `lane: full files=0 reason=no-input`.
2. run: `d=$(mktemp -d); cd "$d" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m b && mkdir -p .claude/bookkeeping && echo 'lane: medium files=1 reason=paths' > .claude/bookkeeping/u1.lane && CLAUDE_PROJECT_DIR="$d" bash "$OLDPWD/bin/unit-bookkeeping.sh" check u1 HEAD | head -n1`
   exit: 0
   stdout: `check: escalate unit=u1 reason=not-small`
   mutation: delete rule C1 → the first line is no longer this one.
3. run: `o=$(bash tests/unit-size.test.sh); r=$?; grep -oE '^OK   \(rv-a[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `3`
   mutation: let `--at-least` lower a full lane to medium → `(rv-a2)` FAILs, exit 1.
4. run: `o=$(bash tests/unit-bookkeeping.test.sh); r=$?; grep -oE '^OK   \(rv-[cf][0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `10`
   mutation: make rule C5 (judge) return pass → `(rv-c5)` FAILs, exit 1; make `flag` create a missing flag → `(rv-f2)` FAILs.
5. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `.claude/bin/unit-bookkeeping.sh` to HEAD~1 → exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
