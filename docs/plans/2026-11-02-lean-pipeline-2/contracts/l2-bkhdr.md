Unit: l2-bkhdr

## Objective
Plan unit 3 (D4, D5). In `bin/unit-bookkeeping.sh`: `review_header` prints, right after `Reviewer model:`, `Review gating: off` exactly when `jq -r '.reviewGating.mode // "enforce"' <dot>/persona-config.json` prints `off` (any other output, a jq error or no file: `Review gating: enforce`), then `Constitution: present` when `<dot>/constitution.md` is a file, else `Constitution: absent`. New subcommand `repo` (add it to `usage`): count tracked files with `git ls-files -- . ':(exclude).claude' ':(exclude)docs/plans'` from the repo top and their total lines; print `repo: small files=<n> lines=<n>` when files <= 10 or lines < 1000, else `repo: large files=<n> lines=<n>`; outside git or on any count error print `repo: large files=0 lines=0`; always exit 0. Tests in `tests/unit-bookkeeping.test.sh` labelled `(l2-b1)`-`(l2-b6)`: mode off; absent key and unreadable config both `enforce`; constitution present and absent; `repo` on 3 files (small), 11 files of 2,000 lines (large), 11 files of 50 lines (small), and outside git (large). One `[Unreleased]` CHANGELOG bullet naming `l2-bkhdr`. Do not change `check`, `flag` or `dispatch`.

## Retrieval
No tracker issue; spec in `docs/plans/2026-11-02-lean-pipeline-2.md`, unit 3.

## Affected files
- `bin/unit-bookkeeping.sh`
- `tests/unit-bookkeeping.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `agents/`, `templates/`, `hooks/`, `bin/review-precheck.sh`, `bin/unit-size.sh`

## Acceptance criteria
1. run: `o=$(bash tests/unit-bookkeeping.test.sh 2>&1); r=$?; grep -oE '^OK +\(l2-b[1-6]\)' <<<"$o" | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `6`
   mutation: make `repo` count lines with `head -n 1000` → `(l2-b4)` FAILs, exit 1.
2. run: `bash bin/unit-bookkeeping.sh repo | cut -d' ' -f1,2`
   exit: 0
   stdout: `repo: large`
   mutation: compare files with `-le 1000` → `repo: small`.
3. run: `bash bin/unit-bookkeeping.sh review l2-bkhdr-probe HEAD~1 | grep -E '^(Reviewer model|Review gating|Constitution):' | cut -d: -f1`
   exit: 0
   stdout: `Reviewer model` then `Review gating` then `Constitution`
   mutation: print the two lines before `Reviewer model:` → order differs.
4. run: `bash bin/unit-bookkeeping.sh review l2-bkhdr-probe HEAD~1 | grep -E '^(Review gating|Constitution):'`
   exit: 0
   stdout: `Review gating: enforce` then `Constitution: present`
   mutation: test `-d` instead of `-f` for the constitution → `Constitution: absent`.
5. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: leave `.claude/bin/unit-bookkeeping.sh` stale → exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
