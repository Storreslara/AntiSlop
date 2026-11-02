Unit: rs-stamp

## Objective
Plan unit 1 (item 1, D3). In `hooks/scripts/dispatch-hygiene.sh`, right after `trap sg_exit EXIT`, add three traps that set `sg_stamp_due=0` and exit 143 (`TERM`), 130 (`INT`), 129 (`HUP`), so a signal never moves the writer-dispatch stamp. Update header item 0a and the comment above `sg_stamp_due=0` ("Touched by the EXIT trap only on exit 0...") to name the signal case. Tests in `tests/dispatch-hygiene.test.sh`: `(rs-s1)` TERM, `(rs-s2)` INT, `(rs-s3)` HUP; a jq PATH shim signals the hook at its `dispatchHygiene.mode` read, each run in its own subshell (an `INT` child otherwise aborts the test script), and a stamp pre-set to 2026-01-01 stays unmoved. One `[Unreleased]` CHANGELOG bullet naming `rs-stamp`.

## Retrieval
No tracker issue; plan unit 1 in `docs/plans/2026-11-03-residuals.md`.

## Affected files
- `hooks/scripts/dispatch-hygiene.sh`
- `tests/dispatch-hygiene.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/scripts/lib/`, `bin/`, `agents/`

## Acceptance criteria
1. run: `o=$(bash tests/dispatch-hygiene.test.sh 2>&1); r=$?; grep '^OK ' <<<"$o" | grep -oE '\(rs-s[1-3]\)' | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `3`
   mutation: drop the three traps → FAIL lines, exit 1.
2. run: `S=$(mktemp -d); mkdir $S/b; printf '#!/bin/bash\ncase "$*" in *dispatchHygiene.mode*) kill -$SIG $HYG_PID; sleep 0.3;; esac\nexec %s "$@"\n' "$(command -v jq)" > $S/b/jq; chmod +x $S/b/jq; r=; for g in TERM INT HUP; do c=$S/$g/.claude; mkdir -p $c/reviewed; echo '{}' > $c/persona-config.json; touch -d 2026-01-01 $c/reviewed/.writer-dispatch-stamp; (jq -cn '{tool_name:"Agent",tool_input:{subagent_type:"lead-programmer",prompt:"do it"}}' | SIG=$g PATH=$S/b:$PATH CLAUDE_PROJECT_DIR=$S/$g bash -c 'export HYG_PID=$$; exec bash hooks/scripts/dispatch-hygiene.sh' >/dev/null 2>&1); r="$r $g $(find $c/reviewed/.writer-dispatch-stamp -newermt 2026-01-02 | wc -l)"; done; echo $r`
   exit: 0
   stdout: last line `TERM 0 INT 0 HUP 0` (bash job notices on stderr are ignored)
   mutation: baseline code (measured at c39d1918) → `TERM 1 INT 1 HUP 1`.
3. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.34\.0\]/p' CHANGELOG.md | grep -c 'rs-stamp'`
   exit: 0
   stdout: `1`
   mutation: no bullet → `0`, exit 1.
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/hooks/scripts/dispatch-hygiene.sh` stale → exit 1.
5. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
   mutation: any suite failure → exit 1.
