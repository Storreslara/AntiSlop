Unit: l2-revprose

## Objective
Plan unit 5 (D5, B2); quotes are exact. `agents/reviewer.md`: after "<contract path>` yourself" add " with `--blast-radius` appended"; after "or the writer." the plan's `br ` sentence, then "A `br blast-radius: unavailable` line means the script is missing."; its `Constitution:` sentence; "read the key with" → "read the dispatch header's `Review gating:` line first; only when it is absent, read the key with"; after "validate.sh`)." the plan's two sentences. `templates/persona-protocol.md`: after "or the writer." add "Its `review-precheck.sh --blast-radius` run counts."; "overwrite a flag that currently exists with `defer: <reason>`, written by `bash .claude/bin/unit-bookkeeping.sh flag defer <reason>`" → "`bash .claude/bin/unit-bookkeeping.sh flag defer <reason>` puts `defer: <reason>` on the first line of each flag that currently exists and keeps the rest"; "reason-less overwrite" → "reason-less `flag` call"; small-lane text as the plan says. Keep all `(j)` pins; `tests/blast-radius.test.sh` adds `(l2-v1)`-`(l2-v6)` (reviewer, both copies), `(l2-v7)` (protocol sentence, four `(j)` copies), `(l2-v8)` (escape hatch), `(l2-v9)` (small lane). One `[Unreleased]` CHANGELOG bullet naming `l2-revprose`.

## Retrieval
`docs/plans/2026-11-02-lean-pipeline-2.md`, unit 5.

## Affected files
- `agents/reviewer.md`
- `templates/persona-protocol.md`
- `tests/blast-radius.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `bin/`, `hooks/`, `adapters/`, `tests/review-precheck.test.sh`

## Acceptance criteria
1. run: `o=$(bash tests/blast-radius.test.sh 2>&1); r=$?; grep -oE '^OK +\(l2-v[1-9]\)' <<<"$o" | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `9`
   mutation: omit the `Constitution:` sentence → `(l2-v3)` FAILs, exit 1.
2. run: `for f in .claude/agents/reviewer.md .claude/persona-protocol.md; do tr -s ' \n' ' ' <"$f" | grep -oF -e 'only when it is absent' -e 'script is missing.' -e 'run counts.' -e 'and keeps the rest' -e 'so it gets the reviewer' -e 'overwrite a flag' | LC_ALL=C sort -u | paste -sd'|'; done`
   exit: 0
   stdout: `only when it is absent|run counts.|script is missing.|so it gets the reviewer` then `and keeps the rest|run counts.|so it gets the reviewer`
   mutation: skip the refresh → both lines differ.
3. run: `bash tests/review-precheck.test.sh >/dev/null 2>&1`
   exit: 0
   stdout: empty
   mutation: `--blast-radius` inside the pinned precheck command → exit 1.
4. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.33\.0\]/p' CHANGELOG.md | grep -c 'l2-revprose'`
   exit: 0
   stdout: `1`
   mutation: bullet under 0.33.0 → `0`, exit 1.
5. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: stale `.claude/persona-protocol.md` → exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
