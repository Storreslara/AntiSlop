Unit: l2-scope

## Objective
Plan unit 12, after l2-prebr. `us_entries` in `hooks/scripts/lib/unit-scope.sh` (not `us_exclusions`) post-processes each `Affected files` token in order: (1) strip one trailing `:<digits>` or `:<digits>-<digits>`; (2) when the token holds exactly one `{` and one `}`, `{` first, with at least one `,` between them and no empty member, print prefix+member+suffix for each member in order; any other brace form (nested, single member, empty member) is printed as is, so it matches nothing (`scope: out`, fail closed). Update its comment. `review-precheck.sh`, `unit-size.sh` and `writer-scope-gate.sh` gain this through the library. Tests: `(l2-sc1)` a contract listing `` `src/x.sh:48` `` → `scope: ok src/x.sh listed`; `(l2-sc2)` `` `src/{a,b}.sh` `` → both files `scope: ok ... listed`; `(l2-sc3)` `` `src/{a,{b,c}}.sh` `` → `scope: out` for its file. One `[Unreleased]` CHANGELOG bullet naming `l2-scope`.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 12.

## Affected files
- `hooks/scripts/lib/unit-scope.sh`
- `tests/review-precheck.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `bin/`, `hooks/scripts/writer-scope-gate.sh`, `tests/scope-libs.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/review-precheck.test.sh 2>&1); r=$?; grep -oE '^OK +\(l2-sc[1-3]\)' <<<"$o" | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `3`
   mutation: skip the brace expansion → `(l2-sc2)` FAILs, exit 1.
2. run: `. hooks/scripts/lib/unit-scope.sh; f=$(mktemp); printf '## Affected files\n- `bin/x.sh:48`\n- `e/f.sh:3-9`\n- `src/{a,b}.sh`\n- `a/{b,{c,d}}.sh`\n- `g/{h}.sh`\n- `k/{m,}.sh`\n' >$f; us_entries $f | paste -sd' '`
   exit: 0
   stdout: `bin/x.sh e/f.sh src/a.sh src/b.sh a/{b,{c,d}}.sh g/{h}.sh k/{m,}.sh`
   mutation: strip only `:<digits>` → `e/f.sh:3-9`; expand nested groups → `a/b.sh` appears.
3. run: `R=$PWD; d=$(mktemp -d); cd $d; G='git -c user.email=t@t -c user.name=t'; git init -q; mkdir src; printf '## Affected files\n- `src/x.sh:48`\n- `src/{a,b}.sh`\n\n## Acceptance criteria\n' >c.md; git add c.md; $G commit -qm b; b=$(git rev-parse HEAD); for f in x a b; do echo 1 >src/$f.sh; done; git add src; $G commit -qm w; CLAUDE_PROJECT_DIR=$d bash $R/bin/review-precheck.sh u $b --contract c.md | grep -c '^scope: ok src/[xab]\.sh listed$'`
   exit: 0
   stdout: `3`
   mutation: strip no `:<digits>` → `2`.
4. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-scope'`
   exit: 0
   stdout: `1`
   mutation: bullet under 0.33.0 → `0`, exit 1.
5. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/hooks/scripts/lib/unit-scope.sh` stale → exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
