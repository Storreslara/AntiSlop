Unit: l2-prebr

## Objective
Plan unit 4 (D5, item 6). `bin/review-precheck.sh` gains the flag `--blast-radius` (add it to `usage`). With it, after the packet is built and before it is written and printed, append one line per output line of `bash "$dir/blast-radius.sh" <baseline>`, each prefixed `br `; if that script is missing or exits non-zero, append the one line `br blast-radius: unavailable` instead. The `.precheck` copy and stdout stay the same text. Without the flag the packet is byte-identical to today. `--blast-radius` together with `--criterion` is usage error 2. Tests in `tests/review-precheck.test.sh` labelled `(l2-r1)`-`(l2-r4)`: without the flag no `br ` line; with it the packet less its `br ` lines equals the run without the flag and every line from the first `br ` line on starts `br `; a copy of the script with no `blast-radius.sh` beside it prints `br blast-radius: unavailable`; `--criterion 1 --blast-radius` exits 2. One `[Unreleased]` CHANGELOG bullet naming `l2-prebr`. Do not change `unit-bookkeeping.sh` (`check` never passes the flag).

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 4.

## Affected files
- `bin/review-precheck.sh`
- `tests/review-precheck.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `bin/blast-radius.sh`, `bin/unit-bookkeeping.sh`, `agents/`, `templates/`, `hooks/`

## Acceptance criteria
1. run: `o=$(bash tests/review-precheck.test.sh 2>&1); r=$?; grep -oE '^OK +\(l2-r[1-4]\)' <<<"$o" | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `4`
   mutation: drop the `br ` prefix → `(l2-r2)` FAILs, exit 1.
2. run: `o=$(bash bin/review-precheck.sh l2-prebr-probe HEAD~1 --blast-radius); p=$(bash bin/review-precheck.sh l2-prebr-probe HEAD~1); [ "$(grep -v '^br ' <<<"$o")" = "$p" ] && echo "$(grep -m1 '^br ' <<<"$o" | cut -d' ' -f1-3) $(sed -n '/^br /,$p' <<<"$o" | grep -vc '^br ')"`
   exit: 0
   stdout: `br blast-radius: provenance=grep 0`
   mutation: append the blast-radius lines without the `br ` prefix → exit 1.
3. run: `bash bin/review-precheck.sh l2-prebr-probe HEAD --contract docs/plans/2026-11-02-lean-pipeline-2/contracts/l2-prebr.md --criterion 4 --blast-radius 2>/dev/null; echo $?`
   exit: 0
   stdout: `2`
   mutation: let `--criterion` ignore the flag → stdout `criterion 4: pass exit=0` then `0`.
4. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-prebr'`
   exit: 0
   stdout: `1`
   mutation: put the bullet under 0.33.0 → stdout `0`, exit 1.
5. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/bin/review-precheck.sh` stale → exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
