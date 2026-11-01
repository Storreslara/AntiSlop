Unit: rv-harden

## Objective
Plan unit 1b (rv-tools PASS notes): `check` gains C2a `uncommitted` (fail), C2b `empty-range`, C4a `sensitive` (escalate), a non-numeric `judge=` as `precheck-error`, `</dev/null` in C6, and in C7 `no-criteria` under `--contract` or the command run from the repo top. `flag` skips symlinks and writes with `dd conv=notrunc,nocreat`. `unit-size.sh` exits 2 on any argument after `--contract <path>`. Tests `(rv-a4)`, `(rv-h1)`-`(rv-h9)`, `(rv-e1)`-`(rv-e3)` as in the plan. One `[Unreleased]` bullet ("small-lane check"), no bump.

## Retrieval
No tracker issue. Spec: `docs/plans/2026-11-01-reviewer-by-lane.md`, unit 1b. Depends on rv-tools.

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
1. run: `d=$(mktemp -d); cd "$d" && git init -q && printf '## Affected files\n- `a.js`\n' > c.md && CLAUDE_PROJECT_DIR="$d" bash "$OLDPWD/bin/unit-size.sh" u1 --contract c.md --at-least medium 2>/dev/null; echo "rc=$? n=$(ls .claude/bookkeeping 2>/dev/null | wc -l)"`
   exit: 0
   stdout: `rc=2 n=0`
   mutation: drop the check after `--contract` → `lane: small files=1 reason=contract`, `rc=0 n=2`.
2. run: `d=$(mktemp -d); cd "$d" && g() { git -c user.email=t@t -c user.name=t "$@"; } && git init -q && printf '## Affected files\n- `a.txt`\n' > c.md && git add c.md && g commit -qm b && echo x > a.txt && git add a.txt && g commit -qm a && mkdir -p .claude/bookkeeping && echo 'lane: small files=1 reason=paths' > .claude/bookkeeping/u1.lane && u() { CLAUDE_PROJECT_DIR="$d" bash "$OLDPWD/bin/unit-bookkeeping.sh" check u1 HEAD~1 --contract c.md | head -n1; } && u && echo y >> a.txt && u`
   exit: 0
   stdout: `check: escalate unit=u1 reason=no-criteria` then `check: fail unit=u1 reason=uncommitted`
   mutation: delete rule C7's no-criteria branch → line 1 is `check: pass unit=u1 reason=precheck`.
3. run: `o=$(bash tests/unit-size.test.sh); r=$?; grep -oE '^OK   \(rv-a[0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `4`
   mutation: drop the check after `--contract` → `(rv-a4)` FAILs, exit 1.
4. run: `o=$(bash tests/unit-bookkeeping.test.sh); r=$?; grep -oE '^OK   \(rv-[cfhe][0-9]\)' <<<"$o" | sort -u | wc -l; exit $r`
   exit: 0
   stdout: `22`
   mutation: remove `</dev/null` → `(rv-h6)` FAILs; write with `cat "$tmp" > "$f"` → `(rv-h9)` FAILs; skip C4a → `(rv-h2)`, `(rv-e3)` FAIL.
5. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: revert `.claude/bin/unit-bookkeeping.sh` to HEAD~1 → exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
