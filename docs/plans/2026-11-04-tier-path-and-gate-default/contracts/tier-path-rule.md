Unit: tier-path-rule

## Objective
Plan unit 1 (D1-D5). `hooks/scripts/lib/sensitive-paths.sh`: add `LOW_RISK_PATHS` (exactly the four D1 patterns) and `touches_low_risk_path <path>` (same loop shape as `touches_sensitive_path`). `hooks/scripts/reviewer-tier.sh`: add `touches_low_risk_path` to the `declare -F` guard; per file, after the quoted, sensitive and binary checks, clear an all-low-risk flag for a non-member; after the zero-file guard print `sonnet` when the flag holds, else the unchanged size rule. Tests and docs as plan unit 1 lists: size fixtures move from `docs/` to `src/`; `(pr1)`-`(pr11)`, `(mc14)`, `(mc15)`; scope-libs `(a2)`, `(b2)`; ADR-0009 amendment; glossary; one `[Unreleased]` bullet naming `tier-path-rule`.

## Retrieval
No tracker issue; plan unit 1 in `docs/plans/2026-11-04-tier-path-and-gate-default.md`.

## Affected files
- `hooks/scripts/lib/sensitive-paths.sh`
- `hooks/scripts/reviewer-tier.sh`
- `tests/reviewer-tier.test.sh`
- `tests/scope-libs.test.sh`
- `docs/adr/0009-reviewer-tier-measured-eligibility.md`
- `docs/harness-glossary.md`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `bin/`, `agents/`, `adapters/`, `CONTEXT.md`, `docs/plans/`, `SENSITIVE_PATHS`

## Acceptance criteria
1. run: `o=$(bash tests/reviewer-tier.test.sh 2>&1); r=$?; grep -oE '^OK +\((pr([1-9]|1[01])|mc1[45])\)' <<<"$o" | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `13`
   mutation: delete the all-low-risk `sonnet` line → (pr1)-(pr4) FAIL, exit 1.
2. run: `git diff 57267561 -- tests/reviewer-tier.test.sh | grep -cE '^-[[:space:]]*run_(case|at) '`
   exit: 1
   stdout: `0`
   mutation: change (l)'s expectation to sonnet → `1`.
3. run: `bash tests/scope-libs.test.sh >/dev/null && grep -rl '^LOW_RISK_PATHS=(' hooks/scripts bin`
   exit: 0
   stdout: `hooks/scripts/lib/sensitive-paths.sh`
   mutation: copy the array into reviewer-tier.sh → (b2) FAIL.
4. run: `for f in docs/adr/0009-reviewer-tier-measured-eligibility.md docs/harness-glossary.md; do for p in '^docs/.*\.md$' '^(README|CHANGELOG|CONTEXT|CONTRIBUTING)\.md$' '^tests/' '^eval/(.+/)?fixtures/'; do sed -n '/^### Amendment (2026-11-04)/,$p;/^\*\*low-risk path class\*\*:/,/^\*\*/p' $f | grep -qF -- "$p" && echo y; done; done | wc -l | tr -d ' '`
   exit: 0
   stdout: `8`
   mutation: omit `^tests/` from the ADR → `7`.
5. run: `sed -n '/^\*\*Measured reviewer tier\*\*/,/^\*\*inert-key/p' docs/harness-glossary.md | grep -c 'low-risk path class'; sed -n '/^## \[Unreleased\]/,/^## \[0\.35\.0\]/p' CHANGELOG.md | grep -c 'tier-path-rule'`
   exit: 0
   stdout: two lines, each `1` or more
6. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory' && jq -r '.reviewGating // "absent"' .claude/persona-config.json`
   exit: 0
   stdout: `absent`
   mutation: stale `.claude/hooks/scripts/reviewer-tier.sh` → exit 1.
7. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms, after the last commit)
   exit: 0
