# Haiku-default cleanup (2026-10-08)

Status: CLOSED 2026-10-09 (see the Status update at the end). FINAL (fast path, 5 units, contracts below; follow-up unit hdc-6 added 2026-10-08, see `## Follow-up unit (2026-10-08)`). Follow-up to
`docs/plans/2026-10-08-haiku-default-tier.md` (htd-1..htd-7, all reviewer-PASSed,
HEAD 5f91df7, version 0.31.144, umbrella #529). ADR: `docs/adr/0040-implementer-tier-haiku-default.md`.

## Goal

Close the defects the htd reviewers recorded as non-blocking notes, so the
orchestrator, the shared digest, the ADR, the glossaries and the tests all
state the same Escalation ladder:

1. (F1) ADR-0040's early-tripwire prose and its audit command agree at every
   population size.
2. (F2) A unit with a pre-cutover FAIL block starts its ladder at the more
   capable of `sonnet` and the default tier (an `opus`-default project keeps
   its `opus` ladder), in the orchestrator, ADR-0040 and CONTEXT.md.
3. (F3) Ladder exhaustion is a FAIL-block count that *reaches or exceeds* the
   ladder length, in the orchestrator, ADR-0040 and CONTEXT.md.
4. (S1-S9) Stale or overstated wording is corrected in `agents/orchestrator.md`,
   `agents/task-master.md`, `templates/protocol-digest.md`,
   `commands/start-feature-team.md`, `README.md`, ADR-0040, `CONTEXT.md` and
   `docs/harness-glossary.md`.
5. (T1, T2, T4) Three test gaps close: migrate-twice no-op, a latent vacuity in
   the migrate check, and the exporter's null-cutover fallback.
6. (G1) CONTEXT.md gains entries for **default tier** and **Haiku-default cutover**.

## Context

Every item was re-verified against the tree at 5f91df7 (2026-10-08). Results:

| item | verdict | evidence |
|---|---|---|
| F1 | real | ADR-0040:59-60 says "from 20 units ... two exhausted units ends the trial early"; the jq at :64 applies `$f6 >= 2` only when `$n < 60`. At n >= 100, f6 = 2 gives 0.02 and prints `met`. |
| F2 | real | orchestrator.md:482-486 "whatever the default tier". For an `opus` default, n=1 gives sonnet-ladder entry 2 = `sonnet` (opus ladder: `opus`); n=2 gives an automatic `opus` dispatch where the opus ladder (length 2) stops. CONTEXT.md:364-365 "a function of the unit's FAIL-block count alone" also overstates; so does orchestrator.md:472 "depends only on n and the default tier". |
| F3 | real | orchestrator.md:470 "When n equals the ladder's length". |
| S1 | real | orchestrator.md:445-447 states tag > config > frontmatter with no "raise only" qualifier; :433-434 says a tag can raise, never lower. The substring is pinned by `tests/default-implementer-model.test.js:112`, so the fix appends a qualifier and keeps the pinned text. |
| S2 | real, premise corrected | `templates/protocol-digest.md:17-18` still says "2 FAILs on the same unit -> stop re-delegating". It is re-injected by `hooks/scripts/session-start.sh:63-65` on `source: resume`/`compact` only, not at every SessionStart. Deployed copy `.claude/protocol-digest.md` is refreshed by `--update`. No test pins its text. |
| S3 | real | README.md:185 "the second FAIL no longer stops for you". Not pinned. |
| S4 | real | commands/start-feature-team.md:46-48 says "the orchestrator's Escalation ladder" and nothing about where it lives or how the lead sets a teammate's tier. Not version-stamped, not mirrored, not pinned except htd-5's own phrase `only at ladder exhaustion do you stop` (kept). |
| S5 | real | agents/task-master.md:105-106 "`haiku` is the default for every unit". The exact wrapped text "`haiku` is\n  the default for every unit" is pinned by `tests/writer-tier-consistency.test.js:54` (AC-D5; measured: a rewrite that drops it fails AC-D5). The fix keeps it and appends "unless this project's `defaultImplementerModel` names another tier". |
| S5 coupling | intended, no change | AC-D10 makes validate.sh fail if this repo's config resolves away from the lead-programmer frontmatter. During ADR-0040's trial this repo is the trial population, so a silent `sonnet` here would invalidate the trial; and the forward rule's revert path flips the frontmatter, after which AC-D10 forces the config to follow. Recorded as a decision; no edit. |
| S6 | real; exporter unchanged | CONTEXT.md:785-786 (FAIL record) and docs/harness-glossary.md:3214-3216 (terminal event) treat the second FAIL as the cap stop. `scripts/unit-outcomes.js:235-243` defines `terminal_ts` as the earlier of the PASS and the second FAIL block, and `fail_blocks` counts every block up to `--until`. Under the ladder the second FAIL is the end of the first tier, not a stop, but the forward rule's rates read `fail_blocks`, which is still complete. Decision: keep the exporter's semantics (changing them would rewrite every historical export and the G3 gate); reword the glossary. The field name `cap_hit` (`fail_blocks >= 2`) is now a misnomer; out of scope, noted in Risks. |
| S7 | real, measured | Markers with a verdict after the cutover 2026-10-08T17:28:48Z: htd-4 (18:05), htd-5 (17:44), htd-6 (18:21), htd-7 (18:35), all PASS with no FAIL block, all dispatched with `Suggested model: sonnet`. They enter the haiku trial's population. Four zero-FAIL units among the first 60 can move fail-rate by up to 4/60 (0.067), enough to turn a 0.37 into a `met`. Decision: add a filter excluding ids that start with `htd-` to the jq and say so in the prose; the pinned phrase `≥60 units dispatched under the \`haiku\` default` stays. A generic dispatch-time filter is not available: `contract_ts` may be null, transcripts are pruned after about 30 days, and era inference returns `haiku` for every post-cutover row. This cleanup's own ids are `hdc-*`, dispatched on the haiku default, and correctly count. |
| S8 | note only | The 19-minute window between the cutover literal (17:28:48Z) and the flip commit 814960b (17:48:13Z) holds no FAIL block in this repo (htd-4 reviewer checked; the marker scan above agrees). The S7 filter also removes the only units that closed in it. |
| S9 | real | CONTEXT.md:359 Writer tier links ADR-0026 only. |
| T1 | real | No test runs `--update` twice after the migration. Prototype check passes at HEAD (scratch worktree). |
| T2 | partly moot, latent gap real | Deleting the `applyImplementerModelMigration(config, dryRun);` call now fails the migrate check (measured). But setting `IMPLEMENTER_HAIKU_DEFAULT_SINCE = null` leaves `default-implementer-model`, `writer-tier-consistency` and `cli-backfill` all green (measured, rc 0 each): the check computes its expectation from the same constant. Fix: assert `expected === 'haiku'` whenever the frontmatter is `haiku`. |
| T3 | dropped | With the constant set, `implementerFrontmatterDefault()` (bin/cli.js:389) is load-bearing on every `--update`, and it reads the packaged frontmatter that validate.sh's frontmatter checks already guard. A dormancy guard no longer applies. |
| T4 | real | No test covers `HAIKU_CUTOVER === null` (scripts/unit-outcomes.js:103-111). Prototype check (copy the script to a temp dir with no cutover line, and with no orchestrator.md) passes at HEAD; mutation `return m ? m[1] : null;` → `return m ? m[1] : '2026-10-08T17:28:48Z';` makes it fail (measured). |
| G1 | partly | Add **default tier** and **Haiku-default cutover** to CONTEXT.md. "forward rule (pre-registered)" is the existing harness-glossary term **Forward-verification rule** (docs/harness-glossary.md:1508): no new entry, one pointer sentence to ADR-0040 there (it also names the early tripwire). "spirit ruling" is a one-off of ADR-0040's Context; no entry. "cutover unit" (htd-2 note) goes into the new entry's `_Avoid_` line. |

Prior FAIL history: no `htd-*.fail` record exists (directory listed in full, 2026-10-08), so no Implementer-tier ratchet applies to any re-scoped work. `bash bin/marker-audit.sh --notes` was not run (Bash was refused by the permission classifier late in the session); the seven `htd-*.pass` notes were read in full with the Read tool and every NOTE is dispositioned in the table above or in Risks. An empty sweep would not prove absence anyway.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-08 Domain entities / data model: Q Should the exporter's terminal event change now that the second FAIL is not a stop? → A (self-resolved): no; the glossary is reworded, `scripts/unit-outcomes.js` is untouched, and `fail_blocks` already counts later blocks up to the cutoff.
- 2026-10-08 External dependencies & integrations: Q How does an agent-teams lead set a teammate's tier? → A (self-resolved): as the `model` parameter of the `Agent` call that spawns the lead-programmer teammate for the unit's next attempt (assumption A1 below).
- 2026-10-08 Edge cases / failure handling: Q For F1, fix the prose or the command? → A (self-resolved): the prose. The command is the operational rule and was pre-registered; bounding "early" to 20-59 units changes no verdict, while widening the command would make the rule stricter after registration.
- 2026-10-08 Edge cases / failure handling: Q For S7, reword only or add a filter? → A (self-resolved): add an `htd-` id filter, because four sonnet-dispatched zero-FAIL units can flip a borderline verdict (measured above).
- 2026-10-08 Technical constraints & tradeoffs: Q Is AC-D10's coupling of the test suite to this repo's config intended? → A (self-resolved): yes, for the trial's duration; no edit.
- 2026-10-08 Technical constraints & tradeoffs: Q Change pinned test strings or keep them? → A (self-resolved): keep every pinned substring (AC-D5 task-master, AC-D8b ADR-0040, the precedence pin in default-implementer-model) and append qualifiers instead, so no persona unit edits a test.
- 2026-10-08 Terminology consistency: Q Which new glossary terms? → A (self-resolved): **default tier** and **Haiku-default cutover** only; "forward rule (pre-registered)" folds into **Forward-verification rule**; "spirit ruling" gets no entry.

Assumptions: A1, the `Agent` tool's `model` parameter applies to a teammate spawn (the start-feature-team wording only tells the lead to pass it; it does not claim a running teammate can change tier). A2, no other unit closes between now and the hdc-4 commit with an id starting `htd-`.

## Risks / dependencies

- R1 Version chain: hdc-1 0.31.145, hdc-2 0.31.146, assuming HEAD stays at 0.31.144. Each persona contract STOPs on a version mismatch; the orchestrator re-derives the literals (HEAD + 1).
- R2 Order: hdc-1 → hdc-2 (serial, both bump). hdc-4 after hdc-1 (same legacy-ladder rule). hdc-5 after hdc-1 and hdc-4. hdc-3 is independent and may run at any point, but not concurrently with a unit whose `--update` rewrites `.claude/` (one unit mid-review at a time anyway).
- R3 `bash tests/validate.sh` takes about 11 minutes and fails in a fresh worktree for environment reasons; run it in the main checkout (htd contracts note).
- R4 Unproven mutations: the permission classifier refused the scratch-worktree mutation runs for T1 and part of hdc-1/hdc-2 late in this session. Every such criterion is marked `proof: not run by spec-master`; the reviewer must run those mutations.
- R5 Residuals not edited: `cap_hit` field name in the exporter (misnomer, schema change); CONTEXT.md **defaultImplementerModel** entry's "(1) explicit per-dispatch tag (if present)" still lacks the raise-only qualifier (its lines carry trailing spaces, which makes literal edits fragile for a haiku executor; candidate for a later scribe pass); the codex/cursor ports keep their per-unit cap (deliberate since htd-5); the old plan's D6 text is history and is not edited.
- R7 hdc-6 edits the `**default tier**:` and `**Haiku-default cutover**:` entries hdc-5 created and the `**terminal event**:` entry hdc-5 reworded. It runs only after hdc-5's PASS. Its edit 3 keeps the phrase `first tier and is not a stop`, so hdc-5 criterion 2 still prints `0 1 1 ` after hdc-6 (measured in a scratch clone); hdc-5 criterion 1 still prints `0 1 1 1 1 1 1 1 0 `.
- R6 Scratch worktree `/tmp/claude-1000/-home-sebas-AntiSlop/59f5acf3-e86d-43dc-8f42-a743bd6c33c3/scratchpad/hdc-wt` (detached at 5f91df7, uncommitted prototype edits) is still registered; spec-master could not remove it (Bash refused). The orchestrator should run `git worktree remove --force` on it.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied (every item re-verified; measured T2/T4/S5/S7 facts; unproven mutations flagged in R4)
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied (mirrors change only through `node bin/cli.js --update`)
- P3 "Version-stamp discipline": satisfied (hdc-1 and hdc-2 bump and add a CHANGELOG entry in the same commit; hdc-3/4/5 touch no stamped path)
- P4 "Optional personas degrade gracefully": satisfied (no new persona references; start-feature-team wording is inside the existing lead-programmer teammate sentence)
- P5 "tests/validate.sh is the merge gate": satisfied (last criterion of every unit)

## Steps

| unit | persona | items | files | bump | after |
|---|---|---|---|---|---|
| hdc-1 | lead-programmer | F2, F3, S1, S5 | agents/orchestrator.md, agents/task-master.md | 0.31.145 | none |
| hdc-2 | lead-programmer | S2, S3, S4 | templates/protocol-digest.md, commands/start-feature-team.md, README.md | 0.31.146 | hdc-1 |
| hdc-3 | lead-programmer | T1, T2, T4 | tests/default-implementer-model.test.js, tests/unit-outcomes.test.js | none | none |
| hdc-4 | scribe | F1, S7, F2/F3 in the ADR | docs/adr/0040-implementer-tier-haiku-default.md | none | hdc-1 |
| hdc-5 | scribe | F2/F3/S6/S9/G1 in glossaries | CONTEXT.md, docs/harness-glossary.md | none | hdc-1, hdc-4 |
| hdc-6 | scribe | N1, N2, N3 (hdc-5 FAIL-record advisory notes) | CONTEXT.md, docs/harness-glossary.md | none | hdc-5 PASS |

Step acceptance criteria are the contract criteria below. Tags: no `hdc-*.fail` exists, so every unit dispatches on the default tier (`haiku`); no `Suggested model` tag. The reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over each unit's actual diff.

## Open Questions

1. (from CHK6) The Self-check replay over `docs/audits/unit-outcomes/` (units with FAIL class `vacuous` or `host` whose files intersect this plan's `run:` files) could not be computed: Bash was refused. Recommended default: the orchestrator runs it once before dispatching hdc-3 (`jq` over the export for those classes, then `git show --name-only` per `final_commit`); if a unit intersects `tests/default-implementer-model.test.js` or `tests/unit-outcomes.test.js`, the reviewer confirms that criterion's `mutation:` line bites. Not blocking.

## Self-check
- CHK1: Do hdc-1 edit 3, hdc-4 Doc edit 1 and hdc-5 Glossary edit 1 state the same legacy-ladder rule ("the more capable of `sonnet` and the default tier")? — PASS
- CHK2: Do ADR-0040's tripwire prose (after hdc-4) and its jq agree for n >= 60 with two exhausted units? — PASS
- CHK3: Is ladder exhaustion defined for n greater than the ladder length in the orchestrator (hdc-1 edit 2), the ADR (hdc-4 Doc edit 1) and CONTEXT.md (hdc-5 Glossary edit 2)? — PASS
- CHK4: Does every pinned substring survive: AC-D5 task-master text, AC-D8b ADR phrases, the precedence pin at tests/default-implementer-model.test.js:112, htd-5's `only at ladder exhaustion do you stop`? — PASS (hdc-1 measured in scratch; the others are kept verbatim in the after-text)
- CHK5: Does every `mutation:` line carry a proof or a "not run" mark? — FAIL (missing) — revised in place (R4; each unproven line says `proof: not run by spec-master`)
- CHK6: Does the unit-outcomes replay add any item for this plan's `run:` files? — FAIL (missing) — converted to Open Question 1
- CHK7: Does the Goal clause "S8" map to a step? — PASS (Context row S8: note only, no step by design)
- CHK8: Do hdc-1 and hdc-2 agree on the version chain and order? — PASS

- CHK9: Does every commit-trailer criterion (hdc-3 criterion 6, hdc-4 criterion 7, hdc-5 criterion 7) still pass when a fix round adds a commit, and fail when any one commit lacks its trailer? — FAIL (conflicting) — revised in place (2026-10-08 Ruling; the old `grep -c` form expected `1` and printed `2` at 082ec3c)
- CHK10: Is each hdc-6 edit's mutation measured, and does hdc-6 leave hdc-5's criteria 1 and 2 unchanged? — PASS (scratch clone, R7)
- CHK11: Does hdc-6's tag-floor wording agree with `agents/orchestrator.md` ("never a tier cheaper than the ladder's entry")? — PASS

Ubiquitous-language (prose mode, advisory): lens 1 none; lens 2 "cutover unit" and "flip commit" are synonyms for the commit that set the Haiku-default cutover, routed to its `_Avoid_` line; lens 3 **default tier** and **Haiku-default cutover** were load-bearing with no entry, added by hdc-5.

## Scribe update hint

hdc-4 and hdc-5 are the scribe work. After hdc-5, hdc-6 is the last scribe unit; R5's **defaultImplementerModel** qualifier is a candidate for a later pass.

## Ruling (2026-10-08): per-commit trailer criteria

- **Contract defect, not an implementer failure.** hdc-5's second FAIL (`.claude/reviewed/hdc-5.fail`, block 2026-10-08T21:34:42Z) rests only on criterion 7. It counted trailer lines over the whole `(hdc-5)` range and expected `1`. The FAIL-1 fix round correctly added a second commit (082ec3c after b3cdba8), so the count became `2`. The old form also caught nothing once the unit had two commits: dropping one commit's trailer printed `1`, the expected value. Rule P5 (`docs/plans/2026-10-07-final-cleanup.md`, P5) already says the trailer count equals the unit's commit count; this plan's criteria did not follow it. The reviewer verified everything else.
- **User-directed remedy:** amend the criterion. No history rewrite (no squash of b3cdba8/082ec3c), no tier change, and the FAIL does not count as a defect of the implementer.
- **Amended:** hdc-3 criterion 6, hdc-4 criterion 7 and hdc-5 criterion 7 now print the distinct per-commit trailer-line counts over the unit's range; expected stdout `1 ` for any number of commits. This is stricter than P5's equal-count form: a commit with two trailers cannot hide one with none (measured: `0 2 `). The regex stays model-agnostic, not P5's `-xF` exact line, because a unit that climbs the Escalation ladder commits its fix rounds under a different model's trailer (hdc-5 already carries Haiku 4.5 and Sonnet 5.5).
- **Also amended:** hdc-5's Objective and `commit:` close condition now allow one commit per fix round; hdc-3's Objective likewise. hdc-3, not yet executed, gets the P5-exact trailer line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. The landed units' (hdc-1, hdc-2, hdc-4, hdc-5) trailer instruction text is left as it was. hdc-1 criterion 10 and hdc-2 criterion 11 keep the old form; both landed as one commit and passed review.
- **Re-review of hdc-5:** criteria 5-8 only, as the reviewer stated. Criteria 1-4 and the edits are unchanged by this ruling. Criterion 9 (validate.sh) is unchanged and was not part of either FAIL.

## Follow-up unit (2026-10-08)

hdc-5's FAIL record carries three advisory spec notes, all small enough for one glossary-only scribe unit (hdc-6):
- N1: `docs/harness-glossary.md` **terminal event** says the second FAIL "ends the unit's first tier and is not a stop". That is false for an `opus` default tier, whose ladder is `opus` alone: the second FAIL there is ladder exhaustion.
- N2: CONTEXT.md **Haiku-default cutover** says ADR-0040's forward rule counts every unit whose terminal event is at or after the cutover, but it leaves out the `htd-` exclusion hdc-4 added.
- N3: CONTEXT.md **default tier** says a `Suggested model` tag cannot lower a unit below the default tier. The floor is the ladder's entry, which is `sonnet` or above for a unit with a pre-cutover FAIL block (`agents/orchestrator.md`: "never a tier cheaper than the ladder's entry").

---

# Dispatch contracts (fast path)

## Retrieval contract
No per-unit issues exist. The retrieval contract for every unit is this file, `docs/plans/2026-10-08-haiku-default-cleanup.md`, under `## Unit hdc-<n>`. The contract block outranks the plan prose above; a conflict is a spec gap: STOP. Every commit subject ends `(#529)`; scribe closes nothing and never closes #529.

## Unit hdc-1

~~~~~markdown
Unit: hdc-1

## Objective
`agents/orchestrator.md` defines ladder exhaustion as n reaching or exceeding the ladder length, starts a pre-cutover unit's ladder at the more capable of `sonnet` and the default tier, says the ladder depends on the cutover too, and says a `Suggested model` tag can only raise the ladder tier. `agents/task-master.md` says `haiku` is the default unless the project's `defaultImplementerModel` names another tier. Version 0.31.145, one commit, mirrors refreshed by `--update`.

## Retrieval
Plan file: `docs/plans/2026-10-08-haiku-default-cleanup.md`, `## Unit hdc-1`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `agents/orchestrator.md` (anchors below)
- `agents/task-master.md` (anchor below)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.144",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/orchestrator.md`
   anchor: line matching `default (CONTEXT.md's **Writer tier** entry). Read the raw value yourself.`
   indent: 0
   before:
```
default (CONTEXT.md's **Writer tier** entry). Read the raw value yourself.
```
   after:
```
default (CONTEXT.md's **Writer tier** entry), except that the tag can only
raise the tier the **Escalation ladder** below gives, never lower it. Read the
raw value yourself.
```
2. file: `agents/orchestrator.md`
   anchor: line matching `attempt n+1 on the ladder's entry n+1. When n equals the ladder's length,`
   indent: 0
   before:
```
attempt n+1 on the ladder's entry n+1. When n equals the ladder's length,
that is **ladder exhaustion**: dispatch nothing and go to **At the 2-FAIL
cap**. The ladder depends only on n and the default tier, so a fresh session
```
   after:
```
attempt n+1 on the ladder's entry n+1. When n reaches or exceeds the ladder's
length, that is **ladder exhaustion**: dispatch nothing and go to **At the 2-FAIL
cap**. The ladder depends only on n, the default tier and whether any block
predates the **Haiku-default cutover** below, so a fresh session
```
3. file: `agents/orchestrator.md`
   anchor: line matching `such block uses the ladder that starts at `
   indent: 0
   before:
```
count alone cannot say which tier wrote them. Fail closed: a unit with any
such block uses the ladder that starts at `sonnet` (`sonnet`, `sonnet`,
`opus`, `opus`), whatever the default tier.
```
   after:
```
count alone cannot say which tier wrote them. Fail closed: a unit with any
such block uses the ladder that starts at the more capable of `sonnet` and the
default tier: `sonnet`, `sonnet`, `opus`, `opus` when the default tier is
`haiku` or `sonnet`, and `opus`, `opus` when it is `opus`.
```
4. file: `agents/task-master.md`
   anchor: line matching `the default for every unit, and a unit you judge security-sensitive,`
   indent: 2
   before:
```
  haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `haiku` is
  the default for every unit, and a unit you judge security-sensitive,
```
   after:
```
  haiku|sonnet|opus`. Tagging is **reactive**, not predictive: `haiku` is
  the default for every unit unless this project's `defaultImplementerModel`
  names another tier (the orchestrator resolves it), and a unit you judge security-sensitive,
```
5. file: `.claude-plugin/plugin.json` (version 0.31.145)
   anchor: line matching `"version": "0.31.144",`
   before: `  "version": "0.31.144",`
   after: `  "version": "0.31.145",`
6. file: `package.json` (version 0.31.145)
   anchor: line matching `"version": "0.31.144",`
   before: `  "version": "0.31.144",`
   after: `  "version": "0.31.145",`
7. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Escalation ladder edge cases (hdc-1, 0.31.145).** `agents/orchestrator.md`: ladder exhaustion is n reaching or exceeding the ladder's length, so a FAIL after a human-directed re-dispatch still stops; a unit with a FAIL block older than the haiku-default cutover starts its ladder at the more capable of `sonnet` and the default tier, so an `opus`-default project keeps its `opus` ladder; the precedence sentence says a `Suggested model` tag can only raise the ladder tier. `agents/task-master.md`: `haiku` is the default unless the project's `defaultImplementerModel` names another tier.
```
8. command: `node bin/cli.js --update`
   expect: 0
9. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
10. command: `git add agents/orchestrator.md agents/task-master.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(hdc-1): escalation ladder edge cases and tag precedence (0.31.145) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0
   (write your own model's name in the trailer, e.g. `Claude Haiku 4.5`)
11. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `tests/` (every pinned substring is kept verbatim on purpose)
- `CONTEXT.md` and `docs/harness-glossary.md` (unit hdc-5)
- `docs/adr/0040-implementer-tier-haiku-default.md` (unit hdc-4)
- `templates/protocol-digest.md` (unit hdc-2)
- `adapters/` (the codex and cursor ports keep their per-unit cap)

## Acceptance criteria
1. run: `F=agents/orchestrator.md; for p in 'When n reaches or exceeds the ladder' 'When n equals the ladder' 'whatever the default tier' 'that starts at the more capable of' 'the tag can only raise the tier the **Escalation ladder** below gives, never lower it' 'predates the **Haiku-default cutover** below'; do tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 0 0 1 1 1 `
   mutation: skip edit 2; prints `0 1 0 1 1 0 `.
   proof: edits 1-4 applied in a scratch worktree of 5f91df7 by spec-master; the per-phrase counts were 1, 0, 0, 1, 1, 1. The skip-edit-2 variant was not run by spec-master.
2. run: `tr '\n' ' ' < agents/task-master.md | tr -s ' ' | /usr/bin/grep -oF -- 'names another tier (the orchestrator resolves it)' | wc -l`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; prints `0`.
3. run: `/usr/bin/grep -c 'When n reaches or exceeds the ladder' .claude/agents/orchestrator.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; prints `0`, exit 1.
4. run: `node tests/writer-tier-consistency.test.js > /dev/null && node tests/default-implementer-model.test.js > /dev/null && echo tier-tests-ok`
   exit: 0
   stdout: `tier-tests-ok`
   mutation: in edit 4 write `every unit starts on the default tier` instead of keeping the line pair "`haiku` is" / "the default for every unit"; AC-D5 fails, exit 1.
   proof: spec-master ran that wording in a scratch worktree; `writer-tier-consistency` printed `1 check(s) failed.` (AC-D5). With edit 4 as written both suites printed their all-passed line.
5. run: `bash hooks/scripts/version-stamp-check.sh "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" | /usr/bin/grep -c '^version-stamp-check: ok'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the line no longer reads `ok`, prints `0`, exit 1 (the script itself exits 0 on a violation, so this gates on stdout).
6. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.145';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 6; prints `version-sync: mismatch`, exit 1.
7. run: `diff <(git diff --name-only "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' .claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md agents/task-master.md package.json | sort) && echo scope-1-ok`
   exit: 0
   stdout: `scope-1-ok`
   mutation: skip edit 7; exit 1.
8. run: `git diff --name-only "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip edit 8; prints `0`.
   proof: spec-master ran edits 1-6 and `node bin/cli.js --update` in a scratch worktree; `git status --porcelain -- .claude` listed 14 paths.
9. run: `git log --format=%s "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
10. run: `git log --format=%B "$(git log --format=%H -F --grep='(hdc-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-1)' | head -1)" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer; prints `0`, exit 1.
11. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
12. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of `.claude/agents/orchestrator.md`; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run (about 11 minutes; run it in the main checkout).

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.144`. Anything else: STOP; the orchestrator re-derives every version literal as HEAD version + 1.
precondition: `git log --format=%H -F --grep='(hdc-1)' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and every `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edit; the checks are greps, two existing test suites that pin the kept substrings, and validate.sh mirror parity
blast-radius: agents/orchestrator.md:447, agents/orchestrator.md:470, agents/orchestrator.md:484, agents/task-master.md:105, tests/default-implementer-model.test.js:112, tests/writer-tier-consistency.test.js:54
note: `tests/default-implementer-model.test.js:112` pins "`Suggested model` tag > `defaultImplementerModel` config field > frontmatter default" and `tests/writer-tier-consistency.test.js:54` pins "`haiku` is\n  the default for every unit"; the after-texts keep both.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
explorer: not needed (provenance: grep and read by spec-master at 5f91df7, plus an explorer blast-radius pass).
commit-message: feat(hdc-1): escalation ladder edge cases and tag precedence (0.31.145) (#529)
review-packet:
```
unit: hdc-1 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criteria 1-12: <FILL: exit and stdout of each>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit hdc-2

~~~~~markdown
Unit: hdc-2

## Objective
The protocol digest re-injected on resume/compact states the per-tier cap; `commands/start-feature-team.md` names where the team lead reads the Escalation ladder and how it sets a teammate's tier; README's review-gating-off paragraph says ladder exhaustion. Version 0.31.146, one commit.

## Retrieval
Plan file: `docs/plans/2026-10-08-haiku-default-cleanup.md`, `## Unit hdc-2`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `templates/protocol-digest.md` (anchor below)
- `commands/start-feature-team.md` (anchor below)
- `README.md` (anchor below)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.145",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `templates/protocol-digest.md`
   anchor: line matching `- FAIL cap: 2 FAILs on the same unit -> stop re-delegating fixes; surface the`
   indent: 0
   before:
```
- FAIL cap: 2 FAILs on the same unit -> stop re-delegating fixes; surface the
  full defect history to the user instead of attempting a third pass.
```
   after:
```
- FAIL cap: 2 FAILs per implementer tier -> move the unit up the Escalation
  ladder; only at ladder exhaustion (the top tier's second FAIL) stop
  re-delegating and surface the full defect history to the user instead.
```
2. file: `commands/start-feature-team.md`
   anchor: line matching `re-delegating and surface the full defect history to the user instead. "Done" is enforced`
   indent: 0
   before:
```
re-delegating and surface the full defect history to the user instead. "Done" is enforced
```
   after:
```
re-delegating and surface the full defect history to the user instead. The ladder
is the **Escalation ladder** paragraph in the **Per-unit model routing** section
of `.claude/agents/orchestrator.md`: compute the unit's next tier there from its
FAIL-block count, and pass that tier as the `model` parameter of the `Agent` call
that spawns the lead-programmer teammate for the unit's next attempt. "Done" is enforced
```
3. file: `README.md`
   anchor: line matching `marker, no human escalation, and the second FAIL no longer stops`
   indent: 0
   before:
```
`.escalated` marker, no human escalation, and the second FAIL no longer stops
```
   after:
```
`.escalated` marker, no human escalation, and ladder exhaustion no longer stops
```
4. file: `.claude-plugin/plugin.json` (version 0.31.146)
   anchor: line matching `"version": "0.31.145",`
   before: `  "version": "0.31.145",`
   after: `  "version": "0.31.146",`
5. file: `package.json` (version 0.31.146)
   anchor: line matching `"version": "0.31.145",`
   before: `  "version": "0.31.145",`
   after: `  "version": "0.31.146",`
6. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**FAIL-cap wording outside the orchestrator (hdc-2, 0.31.146).** `templates/protocol-digest.md` (re-injected on resume and compact): two FAILs per implementer tier, stop only at ladder exhaustion. `commands/start-feature-team.md` names where the team lead reads the Escalation ladder and that it passes the ladder's tier as the teammate spawn's `model` parameter. README's review-gating-off paragraph says ladder exhaustion.
```
7. command: `node bin/cli.js --update`
   expect: 0
8. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
9. command: `git add templates/protocol-digest.md commands/start-feature-team.md README.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(hdc-2): digest, team command and README state the per-tier cap (0.31.146) (#529)" -m "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"`
   expect: 0
   (write your own model's name in the trailer)
10. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `agents/orchestrator.md` (unit hdc-1, already landed)
- `templates/persona-protocol.md` (its cap paragraph is already per tier since htd-5)
- `adapters/` (the codex and cursor ports keep their per-unit cap)
- `tests/`

## Acceptance criteria
1. run: `F=templates/protocol-digest.md; for p in '2 FAILs per implementer tier' 'stop re-delegating fixes' 'only at ladder exhaustion'; do tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 0 1 `
   mutation: skip edit 1; prints `0 1 0 `.
2. run: `/usr/bin/grep -c '2 FAILs per implementer tier' .claude/protocol-digest.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; prints `0`, exit 1.
3. run: `F=commands/start-feature-team.md; for p in '**Per-unit model routing**' 'only at ladder exhaustion do you stop' 'spawns the lead-programmer teammate for the unit'; do tr '\n' ' ' < $F | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 1 `
   mutation: skip edit 2; prints `0 1 0 `.
4. run: `printf '%s %s\n' "$(/usr/bin/grep -c 'the second FAIL no longer stops' README.md)" "$(/usr/bin/grep -c 'ladder exhaustion no longer stops' README.md)"`
   exit: 0
   stdout: `0 1`
   mutation: skip edit 3; prints `1 0`.
5. run: `bash hooks/scripts/version-stamp-check.sh "$(git log --format=%H -F --grep='(hdc-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-2)' | head -1)" | /usr/bin/grep -c '^version-stamp-check: ok'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; prints `0`, exit 1.
6. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.146';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 5; prints `version-sync: mismatch`, exit 1.
7. run: `diff <(git diff --name-only "$(git log --format=%H -F --grep='(hdc-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-2)' | head -1)" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' .claude-plugin/plugin.json CHANGELOG.md README.md commands/start-feature-team.md package.json templates/protocol-digest.md | sort) && echo scope-1-ok`
   exit: 0
   stdout: `scope-1-ok`
   mutation: skip edit 6; exit 1.
8. run: `git diff --name-only "$(git log --format=%H -F --grep='(hdc-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-2)' | head -1)" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip edit 7; prints `0`.
9. run: `node tests/cli-backfill.test.js > /dev/null && echo cli-backfill-ok`
   exit: 0
   stdout: `cli-backfill-ok`
   mutation: delete `templates/protocol-digest.md`; the digest create/heal checks fail, exit 1.
   proof: not run by spec-master.
10. run: `git log --format=%s "$(git log --format=%H -F --grep='(hdc-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-2)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
11. run: `git log --format=%B "$(git log --format=%H -F --grep='(hdc-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-2)' | head -1)" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'`
   exit: 0
   stdout: `1`
   mutation: drop the trailer; prints `0`, exit 1.
12. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
13. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of `.claude/protocol-digest.md`; the mirror check fails, prints `validate-exit=1`.
   proof: not run (about 11 minutes; run it in the main checkout).

## Pre-resolved context
precondition: both version files print `0.31.145`. Anything else: STOP; the orchestrator re-derives the literals.
precondition: hdc-1 has landed: `git log --format=%H -F --grep='(hdc-1)' | wc -l` prints `1`; and `git log --format=%H -F --grep='(hdc-2)' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and every `before:` payload appears verbatim. On any mismatch STOP and report.
tdd: no prose-only edit; the checks are greps, cli-backfill and validate.sh mirror parity
blast-radius: templates/protocol-digest.md:17, commands/start-feature-team.md:48, README.md:185, hooks/scripts/session-start.sh:63
note: the digest is re-injected only on `source: resume`/`compact` (session-start.sh:64); its header asks to stay under about 15 lines; this edit adds one line.
note: htd-5's criterion pinned `only at ladder exhaustion do you stop` in start-feature-team; edit 2 keeps it.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
commit-message: feat(hdc-2): digest, team command and README state the per-tier cap (0.31.146) (#529)
review-packet:
```
unit: hdc-2 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criteria 1-13: <FILL: exit and stdout of each>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit hdc-3

~~~~~markdown
Unit: hdc-3

## Objective
Three tests: a second `--update` after the haiku migration is a no-op; the migrate check fails if the migration is disabled while the frontmatter ships `haiku`; the exporter falls back to the pre-haiku eras when the orchestrator has no cutover line or is absent. Test-only, one commit (plus one per fix round after a FAIL), no version bump.

## Retrieval
Plan file: `docs/plans/2026-10-08-haiku-default-cleanup.md`, `## Unit hdc-3`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `tests/default-implementer-model.test.js` (anchors below)
- `tests/unit-outcomes.test.js` (anchor below)

## Ordered edits
1. file: `tests/default-implementer-model.test.js`
   anchor: line matching `    const expected = cli.migrateDefaultImplementerModel('sonnet', '0.31.0', cli.IMPLEMENTER_HAIKU_DEFAULT_SINCE, frontmatter) || 'sonnet';`
   indent: 4
   before:
```
    const expected = cli.migrateDefaultImplementerModel('sonnet', '0.31.0', cli.IMPLEMENTER_HAIKU_DEFAULT_SINCE, frontmatter) || 'sonnet';
    assert.strictEqual(readConfig(tmp).defaultImplementerModel, expected);
```
   after:
```
    const expected = cli.migrateDefaultImplementerModel('sonnet', '0.31.0', cli.IMPLEMENTER_HAIKU_DEFAULT_SINCE, frontmatter) || 'sonnet';
    if (frontmatter === 'haiku') {
      assert.strictEqual(expected, 'haiku', 'lead-programmer ships model: haiku, so an old-version "sonnet" must migrate; IMPLEMENTER_HAIKU_DEFAULT_SINCE is disabled');
    }
    assert.strictEqual(readConfig(tmp).defaultImplementerModel, expected);
```
2. file: `tests/default-implementer-model.test.js`
   anchor: line matching `check('--update --dry-run against a config missing defaultImplementerModel reports the pending change without writing it', () => {`
   indent: 0
   before:
```
check('--update --dry-run against a config missing defaultImplementerModel reports the pending change without writing it', () => {
```
   after:
```
check('--update after the haiku migration is a no-op: a second run leaves the config byte-identical and prints no migration note', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'antislop-dim-migrate-twice-'));
  try {
    const before = buildBaselineProject(tmp);
    before.defaultImplementerModel = 'sonnet';
    before.pluginVersion = '0.31.0';
    writeConfig(tmp, before);
    const configPath = path.join(tmp, '.claude', 'persona-config.json');

    const first = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(first.status, 0, `first --update expected exit 0, got ${first.status}: ${first.stdout}${first.stderr}`);
    const afterFirst = fs.readFileSync(configPath, 'utf8');

    const second = spawnSync('node', [cliPath, '--update'], { cwd: tmp, encoding: 'utf8' });
    assert.strictEqual(second.status, 0, `second --update expected exit 0, got ${second.status}: ${second.stdout}${second.stderr}`);
    assert.strictEqual(fs.readFileSync(configPath, 'utf8'), afterFirst, 'a second --update must leave persona-config.json byte-identical to the first');
    assert.ok(!second.stdout.includes('predates the haiku default'), `a second --update must not print the migration note again, got: ${second.stdout}`);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

check('--update --dry-run against a config missing defaultImplementerModel reports the pending change without writing it', () => {
```
3. file: `tests/unit-outcomes.test.js`
   anchor: line matching `check('era reviewer empty', () => {`
   indent: 0
   before:
```
check('era reviewer empty', () => {
```
   after:
```
check('era null cutover falls back to the pre-haiku eras', () => {
  for (const withOrchestrator of [true, false]) {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'unit-outcomes-nocutover-'));
    try {
      fs.mkdirSync(path.join(tmp, 'scripts'));
      fs.copyFileSync(SCRIPT, path.join(tmp, 'scripts', 'unit-outcomes.js'));
      if (withOrchestrator) {
        fs.mkdirSync(path.join(tmp, 'agents'));
        fs.writeFileSync(path.join(tmp, 'agents', 'orchestrator.md'), '# orchestrator\nno cutover line here\n');
      }
      const out = cp.execFileSync('node', [
        path.join(tmp, 'scripts', 'unit-outcomes.js'),
        `--repo=${scratch.dir}`,
        `--markers=${path.join(FIX, 'markers')}`,
        `--transcripts=${path.join(FIX, 'transcripts')}`,
        '--until=2027-01-01T00:00:00Z',
      ], { cwd: REPO_ROOT, encoding: 'utf8', env: { ...process.env, GH_BIN: path.join(FIX, 'bin', 'gh') } });
      const map = {};
      out.split('\n').filter(Boolean).forEach((l) => { const o = JSON.parse(l); map[o.id] = o; });
      assert.deepStrictEqual(map['fx-era-4'].implementer_tiers, [{ tier: 'sonnet', source: 'era-inferred' }]);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  }
});

check('era reviewer empty', () => {
```
4. command: `git add tests/default-implementer-model.test.js tests/unit-outcomes.test.js && git commit -m "test(hdc-3): migrate-twice no-op, migration-disabled guard, null cutover fallback (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
   (use this trailer line exactly, per rule P5 of `docs/plans/2026-10-07-final-cleanup.md`; a fix round after a FAIL commits again with the same trailer line)
5. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `bin/cli.js` (the mutations below are run in a scratch copy only, never committed)
- `scripts/unit-outcomes.js`
- `tests/fixtures/unit-outcomes/` (the new check reuses the existing fx-era-4 fixture)
- `agents/`, `templates/` (no version bump in this unit)

## Acceptance criteria
1. run: `node tests/default-implementer-model.test.js > /dev/null && echo dim-ok`
   exit: 0
   stdout: `dim-ok`
   mutation: in a scratch copy set `const IMPLEMENTER_HAIKU_DEFAULT_SINCE = null;` in `bin/cli.js`; edit 1's assertion fails, exit 1.
   proof: before this unit, spec-master set that constant to null in a scratch worktree and `default-implementer-model`, `writer-tier-consistency` and `cli-backfill` all exited 0 (the gap). The post-edit failure was not run by spec-master.
2. run: `node tests/default-implementer-model.test.js | /usr/bin/grep -c '^OK   --update after the haiku migration is a no-op'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy change `  if (migratedImplementerModel) {` in `bin/cli.js` to `  if (true) {`; the second run prints the note again (and nulls the value), the check prints FAIL, this prints `0`, exit 1.
   proof: edits 1 and 2 applied in a scratch worktree of 5f91df7; the new check printed `OK`. The mutation was not run by spec-master (refused by the permission classifier).
3. run: `node tests/unit-outcomes.test.js | /usr/bin/grep -cE '^OK   era null cutover falls back to the pre-haiku eras$|^All unit-outcomes checks passed\.$'`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy change `return m ? m[1] : null;` in `scripts/unit-outcomes.js` to `return m ? m[1] : '2026-10-08T17:28:48Z';`; the new check FAILs, prints `0`, exit 1.
   proof: spec-master applied edit 3 and that mutation in a scratch worktree of 5f91df7; before the mutation it printed `OK   era null cutover ...` and `All unit-outcomes checks passed.`; with it, `FAIL era null cutover ...` and `1 check(s) failed.`. The suite takes over a minute: use a Bash timeout of 600000.
4. run: `git diff --name-only "$(git log --format=%H -F --grep='(hdc-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-3)' | head -1)" | sort | tr '\n' ' '`
   exit: 0
   stdout: `tests/default-implementer-model.test.js tests/unit-outcomes.test.js `
   mutation: also commit `bin/cli.js`; the list gains it.
5. run: `git log --format=%s "$(git log --format=%H -F --grep='(hdc-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-3)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
6. run: `R="$(git log --format=%H -F --grep='(hdc-3)' | tail -1)~1..$(git log --format=%H -F --grep='(hdc-3)' | head -1)"; for c in $(git rev-list "$R"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   check: prints the distinct per-commit counts of trailer lines over the unit's range, so `1 ` means every commit in the range (the original and each fix-round commit) carries exactly one trailer line, whatever the commit count. Empty stdout (no `(hdc-3)` commit) fails. Amended 2026-10-08, see `## Ruling (2026-10-08): per-commit trailer criteria`.
   mutation: drop one commit's trailer; prints `0 1 ` (or `0 ` for a one-commit unit).
   proof: the hdc-3 range does not exist yet; the same `run:` shape is proven on hdc-4 and hdc-5 (see hdc-5 criterion 7).
7. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave `bin/cli.js` mutated after a proof run; prints `1`.
8. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: break one assertion in a test that validate.sh runs; prints `validate-exit=1`.
   proof: not run (about 11 minutes; run it in the main checkout).

## Pre-resolved context
precondition: `git log --format=%H -F --grep='(hdc-3)' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and every `before:` payload appears verbatim. On any mismatch STOP and report.
precondition: run every mutation in a scratch `git worktree` or restore with `git checkout -- <file>` before committing; criterion 7 catches a leftover.
tdd: yes the three checks are the deliverable; checks 2 and 3 already pass at HEAD (they pin current behaviour), check 1's new assertion is what fails under a disabled migration
blast-radius: tests/default-implementer-model.test.js:268, tests/default-implementer-model.test.js:275, tests/unit-outcomes.test.js:305, scripts/unit-outcomes.js:107, bin/cli.js:343
note: `SCRIPT`, `FIX`, `REPO_ROOT`, `scratch`, `cp`, `fs`, `os`, `path` are already defined at the top of `tests/unit-outcomes.test.js`; the copied script finds no `bin/contract-score.js`, so contract scores come out null, which the check does not read.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff.
commit-message: test(hdc-3): migrate-twice no-op, migration-disabled guard, null cutover fallback (#529)
review-packet:
```
unit: hdc-3 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criteria 1-8: <FILL: exit and stdout of each, plus each mutation run>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit hdc-4

~~~~~markdown
Unit: hdc-4

## Objective
ADR-0040 agrees with itself and with `agents/orchestrator.md` after hdc-1: the legacy ladder starts at the more capable of `sonnet` and the default tier; ladder exhaustion is a count that reaches or exceeds the ladder length; the early tripwire is bounded to 20-59 units (matching the audit command); the forward-rule population excludes the `htd-` units, in prose and in the jq. An `## Amendments` section records it. One commit; no threshold changes.

## Retrieval
Plan file: `docs/plans/2026-10-08-haiku-default-cleanup.md`, `## Unit hdc-4`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
none

## Doc edits
1. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Decision`
   before:
```
   count dispatches `opus`. FAIL blocks older than the haiku-default cutover start
   the unit's ladder at `sonnet`.
```
   text:
```
   count dispatches `opus`. FAIL blocks older than the haiku-default cutover start
   the unit's ladder at the more capable of `sonnet` and the default tier.
   Ladder exhaustion is a FAIL-block count that reaches or exceeds the ladder's
   length.
```
2. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Forward rule (pre-registered)`
   before:
```
**Haiku-default cutover** timestamp in `agents/orchestrator.md`), all three must
hold:
```
   text:
```
**Haiku-default cutover** timestamp in `agents/orchestrator.md`, except the
`htd-` units of the haiku-default programme itself, which were dispatched on
`sonnet` before the flip and closed after the cutover), all three must hold:
```
3. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Forward rule (pre-registered)`
   before:
```
Early tripwire: from 20 units, an escalation-rate above 0.30 or two exhausted
units ends the trial early with the same consequence.
```
   text:
```
Early tripwire: while the population holds 20 to 59 units, an escalation-rate
above 0.30 or two exhausted units ends the trial early with the same
consequence. From 60 units only the three rates above decide; two exhausted
units then fail the rule only through the exhaustion-rate.
```
4. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Forward rule (pre-registered)`
   before: `[.[] | select(.terminal_ts >= $t0)] as $p`
   text: `[.[] | select(.terminal_ts >= $t0 and (.id | startswith("htd-") | not))] as $p`
   (a substring replacement inside the single indented `    jq -rs` line; nothing else on that line changes)
5. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Related`
   insert-after:
```
- Plan: `docs/plans/2026-10-08-haiku-default-tier.md`.
```
   text:
```

## Amendments

- 2026-10-08 (hdc-4, `docs/plans/2026-10-08-haiku-default-cleanup.md`): the
  legacy ladder starts at the more capable of `sonnet` and the default tier;
  ladder exhaustion is a count that reaches or exceeds the ladder length; the
  early tripwire is bounded to 20-59 units, matching the audit command; the
  forward-rule population excludes the `htd-` units, which ran on `sonnet` and
  closed after the cutover. No threshold changed.
```
prune: none

## ADR
none

## Close conditions
- issue #529 is the umbrella [spec] issue and no per-unit issue exists: close nothing, and never close #529
- task-id: hdc-4
- marker first line: "PASS hdc-4 "
- commit: one commit of the one file, subject `docs(hdc-4): ADR-0040 tripwire bound, htd exclusion, legacy ladder start (#529)`, then a second `-m` argument holding exactly one `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>` line; stage with `git add docs/adr/0040-implementer-tier-haiku-default.md`
- precondition: hdc-1 has landed (`git log --format=%H -F --grep='(hdc-1)' | wc -l` prints `1`) and `git log --format=%H -F --grep='(hdc-4)' | wc -l` prints `0`; every `before:` payload appears verbatim exactly once in the ADR. Anything else: STOP and report.

## Do NOT touch
- `docs/adr/0026-writer-tier-reversed-to-sonnet.md`
- every other file under `docs/adr/`
- `CONTEXT.md` and `docs/harness-glossary.md` (unit hdc-5)
- `tests/` (the phrases AC-D8b pins in this ADR, listed in tests/writer-tier-consistency.test.js:90-94, must stay verbatim; criterion 4 checks them)

## Acceptance criteria
1. run: `A=docs/adr/0040-implementer-tier-haiku-default.md; for p in 'ladder at the more capable of' 'FAIL-block count that reaches or exceeds' 'while the population holds 20 to 59 units' 'From 60 units only the three rates above decide' 'units of the haiku-default programme itself' '## Amendments' 'from 20 units, an escalation-rate'; do tr '\n' ' ' < $A | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 1 1 1 1 0 `
   mutation: skip Doc edit 3; prints `1 1 0 0 1 1 1 `.
2. run: `A=docs/adr/0040-implementer-tier-haiku-default.md; C=$(/usr/bin/grep -E '^    jq -rs' "$A" | sed "s/^    //; s/<T0>/2026-10-08T17:28:48Z/; s#<F>#/dev/stdin#"); for i in $(seq 1 20); do printf '{"id":"htd-%s","terminal_ts":"2026-10-09T00:00:00Z","fail_blocks":6}\n{"id":"x-%s","terminal_ts":"2026-10-09T00:00:00Z","fail_blocks":0}\n' $i $i; done | bash -c "$C"`
   exit: 0
   stdout: `insufficient`
   mutation: skip Doc edit 4; prints `tripwire` (40 rows, 20 exhausted).
   proof: spec-master ran this `run:` against the ADR at 5f91df7 (the skip-edit-4 state) and it printed `tripwire`; the filtered jq run by hand on the same rows printed `insufficient`.
3. run: `A=docs/adr/0040-implementer-tier-haiku-default.md; for t in 2026-08-25T00:00:00Z 2026-10-05T00:00:00Z; do /usr/bin/grep -E '^    jq -rs' "$A" | sed "s/^    //; s/<T0>/$t/; s#<F>#docs/audits/unit-outcomes/2026-10-06.jsonl#" | bash; done | tr '\n' ' '`
   exit: 0
   stdout: `met insufficient `
   mutation: in a scratch copy replace `<= 0.35` by `<= 0.30` in the jq line; the first word becomes `not-met`.
   proof: spec-master ran the filtered jq on that export for both cutoffs; it printed `met` and `insufficient` (the export has no `htd-` rows, so the filter changes nothing there).
4. run: `node tests/writer-tier-consistency.test.js > /dev/null && echo wtc-ok`
   exit: 0
   stdout: `wtc-ok`
   mutation: delete the word `tripwire` from the ADR; AC-D8b fails, prints nothing, exit 1.
5. run: `git diff --name-only "$(git log --format=%H -F --grep='(hdc-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-4)' | head -1)" | tr '\n' ' '`
   exit: 0
   stdout: `docs/adr/0040-implementer-tier-haiku-default.md `
   mutation: also commit an edit to `CONTEXT.md`; the list gains it.
6. run: `git log --format=%s "$(git log --format=%H -F --grep='(hdc-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-4)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
7. run: `R="$(git log --format=%H -F --grep='(hdc-4)' | tail -1)~1..$(git log --format=%H -F --grep='(hdc-4)' | head -1)"; for c in $(git rev-list "$R"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   check: prints the distinct per-commit counts of trailer lines over the unit's range, so `1 ` means every commit in the range (the original and each fix-round commit) carries exactly one trailer line, whatever the commit count. Empty stdout (no `(hdc-4)` commit) fails. Amended 2026-10-08, see `## Ruling (2026-10-08): per-commit trailer criteria`.
   mutation: drop one commit's trailer; prints `0 1 ` (or `0 ` for a one-commit unit).
   proof: spec-master ran this `run:` in a scratch clone at 082ec3c: hdc-5 printed `1 ` (2 commits) and hdc-4 printed `1 ` (1 commit); dropping 082ec3c's trailer printed `0 1 `, dropping b3cdba8's printed `0 1 `, both trailers on one commit and none on the other printed `0 2 `, dropping 789725d's trailer printed `0 `. The old form (`grep -c` over the whole range) printed `1` with 082ec3c's trailer dropped, so it caught nothing.
8. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave the ADR unstaged at commit time; prints `1`.
9. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: break a `[[link]]` in CONTEXT.md; the glossary-link check fails, prints `validate-exit=1`.
   proof: not run (about 11 minutes; run it in the main checkout).

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap.
~~~~~

## Unit hdc-5

~~~~~markdown
Unit: hdc-5

## Objective
CONTEXT.md and docs/harness-glossary.md agree with hdc-1 and hdc-4: the Escalation ladder entry names the default tier and the cutover as inputs and the more-capable legacy start; ladder exhaustion is reaching or exceeding the ladder length; Writer tier links ADR-0040; the FAIL record entry says ladder exhaustion; new entries **default tier** and **Haiku-default cutover**; the terminal event entry no longer calls the second FAIL a stop; the Forward-verification rule entry points to ADR-0040. One commit, plus one per fix round after a FAIL (amended 2026-10-08, see the Ruling).

## Retrieval
Plan file: `docs/plans/2026-10-08-haiku-default-cleanup.md`, `## Unit hdc-5`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
1. file: `CONTEXT.md`
   heading: `**Escalation ladder**:`
   before:
```
  `opus`), two attempts each. The next tier is a function of the unit's
  FAIL-block count alone, so a session with no memory of earlier FAILs
  computes the same tier. A unit with a FAIL block older than the
  haiku-default cutover starts its ladder at `sonnet`. See [[ladder
  exhaustion]] and [[Implementer-tier ratchet]].
```
   text:
```
  `opus`), two attempts each. The next tier is a function of the unit's
  FAIL-block count, its [[default tier]] and whether any block predates the
  [[Haiku-default cutover]], so a session with no memory of earlier FAILs
  computes the same tier. A unit with a FAIL block older than the cutover
  starts its ladder at the more capable of `sonnet` and its default tier. See
  [[ladder exhaustion]] and [[Implementer-tier ratchet]].
```
2. file: `CONTEXT.md`
   heading: `**ladder exhaustion**:`
   before:
```
(ADR-0040, 2026-10-08) — a unit's second FAIL on the top tier of its
  [[Escalation ladder]]: the only point at which the orchestrator stops
```
   text:
```
(ADR-0040, 2026-10-08) — a unit's FAIL-block count reaching or exceeding the
  length of its [[Escalation ladder]] (the second FAIL on its top tier, or any
  later FAIL after a human-directed re-dispatch): the only point at which the orchestrator stops
```
3. file: `CONTEXT.md`
   heading: `**ladder exhaustion**:`
   insert-after: `_Avoid_: "the 2-FAIL cap" for this stop alone (the 2-FAIL cap is per tier)`
   text:
```

**default tier**:
(ADR-0040, unit hdc-5, 2026-10-08) — the implementer tier a unit's
  [[Escalation ladder]] starts from: the project's [[defaultImplementerModel]]
  value when present (any unrecognised value counts as `opus`), else
  lead-programmer's frontmatter `model:` (`haiku` as shipped). A `Suggested
  model` tag can raise a unit above it, never below it.
_Avoid_: base tier, starting model

**Haiku-default cutover**:
(ADR-0040, unit hdc-5, 2026-10-08) — the timestamp, stated once in
  `agents/orchestrator.md`, at which the shipped [[default tier]] moved from
  `sonnet` to `haiku`. A FAIL block older than it was written under ADR-0026's
  `sonnet` default, so a unit holding one starts its [[Escalation ladder]] at
  the more capable of `sonnet` and its default tier. The [[unit-outcome export]]
  reads the same timestamp to infer the `haiku` era, and ADR-0040's forward
  rule counts units whose [[terminal event]] falls at or after it.
_Avoid_: cutover unit (the commit that set it), flip commit
```
4. file: `CONTEXT.md`
   heading: `**Writer tier**:`
   before: `  See [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md).`
   text: `  See [ADR-0040](docs/adr/0040-implementer-tier-haiku-default.md) and [ADR-0026](docs/adr/0026-writer-tier-reversed-to-sonnet.md).`
5. file: `CONTEXT.md`
   heading: `**FAIL record**:`
   before: `  spec when a unit hits the 2-FAIL cap.`
   text: `  spec when a unit reaches [[ladder exhaustion]].`
6. file: `docs/harness-glossary.md`
   heading: `**terminal event**:`
   before:
```
(unit rgh-u0-2b, 2026-10-06) — a unit's PASS timestamp, or for a unit that hit
  the 2-FAIL cap without a PASS, the second FAIL block's header timestamp.
```
   text:
```
(unit rgh-u0-2b, 2026-10-06; reworded hdc-5, 2026-10-08) — the earlier of a
  unit's PASS timestamp and its second FAIL block's header timestamp. Under
  ADR-0026 the second FAIL was the 2-FAIL cap stop; under the [[Escalation
  ladder]] (ADR-0040) it ends the unit's first tier and is not a stop, and
  `fail_blocks` still counts every later FAIL block up to the cutoff.
```
7. file: `docs/harness-glossary.md`
   heading: `**Forward-verification rule**:`
   before: `  **spend-neutrality** — both conditions must hold for the reversal to remain valid.`
   text:
```
  **spend-neutrality** — both conditions must hold for the reversal to remain valid.
  ADR-0040 (2026-10-08, `docs/adr/0040-implementer-tier-haiku-default.md`)
  pre-registers a successor rule for the `haiku` default: three rate
  thresholds from 60 units and an early tripwire for 20 to 59 units.
```

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #529 is the umbrella [spec] issue and no per-unit issue exists: close nothing, and never close #529
- task-id: hdc-5
- marker first line: "PASS hdc-5 "
- commit: one commit of the two files (plus one per fix round after a FAIL; amended 2026-10-08, see the Ruling), subject `docs(hdc-5): glossary states default tier, Haiku-default cutover and ladder edge cases (#529)`, then a second `-m` argument holding exactly one `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>` line; stage with `git add CONTEXT.md docs/harness-glossary.md`
- precondition: hdc-1 and hdc-4 have landed (`git log --format=%H -F --grep='(hdc-1)' | wc -l` and the same for `(hdc-4)` each print `1`); `(hdc-5)` prints `0`; every `before:` payload and `insert-after:` line appears verbatim exactly once inside the entry its `heading:` names (the same text may recur in other entries; edit only the named entry). Anything else: STOP and report.

## Do NOT touch
- the `**Implementer-tier ratchet**:` entry (its two-attempts-per-tier phrase is pinned by tests/writer-tier-consistency.test.js AC-D5)
- the `**defaultImplementerModel**:` entry (its lines carry trailing spaces; deferred, plan R5)
- `docs/adr/`
- `agents/`, `tests/`, `scripts/`

## Acceptance criteria
1. run: `C=CONTEXT.md; for p in 'FAIL-block count alone' 'its [[default tier]] and whether any block predates the [[Haiku-default cutover]]' 'starts its ladder at the more capable of' 'reaching or exceeding the length of its [[Escalation ladder]]' '**default tier**:' '**Haiku-default cutover**:' 'See [ADR-0040](docs/adr/0040-implementer-tier-haiku-default.md) and [ADR-0026]' 'reaches [[ladder exhaustion]]' 'hits the 2-FAIL cap'; do tr '\n' ' ' < $C | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `0 1 1 1 1 1 1 1 0 `
   mutation: skip Glossary edit 1; prints `1 0 0 1 1 1 1 1 0 `.
2. run: `H=docs/harness-glossary.md; for p in 'hit the 2-FAIL cap without a PASS' 'first tier and is not a stop' 'pre-registers a successor rule for the'; do tr '\n' ' ' < $H | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `0 1 1 `
   mutation: skip Glossary edit 6; prints `1 0 1 `.
3. run: `node tests/context-glossary-links.test.js > /dev/null && node tests/ubiquitous-language.test.js > /dev/null && echo glossary-tests-ok`
   exit: 0
   stdout: `glossary-tests-ok`
   mutation: in Glossary edit 3 write `[[default tiers]]` instead of `[[default tier]]` in the cutover entry; the dangling-link check fails, prints nothing, exit 1.
   proof: not run by spec-master (Bash was refused late in the session); the reviewer runs it.
4. run: `node tests/writer-tier-consistency.test.js > /dev/null && echo wtc-ok`
   exit: 0
   stdout: `wtc-ok`
   mutation: change the Implementer-tier ratchet entry's two-attempts-per-tier phrase; AC-D5 fails, prints nothing, exit 1.
5. run: `git diff --name-only "$(git log --format=%H -F --grep='(hdc-5)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-5)' | head -1)" | sort | tr '\n' ' '`
   exit: 0
   stdout: `CONTEXT.md docs/harness-glossary.md `
   mutation: also commit an edit to the ADR; the list gains it.
6. run: `git log --format=%s "$(git log --format=%H -F --grep='(hdc-5)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-5)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
7. run: `R="$(git log --format=%H -F --grep='(hdc-5)' | tail -1)~1..$(git log --format=%H -F --grep='(hdc-5)' | head -1)"; for c in $(git rev-list "$R"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   check: prints the distinct per-commit counts of trailer lines over the unit's range, so `1 ` means every commit in the range (the original and each fix-round commit) carries exactly one trailer line, whatever the commit count. Empty stdout (no `(hdc-5)` commit) fails. Amended 2026-10-08, see `## Ruling (2026-10-08): per-commit trailer criteria`.
   mutation: drop one commit's trailer; prints `0 1 ` (or `0 ` for a one-commit unit).
   proof: spec-master ran this `run:` in a scratch clone at 082ec3c: hdc-5 printed `1 ` (2 commits) and hdc-4 printed `1 ` (1 commit); dropping 082ec3c's trailer printed `0 1 `, dropping b3cdba8's printed `0 1 `, both trailers on one commit and none on the other printed `0 2 `, and over hdc-4's one-commit range (the same `run:` with `(hdc-4)` in place of `(hdc-5)`) dropping 789725d's trailer printed `0 `. The old form (`grep -c` over the whole range) printed `1` with 082ec3c's trailer dropped, so it caught nothing.
8. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave CONTEXT.md unstaged at commit time; prints `1`.
9. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: add a `[[deliberately-missing-term]]` link to CONTEXT.md; prints `validate-exit=1`.
   proof: not run (about 11 minutes; run it in the main checkout).

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap. If the glossary tests reject the new entries' shape, STOP and report the failing check verbatim; do not reshape the entries.
~~~~~

## Unit hdc-6

~~~~~markdown
Unit: hdc-6

## Objective
Three glossary corrections: CONTEXT.md **default tier** says a `Suggested model` tag's floor is the ladder's entry, not the default tier (N3); CONTEXT.md **Haiku-default cutover** says ADR-0040's forward rule leaves out the `htd-` units (N2); `docs/harness-glossary.md` **terminal event** says the second FAIL is a stop for a one-tier `opus` ladder (N1). One commit, plus one per fix round after a FAIL.

## Retrieval
Plan file: `docs/plans/2026-10-08-haiku-default-cleanup.md`, `## Unit hdc-6`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
Each `before:` is one whole line (two leading spaces); replace that line with the `text:` lines.
1. file: `CONTEXT.md`
   heading: `**default tier**:`
   before:
```
  model` tag can raise a unit above it, never below it.
```
   text:
```
  model` tag can raise a unit's tier above its ladder's entry, never below
  that entry (the default tier, or for a unit with a FAIL block older than
  the [[Haiku-default cutover]], the more capable of `sonnet` and the default
  tier).
```
2. file: `CONTEXT.md`
   heading: `**Haiku-default cutover**:`
   before:
```
  rule counts units whose [[terminal event]] falls at or after it.
```
   text:
```
  rule counts units whose [[terminal event]] falls at or after it, except
  the `htd-` units of the haiku-default programme itself.
```
3. file: `docs/harness-glossary.md`
   heading: `**terminal event**:`
   before:
```
  ladder]] (ADR-0040) it ends the unit's first tier and is not a stop, and
```
   text:
```
  ladder]] (ADR-0040) it ends the unit's first tier and is not a stop unless
  that tier is the ladder's last (an `opus` default tier gives a one-tier
  `opus` ladder, where the second FAIL is ladder exhaustion), and
```

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #529 is the umbrella [spec] issue and no per-unit issue exists: close nothing, and never close #529
- task-id: hdc-6
- marker first line: "PASS hdc-6 "
- commit: one commit of the two files (plus one per fix round after a FAIL), subject `docs(hdc-6): glossary tag floor is the ladder entry, cutover htd exclusion, one-tier opus stop (#529)`, then a second `-m` argument holding exactly the line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; stage with `git add CONTEXT.md docs/harness-glossary.md`
- precondition: hdc-5 has PASSed (the orchestrator confirms the hdc-5 PASS marker before dispatch); `git log --format=%H -F --grep='(hdc-6)' | wc -l` prints `0`; each `before:` line matches exactly once as a whole line (`/usr/bin/grep -cxF -- '<before line>' <file>` prints `1`). Anything else: STOP and report.

## Do NOT touch
- every other entry in both files (in particular **Escalation ladder**, **ladder exhaustion**, **Implementer-tier ratchet**, **defaultImplementerModel**, **Forward-verification rule**, **Spend-neutrality**)
- `docs/adr/`, `agents/`, `tests/`, `scripts/`

## Acceptance criteria
1. run: `C=CONTEXT.md; for p in 'raise a unit above it, never below it' 'never below that entry' 'the more capable of `sonnet` and the default tier).' 'falls at or after it, except the `htd-` units of the haiku-default programme itself.'; do tr '\n' ' ' < $C | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `0 1 1 1 `
   mutation: skip edit 1; prints `1 0 0 1 `. Skip edit 2; prints `0 1 1 0 `.
   proof: spec-master applied the three edits in a scratch clone at 082ec3c: full `0 1 1 1 `, skip-1 `1 0 0 1 `, skip-2 `0 1 1 0 `, before any edit `1 0 0 0 `.
2. run: `H=docs/harness-glossary.md; for p in 'is not a stop, and' "is not a stop unless that tier is the ladder's last" 'first tier and is not a stop' 'where the second FAIL is ladder exhaustion), and'; do tr '\n' ' ' < $H | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `0 1 1 1 `
   mutation: skip edit 3; prints `1 0 1 0 `.
   proof: measured in the same scratch clone (full `0 1 1 1 `, skip-3 `1 0 1 0 `).
3. run: `node tests/context-glossary-links.test.js > /dev/null && node tests/ubiquitous-language.test.js > /dev/null && echo glossary-tests-ok`
   exit: 0
   stdout: `glossary-tests-ok`
   mutation: in edit 1 write `[[Haiku-default cutovers]]`; the dangling-link check fails, prints nothing, exit 1.
   proof: measured in the scratch clone (passes with the edits; the mutation fails the link test).
4. run: `node tests/writer-tier-consistency.test.js > /dev/null && echo wtc-ok`
   exit: 0
   stdout: `wtc-ok`
   mutation: change the Implementer-tier ratchet entry's two-attempts-per-tier phrase; AC-D5 fails, prints nothing, exit 1.
   proof: passes with the edits in the scratch clone; the mutation is as in hdc-5 criterion 4.
5. run: `git diff --name-only "$(git log --format=%H -F --grep='(hdc-6)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-6)' | head -1)" | sort | tr '\n' ' '`
   exit: 0
   stdout: `CONTEXT.md docs/harness-glossary.md `
   mutation: also commit an edit to the ADR; the list gains it.
6. run: `git log --format=%s "$(git log --format=%H -F --grep='(hdc-6)' | tail -1)~1".."$(git log --format=%H -F --grep='(hdc-6)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
7. run: `R="$(git log --format=%H -F --grep='(hdc-6)' | tail -1)~1..$(git log --format=%H -F --grep='(hdc-6)' | head -1)"; for c in $(git rev-list "$R"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   check: every commit in the range carries exactly one trailer line (see the 2026-10-08 Ruling).
   mutation: drop one commit's trailer; prints `0 ` or `0 1 `.
   proof: shape proven on hdc-4 and hdc-5 (hdc-5 criterion 7).
8. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave CONTEXT.md unstaged at commit time; prints `1`.
9. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: add a `[[deliberately-missing-term]]` link to CONTEXT.md; prints `validate-exit=1`.
   proof: not run (about 11 minutes; run it in the main checkout).

## Pre-resolved context
blast-radius: CONTEXT.md:385, CONTEXT.md:395, docs/harness-glossary.md:3221 (line numbers at 082ec3c; anchor on the `before:` text, not the number)
note: edit 3 keeps the phrase `first tier and is not a stop`, so hdc-5 criterion 2 still prints `0 1 1 ` afterwards.
note: the tag-floor wording mirrors `agents/orchestrator.md` ("never a tier cheaper than the ladder's entry"); do not edit the orchestrator.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap. If the glossary tests reject the new text, STOP and report the failing check verbatim; do not reshape the entries.
~~~~~

## Status update (2026-10-09)

Closed. hdc-1 .. hdc-6 are reviewer-PASSed; hdc-5 passed after two FAILs, the second a contract defect (see the Ruling). The reviewers' remaining notes are carried by docs/plans/2026-10-09-backlog-cleanup.md. Trailer sweep (blc-4): the hdc-1, hdc-2, hdc-4 and hdc-5 contracts gave a placeholder instead of a model name in their trailer line; each now names the trailer its first commit carries (Claude Haiku 4.5 for all four, measured with git log). hdc-5's fix-round commit 082ec3c carries the Claude Sonnet 5.5 trailer: a fix round's trailer names the model of its own tier. No other docs/plans contract held the placeholder.
