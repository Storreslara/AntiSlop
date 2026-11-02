Unit: l2-ckhard

## Objective
Plan unit 11, after l2-bkhdr (prior FAILs qw-u1, rv-harden2). `check` in `bin/unit-bookkeeping.sh` gains two fail-closed rules; nothing else changes. (1) `check_declared`: a `--contract` argument with a `..` segment (`(^|/)\.\.(/|$)`) → `finish escalate criteria-mismatch` before any read. (2) `check_tree`, right after C2a: `git -C "$CK_TOP" ls-files -v` failing, or printing a line tagged lowercase or `S` → `finish escalate index-flags`. Tests: `(l2-k1)` `sub/../c.md` with `sub/` present → `criteria-mismatch`; `(l2-k2)` skip-worktree, then assume-unchanged → `index-flags`; `(l2-k3)` bits cleared, contract `x..md` → `check: pass`. One `[Unreleased]` CHANGELOG bullet naming `l2-ckhard`.

## Retrieval
No tracker issue; plan unit 11. Lane small; size with `unit-size.sh l2-ckhard --at-least medium` so it gets the reviewer (D8).

## Affected files
- `bin/unit-bookkeeping.sh`
- `tests/unit-bookkeeping.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `bin/review-precheck.sh`, `hooks/`, `agents/`

## Acceptance criteria
1. run: `o=$(bash tests/unit-bookkeeping.test.sh 2>&1); r=$?; grep -oE '^OK +\(l2-k[1-3]\)' <<<"$o" | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `3`
   mutation: drop the `ls-files` rule → exit 1.
2. run: `R=$PWD; d=$(mktemp -d); printf 'precheck: result=pass unit=u range=a..b fails=0 deferred=0 judge=0\nsize: files=1 lines=1 binary=0\ncriterion 1: pass exit=0\n' >$d/pk; echo "cat $d/pk" >$d/pre; mkdir -p $d/r/sub $d/r/.claude/bookkeeping; cd $d/r; G='git -c user.email=t@t -c user.name=t'; git init -q; echo .claude/ >.gitignore; printf '## Acceptance criteria\n1. run: x\n' >c.md; cp c.md x..md; git add -A; $G commit -qm b; b=$(git rev-parse @); echo y >a; git add a; $G commit -qm w; echo 'lane: small x' >.claude/bookkeeping/u.lane; k() { CLAUDE_PROJECT_DIR=$d/r UB_PRECHECK=$d/pre bash $R/bin/unit-bookkeeping.sh check u $b --contract $1 | sed -n '1s/^check: \([a-z]*\) .*reason=/\1:/p'; }; o="$(k c.md) $(k sub/../c.md)"; git update-index --skip-worktree a; o="$o $(k c.md)"; git update-index --no-skip-worktree a; git update-index --assume-unchanged a; o="$o $(k c.md)"; git update-index --no-assume-unchanged a; echo "$o $(k x..md)"`
   exit: 0
   stdout: `pass:precheck escalate:criteria-mismatch escalate:index-flags escalate:index-flags pass:precheck`
   mutation: `^S ` only → word 4 `pass:precheck`; `*..*` → word 5 `escalate:criteria-mismatch`.
3. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-ckhard'`
   exit: 0
   stdout: `1`
   mutation: bullet under 0.33.0 → `0`, exit 1.
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/bin/unit-bookkeeping.sh` stale → exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
