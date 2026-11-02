Unit: rs-prose

## Objective
Plan unit 5 (D5, D6) plus the appendix "Contract notes" deviation; exact new phrases: criterion 1's first three. `agents/reviewer.md`: (a) :95 "absent or wrong, check for yourself" → "absent, or the `Review gating:` line says `off`, check for yourself". (b) Keep the :181 span pinned by `(l2-v4)`; after "other value means `enforce`." add "If the header says `off`, run that command too; only its `off` counts." (c) "Under `off` your verdict" → "Under `off`, or for a dispatch whose second non-blank line is `Mode: advisory`, your verdict". `agents/spec-master.md:199` "even when true. Example:" → "even when true. Example (in `appendix.md`):". Pins (one loop, both reviewer copies): `has` criterion 1's three new phrases, `hasnot` 'absent or wrong'. One `[Unreleased]` CHANGELOG bullet naming `rs-prose`.

## Retrieval
No tracker issue; plan unit 5 in `docs/plans/2026-11-03-residuals.md`.

## Affected files
- `agents/reviewer.md`
- `agents/spec-master.md`
- `tests/persona-prose-pins.test.sh`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `agents/orchestrator.md`, `tests/blast-radius.test.sh`, `adapters/`, `hooks/`, `bin/`

## Acceptance criteria
1. run: `echo $(for f in agents/reviewer.md .claude/agents/reviewer.md; do t=$(tr -s ' \n' ' ' < $f); for p in 'or the `Review gating:` line says `off`, check for yourself' 'If the header says `off`, run that command too; only its `off` counts.' 'second non-blank line is `Mode: advisory`, your verdict is advisory' 'absent or wrong' 'only when it is absent, read the key'; do grep -cF -- "$p" <<<"$t"; done; done)`
   exit: 0
   stdout: `1 1 1 0 1 1 1 1 0 1`
   mutation: mirror stale → second half `0 0 0 1 1` (baseline: `0 0 0 1 1 0 0 0 1 1`).
2. run: `bash tests/persona-prose-pins.test.sh >/dev/null; echo $? $(grep -cF 'Mode: advisory' tests/persona-prose-pins.test.sh) $([ $(wc -c < agents/reviewer.md) -le 24630 ] && echo ok)`
   exit: 0
   stdout: `0 1 ok` (D8 budget)
   mutation: revert `agents/reviewer.md` → `1 1 ok`; +300 bytes → `0 1`.
3. run: `o=$(bash tests/blast-radius.test.sh 2>&1); r=$?; grep -cE '^OK   \(l2-v[46]\) ' <<<"$o"; exit $r`
   exit: 0
   stdout: `4`
   mutation: rewrite the kept :181 span → `3`, exit 1.
4. run: `grep -c 'even when true. Example (in `appendix.md`):' agents/spec-master.md .claude/agents/spec-master.md`
   exit: 0
   stdout: both lines end `:1`
   mutation: mirror stale → `.claude/agents/spec-master.md:0`.
5. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.34\.0\]/p' CHANGELOG.md | grep -c 'rs-prose'`
   exit: 0
   stdout: `1`
   mutation: no bullet → `0`, exit 1.
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory'`
   exit: 0
   stdout: empty
   mutation: mirror stale → exit 1.
7. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
   mutation: any suite failure → exit 1.
