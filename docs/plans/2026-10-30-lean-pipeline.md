# Lean pipeline: five approved cuts from the 2026-10-30 architecture review

Plan slug: `2026-10-30-lean-pipeline`. Unit prefix `lp-`. Contracts: `docs/plans/2026-10-30-lean-pipeline/contracts/<unit>.md`.

## Goal
Implement the five user-approved changes from the 2026-10-30 review (source: session scratchpad `antislop-review.md`, sections 4-7):
(1) delete `task-master`, contracts become five fields and at most 3KB, written by spec-master or the orchestrator, fix contracts by the orchestrator;
(2) cap spec-master output (25KB / 400 lines per plan, no scorecard/PRD/Self-check below 6 units, no whole-file reads over 50KB);
(3) remove the ESCALATE-TO-HUMAN machinery, keeping shared code;
(4) drop Bash command-text scanning from `harness-integrity-gate.sh` and `reviewed-path-gate.sh`, and reduce `stop-gate` to one pending-review flag check, with a replacement check landing first;
(5) slim outputs (3-5 line packet, verdict and final message), one version bump per release, one `validate.sh` run per unit, orchestrator source toward 15KB.
The system must keep working after every unit.

## Context
- Evidence and savings per change: review sections 3, 4, 5, 6, 7. Not restated here.
- Five-field contract (D1). It reuses existing headings so every current parser keeps working: `Unit: <id>`, `## Objective` (the "do"), `## Affected files`, `## Do NOT touch`, `## Acceptance criteria` (`N. run:` lines). Headings are already parsed by `hooks/scripts/lib/unit-scope.sh:24-42`, `hooks/scripts/writer-scope-gate.sh:162-197`, `bin/review-precheck.sh:79,141`. An optional `## Ordered edits` stays allowed for a haiku writer, so `bin/contract-guard.js`/`contract-score.js`/`contract-anchors.js` need no change (a contract without it is demoted to sonnet, the status quo). Only `dispatch-hygiene.sh:398-417` (H4) hard-codes the nine headings.
- Fix contracts are defined only in `agents/task-master.md:98-108` today and consumed at `agents/orchestrator.md:255-268,363-364,394-416`, `agents/lead-programmer.md:43-50,75-76`, `agents/reviewer.md:22-23,63-64`. The storage path `docs/plans/<slug>/contracts/<unit>.md` is enforced by `writer-scope-gate.sh:175-180` and stays.
- `bin/cli.js --update` has a version-match fast path (`bin/cli.js:1515-1545`). Under per-release bumps, the in-repo mirror refresh is `node bin/cli.js --update --force-render`. It never deletes a removed persona's mirror (only `pruneStaleFileHashes`, `cli.js:552`), so U4 must `git rm` `.claude/agents/task-master.md`.
- `tests/abtest-arms.test.sh:112,114` (A/B harness, do not touch) scaffolds `--personas=spec-master,task-master,...`, and expects the full checkout to register exactly the `reviewed-path-gate.sh` and `harness-integrity-gate.sh` Bash hooks that the pruned copy drops. Therefore: `task-master` becomes a legacy token (D2), and the two Bash registrations stay in `hooks/hooks.json` with a Bash branch that allows at once (D5). `eval/abtest/run-matrix.sh:338` counts `*.escalated` files; with none written it reads 0, so eval needs no change.
- Escalation shared code to KEEP: `hooks/scripts/lib/state-access.sh`, `agent-identity.sh`, `audit-log.sh`, `portable-tools.sh`, `hooks/scripts/reviewer-tier.sh` (no escalation reference), the microworld rerun reporter (`microworld-rerun.sh`, `lib/microworld-rerun-core.sh`, `lib/microworld-queue.sh`, `microworlds/`) and every dashboard file not listed in U7b. `lib/benign-command.sh` is kept until U9 removes its last two sourcers. Escalation-only, to delete: `human-decision-gate.sh` (758 lines, hooks.json lines 20 and 35), `heavy-trigger.sh` (unregistered, reviewer-called), `bin/escalation-card.sh`, `bin/human-review-cleanup.sh`, `bin/microworld-dashboard/decision-block.js`, `decisions.js`, plus the protocol sections `templates/persona-protocol.md:388-930` (fourth verdict, packet viewer, DECISION routes, orchestrator steps).
- Stop gate today: `stop-gate.sh` (175 lines) + `lib/stop-gate-core.sh` (772): tombstones, resurrection guard, review-join stamps (written by `lib/reviewer-route-gate-core.sh:114,149`), zero-stamp bootstrap, grant-denied logging, `defer:`/`skip:`, microworld skip, config-drift check, test+lint run, `.escalated` block. Adapters carry copies, pinned by `tests/adapter-stop-gate-parity.test.sh`.
- No commit-time check detects a non-reviewer Bash write to `.claude/reviewed/` (`marker-commit-check.sh` is advisory). The replacement check (D6) lands in U8a before U9 relaxes the scans.
- Gate friction, observed while writing this plan: three read-only commands of mine were blocked (`human-decision-gate` twice on a grep pattern, `reviewed-path-gate` once on `git check-ignore`). The explorers hit four more.
- Prior history (marker sweep and `docs/audits/unit-outcomes/2026-10-06.jsonl`). `agents/task-master.md` notes (units 126 and 247) are version-stamp misses, which U1 retires. `vacuous`/`host` FAILs touched this plan's surfaces: `tests/validate.sh` (12 units), `agents/reviewer.md` (7), `bin/cli.js` (6), `stop-gate-core.sh` (4), `persona-protocol.md` (4). Hence every targeted criterion below carries a `mutation:` line. Agent-memory lessons applied: a source edit and its `.claude`/adapter copy ship in the same unit; docs units get claim-anchored greps, not existence greps.
- Marker-sweep `NOTE[spec]` dispositions:
  - `human-decision-gate.sh` (esc-left-3, esf-gate-bytes, esf-flag-prose) and `agents/task-master.md` (abt-u08b): moot, because U7a and U4 delete those files.
  - `harness-integrity-gate.sh` (hcb-branch, the header lists Set B with 3 literals but the code has 4): U9 rewrites that header, so U9 fixes it.
  - `version-stamp-check.sh`:
    - rgh-u2-1 and rgh-u3-1 (the script reads only `.claude-plugin/plugin.json`, never `package.json`): U1 keeps reading plugin.json, and its mutation lines name plugin.json.
    - version-stamp-check-roast-1 ("unmeasurable range" semantics): U1 keeps the existing unmeasurable-range handling unchanged.
    - aof-u3b (criterion commands that a writer may edit): no action.
- Strings in gate-scanned vocabulary (the escalation and marker-dir terms) appear in criteria only inside test files or split literals until U7a/U9 land, so criteria do not self-block.

### Decisions
- D1: five-field contract via existing headings (see above). At most 3072 bytes; H4 warns above that.
- D2: `task-master` and `hivemind` map to `['spec-master']` in `LEGACY_PERSONA_MAP`. Old `--personas` and `personaSelection` values keep working with a deprecation note.
- D3: a release is one commit that bumps `.claude-plugin/plugin.json` and adds a `## [<version>]` CHANGELOG heading. Content commits need no bump. Content commits may add `[Unreleased]` bullets, but none are required. `version-stamp-check.sh` checks two things only: a bumping commit names its version in CHANGELOG, and the version never decreases. Constitution P3 goes to 1.2.0 in U1. This plan has two releases: U1 (0.31.227, ships the new rule) and U13 (0.32.0).
- D4: escalation is replaced by a reviewer `needs-human: <one line>` note in its verdict. The orchestrator relays the note with AskUserQuestion. No marker, packet or gate.
- D5: the Bash branches of both gates become `exit 0` at entry. The hooks.json registrations stay (A/B harness parity, abtest-arms:114). Removing them is a follow-up that needs the A/B harness changed (out of scope).
- D6 (replacement check): `dispatch-hygiene.sh` touches `.claude/reviewed/.writer-dispatch-stamp` on every gated writer dispatch. At a gated writer's SubagentStop, stop-gate blocks if any `*.pass`, `*.fail` or `*.blocked` file in `.claude/reviewed/` is newer than that stamp, and names the file. Pending-review flags clear only on a reviewer SubagentStop, so a forged marker cannot end the review obligation.
- D7: the new stop-gate does three things. Under `reviewGating.mode: off` it exits 0. On a gated writer's SubagentStop it honours the WIP sentinel, runs D6, then writes the flag. On a reviewer SubagentStop it clears the flags. On the main Stop it blocks while a flag exists whose first line does not start with `skip:` or `defer:`.
- D8: one `validate.sh` run per unit, by the reviewer, after the final commit. If `bin/review-precheck.sh` already runs the testAndLintCommand, that run is the one. Writers run only the unit's targeted tests, and spec-master runs none.
- D9: reviewer notes stay in the marker body (lines 2+). The message only points at them. No new `.notes` file.
- D10: orchestrator source `agents/orchestrator.md` at most 16,384 bytes. Deployed `.claude/agents/orchestrator.md` at most 40,960 bytes (assumption A2). Moved prose goes to `docs/orchestrator-rationale.md`.
- D11: plan cap test applies to plans whose filename date is 2026-10-31 or later (this plan predates the rule; at ~34KB it would exceed the cap, which is why the cutoff is not back-dated).
- ADR candidate (for scribe to number): "Retire the escalation verdict and Bash text scanning" meets all three tests (hard to reverse, surprising, real trade-off). Draft: the context is 0 `.escalated` in 917 markers and 583 Bash blocks per month, all sampled read-only. The decision is D4+D5+D6. The consequences are the lost protections listed under Risks.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-30 Domain entities / data model: Q Which syntax do the five contract fields use? → A (self-resolved): existing headings (D1), because new `files:`/`check:` lines would fail closed in unit-scope.sh, writer-scope-gate.sh and review-precheck.sh.
- 2026-10-30 User interaction flow: Q What replaces the escalation card the user saw? → A (self-resolved): a `needs-human:` note relayed by AskUserQuestion (D4).
- 2026-10-30 Non-functional attributes: Q Which protection is lost when the Bash scans go, and is that acceptable? → A (self-resolved): see Risks R1; a detection check lands first (D6).
- 2026-10-30 External dependencies: Q Can the hooks.json Bash registrations be removed without touching the A/B harness? → A (self-resolved): no (abtest-arms:114 pins them), so they stay as no-ops (D5).
- 2026-10-30 Edge cases: Q How do old `personaSelection: [task-master]` configs behave? → A (self-resolved): legacy token mapped to spec-master (D2).
- 2026-10-30 Technical constraints: Q How do mirrors refresh when the version stops changing per commit? → A (self-resolved): `--update --force-render` in every unit criterion; consumers update at releases (R3).
- 2026-10-30 Terminology: Q New terms "five-field contract", "release", "needs-human note"; retired "ESCALATE-TO-HUMAN", "escalation card", "`.escalated` marker", "Escalation packet", "decision-gate denial", "review-join". → A (self-resolved): U12 (scribe) records them in CONTEXT.md / docs/harness-glossary.md.

## Risks / dependencies
- R1 Lost protection (U9). Any agent can now write `.claude/reviewed/*` or the Set A files (persona-config, audit logs and their seals) through Bash without a pre-block. What is kept: Write/Edit denies on both. D6 blocks a writer stop when a marker appeared during its dispatch. Flags clear only on reviewer stops. `bin/audit-seal-verify.sh` detects log tampering on demand. Why it is acceptable: 583 blocks per month, every sampled block was read-only, and no recorded case of a Bash forgery was caught. The A/B arm already runs without the scans (OD-20). Agents are instructed never to write markers outside their role.
- R2 Lost protections (U8a). The new stop-gate drops five things: the test+lint run at Stop (covered by D8's reviewer run), the microworld-rerun gating, the config-drift check, per-unit review-join scoping (the protocol already forbids two units mid-review), and the `.escalated` block (the path is gone).
- R3 Consumers on `--update` see content changes only at releases (D3). Accepted in the review, item 7.
- R4 U7a and U8a edit `hooks/hooks.json` or harness-guarded files. `harness-integrity-gate` asks the human for Set B writes. The writer must expect an approval prompt and must not route around it.
- R5 U3, U6, U10 and U11 each edit `agents/orchestrator.md`. They are strictly sequential, and U11 rewrites the result.
- R6 Prose pins in `tests/persona-prose-pins.test.sh`, `writer-tier-consistency.test.js`, `prompt-diet-pins.test.sh`, `protocol-cross-references.test.js` and `adapter-protocol-parity.test.js` will fail when pinned prose goes. A unit updates or deletes a pin only for the prose it removed (recorded in its notes line).
- Dependency order: U1 → U2 → U3 → U4 → U5 → U6 → U7a → U7b → U8a → U8b → U9 → U10 → U11 → U12 → U13.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every criterion is a command, and the targeted ones carry mutation lines.
- P2 "Prefer deterministic scripts": satisfied. `.claude` mirrors refresh via `node bin/cli.js --update --force-render`, and adapters are hand-synced (no script path exists).
- P3 "Version-stamp discipline": deviation. U1 amends P3 itself to per-release semantics (user-approved change 5). U1 obeys the old rule (it bumps), and U2-U12 follow the amended rule.
- P5 "validate.sh is the merge gate": satisfied. Each unit ends in one reviewer run of `bash tests/validate.sh` (D8).

## Steps
Each step: files, edits, criteria. Every unit also has two common criteria. **C-mirror** is `node bin/cli.js --update --force-render >/dev/null && git diff --quiet -- .claude adapters` (exit 0 after the final commit). **C-full** is `bash tests/validate.sh` (exit 0, run once by the reviewer). Suggested tier and lane in brackets.

### U1 lp-vsr: per-release version policy [sonnet, medium]
Files: `hooks/scripts/version-stamp-check.sh`, `tests/version-stamp-check.test.sh`, `.claude/constitution.md`, `skills/version-stamp-discipline/SKILL.md`, `agents/lead-programmer.md` (version paragraph), `agents/reviewer.md` (version-stamp lines), `.claude-plugin/plugin.json`, `CHANGELOG.md`, the `.claude` and adapter copies of the edited files.
Edits: implement the D3 check. Rewrite P3 per D3 and set `Version: 1.2.0` with an amendment-log line. Make the skill and persona prose say "per release". Bump to 0.31.227 with a CHANGELOG entry.
Criteria:
1. run: `bash tests/version-stamp-check.test.sh` → exit 0. The new cases must show: a stamped-file commit without a bump gives status ok; a bump without a CHANGELOG line naming the version is a violation; a version decrease is a violation. mutation: restore the old "stamped path requires bump" branch → the first case fails.
2. run: `grep -c '^Version: 1.2.0' .claude/constitution.md` → 1; `grep -ci 'per release' .claude/constitution.md skills/version-stamp-discipline/SKILL.md agents/lead-programmer.md | grep -c ':0$'` → 0.
3. C-mirror, C-full.

### U2 lp-cfx: five-field contract exists [sonnet, small]
Files: `templates/persona-protocol.md` (new section `## Dispatch contract (five fields)`, replacing nothing yet), `bin/cli.js` (`PROTOCOL_SECTIONS_BY_PERSONA`: include the section for lead-programmer, reviewer, spec-master, and the orchestrator if it is in the matrix), `hooks/scripts/dispatch-hygiene.sh` (H4: require the five, accept supersets, warn over 3072 bytes; reword comments at :60, :398-400 off task-master), `tests/dispatch-hygiene.test.sh`, mirrors.
Section text: the five fields per D1, the 3KB cap, optional `## Ordered edits` for haiku only, fix contract = same `Unit:` with `fix-of: <FAIL timestamp>` as the first Objective line.
Criteria:
1. run: `bash tests/dispatch-hygiene.test.sh` → exit 0. New cases: five-field contract gives no H4; missing `## Acceptance criteria` gives H4 naming it; a 3073-byte five-field body gives H4 naming the size; a nine-element contract gives no H4. mutation: re-add `## Ordered edits` to the required list → the first case fails.
2. run: `grep -l '^## Dispatch contract (five fields)' .claude/agents/lead-programmer.md .claude/agents/reviewer.md .claude/agents/spec-master.md | wc -l` → 3.
3. C-mirror, C-full.

### U3 lp-tmroute: stop routing to task-master [sonnet, medium]
Files: `agents/orchestrator.md` (routing table; fix-contract path at :255-268, :363-364, :394-416), `agents/spec-master.md` (hand-off: contracts for any unit count, no task-master and no tracker requirement), `agents/lead-programmer.md`, `agents/reviewer.md`, `agents/scribe.md`, `agents/agent-auditor.md`, `templates/persona-protocol.md` (:211, :964), `templates/persona-protocol-slim.md`, `commands/start-feature-team.md`, `skills/pathfinder/SKILL.md`, `skills/install-antislop/SKILL.md`, `skills/ubiquitous-language/SKILL.md`, `README.md`, `.claude-plugin/plugin.json` (description only, no bump), adapters (codex/cursor orchestrator and lead-programmer), the prose-pin tests that pin removed wording, mirrors.
Edits: the orchestrator writes the five-field fix contract after a FAIL. The anchor sentence is: `On FAIL, the orchestrator writes the fix contract`. spec-master `emits one five-field contract per unit`.
Criteria:
1. run: `git grep -n 'task-master' -- agents templates commands skills adapters README.md .claude-plugin ':!agents/task-master.md' | wc -l` → 0. mutation: restore one routing-table row → 1.
2. run: `grep -c 'On FAIL, the orchestrator writes the fix contract' agents/orchestrator.md` → 1; `grep -c 'emits one five-field contract per unit' agents/spec-master.md` → 1.
3. C-mirror, C-full.

### U4 lp-tmdel: delete the persona [sonnet, medium]
Files: `git rm` `agents/task-master.md` and `.claude/agents/task-master.md`. Also `bin/cli.js` (`OPTIONAL_PERSONAS`, `PROTOCOL_SECTIONS_BY_PERSONA` row :886, label :2509, D2 legacy map), `templates/persona-config.schema.json`, `.claude/constitution.md` (P4 list), `tests/validate.sh` (:280-292 cacheTtl entry; :1549 contract-examples now reads the protocol section), `tests/contract-examples.test.js`, `tests/protocol-cross-references.test.js:42`, `tests/rubric-doc-parity.test.js:68`, `tests/writer-tier-consistency.test.js`, `tests/persona-prose-pins.test.sh`, `tests/cli-backfill.test.js`, `tests/knowledge-writes.test.sh`, `tests/prompt-diet-pins.test.sh`, `tests/bin-helpers-scaffold.test.sh`, `tests/orchestrator-model.test.js`, `tests/effort-tier-consistency.test.js`, `tests/reviewed-path-gate.test.sh` (identity fixtures may keep the bare string as an arbitrary agent name). Not touched: `tests/abtest-arms.test.sh`, `eval/`, `scripts/` (historical analysers).
Criteria:
1. run: `test ! -e agents/task-master.md && test ! -e .claude/agents/task-master.md && echo gone` → `gone`.
2. run: `d=$(mktemp -d) && cd $d && git init -q && node /home/sebas/AntiSlop/bin/cli.js --personas=spec-master,task-master,reviewer >out.txt 2>&1; echo $?; test ! -e .claude/agents/task-master.md && grep -c 'Deprecation note' out.txt` → `0` then a count ≥1. mutation: drop the legacy-map entry → nonzero exit or no note.
3. run: `bash tests/abtest-arms.test.sh` → exit 0, and `git diff --quiet a511e8e7 -- tests/abtest-arms.test.sh eval` → exit 0.
4. run: `grep -c 'task-master' .claude/constitution.md` → 0. C-mirror, C-full.

### U5 lp-speccap: cap spec-master output [sonnet, medium]
Files: `agents/spec-master.md`, new `tests/plan-size-cap.test.sh`, `tests/validate.sh` (register it), mirrors.
Edits to spec-master.md: plan ≤ 25,600 bytes and ≤ 400 lines; contract ≤ 3,072 bytes. Below 6 units: no scorecard, no Clarifications log, no Self-check, no PRD mapping, no marker sweep, no publish. The plan shape is goal / decisions (at most 10) / units / open (at most 3). At 6 or more units these sections go to `docs/plans/<slug>/appendix.md`. Never Read or `cat` a file over 50KB whole; use offset/limit or grep. Run no `validate.sh`. Keep the 9-category scorecard as a private checklist.
Test: every `docs/plans/*.md` dated 2026-10-31 or later is within the plan caps, and every contract under such a slug is within the contract cap. A self-test plants an oversize plan under `PLANS_DIR=<tmp>` and expects failure.
Criteria:
1. run: `bash tests/plan-size-cap.test.sh` → exit 0 (includes the self-test). mutation: make the size comparison always pass → the self-test's oversize-fixture case fails, exit 1.
2. run: `for s in '25,600' '400 lines' '3,072' 'below 6 units' '50KB'; do grep -c -- "$s" agents/spec-master.md; done | grep -c '^0$'` → 0.
3. C-mirror, C-full.

### U6 lp-escprose: retire escalation in prose [sonnet, large]
Files: `templates/persona-protocol.md` (delete :388-930; edit the mixed lines :94-99, :291, :405, :424, :626, :655, :895), `agents/reviewer.md`, `agents/orchestrator.md`, `agents/lead-programmer.md`, `agents/spec-master.md`, `agents/milestone-auditor.md`, `agents/agent-auditor.md`, `commands/gate.md`, `adapters/codex/agents-md-fragment.md`, `adapters/cursor/rules/persona-protocol.mdc`, adapter persona copies, pinning tests, new `tests/escalation-retired.test.sh` (patterns assembled from fragments), `tests/validate.sh`, mirrors.
Edits: the reviewer has three verdicts (PASS, FAIL, INSUFFICIENT-CONTEXT) plus an optional `needs-human: <one line>` (D4). The orchestrator relays that note via AskUserQuestion.
Criteria:
1. run: `bash tests/escalation-retired.test.sh prose` → exit 0. It checks that `agents templates commands adapters skills` contain no escalation-verdict, escalated-marker, human-review packet, DECISION-route, escalation-card or heavy-trigger strings, and that `needs-human:` appears in reviewer.md and orchestrator.md. mutation: re-insert one fourth-verdict heading → exit 1.
2. run: `test $(wc -l < templates/persona-protocol.md) -le 560 && echo ok` → `ok`.
3. C-mirror, C-full.

### U7a lp-hdg: delete human-decision-gate [sonnet, medium]
Files: `hooks/scripts/human-decision-gate.sh` (delete), `hooks/hooks.json` (lines 20 and 35), `.claude/hooks/scripts` copy, `.claude/settings.json` via `--update`, `tests/human-decision-gate.test.sh` (delete), `tests/refusal-disclosure.test.sh`, `tests/validate.sh` (:535 and the suite entry), `bin/cli.js` (copy lists), `scripts/rollout-preflight.sh:81,98`, `tests/escalation-retired.test.sh` (add `code-hdg` mode).
Criteria:
1. run: `bash tests/escalation-retired.test.sh code-hdg` → exit 0 (the file is absent and named neither in hooks.json nor in .claude/settings.json). mutation: restore the hooks.json entry → exit 1.
2. run: `bash tests/abtest-arms.test.sh` → exit 0.
3. C-mirror, C-full.

### U7b lp-escbin: delete escalation helpers and dashboard decision code [sonnet, medium]
Files: delete `hooks/scripts/heavy-trigger.sh`, `bin/escalation-card.sh`, `bin/human-review-cleanup.sh`, `bin/microworld-dashboard/decision-block.js`, `bin/microworld-dashboard/decisions.js`; remove their call sites and routes in `server.js`, `index.html`, `discover.js`, `invoke.js`. Delete the tests: `tests/heavy-trigger.test.sh`, `tests/human-review-cleanup.test.sh`, `tests/packet-view-script.test.sh`, `tests/microworld/dashboard-decision*.test.js`, `dashboard-decisions*.test.js`, `dashboard-packets.test.js`. Also edit `bin/cli.js` (`BIN_HELPER_FILES` :656, human-review exclusions :169-171), `tests/validate.sh` (:959-963), `tests/escalation-retired.test.sh` (`code-bin` mode), mirrors. Keep the rest of the dashboard and the microworld reporter.
Criteria:
1. run: `bash tests/escalation-retired.test.sh code-bin` → exit 0 (the files are absent, and `git grep` finds no require/source of them in `bin hooks adapters`). mutation: re-add the `require('./decisions')` line → exit 1.
2. run: `for t in tests/microworld/dashboard-*.test.js; do node "$t" || echo FAIL; done | grep -c FAIL` → 0.
3. C-mirror, C-full.

### U8a lp-stopgate: one-flag stop gate plus marker check [opus, large]
Files: `hooks/scripts/stop-gate.sh`, `hooks/scripts/lib/stop-gate-core.sh`, `hooks/scripts/dispatch-hygiene.sh` (touch the D6 stamp in item 0a), the adapter stop-gate copies, new `tests/stop-gate.test.sh`. Delete `tests/stop-gate-blocked.test.sh`, `stop-gate-config-drift.test.sh`, `stop-gate-microworld-skip.test.sh`, `stop-gate-deferred-microworld.test.sh`, `stop-gate-escalated.test.sh` and `stop-gate-review-inflight.test.sh`, folding their surviving cases into the new file. Also edit `tests/adapter-stop-gate-parity.test.sh`, `tests/validate.sh`, mirrors.
Edits: D7 + D6 exactly. Remove the tombstones, resurrection-guard call, join-stamp consumption, bootstrap, grant-denied logging, microworld, config drift, test+lint and the escalated block.
Criteria:
1. run: `bash tests/stop-gate.test.sh` → exit 0. Cases: (a) gated writer stop writes a flag; (b) reviewer stop clears it; (c) main Stop blocks with a flag; (d) `skip:` flag does not block; (e) mode off never blocks; (f) a `.pass` newer than the stamp at writer stop blocks and names it; (g) an older `.pass` does not block; (h) WIP sentinel stop writes no flag. mutation: delete the D6 branch → case (f) fails.
2. run: `test $(cat hooks/scripts/stop-gate.sh hooks/scripts/lib/stop-gate-core.sh | wc -l) -le 250 && echo ok` → `ok`.
3. run: `bash tests/adapter-stop-gate-parity.test.sh` → exit 0. C-mirror, C-full.

### U8b lp-joinstamp: remove review-join stamps [sonnet, small]
Files: `hooks/scripts/lib/reviewer-route-gate-core.sh` (:33 resurrection guard if it serves only stop-gate; :114, :149 stamp writes), `hooks/scripts/lib/state-access.sh` (:82-101 join helpers; tombstone helpers :143-148 if they have no remaining caller), adapter copies, `tests/review-join.test.sh` (delete), `tests/pending-review-resurrection.test.sh`, `tests/state-access-*.test.sh`, `tests/validate.sh`, mirrors.
Criteria:
1. run: `git grep -n 'review-join' -- hooks bin adapters | wc -l` → 0. mutation: restore the :149 write → ≥1.
2. run: `bash tests/reviewer-route-gate.test.sh` (or the suite validate.sh names for that gate) → exit 0 with the one-unit-mid-review block case still present: `grep -c 'mid-review' tests/reviewer-route-gate*.test.sh` ≥ 1.
3. C-mirror, C-full.

### U9 lp-bashscan: drop Bash text scanning [opus, medium]
Files: `hooks/scripts/reviewed-path-gate.sh` (delete `mentions_marker_dir` :93, `mask_comments_only` :131, `write_with_commented_mention` :169 and the Bash checks :253-262 and :302; the Bash payload exits 0 at entry), `hooks/scripts/harness-integrity-gate.sh` (delete `set_a_mentioned` :197-277 and `is_benign_jq_read` :280; the Bash payload exits 0), `hooks/scripts/lib/benign-command.sh` and `tests/benign-command-families.test.sh` (delete), `bin/cli.js` (`CLAUDE_ONLY_HOOK_LIB_FILES` :686). Also: `tests/reviewed-path-gate.test.sh` and `tests/harness-integrity-gate.test.sh` (convert Bash cases to "allowed"), `templates/persona-protocol.md` (rephrasing-doctrine lines on Bash refusals), adapter copies, mirrors. `hooks/hooks.json` is unchanged (D5).
Criteria:
1. run: `bash tests/reviewed-path-gate.test.sh && bash tests/harness-integrity-gate.test.sh` → exit 0, with these cases present. A Bash payload `printf x > .claude/reviewed/a.pass` from lead-programmer → exit 0 (R1, documented loss). A Write to `.claude/reviewed/a.pass` from lead-programmer → deny. A Write to `.claude/persona-config.json` → deny. mutation: make the Write branch allow → the deny cases fail.
2. run: `git grep -nE 'mentions_marker_dir|set_a_mentioned|benign-command' -- hooks bin adapters | wc -l` → 0.
3. run: `bash tests/abtest-arms.test.sh` → exit 0. C-mirror, C-full.

### U10 lp-slim: short packet, verdict, one validate run [sonnet, medium]
Files: `agents/lead-programmer.md` (packet :94-120), `agents/reviewer.md` (verdict, notes, validate runs), `agents/spec-master.md` (no validate run), `templates/persona-protocol.md` (answer-shape lines if they restate the packet), adapter copies, pins, mirrors.
Edits: the packet is exactly 5 lines: `READY <unit> <base>..<head>` / `files: …` / `checks: …` / `notes: … (proposals and knowledge items go here or in docs/plans/<slug>/notes.md)` / `STATUS: …`. The PASS message is `PASS <unit> <sha> checks: …` / `notes: <n> (see marker)` / STATUS. A FAIL lists at most 3 defects of at most 3 lines each, then `more: <fail record path>`. Advisory sections go only in the marker body (D9). D8 wording: reviewer.md says `Run \`bash tests/validate.sh\` once`, and lead-programmer.md says `Run only the unit's own test files`.
Criteria:
1. run: `grep -c '^READY <unit-id> <base>..<head>$' agents/lead-programmer.md; grep -c 'Run only the unit.s own test files' agents/lead-programmer.md; grep -c 'Run `bash tests/validate.sh` once' agents/reviewer.md` → `1`,`1`,`1`. mutation: delete the READY line → 0.
2. run: `grep -c 'Knowledge proposals:' agents/lead-programmer.md` → 0 (folded into `notes:`).
3. C-mirror, C-full.

### U11 lp-orch: orchestrator toward 15KB [opus, large]
Files: `agents/orchestrator.md`, `docs/orchestrator-rationale.md` (receives the moved mechanics), `adapters/codex/agents/orchestrator.toml`, `adapters/cursor/agents/orchestrator.md`, `bin/cli.js` (orchestrator protocol sections, if needed for D10), orchestrator prose pins, mirrors.
Keep: routing table, lanes, writer→reviewer rule, fix-contract rule (U3 anchor sentence), the `needs-human` relay, and one line on running `bin/unit-bookkeeping.sh`/`bin/ladder-tier.sh` and passing their output. The final message is three lines: `<unit>: PASS|FAIL … ` / `open: …` / `next: …`. Rulings and tier choices go to `.claude/orchestrator-rulings.log` only.
Criteria:
1. run: `test $(wc -c < agents/orchestrator.md) -le 16384 && test $(wc -c < .claude/agents/orchestrator.md) -le 40960 && echo ok` → `ok`. mutation: append 1KB of pre-cut text → fails.
2. run: `for s in 'On FAIL, the orchestrator writes the fix contract' 'needs-human' '^open: ' '^next: ' 'unit-bookkeeping.sh'; do grep -c -- "$s" agents/orchestrator.md; done | grep -c '^0$'` → 0.
3. C-mirror, C-full.

### U12 lp-scribe: glossary and ADR [haiku (scribe), small]
Files: `CONTEXT.md`, `docs/harness-glossary.md`, `docs/adr/<next>-retire-escalation-and-bash-scans.md` (from the ADR draft above).
Edits: add the entries "five-field contract", "release" and "needs-human note". Mark these entries `Retired (0.32.0)` without deleting them: task-master, ESCALATE-TO-HUMAN, `.escalated` marker, escalation card, Escalation packet, decision-gate denial, review-join.
Criteria:
1. run: `bash tests/escalation-retired.test.sh glossary` (U12 adds the mode) → exit 0. It checks that each retired term's entry contains `Retired (0.32.0)` and that each new term has a `**term**` line. mutation: remove one marker → exit 1.
2. run: `ls docs/adr | grep -c 'retire-escalation-and-bash-scans'` → 1. C-full.

### U13 lp-release: release 0.32.0 [haiku, small]
Files: `.claude-plugin/plugin.json`, `CHANGELOG.md`, `.claude/persona-config.json` (`pluginVersion` via `--update`).
Criteria:
1. run: `grep -c '"version": "0.32.0"' .claude-plugin/plugin.json; grep -c '^## \[0.32.0\]' CHANGELOG.md` → `1`,`1`.
2. run: `bash hooks/scripts/version-stamp-check.sh HEAD~1..HEAD` → its ok status line. Then `node bin/cli.js --update >/dev/null && git diff --quiet -- .claude` → exit 0. C-full.

## Dispatch
Contract files, written in this order, three per spec-master spawn (checkpoint rule). Links appear as each file is committed:
- [contracts/lp-vsr.md](2026-10-30-lean-pipeline/contracts/lp-vsr.md), [contracts/lp-cfx.md](2026-10-30-lean-pipeline/contracts/lp-cfx.md), [contracts/lp-tmroute.md](2026-10-30-lean-pipeline/contracts/lp-tmroute.md)
- [contracts/lp-tmdel.md](2026-10-30-lean-pipeline/contracts/lp-tmdel.md), [contracts/lp-speccap.md](2026-10-30-lean-pipeline/contracts/lp-speccap.md), [contracts/lp-escprose.md](2026-10-30-lean-pipeline/contracts/lp-escprose.md)
- [contracts/lp-hdg.md](2026-10-30-lean-pipeline/contracts/lp-hdg.md), [contracts/lp-escbin.md](2026-10-30-lean-pipeline/contracts/lp-escbin.md), [contracts/lp-stopgate.md](2026-10-30-lean-pipeline/contracts/lp-stopgate.md)
- [contracts/lp-joinstamp.md](2026-10-30-lean-pipeline/contracts/lp-joinstamp.md), [contracts/lp-bashscan.md](2026-10-30-lean-pipeline/contracts/lp-bashscan.md), [contracts/lp-slim.md](2026-10-30-lean-pipeline/contracts/lp-slim.md)
- (pending) lp-orch.md, lp-scribe.md, lp-release.md

## Open Questions
None block dispatch. Assumptions, each with the default taken:
- A1: tracker publication is skipped. The PRD-to-tracker step would hand work to the persona this plan deletes, and the user asked for contract files. To publish anyway, run `gh issue create` from this file.
- A2: deployed orchestrator at most 40,960 bytes (D10). If the inlined protocol cannot reach it after U6, U11 reports the measured figure and the cap is revisited.
- A3: U6's 560-line ceiling for the protocol is derived from deleting :388-930 (543 lines) out of 1026, with ~80 lines of slack for the new contract section and the needs-human text.

## Self-check
- CHK1: Is a five-field contract parseable by every current consumer (unit-scope, writer-scope-gate, review-precheck)? — PASS (D1 keeps their headings)
- CHK2: Do U2 and U4 agree on where contract examples live after the persona goes? — FAIL (missing) — revised in place (U4 repoints contract-examples to the U2 protocol section)
- CHK3: Is the replacement check defined before any Bash scan is dropped? — PASS (D6 in U8a, U9 after)
- CHK4: Is the lost protection of change 4 stated? — PASS (R1, R2)
- CHK5: Does any unit modify eval/ or tests/abtest-arms.test.sh? — PASS (U4 criterion 3 asserts no diff; D5 keeps the registrations it pins)
- CHK6: Is the per-commit P3 rule obeyed by the unit that changes it? — PASS (U1 bumps 0.31.227)
- CHK7: Is there a criterion that self-blocks on gate-scanned text before the gate is gone? — FAIL (conflicting) — revised in place (escalation strings moved into tests/escalation-retired.test.sh)
- CHK8: Replay — do the `tests/validate.sh` criteria still fail under mutation, given gh317, gh320, gh409, gh413 (class vacuous/host)? — PASS (C-full is backed by a targeted criterion with its own mutation line in every unit)
- CHK9: Replay — does U8a criterion 1 still fail under its mutation, given gh413, mw-step3, spec2-unitA/B (vacuous on stop-gate-core.sh)? — PASS (case f is tied to the D6 branch)
- CHK10: Replay — does U9 criterion 1 still fail under its mutation, given gh418 and human-review-cleanup-1 (vacuous on both gates)? — PASS (the mutation flips the Write branch, which the deny cases assert)
- CHK11: Replay — does U1 criterion 1 fail under its mutation, given item17-4 (host on version-stamp-check)? — PASS
- CHK12: Replay — does U4 criterion 2 fail under its mutation, given gh360, gh409 (vacuous on bin/cli.js)? — PASS
- CHK13: Does every Goal clause map to a step criterion? — PASS. Change 1 maps to U2-U4; change 2 to U5; change 3 to U6-U7b; change 4 to U8a-U9; change 5 (packet/verdict) to U10, final message to U11, per-release bump to U1/U13, one validate run to U10, orchestrator size to U11.
- CHK14: Is U5 criterion 1's mutation able to fail? — FAIL (ambiguous) — revised in place (mutation is the `PLANS_DIR` fixture run expecting exit 1)

## Scribe update hint
U12 is the scribe unit: three new glossary terms, seven retired terms, one ADR (draft in Context, Decisions).
