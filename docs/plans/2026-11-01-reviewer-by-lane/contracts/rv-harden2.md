Unit: rv-harden2

## Objective
Plan unit 1c: `unit-bookkeeping.sh check` fails closed per the plan's 1c table; C7 escalates `criteria-mismatch` on duplicate declared numbers too; no `<bad> && finish` guard. Tests `(rv-k1)`-`(rv-k10)`, `(rv-e4)`-`(rv-e9)`. One `[Unreleased]` bullet `(rv-harden2)`, no bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 1c.

## Affected files
- `bin/unit-bookkeeping.sh`
- `tests/unit-bookkeeping.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, via `node bin/cli.js --update --force-render`

## Do NOT touch
- `bin/review-precheck.sh`, `bin/unit-size.sh`, `hooks/`, `eval/`, `.gitignore`, `tests/abtest-arms.test.sh`, `.claude/reviewed/`

## Acceptance criteria
1. run: `d=$(mktemp -d); cd "$d" && g() { git -c user.email=t@t -c user.name=t "$@"; } && git init -q && echo .claude/ > .gitignore && h='## Affected files\n- `a.txt`\n\n## Acceptance criteria\n' && e='   exit: 0\n   stdout: empty\n' && printf "$h"'1. run: `test -f b.txt`\n'"$e" > c.md && printf "$h"'1. run: `true`\n'"$e"'2. run: false\n' > c2.md && printf "$h"'1. run: `true`\n'"$e" > c3.md && cp c3.md c4.md && printf '1. run: `false` (Bash tool timeout 600000 ms)\n'"$e" >> c4.md && g add -A && g commit -qm c && b=$(git rev-parse HEAD) && echo x > a.txt && g add a.txt && g commit -qm a && w=$(git rev-parse HEAD) && mkdir -p .claude/bookkeeping && echo 'lane: small x' > .claude/bookkeeping/u.lane && k() { CLAUDE_PROJECT_DIR="$d" bash "$OLDPWD/bin/unit-bookkeeping.sh" check u "$1" --contract "$2" | head -n1; } && k "$b" c3.md && touch b.txt && k "$b" c.md && rm b.txt && k "$b" c2.md && k "$b" c4.md && g commit -q --allow-empty -m e && k "$w" c3.md && git checkout -q "$b" && k "$w" c3.md`
   exit: 0
   stdout: `check: pass unit=u reason=precheck` then `check: fail unit=u reason=uncommitted` then `check: escalate unit=u reason=criteria-mismatch` then `check: escalate unit=u reason=criteria-mismatch` then `check: escalate unit=u reason=empty-range` then `check: escalate unit=u reason=bad-baseline`
   mutation: C2a as `git diff --quiet HEAD`, or no count, duplicate or ancestor test → line 2, 3, 4 or 6 is `check: pass`.
2. run: `printf '%s %s %s\n' "$(grep -c '&& finish' bin/unit-bookkeeping.sh)" "$(grep -c 'finish pass' bin/unit-bookkeeping.sh)" "$(sed -n '/^## \[Unreleased\]/,/^## \[0/p' CHANGELOG.md | grep -c '(rv-harden2)')"`
   exit: 0
   stdout: `0 1 1`
   mutation: add a `<bad> && finish` guard → `1 1 1`.
3. run: `o=$(bash tests/unit-bookkeeping.test.sh); r=$?; grep -oE '^OK   \(rv-[cfhek][0-9]+\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `38`
   mutation: `-gt` judge test or no duplicate check → `(rv-k6)` or `(rv-k10)` FAILs, exit 1.
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: a stale `.claude/bin/unit-bookkeeping.sh` → exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, last)
   exit: 0
   stdout: empty
