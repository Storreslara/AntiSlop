Unit: rv-harden2

## Objective
Plan unit 1c: make `unit-bookkeeping.sh check` fail-closed per the plan's rule table (C2a untracked files, C2b `bad-baseline`/`empty-range`, strict first line, `size:`, literal `judge=0`, deferred count, C7 `criteria-mismatch`; no `<bad> && finish` guard). Tests `(rv-k1)`-`(rv-k9)`, `(rv-e4)`-`(rv-e8)`. One `[Unreleased]` bullet `(rv-harden2)`, no bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 1c. Depends on rv-harden.

## Affected files
- `bin/unit-bookkeeping.sh`
- `tests/unit-bookkeeping.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `bin/review-precheck.sh`, `bin/unit-size.sh`, `hooks/`, `eval/`, `.gitignore`, `tests/abtest-arms.test.sh`, `.claude/reviewed/`

## Acceptance criteria
1. run: `d=$(mktemp -d); cd "$d" && g() { git -c user.email=t@t -c user.name=t "$@"; } && git init -q && echo .claude/ > .gitignore && h='## Affected files\n- `a.txt`\n\n## Acceptance criteria\n' && e='   exit: 0\n   stdout: empty\n' && printf "$h"'1. run: `test -f b.txt`\n'"$e" > c.md && printf "$h"'1. run: `true`\n'"$e"'2. run: false\n' > c2.md && printf "$h"'1. run: `true`\n'"$e" > c3.md && g add -A && g commit -qm c && b=$(git rev-parse HEAD) && echo x > a.txt && g add a.txt && g commit -qm a && w=$(git rev-parse HEAD) && mkdir -p .claude/bookkeeping && echo 'lane: small x' > .claude/bookkeeping/u.lane && k() { CLAUDE_PROJECT_DIR="$d" bash "$OLDPWD/bin/unit-bookkeeping.sh" check u "$1" --contract "$2" | head -n1; } && k "$b" c3.md && touch b.txt && k "$b" c.md && rm b.txt && k "$b" c2.md && g commit -q --allow-empty -m e && k "$w" c3.md && git checkout -q "$b" && k "$w" c3.md`
   exit: 0
   stdout: `check: pass unit=u reason=precheck` then `check: fail unit=u reason=uncommitted` then `check: escalate unit=u reason=criteria-mismatch` then `check: escalate unit=u reason=empty-range` then `check: escalate unit=u reason=bad-baseline`
   mutation: C2a back to `git diff --quiet HEAD`, no count check, or no ancestor test → line 2, 3 or 5 is `check: pass`.
2. run: `printf '%s %s %s\n' "$(grep -c '&& finish' bin/unit-bookkeeping.sh)" "$(grep -c 'finish pass' bin/unit-bookkeeping.sh)" "$(sed -n '/^## \[Unreleased\]/,/^## \[0/p' CHANGELOG.md | grep -c '(rv-harden2)')"`
   exit: 0
   stdout: `0 1 1`
   mutation: restore `[ "$n" -gt 0 ] && finish escalate judge` → `1 1 1`.
3. run: `o=$(bash tests/unit-bookkeeping.test.sh); r=$?; grep -oE '^OK   \(rv-[cfhek][0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `36`
   mutation: judge test back to `-gt` → `(rv-k6)` FAILs, exit 1; no `size:` rule → `(rv-k4)` FAILs.
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `.claude/bin/unit-bookkeeping.sh` to HEAD~1 → exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
