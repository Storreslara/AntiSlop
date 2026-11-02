Unit: rs-tokens

## Objective
Plan unit 4 (item 4). Since l2-slim the reviewer preloads `roast-work` only, so its transcripts fall to `other`. Add the entry `frozenset(['antislop:roast-work']): 'reviewer'` to the skill-signature map in each of `scripts/token-usage/agg.py` (`SKILL_SIG`, :73), `agg2.py` (`SKILL_SIG`, :47) and `cache.py` (`SIG`, :41). Keep the existing `roast-work` plus `ubiquitous-language` pair (older transcripts). New fixture `tests/fixtures/token-usage-roast/`, same layout as `tests/fixtures/token-usage/` (`<session>.jsonl` plus `<session>/subagents/agent-*.jsonl`): one subagent transcript whose only `<command-name>` is `antislop:roast-work`, with no parent Agent tool_use naming it. Tests in `tests/token-usage.test.sh`, each `check` description starting with its id: `(rs-t1)` agg.py, `(rs-t2)` agg2.py, `(rs-t3)` cache.py attribute that transcript to `reviewer` (a `reviewer` row with n 1, no `other` row). One `[Unreleased]` CHANGELOG bullet naming `rs-tokens`.

## Retrieval
No tracker issue; plan unit 4 in `docs/plans/2026-11-03-residuals.md`.

## Affected files
- `scripts/token-usage/agg.py`
- `scripts/token-usage/agg2.py`
- `scripts/token-usage/cache.py`
- `tests/token-usage.test.sh`
- `tests/fixtures/token-usage-roast/` (new)
- `CHANGELOG.md`

## Do NOT touch
- `tests/fixtures/token-usage/`, `tests/fixtures/token-usage-main/` (their medians are pinned), `agents/`, `hooks/`, `bin/`

## Acceptance criteria
1. run: `grep -c "frozenset(\['antislop:roast-work'\]): 'reviewer'" scripts/token-usage/agg.py scripts/token-usage/agg2.py scripts/token-usage/cache.py`
   exit: 0
   stdout: three lines, each ending `:1`
   mutation: cache.py entry missing → a line `scripts/token-usage/cache.py:0` (baseline: all three `:0`, exit 1).
2. run: `o=$(bash tests/token-usage.test.sh 2>&1); r=$?; grep '^ok ' <<<"$o" | grep -oE 'rs-t[1-3]' | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `3`
   mutation: agg2.py entry missing → `2`, exit 1.
3. run: `grep -c "frozenset(\['antislop:roast-work', 'antislop:ubiquitous-language'\]): 'reviewer'" scripts/token-usage/agg.py scripts/token-usage/agg2.py scripts/token-usage/cache.py`
   exit: 0
   stdout: three lines, each ending `:1`
   mutation: old pair replaced by the new entry → a `:0` line.
4. run: `git diff --quiet b93658d3 -- tests/fixtures/token-usage tests/fixtures/token-usage-main`
   exit: 0
   stdout: empty
   mutation: add the roast transcript under `tests/fixtures/token-usage/` → exit 1.
5. run: `sed -n '/^## \[Unreleased\]/,/^## \[0\.34\.0\]/p' CHANGELOG.md | grep -c 'rs-tokens'`
   exit: 0
   stdout: `1`
   mutation: no bullet → `0`, exit 1.
6. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; once, after the final commit)
   exit: 0
   stdout: empty
   mutation: any suite failure → exit 1.
