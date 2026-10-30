Unit: lp-escbin

## Objective
Delete the escalation-only helpers and the dashboard's decision and packet code (plan change 3, decision D4, step "U7b lp-escbin"). Removed: `heavy-trigger.sh`, `bin/escalation-card.sh`, `bin/human-review-cleanup.sh`, `bin/microworld-dashboard/decision-block.js` and `decisions.js`, with their call sites, routes, tests and mirrors. The rest of the dashboard and the microworld reporter stay working. A new `code-bin` mode in `tests/escalation-retired.test.sh` enforces it. No version bump.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-30-lean-pipeline.md`, step "U7b lp-escbin", Context bullet "Escalation shared code to KEEP". This file is the contract of record and supersedes the plan's U7b file list where they differ. Dispatch after lp-hdg has PASSed. Implementer tier: sonnet.

## Affected files
- `git rm`: `hooks/scripts/heavy-trigger.sh`, `.claude/hooks/scripts/heavy-trigger.sh`, `bin/escalation-card.sh`, `.claude/bin/escalation-card.sh`, `bin/human-review-cleanup.sh`, `bin/microworld-dashboard/decision-block.js`, `bin/microworld-dashboard/decisions.js`, `tests/heavy-trigger.test.sh`, `tests/human-review-cleanup.test.sh`, `tests/microworld/dashboard-decision-block.test.js`, `dashboard-decision-run.test.js`, `dashboard-decisions.test.js`, `dashboard-decisions-client.test.js`, `dashboard-packets.test.js`
- `bin/microworld-dashboard/server.js` (requires :19-20, composer injection :88-89, `/api/decisions` :117-124, packet bundle path :236-239, decision arm route near :321, decision write route near :505), `index.html` (injected composer :125-127, `/api/decisions` fetch :184, `composeDecisionBlock` wrapper :586 and their UI), `discover.js` (`discoverPackets`: return `bundles` directly)
- `bin/cli.js` (`'escalation-card.sh'` out of `BIN_HELPER_FILES` :656)
- `tests/validate.sh` (blocks at :923-927, :959-963 and the five dashboard blocks :1241-1290), `tests/watch-map.json` (entry `gh351`)
- Tests that cover removed code: `tests/bin-helpers-scaffold.test.sh:15` (FILES list), `tests/ladder-tier.test.sh` (the escalation-card section from :149, and the header), `tests/fail-record-refutation.test.sh` (case c), `tests/state-access-constraints.test.sh` (constraint 7, which calls the arm route), `tests/state-distinctions-manifest.test.sh` (the D10 row on `server.js`)
- `tests/escalation-retired.test.sh` (add mode `code-bin`); `CHANGELOG.md` (one `[Unreleased]` bullet naming each test edited)
- Found by the 2026-10-30 scan of the half-done tree: `tests/microworld/dashboard-server.test.js` (Test (k), :502-522), `docs/microworld-dashboard-capabilities.md`, `tests/state-access-capability-regression.test.sh` (part 3, :52-100), `bin/cli.js` (`runDashboard`'s two `startServer` calls), `docs/microworld/README.md` (:11-17, :55)

## Ordered edits
1. `git rm` the files above. `--update` never deletes a mirror, so remove the two `.claude` mirrors by hand.
2. Cut the dashboard call sites. `invoke.js` needs no change: its `escalateHandle` is a SIGTERM→SIGKILL timer, not escalation code. Every other dashboard route, the notebook and the feedback blocks stay as they are.
3. Edit each listed test only to drop the cases for removed code.
4. `code-bin` mode fails, printing each hit, unless all of these hold: (a) the 7 deleted source and mirror paths are absent; (b) `git grep -nE` over `bin hooks adapters` finds no `require('./decisions')` or `require('./decision-block')` and no line that runs or sources `escalation-card.sh`, `human-review-cleanup.sh` or `heavy-trigger.sh` (comments do not count); (c) `server.js` has no `/api/decision` route string; (d) `BIN_HELPER_FILES` does not list `escalation-card.sh`. Assemble the patterns from split literals. Register `bash tests/escalation-retired.test.sh code-bin` in `tests/validate.sh`.
5. `node bin/cli.js --update --force-render`; stage the mirrors with `git add -- .claude adapters`. It also drops the two deleted mirrors' `fileHashes` entries from `.claude/persona-config.json`; never edit that file by hand.
6. `dashboard-server.test.js` Test (k): one render site is left (the bundle rail). Change `siteCount !== 3` and `labelCallCount !== 3` to `!== 1`; say "exactly 1 ... call site" in both failure messages and "exactly one render site" in the comment and the `console.log` label. Keep the stub proof.
7. `docs/microworld-dashboard-capabilities.md`: delete the `GET /api/decisions` row and the `POST /api/decision/arm`, `POST /api/decision/run` row. In the `GET /api/context` row, set Capability to "git HEAD sha + userName" and Cited by to "the sha stamps every copied feedback block (`doCopyFeedback` in `index.html`)".
8. `state-access-capability-regression.test.sh`: delete part (3), from `# (3) real dashboard decision/arm route` through its closing `fi`. Keep part (1).
9. `bin/cli.js`: `{ ttyWrite, readOnly: false }` becomes `{ readOnly: false }`, `{ ttyWrite: null, readOnly: true }` becomes `{ readOnly: true }`. Keep the `/dev/tty` probe and URL write (the token stays out of logs; Test (l) pins it).
10. `docs/microworld/README.md`: "Ten modules" to "Eight modules", drop "the decision surface, ", "all fourteen tests" to "all nine tests", delete the `.claude/human-review/<task-id>/` bullet.

## Do NOT touch
- `bin/cli.js` `'{{DOTDIR}}/human-review/'` gitignore pattern (:170) and `tests/cli-backfill.test.js`: kept so leftover packet dirs in consumer projects stay ignored
- Comments in `hooks/scripts/lib/audit-log.sh:82` and `hooks/scripts/version-stamp-check.sh:19` (shared code, KEEP list)
- Owned by lp-scribe or later prose work, not this unit: `CONTEXT.md`, `docs/harness-glossary.md`, `docs/trust-model.md` (row 18), `README.md:111`, `.claude/wiki/`
- History, kept: `docs/plans/`, `docs/adr/`, `docs/audits/`, `CHANGELOG.md`, `.claude/agent-memory/`, the verbatim fixture in `tests/scope-libs.test.sh:114`
- `hooks/scripts/lib/state-access.sh` (U8b), `hooks/scripts/stop-gate.sh`, `lib/stop-gate-core.sh` (U8a), `hooks/scripts/human-decision-gate.sh` (lp-hdg stub), `hooks/hooks.json`, `.claude/settings.json`
- `microworld-rerun.sh`, `lib/microworld-rerun-core.sh`, `lib/microworld-queue.sh`, `microworlds/`, `eval/`, `tests/abtest-arms.test.sh`
- `agents/`, `templates/`, `commands/`, `skills/`, `adapters/*/agents*`, `adapters/*/rules/` (prose went in lp-escprose; never re-add any)

## Acceptance criteria
1. run: `bash tests/escalation-retired.test.sh code-bin >/dev/null`
   exit: 0
   stdout: empty
   mutation: re-add `const { enumerateDecisions } = require('./decisions');` to `server.js` → exit 1.
2. run: `for t in tests/microworld/dashboard-*.test.js; do node "$t" >/dev/null 2>&1 || echo FAIL; done | grep -c FAIL || true`
   exit: 0
   stdout: `0`
   mutation: in `discover.js`, call the deleted `discoverPackets` again → ≥ 1.
3. run: `{ bash tests/ladder-tier.test.sh && bash tests/fail-record-refutation.test.sh && bash tests/bin-helpers-scaffold.test.sh && bash tests/state-access-constraints.test.sh && bash tests/state-distinctions-manifest.test.sh && bash tests/watch-map-registration.test.sh; } >/dev/null`
   exit: 0
   stdout: empty
4. run: `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` (C-mirror)
   exit: 0
   stdout: empty
5. run: `bash tests/validate.sh >/dev/null 2>&1` (Bash tool timeout 600000 ms; C-full, run once by the reviewer after the final commit)
   exit: 0
   stdout: empty
6. run: `node tests/microworld/dashboard-server.test.js 2>&1 | grep -c "Test (k) passed"; grep -cE "(siteCount|labelCallCount) !== 1\)" tests/microworld/dashboard-server.test.js; grep -c "isUnverifiedStatus(b.status)" bin/microworld-dashboard/index.html`
   exit: 0
   stdout: `1` then `2` then `1`
   mutation: append a second `${getStatusClass(b.status)} ${isUnverifiedStatus(b.status)}` to `index.html` → `0` then `2` then `2`.
7. run: `node tests/microworld/dashboard-capability-register.test.js >/dev/null 2>&1; echo $?; grep -c "api/decision" docs/microworld-dashboard-capabilities.md; grep -c "feedback block" docs/microworld-dashboard-capabilities.md`
   exit: 0
   stdout: `0` then `0` then `1`
   mutation: re-add a `GET /api/decisions` row → `1` then `1` then `1`.
8. run: `bash tests/state-access-capability-regression.test.sh >/dev/null 2>&1; echo $?; grep -c "api/decision" tests/state-access-capability-regression.test.sh; grep -c "startServer(.*ttyWrite" bin/cli.js || true`
   exit: 0
   stdout: `0` then `0` then `0`
9. run: `grep -cE "Eight modules|all nine tests" docs/microworld/README.md; grep -cE "decision surface|human-review/" docs/microworld/README.md || true`
   exit: 0
   stdout: `2` then `0`

## Pre-resolved context
- Today (2026-10-30, 94b55ee3): criterion 1 exits 127 (no test file); all 5 helper files exist; 2 `require('./decision…')` lines in `bin`. The tests in criteria 2 and 3 pass (baseline).
- `tests/packet-view-script.test.sh` is already deleted by lp-escprose, so it is not in this list.
- Half-done tree scan (2026-10-30): every `tests/validate.sh` suite was run in a copy; only `dashboard-server` (Test (k)), `dashboard-capability-register` (8 doc routes vs 5 in `server.js`) and `state-access-capability-regression` (calls the arm route) failed for this unit's reasons; the rest were the copy's missing git history. On HEAD 97073855 criteria 6-9 print `1 0 3`, `0 2 0`, `0 1 2`, `0 2`.
- Plan gaps resolved here: the `.claude` mirrors, `bin-helpers-scaffold`, `ladder-tier`, `fail-record-refutation`, `state-access-constraints` C7, the manifest row and watch-map `gh351` were missing from the plan's list. The plan's "human-review exclusions :169-171" edit is dropped: only :170 concerns packets, and keeping it costs nothing.

## Escalation
If a gate blocks a write, stop and report the path and the refusal text, never route around it. If a surviving dashboard test needs a change beyond removing decision or packet cases and edits 6-8, stop and report it.
