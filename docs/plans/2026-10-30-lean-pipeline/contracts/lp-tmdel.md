Unit: lp-tmdel

## Objective
Delete the `task-master` persona (plan change 1, decision D2). `agents/task-master.md` and its `.claude` mirror go. `bin/cli.js` stops knowing it as a persona; `task-master` and `hivemind` become legacy tokens that map to `['spec-master']` with the existing deprecation note, so old `--personas` values and `personaSelection` entries keep working. Tests that read the deleted file are repointed or trimmed. The worked contract examples it carried move to `docs/contract-examples.md` so `tests/contract-examples.test.js` keeps scoring them. No version bump (per-release rule from U1).

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, section "U4 lp-tmdel", decision D2, Context bullets on `--update` and on `tests/abtest-arms.test.sh`. This file is the contract of record. Dispatch after lp-tmroute has PASSed (no prose surface may still name the persona). Implementer tier: sonnet.

## Affected files
- `agents/task-master.md` (`git rm`), `.claude/agents/task-master.md` (`git rm`)
- `bin/cli.js`
- `docs/contract-examples.md` (new)
- `.claude/constitution.md` (P4 list only; no version change)
- `tests/validate.sh`, `tests/contract-examples.test.js`, `tests/protocol-cross-references.test.js`, `tests/rubric-doc-parity.test.js`, `tests/writer-tier-consistency.test.js`, `tests/persona-prose-pins.test.sh`, `tests/cli-backfill.test.js`, `tests/knowledge-writes.test.sh`, `tests/prompt-diet-pins.test.sh`, `tests/bin-helpers-scaffold.test.sh`, `tests/orchestrator-model.test.js`, `tests/effort-tier-consistency.test.js`, `tests/adapter-protocol-parity.test.js` (deferred reason strings, ~:116 and ~:140)
- `CHANGELOG.md` (one bullet under `## [Unreleased]`, no version)
- `.claude/persona-config.json` and other `.claude/` mirrors, written only by `node bin/cli.js --update --force-render`

## Ordered edits
1. `bin/cli.js`: drop `'task-master'` from `OPTIONAL_PERSONAS`; delete the `'task-master'` row of `PROTOCOL_SECTIONS_BY_PERSONA` (anchor: line matching `  'task-master': {`); delete the wizard label (anchor: line matching `'task-master': 'task-master (slices`); set `LEGACY_PERSONA_MAP` to `hivemind: ['spec-master']` and add `'task-master': ['spec-master']`; update the comments above the map and above `resolveLegacyToken` to the new chain.
2. Move the three marked blocks `lead-contract-example`, `issue-body-layout-example`, `scribe-contract-example` (markers included, bytes unchanged) from `agents/task-master.md` into `docs/contract-examples.md` under a one-paragraph header. Point `tests/contract-examples.test.js` at that file and fix its comments.
3. `git rm agents/task-master.md .claude/agents/task-master.md`.
4. `tests/validate.sh`: drop `agents/task-master.md` from the cacheTtl loop (~:280) and its echo label; reword the :326 comment and the :1549 label (examples now in `docs/contract-examples.md`).
5. Other tests: delete checks and list entries that read the deleted file (protocol-cross-references :42, rubric-doc-parity :68, writer-tier-consistency AC-D5/AC-D9b/:164/:199/:65-67, persona-prose-pins :26 and :73 blocks, prompt-diet-pins :43/:55/:136 entries, effort-tier-consistency `TIERS`). In `--personas=` lists, drop `task-master`. In cli-backfill, rewrite the hivemind cases (:459-471, :1944, :2156-2195, :2485-2505) to expect `['spec-master']` and add one case: `task-master` alone migrates to `spec-master` with the note.
6. `.claude/constitution.md` P4: drop `task-master` from the list.
7. Run `node bin/cli.js --update --force-render`; commit the mirrors and `.claude/persona-config.json` it rewrites, with a CHANGELOG `[Unreleased]` bullet.

## Do NOT touch
- `tests/abtest-arms.test.sh`, `eval/`, `scripts/`, `tests/fixtures/`, `tests/unit-outcomes.test.js` (historical `contract_author` data)
- `tests/reviewed-path-gate.test.sh`, `tests/writer-scope-gate.test.sh` (bare string kept as an arbitrary agent name)
- `hooks/` (U2 already cleaned dispatch-hygiene), `.claude-plugin/plugin.json`, `package.json`
- `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/` (U12)

## Acceptance criteria
1. run: `test ! -e agents/task-master.md && test ! -e .claude/agents/task-master.md && echo gone`
   exit: 0
   stdout: `gone`
   mutation: `git checkout HEAD~1 -- agents/task-master.md` → no output, exit 1.
2. run: `d=$(mktemp -d) && cd $d && git init -q && node /home/sebas/AntiSlop/bin/cli.js --personas=spec-master,task-master,reviewer >out.txt 2>&1; echo $?; test ! -e .claude/agents/task-master.md && test "$(grep -c 'Deprecation note' out.txt)" -ge 1 && echo noted`
   exit: 0
   stdout: `0` then `noted`
   mutation: drop the `'task-master'` legacy-map entry → no `noted` line (or a nonzero first line), exit 1.
3. run: `node -e "const c=require('/home/sebas/AntiSlop/bin/cli.js'); console.log(JSON.stringify(c.migrateLegacyPersonaTokens(['hivemind','task-master'])), 'task-master' in c.PROTOCOL_SECTIONS_BY_PERSONA)"`
   exit: 0
   stdout: `["spec-master"] false`
   mutation: restore `hivemind: ['spec-master', 'task-master']` → `["spec-master","task-master"] false`.
4. run: `node tests/contract-examples.test.js >/dev/null && test "$(grep -c 'contract-examples.md' tests/contract-examples.test.js)" -ge 1 && echo ok`
   exit: 0
   stdout: `ok`
   mutation: delete the `<!-- lead-contract-example:end -->` line from `docs/contract-examples.md` → no `ok`, exit 1 (markers not found).
5. run: `git grep -n 'task-master' -- hooks bin tests ':!bin/cli.js' ':!tests/fixtures' ':!tests/abtest-arms.test.sh' ':!tests/reviewed-path-gate.test.sh' ':!tests/unit-outcomes.test.js' ':!tests/writer-scope-gate.test.sh' ':!tests/cli-backfill.test.js' | wc -l; n=$(grep -c 'task-master' tests/cli-backfill.test.js); test "$n" -ge 1 && test "$n" -le 8 && echo cb-ok; grep 'task-master' tests/cli-backfill.test.js | grep -vcE "![A-Za-z.]+\.includes\('task-master'\)|migrateLegacyPersonaTokens\(\['task-master'\]|includes\('.task-master.'\)|check\('migrateLegacyPersonaTokens migrates a lone task-master" || true; grep -c 'task-master' .claude/constitution.md || true`
   exit: 0
   stdout: `0`, `cb-ok`, `0`, `0` (cli-backfill may name the token only in the lone-task-master migration case and `!...includes('task-master')` assertions, at most 8 lines)
   mutation: append `// task-master` to `tests/validate.sh` → first line `1`; append `const x = 'task-master';` to `tests/cli-backfill.test.js` → third line `1`; 3 more `!a.includes('task-master')` lines there → no `cb-ok`.
6. run: `bash tests/abtest-arms.test.sh >/dev/null && git diff --quiet a511e8e7 -- tests/abtest-arms.test.sh eval`
   exit: 0
   stdout: empty
7. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` (C-mirror)
   exit: 0
   stdout: empty
8. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; C-full, run once by the reviewer after the final commit)
   exit: 0
   stdout: empty

## Pre-resolved context
- Today (2026-10-30): criteria 1, 2 (task-master.md created, 0 notes), 3 (`["spec-master","task-master"] true`), 5 (58 lines; constitution 1) fail; 6 passes and is a regression guard.
- `migrateLegacyPersonaTokens` already prints `Deprecation note: migrating the legacy "<t>" token ...` for any key in `LEGACY_PERSONA_MAP`; adding the key is enough.
- `bin/cli.js --update` never deletes a removed persona's mirror (only `pruneStaleFileHashes`), hence the explicit `git rm` of `.claude/agents/task-master.md`.
- This repo's `.claude/persona-config.json` lists `task-master` in `personaSelection` and `fileHashes`; read it with the Read tool, change it only through `--update`.
- Plan gap resolved here: the plan says the examples move to the U2 protocol section, but that section has none, and inlining ~170 example lines into every persona would break U6's 560-line ceiling (A3). A plain docs file keeps them out of every prompt. The schema descriptions moved to U3 (lp-tmroute), so this unit does not edit `templates/persona-config.schema.json`.

## Escalation
If `git rm .claude/agents/task-master.md` raises a harness approval prompt, let the human answer it; do not route around it (R4). If a test outside the affected files fails because it reads the deleted file, stop and report the path and line.
