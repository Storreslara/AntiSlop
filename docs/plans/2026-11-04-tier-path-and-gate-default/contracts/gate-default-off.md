Unit: gate-default-off

## Objective
Plan unit 2 (D6-D10). Add `reviewGating: { mode: 'off' }` to the fresh-install `personaConfig` literal in `bin/cli.js` only, with a comment after the `humanReviewMode` one; no backfill in `--update` or `--overwrite`. Reader rule unchanged everywhere. Tests `(gdo-1)`-`(gdo-3)` before the `failures > 0` exit; drift T20-T22 appended; trust-model row 13 converted, exempt count 2→1; ADR-0038 amendment; CONTEXT, README, schema description, install-skill bullet as plan unit 2 says; one `[Unreleased]` bullet naming `gate-default-off`.

## Retrieval
No tracker issue; plan unit 2 in `docs/plans/2026-11-04-tier-path-and-gate-default.md`.

## Affected files
- `bin/cli.js`
- `templates/persona-config.schema.json`
- `tests/cli-backfill.test.js`
- `tests/harness-config-drift.test.sh`
- `tests/trust-model-bijection.test.js`
- `docs/trust-model.md`
- `docs/adr/0038-review-gating-runtime-switch.md`
- `CONTEXT.md`
- `README.md`
- `skills/install-antislop/SKILL.md`
- `CHANGELOG.md`
- `.claude/` copies, only through `node bin/cli.js --update --force-render`

## Do NOT touch
- `hooks/`, `adapters/`, `commands/`, `eval/`, `bin/harness-integrity.sh`, `docs/plans/`

## Acceptance criteria
1. run: `o=$(node tests/cli-backfill.test.js 2>&1); r=$?; grep -oE '^OK +\(gdo-[1-3]\)' <<<"$o" | sort -u | wc -l | tr -d ' '; exit $r`
   exit: 0
   stdout: `3`
   mutation: drop the skeleton key → (gdo-1) FAIL; set it in the `--overwrite` branch → (gdo-3) FAIL.
2. run: `R=$PWD; T=$(mktemp -d); H=$(mktemp -d); (cd $T && HOME=$H node $R/bin/cli.js --yes >/dev/null 2>&1); jq -r .reviewGating.mode $T/.claude/persona-config.json`
   exit: 0
   stdout: `off`
3. run: `o=$(bash tests/harness-config-drift.test.sh 2>&1); r=$?; grep -oE '^OK +T(5|6|7|19|20|21|22) ' <<<"$o" | sort -u | wc -l | tr -d ' '; git diff 57267561 -- tests/harness-config-drift.test.sh | grep -cE '^-[^-]'; exit $r`
   exit: 0
   stdout: `7` then `0`
4. run: `bash docs/plans/2026-11-04-tier-path-and-gate-default/criteria/gdo-reader.sh`
   exit: 0
   stdout: `enforce`, `true`, `1`
   mutation: change a hook's `// "enforce"` read → exit 1.
5. run: `bash docs/plans/2026-11-04-tier-path-and-gate-default/criteria/gdo-docs.sh`
   exit: 0
   stdout: `7`
   mutation: skip the README row → `6`.
6. run: `node tests/trust-model-bijection.test.js >/dev/null && node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters ':!.claude/agent-memory' && jq -r '.reviewGating // "absent"' .claude/persona-config.json`
   exit: 0
   stdout: `absent`
7. run: `bash tests/validate.sh >/dev/null 2>&1` (timeout 600000 ms, after the last commit)
   exit: 0
