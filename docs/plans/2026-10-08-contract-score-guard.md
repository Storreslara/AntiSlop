# Contract-score guard for haiku dispatch (2026-10-08)

Status: FINAL (fast path, 4 units, dispatch contracts below). Follow-up to
`docs/plans/2026-10-08-haiku-default-tier.md` and
`docs/plans/2026-10-08-haiku-default-cleanup.md` (HEAD 9f12c80, version 0.31.146,
umbrella #529). ADR: `docs/adr/0040-implementer-tier-haiku-default.md` (amended by
csg-3). Restores, under the current regime, the safeguard planned as U5-3 in
`docs/plans/2026-10-06-rubric-gated-haiku-programme.md`.

## Goal

1. (G1) Before every dispatch of a unit whose Escalation ladder starts at `haiku`,
   the orchestrator scores the unit's contract of record with one deterministic
   command, `node bin/contract-guard.js`. Unless the guard passes, the unit uses
   the ladder that starts at `sonnet`, the user is told in one line, and a
   `RULING` line is written. (csg-1, csg-2)
2. (G2) The pass mark is every rubric-v2 row true: 7/7 for the lead shape (plus
   `"sizeOver":false`), 7/7 for the scribe shape. `score-exception:` lines are
   not honoured. (csg-1)
3. (G3) Contracts cited by path are scored. The guard pulls the `Unit: <id>`
   block out of a `docs/plans/` file or an issue body; when the cited contract
   is missing, ambiguous or unclosed, it fails closed. (csg-1)
4. (G4) A guard demotion selects the `sonnet` ladder (`sonnet`, `sonnet`, `opus`,
   `opus`). Because scoring is pure, the guard re-runs before every dispatch, so
   a fresh session computes the same tier from n and the contract. (csg-2)
5. (G5) OQ3 of the rubric-gated programme closes on its default:
   `dispatchHygiene.mode` stays `warn`, scribe stays out of `gatedAgents`, and no
   hook is added. (csg-2)
6. (G6) ADR-0040's forward-rule population excludes guard-demoted units, which
   never ran on `haiku`, and its audit command reads them from the rulings
   ledger. (csg-3) The glossary defines the term. (csg-4)

## Context

**What was dropped.** U5-3 (programme plan line 841) said: "before passing
`model: haiku`, write the prompt to a scratch file and run `node
bin/contract-score.js`; if the score is below 7 or the exit is non-zero,
dispatch `sonnet` and say so". Its OQ3 default (line 878) was "no global flip;
fail-closed scorer gate on haiku routing only". Stage 5 was superseded by
ADR-0040 on 2026-10-08 and U5-3 was never dispatched, so it shipped without the
guard. `agents/orchestrator.md` `## Per-unit model routing` (lines 431-496 at
9f12c80) contains no scoring step.

**Measured contract scores (v2, 2026-10-08; spec-master's prototype extractor
was the same as csg-1's `blocks()`).**

| source | units | v2 result |
|---|---|---|
| `docs/plans/2026-10-08-haiku-default-cleanup.md` | hdc-1..hdc-5 | 7/7 |
| same | hdc-6 (scribe) | 6/7, S7 false: the contract carries a `## Pre-resolved context` heading that is not part of the scribe skeleton |
| `docs/plans/2026-10-08-haiku-default-tier-contracts.md` | htd-2..htd-7 | 7/7; htd-1 has two blocks with the same `Unit: htd-1` line (scribe dispatch A, lead dispatch B), and each is 7/7 for its own shape |
| issues #508-#527 (rgh-h*, fc-1..4) | 19 | 7/7; #517 (rgh-h10) has a lead block and a scribe block, each 7/7 |
| issue #528 (fc-5, `## Dispatch contract (scribe)`) | 1 | 7/7 |
| issues #500-#506 (rgh-u*, v1 era) | 7 | 3/7 to 5/7 |

No measured 7/7 lead contract has `"sizeOver":true` (the largest is htd-3 at
28875 bytes and 30 block lines). Among the contracts measured, the guard would
have demoted hdc-6 and the v1-era rgh-u units, and nothing else.

**Exporter cannot serve as the record.** `scripts/unit-outcomes.js`
`contractFor()` (lines 211-224) looks for issue blocks only under the exact
heading `## Dispatch contract` and for plan blocks only under `### Unit: <id>`
headings. A fresh export (run by spec-master, not committed) gives
`contract_source: none` and `contract_score_v2: null` for every hdc-, htd- and
fc-5 unit. Its `implementer_tiers` field is `observed` only while transcripts
survive (about 30 days), and `era-inferred` gives `haiku` for every post-cutover
row. So the exporter cannot tell whether a unit was guard-demoted. The record
is the `RULING` line instead (decision 6 below).

**Blast radius (explorer, graph plus grep, 2026-10-08).** `package.json:25` ships
the whole `bin/` directory, so a new `bin/contract-guard.js` needs no
registration. `tests/contract-score.test.js` is registered in
`tests/validate.sh:1216-1220`. Appending the guard checks to that file therefore
avoids editing `tests/validate.sh`, which is a SENSITIVE_PATHS entry
(`hooks/scripts/reviewer-tier.sh:30`). `bin/` (except `bin/cli.js`) and `tests/`
(except `validate.sh`) are not sensitive. `agents/` is sensitive
(reviewer-tier.sh:35), so csg-2 gets an `opus` review. The cursor port
`adapters/cursor/agents/orchestrator.md` has no ladder text (grep for `ladder`
and `haiku`: 0 hits), so it needs no sync. Tests that pin
`agents/orchestrator.md`: `tests/writer-tier-consistency.test.js:73-78, 106-125,
193` and `tests/default-implementer-model.test.js:109-128`. With csg-2's
paragraph applied, both pass (run in a scratch worktree). The paragraph contains
none of the banned literals (`never dispatch on \`haiku\``, `Haiku units
escalate on first FAIL`, `` `haiku` is the default ``).

**Prior FAIL history.** No `csg-*.fail` record exists. The only `.fail` record in
this programme is `hdc-5`'s, a contract defect in its trailer criterion (see the
Ruling in the cleanup plan). That is why every criterion here uses the
per-commit trailer loop. `bash bin/marker-audit.sh . --notes
--surface=<path>` was not run for this plan's surfaces. The hdc-*.pass notes
were dispositioned in the cleanup plan. An empty sweep would not prove absence
anyway.

**Mutation table for csg-1** (each one was applied to a scratch copy of
`bin/contract-guard.js` and `node tests/contract-score.test.js` was run;
measured by spec-master 2026-10-08):

| id | mutation | failing check(s) |
|---|---|---|
| M1 | drop the shape filter (`const found = blocks(lines, id);`) | guard-shape-filter |
| M2 | pass mark `failed.length > 1` | guard-sonnet-below-pass-mark, guard-plan-files |
| M3 | skip the lead `sizeOver` test | guard-size-over |
| M4 | drop the CRLF normalisation | guard-crlf |
| M5 | treat a nested fence opener followed by `Unit: <id>` as a block start | guard-nested-block-ignored |
| M6 | drop the whole-input rule | guard-whole-input |
| M7 | also return an unclosed block | guard-unclosed-block |
| M8 | skip the ambiguity test | guard-ambiguous |
| M9 | accept any `--unit` value (`if (!id)`) | guard-usage |

### Decisions

1. **Where the rule lives: a prose duty plus a helper script.** The duty goes in
   the orchestrator's `## Per-unit model routing`, as a new **Contract-score
   guard.** paragraph right after **Haiku-default cutover**. The deterministic
   part (extracting the block, scoring it, applying the pass mark) is in
   `bin/contract-guard.js` (P2). No hook is added: a PreToolUse gate on `Agent`
   calls would sit under `hooks/` (SENSITIVE_PATHS, `opus` review) and would turn
   OQ3's "warn" into a block. The orchestrator's compliance is enforced by
   instruction only; see R1.
2. **Thresholds.** The pass mark is every row of the v2 table true: 7/7 for lead
   and 7/7 for scribe. Lead also requires `"sizeOver":false`, matching
   task-master's **Contract self-check** (`agents/task-master.md:190-191`). The
   scribe pass mark is 7/7, matching task-master's scribe rule
   (`agents/task-master.md:329-331`). U5-3's "below 5" was the v1 five-row scribe
   shape and is superseded. `score-exception:` lines (rulings H-F, H-F2) are
   ignored. They excuse a v1 R1 shortfall caused by pointer phrases inside
   payloads, and v2 R1 already skips payloads (contract-hardening plan, line
   1161: "After H2's PASS the exception list stops growing, because v2 has no
   payload pointer shortfall"). The guard uses `--rubric=v2` only. A shortfall
   of any kind demotes the unit.
3. **Obtaining the text: the contract of record, by path, never the prompt
   wrapper.** The orchestrator does not write a scratch file. It has no Write
   tool, and a Bash heredoc of contract text that names `.claude/reviewed/` or
   decision tokens would trip `reviewed-path-gate.sh` /
   `human-decision-gate.sh`. Instead:
   - fast path: `node bin/contract-guard.js <plan-file> --unit=<id>`;
   - standard path: the retrieval contract's `gh issue view <N>` with
     `--json body -q .body`, piped into `node bin/contract-guard.js - --unit=<id>`.

   Extraction takes the top-level fenced blocks (``` or `~~~`, any run of 3 or
   more, closed by a line equal to the opening run) whose first interior line is
   exactly `Unit: <id>`. It keeps those whose own top-level `## ` headings
   include `## Ordered edits` (lead) or `## Glossary edits` (scribe), which
   separates the two blocks of a two-dispatch unit (htd-1, rgh-h10). A whole
   input whose line 1 is `Unit: <id>` also counts. Zero matches gives
   `reason=no-contract`, two or more give `reason=ambiguous-contract(n)`, and
   unclosed blocks are never returned. Old `### Unit:`-heading plans (pre-rubric)
   have no fenced block, so they get `no-contract`, which is correct because
   they would not score 7 anyway. A dispatch whose contract sits in no file or
   issue body is unscorable and is demoted.
4. **Ladder.** A guard demotion makes the unit's ladder the one that starts at
   `sonnet`: `sonnet`, `sonnet`, `opus`, `opus`, with exhaustion at n = 4. This
   is the same shape as the pre-cutover rule. The guard decides the ladder, not
   one attempt, so it runs before every dispatch of a unit whose default ladder
   starts at `haiku`, including n ≥ 2. Otherwise a demoted unit at n = 2 would
   read `sonnet` from the haiku ladder instead of `opus`. A `Suggested model` tag
   still raises the tier. The guard never selects a cheaper ladder than the
   default ladder. It scores the contract of record, never a fix contract (fix
   contracts are transient reports and are not on disk). A fresh session
   recomputes the same ladder from n, the default tier, the cutover and the
   contract. No memory of earlier demotions is needed, which keeps the ladder's
   "which tier wrote a block is never needed" property.
5. **OQ3.** Closed on its recommended default. `dispatchHygiene.mode` stays
   `warn`, scribe stays out of `gatedAgents`, and the U5-3 "block" alternative
   (a `--update`-routed config flip plus an H4 substance test under `hooks/`) is
   not taken. The guard is the fail-closed mechanism for `haiku` routing. For
   scribe, a dispatch that carries a scribe dispatch contract and would go on
   `haiku` is checked with `--shape=scribe` and goes on `sonnet` if the check
   fails. A scribe dispatch with no contract (a post-PASS digest-only pass, or a
   wiki question) is not a unit contract and stays on scribe's frontmatter.
6. **Measurement.** On a demotion, the orchestrator appends `RULING <ts>
   unit=<id> decision=contract-guard sonnet: <guard line>` to
   `.claude/orchestrator-rulings.log`. Guard-demoted units are **excluded** from
   ADR-0040's forward-rule population. The rates are defined over `haiku`
   attempts (escalation-rate is "units that left `haiku`"). A demoted unit never
   ran on `haiku`, and a zero-FAIL `sonnet` unit would dilute the fail-rate,
   which is the same reasoning that excluded the `htd-` units (cleanup plan,
   S7). Amendment, in csg-3: the population sentence names the exclusion, and
   the audit command adds `--rawfile r .claude/orchestrator-rulings.log` and
   filters ids that match `^RULING \S+ unit=(\S+) decision=contract-guard
   sonnet:`. The demoted count is reported alongside, for information, so that
   a high demotion rate stays visible. No threshold changes. The log is
   per-clone and gitignored (`.gitignore:21`): a missing log makes `jq` exit 2
   (measured) rather than silently counting demoted units.

### Domain model (inline, per grill-with-docs)

- **Contract-score guard**: glossary entry drafted in csg-4's Glossary edit 3.
- **guard demotion**: defined inside that entry. Not "escalation", which is
  FAIL-driven.
- **contract of record**: defined inside that entry ("its `Unit:` contract block
  in the plan file or issue body the dispatch cites, never a fix contract").
- ADR: an amendment to ADR-0040 (csg-3), not a new ADR. The guard is easy to
  reverse (prose plus a script), so it fails `domain-modeling`'s first ADR test.
  The forward-rule population change, however, amends a pre-registered rule and
  must be recorded in ADR-0040's `## Amendments`, as hdc-4 did.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Clear
4. Non-functional attributes (perf, security, scale): Clear
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-08 Functional scope & success criteria: Q Is the pass mark 7/7 for both shapes under v2, and does `score-exception:` count? → A (self-resolved): 7/7 for both (lead also `sizeOver:false`), matching task-master's self-checks; `score-exception:` is v1-only and ignored (Decision 2).
- 2026-10-08 Domain entities / data model: Q What exactly is scored when the dispatch only cites a plan section? → A (self-resolved): the contract of record, the unique top-level fenced `Unit: <id>` block of the requested shape in the cited file or issue body (Decision 3).
- 2026-10-08 External dependencies & integrations: Q How does the guard read a standard-path contract without a scratch file? → A (self-resolved): `gh issue view <N> --json body -q .body | node bin/contract-guard.js - --unit=<id>`. In a consumer project without `bin/`, the command fails and the dispatch fails closed to `sonnet` (R3).
- 2026-10-08 Edge cases / failure handling: Q What does a guard-demoted unit's next FAIL do, and what does a fresh session do? → A (self-resolved): the `sonnet` ladder applies, so after the second FAIL the next attempt is `opus`, with exhaustion at n = 4. The guard re-runs on every dispatch, so a fresh session computes the same ladder (Decision 4).
- 2026-10-08 Edge cases / failure handling: Q Two blocks with the same `Unit:` id, nested quoted contracts, unclosed fences, CRLF? → A (self-resolved): shape filter, top-level only, never returned, normalised; each has a test (M1, M5, M7, M4).
- 2026-10-08 Technical constraints & tradeoffs: Q Prose duty or hook? → A (self-resolved): prose plus `bin/contract-guard.js`. A hook would sit under `hooks/` (opus review) and flip OQ3 to block (Decision 1, Decision 5).
- 2026-10-08 Technical constraints & tradeoffs: Q Does the guard need a `tests/validate.sh` edit? → A (self-resolved): no. The checks are appended to the already-registered `tests/contract-score.test.js`.
- 2026-10-08 Terminology consistency: Q "demoted" or "escalated"? → A (self-resolved): **guard demotion** (the unit is kept off `haiku`). "Escalation" stays FAIL-driven (csg-4 `_Avoid_`).

Assumptions: A1, the orchestrator's dispatch prompts keep citing the plan file
(fast path) or the issue number (standard path), as this session's did. A2, no
other unit with an id starting `csg-` is committed before csg-1.

## Risks / dependencies

- R1 The duty is enforced by instruction only. If the orchestrator skips the
  guard, nothing blocks the dispatch, and the forward audit sees a normal haiku
  unit. A detector would need dispatch-time evidence (an `Agent` call's `model`
  parameter): it would be a PreToolUse hook (sensitive) or a transcript audit.
  Out of scope; candidate follow-up.
- R2 Amended contracts. The guard scores the contract as it stands. A contract
  amended to pass after a demoted attempt returns the unit to the haiku ladder
  at the same n, so at n = 2 the next tier is `sonnet`, not `opus`. A contract
  amended to fail at n = 4 on the haiku ladder reaches exhaustion (sonnet ladder
  length 4). Accepted: amendments are spec-master Rulings, and such a Ruling
  should state the next tier. The pre-cutover rule has the same shape.
- R3 Consumer projects. `bin/` ships in the npm package, but `--update` copies
  nothing into a consumer's `bin/`. Where `node bin/contract-guard.js` is absent,
  the command exits non-zero and every haiku dispatch fails closed to `sonnet`,
  which is ADR-0026's behaviour. `agents/task-master.md` already assumes
  `node bin/contract-score.js` is reachable, so this is not a new assumption.
- R4 The audit command depends on per-clone state. It now reads the gitignored
  rulings log, so the forward audit must run in the dispatching clone. A lost
  log makes `jq` exit 2. The landed hdc-4 criterion 3 (real-export check) now
  needs the log too, so it is not portable to a fresh clone. A sturdier
  alternative (an exporter field read from the log and snapshotted into the
  tracked export) is deferred.
- R5 Scribe's own ladder is not in prose. `## Per-unit model routing` speaks of
  lead-programmer only. hdc-5's climb to `sonnet` was practice. csg-2 adds only
  the scribe guard sentence. Writing a scribe ladder down is out of scope.
- R6 Order and version: csg-1 → csg-2 (0.31.147; the prose names the script) →
  csg-3 (its criterion 2 reads csg-2's `RULING` template) → csg-4 (links the
  terms). csg-2 STOPs if HEAD's version is not 0.31.146; the orchestrator then
  re-derives HEAD + 1.
- R7 `tests/validate.sh` (about 11 minutes) was not run by spec-master (brief
  boundary). Every unit's last criterion is validate.sh; the reviewer runs it in
  the main checkout.
- R8 csg-3 and csg-4 dispatch after csg-2 lands, so the guard applies to them.
  Both scribe contracts score 7/7 under v2, and csg-1 and csg-2 score 7/7 lead
  with `sizeOver:false` (measured with the prototype guard against this file;
  CHK1).
- R9 The units' commit trailer is the exact line `Co-Authored-By: Claude Sonnet
  5.5 <noreply@anthropic.com>`, as briefed, even on a `haiku` dispatch. The
  trailer criterion is model-agnostic (cleanup plan Ruling).

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Every score, anchor and mutation in csg-1..csg-4 was measured in a scratch worktree of 9f12c80, except the validate.sh criteria and the version-stamp-check skip-edit mutation, which are marked `proof: not run by spec-master`.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. Extraction and scoring are in `bin/contract-guard.js`, and mirrors change only through `node bin/cli.js --update`.
- P3 "Version-stamp discipline": satisfied. csg-2 is the only unit that touches `agents/`, and it bumps plugin.json and package.json to 0.31.147 and adds a CHANGELOG entry in the same commit, checked per commit by `version-stamp-check.sh`. csg-1 (bin, tests), csg-3 (ADR) and csg-4 (glossary) touch no stamped path.
- P4 "Optional personas degrade gracefully": satisfied. The scribe sentence applies only to "a scribe dispatch that carries a scribe dispatch contract", so it never fires without scribe. The standard-path sentence applies only where an issue body exists.
- P5 "tests/validate.sh is the merge gate": satisfied. It is the last criterion of every unit.

## Steps

| unit | persona | goal | files | bump | after |
|---|---|---|---|---|---|
| csg-1 | lead-programmer | G2, G3 | `bin/contract-guard.js` (new), `tests/contract-score.test.js` | none | none |
| csg-2 | lead-programmer | G1, G4, G5 | `agents/orchestrator.md`, plugin.json, package.json, CHANGELOG.md, 14 `.claude/` mirrors via `--update` | 0.31.147 | csg-1 |
| csg-3 | scribe | G6 (ADR) | `docs/adr/0040-implementer-tier-haiku-default.md` | none | csg-2 |
| csg-4 | scribe | G6 (glossary) | `CONTEXT.md` | none | csg-2, csg-3 |

Step acceptance criteria are the contract criteria below. No `csg-*.fail` exists,
so every unit dispatches on the default tier (`haiku`) with no `Suggested model`
tag. Once csg-2 has landed, the guard itself decides csg-3's and csg-4's ladder.
The reviewer tier is decided at dispatch time by `hooks/scripts/reviewer-tier.sh`
over each unit's diff (csg-2: `opus`, `agents/` is sensitive). Four units, so this
is the fast path and task-master is not needed.

## Open Questions

None blocking. Every decision above has a recorded default.

## Self-check
- CHK1: Do all four contracts below meet the guard they introduce (lead 7/7 with `sizeOver:false`, scribe 7/7, under v2)? — PASS (prototype guard run against this file: csg-1/csg-2 `haiku ... score=7/7`, csg-3/csg-4 `shape=scribe score=7/7`)
- CHK2: Do csg-2's paragraph and csg-1's script agree on the pass line `contract-guard: haiku `? — PASS (csg-2 criterion 4 derives the prefix from the script's output and greps the prose for it; mutation measured)
- CHK3: Do csg-2's `RULING` template and csg-3's jq regex agree on `decision=contract-guard sonnet:`? — PASS (csg-3 criterion 2 builds its log lines from the orchestrator's template; writing `decision=guard sonnet:` in the template prints `insufficient`, measured)
- CHK4: Is the ladder of a guard-demoted unit defined for every n, including exhaustion and a fresh session? — PASS (Decision 4, csg-2 after-text "so ladder exhaustion comes at n = 4", "re-runs on every dispatch")
- CHK5: Is the behaviour defined when the contract is cited by path, held in an issue, in no file, duplicated by shape, nested, unclosed or CRLF? — PASS (Decision 3; csg-1 checks guard-no-contract, guard-shape-filter, guard-nested-block-ignored, guard-unclosed-block, guard-crlf, guard-whole-input)
- CHK6: Is it defined whether `score-exception:` lines raise a score? — PASS (Decision 2: ignored, v2 only)
- CHK7: Do Decision 6, csg-3 and csg-4 agree that guard-demoted units leave the forward-rule population? — PASS
- CHK8: Is OQ3's fate stated in the shipped prose, not only here? — PASS (csg-2 after-text: "`dispatchHygiene.mode` stays `warn` and scribe stays out of `gatedAgents`")
- CHK9: Does every `mutation:` line carry a measured proof or a `proof: not run by spec-master` mark? — FAIL (missing) — revised in place (every criterion now carries one or the other)
- CHK10: Does every per-commit trailer criterion use the amended loop form, and print `1 ` for any commit count? — PASS (csg-1 c9, csg-2 c10, csg-3 c8, csg-4 c5; drop-trailer mutation measured on csg-4 in scratch: `0 `)
- CHK11: Does every Goal clause map to a step criterion? — PASS (G1: csg-2 c1, c4; G2: csg-1 c2, c3; G3: csg-1 c1, c4; G4: csg-2 c1 "so ladder exhaustion comes at n = 4"; G5: csg-2 c1 via the after-text and Decision 5; G6: csg-3 c1-c3, csg-4 c1-c2)
- CHK12: Replay, unit gh307 (class vacuous) and gh429 (vacuous, host), both touching `agents/orchestrator.md`: does csg-2 criterion 1 still fail under its own `mutation:` line? — PASS (skip edit 1 prints `0 0 0 0 0 0 `, measured)
- CHK13: Replay, gh348-14 and gh310 (vacuous) on `agents/orchestrator.md`: does csg-2 criterion 4 still fail under its `mutation:` line? — PASS (prints `0`, measured)
- CHK14: Replay, gh303, gh354 and spec2-unitA (vacuous) on `CONTEXT.md`: does csg-4 criterion 1 still fail under its `mutation:` line? — PASS (`0 2 0 0 `, reasoned from edit 3 alone carrying three of the four phrases; the links-test half was measured, 2 checks FAILED)
- CHK15: Replay, item03-2-link-integrity-guard (vacuous) on `tests/context-glossary-links.test.js`: does csg-4 criterion 2 still fail under its `mutation:` line? — PASS (renaming the heading made `context-glossary-links` report 2 failures, measured)
- CHK16: Replay, ci-fetch-depth-cleanup (host) and item17-4-name-p3-offenders (host) on `hooks/scripts/version-stamp-check.sh`: does csg-2 criterion 5 still fail under its `mutation:` line? — PASS by construction (the criterion gates on stdout, not exit; proof: not run by spec-master for the skip-edit variant)
- CHK17: Replay, gh317, gh320, gh409, gh413, mw-step1..3 and others (vacuous/host) on `tests/validate.sh`: does each unit's validate.sh criterion still fail under its `mutation:` line? — PASS by construction (mirror-parity mutation; proof: not run by spec-master, R7)

Ubiquitous-language (prose mode, advisory). Lens 1: none; "default tier",
"Escalation ladder" and "Haiku-default cutover" are used as CONTEXT.md defines
them. Lens 2: "demoted" in the brief could read as a synonym for escalation, so
it is fixed as **guard demotion**, with "escalation" on the `_Avoid_` line.
"contract of record" overlaps harness-glossary **contract precedence** without
duplicating it; it is defined inside the new entry. Lens 3: **Contract-score
guard** is load-bearing and has no entry; csg-4 adds it.

## Scribe update hint

csg-3 (ADR-0040 amendment) and csg-4 (CONTEXT.md) are the scribe work.
Candidates for a later pass: `docs/harness-glossary.md` **contract self-check**
could point to the guard as its dispatch-time twin, and **ruling / rulings
disambiguation** could cite the `decision=contract-guard sonnet:` line as an
orchestrator-ruling example.

---

# Dispatch contracts (fast path)

## Retrieval contract
No per-unit issues exist. The retrieval contract for every unit is this file, `docs/plans/2026-10-08-contract-score-guard.md`, under `## Unit csg-<n>`. The contract block outranks the plan prose above; a conflict is a spec gap: STOP. Every commit subject ends `(#529)`; scribe closes nothing and never closes #529.

## Unit csg-1

~~~~~markdown
Unit: csg-1

## Objective
A new script `bin/contract-guard.js` (mode 755) prints one line, `contract-guard: haiku ...` or `contract-guard: sonnet ...`, for a unit's contract of record. It finds the one top-level fenced `Unit: <id>` block of the requested shape, scores it with `bin/contract-score.js --rubric=v2`, and passes only when every row is true (lead: and `sizeOver` is false). `tests/contract-score.test.js` gains twelve `guard-` checks. No version bump (no stamped path). One commit, plus one per fix round after a FAIL.

## Retrieval
Plan file: `docs/plans/2026-10-08-contract-score-guard.md`, `## Unit csg-1`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `bin/contract-guard.js` (anchor: new file)
- `tests/contract-score.test.js` (anchor: line matching `All contract-score checks passed.`)

## Ordered edits
1. file: `bin/contract-guard.js`
   anchor: new file (create it with exactly this content; its last line is `function main() {`, and edit 2 appends the rest)
   indent: 0
   insert-after:
```
#!/usr/bin/env node
'use strict';

// Contract-score guard (csg-1). Before a unit is dispatched on `haiku`, the orchestrator runs this
// over the unit's contract of record. One stdout line; `contract-guard: haiku ` only when the one
// matching contract block scores every row true under --rubric=v2 (lead shape: and not sizeOver).
// Exit 0 with a decision, exit 2 on a usage or read error; the orchestrator treats any output
// other than a `contract-guard: haiku ` line, and any non-zero exit, as `sonnet`.

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const FENCE = /^\s*(`{3,}|~{3,})/;
const SHAPE_HEADING = { lead: '## Ordered edits', scribe: '## Glossary edits' };
const UNIT_ID = /^[A-Za-z0-9][A-Za-z0-9._#-]{0,63}$/;

function usage(msg) {
  process.stderr.write(`${msg}\nusage: contract-guard.js <path|-> --unit=<id> [--shape=lead|scribe]\n`);
  process.exit(2);
}

// Top-level fenced blocks whose first interior line is exactly `Unit: <id>`; nested fences are
// interior lines. An unclosed block is never returned. A whole input whose line 1 is `Unit: <id>`
// is a block too.
function blocks(lines, id) {
  const out = [];
  let open = null;
  let start = -1;
  lines.forEach((l, i) => {
    if (open === null) {
      const m = FENCE.exec(l);
      if (m) { open = m[1]; start = i; }
    } else if (l.trim() === open) {
      if (lines[start + 1] === `Unit: ${id}`) out.push(lines.slice(start + 1, i));
      open = null;
    }
  });
  if (lines[0] === `Unit: ${id}`) out.push(lines);
  return out;
}

// `## ` headings outside the block's own nested fences.
function headings(block) {
  const hs = [];
  let open = null;
  for (const l of block) {
    if (open === null) {
      const m = FENCE.exec(l);
      if (m) open = m[1];
      else if (/^## /.test(l)) hs.push(l.trim());
    } else if (l.trim() === open) open = null;
  }
  return hs;
}

function main() {
```
2. file: `bin/contract-guard.js`
   anchor: line matching `function main() {`
   indent: 0
   insert-after:
```
  const args = process.argv.slice(2);
  const opt = (k) => {
    const a = args.find((x) => x.startsWith(`--${k}=`));
    return a ? a.slice(k.length + 3) : null;
  };
  const id = opt('unit');
  const shape = opt('shape') || 'lead';
  const file = args.find((a) => !a.startsWith('--') || a === '-');
  if (!id || !UNIT_ID.test(id)) usage('bad or missing --unit');
  if (!Object.hasOwn(SHAPE_HEADING, shape)) usage('bad --shape');
  if (!file) usage('missing <path|->');
  let raw;
  try { raw = fs.readFileSync(file === '-' ? 0 : file, 'utf8'); } catch (e) { usage(`unreadable: ${e.message}`); }
  const lines = raw.replace(/\r\n/g, '\n').split('\n');
  const say = (tier, why) => process.stdout.write(`contract-guard: ${tier} unit=${id} shape=${shape} ${why}\n`);
  const found = blocks(lines, id).filter((b) => headings(b).includes(SHAPE_HEADING[shape]));
  if (found.length === 0) return say('sonnet', 'reason=no-contract');
  if (found.length > 1) return say('sonnet', `reason=ambiguous-contract(${found.length})`);
  const r = spawnSync(process.execPath,
    [path.join(__dirname, 'contract-score.js'), '-', `--shape=${shape}`, '--rubric=v2'],
    { input: `${found[0].join('\n')}\n`, encoding: 'utf8' });
  let j = null;
  try { j = JSON.parse(r.stdout); } catch (e) { j = null; }
  if (r.status !== 0 || !j || !j.rows) return say('sonnet', `reason=scorer-exit-${r.status}`);
  const rows = Object.keys(j.rows);
  const failed = rows.filter((k) => j.rows[k] !== true);
  const score = `score=${rows.length - failed.length}/${rows.length}`;
  if (failed.length > 0) return say('sonnet', `${score} failed=${failed.join(',')}`);
  if (shape === 'lead' && j.sizeOver !== false) return say('sonnet', `${score} reason=sizeOver`);
  return say('haiku', score);
}

main();
```
3. command: `chmod 755 bin/contract-guard.js`
   expect: 0
4. file: `tests/contract-score.test.js`
   anchor: line matching `All contract-score checks passed.`
   indent: 0
   before:
```
console.log(failures === 0 ? '\nAll contract-score checks passed.' : `\n${failures} check(s) failed.`);
```
   after:
```
// --- Contract-score guard (csg-1): bin/contract-guard.js ---

function guard(args, input) {
  return spawnSync('node', ['bin/contract-guard.js', ...args], { cwd: REPO_ROOT, encoding: 'utf8', input });
}

const G_LEAD = fs.readFileSync(path.join(REPO_ROOT, FIX, 'v2-all-pass.md'), 'utf8');
const G_SCRIBE = fs.readFileSync(path.join(REPO_ROOT, FIX, 'v2-scribe-all-pass.md'), 'utf8');
const G_MINUS = fs.readFileSync(path.join(REPO_ROOT, FIX, 'v2-minus-R5-packet.md'), 'utf8');
const gWrap = (text) => `## Unit x\n\n~~~~~markdown\n${text.trimEnd()}\n~~~~~\n\n`;
const gLine = (r) => {
  assert.strictEqual(r.status, 0, `exit ${r.status}: ${r.stderr}`);
  const lines = r.stdout.split('\n').filter(Boolean);
  assert.strictEqual(lines.length, 1, 'expected exactly one output line');
  return lines[0];
};

check('guard-haiku-lead', () => {
  const line = gLine(guard(['-', '--unit=demo-2'], `# Plan\n\n${gWrap(G_LEAD)}`));
  assert.strictEqual(line, 'contract-guard: haiku unit=demo-2 shape=lead score=7/7');
});

check('guard-sonnet-below-pass-mark', () => {
  const line = gLine(guard(['-', '--unit=demo-2'], gWrap(G_MINUS)));
  assert.strictEqual(line, 'contract-guard: sonnet unit=demo-2 shape=lead score=6/7 failed=R5');
});

check('guard-no-contract', () => {
  const line = gLine(guard(['-', '--unit=demo-9'], gWrap(G_LEAD)));
  assert.strictEqual(line, 'contract-guard: sonnet unit=demo-9 shape=lead reason=no-contract');
});

check('guard-ambiguous', () => {
  const line = gLine(guard(['-', '--unit=demo-2'], gWrap(G_LEAD) + gWrap(G_LEAD)));
  assert.strictEqual(line, 'contract-guard: sonnet unit=demo-2 shape=lead reason=ambiguous-contract(2)');
});

check('guard-shape-filter', () => {
  const doc = gWrap(G_LEAD.replace(/^Unit: demo-2$/m, 'Unit: demo-3')) + gWrap(G_SCRIBE);
  assert.strictEqual(gLine(guard(['-', '--unit=demo-3'], doc)), 'contract-guard: haiku unit=demo-3 shape=lead score=7/7');
  assert.strictEqual(gLine(guard(['-', '--unit=demo-3', '--shape=scribe'], doc)), 'contract-guard: haiku unit=demo-3 shape=scribe score=7/7');
});

check('guard-nested-block-ignored', () => {
  const doc = `~~~~~~markdown\nUnit: other\n\n## Ordered edits\n~~~~\n${G_LEAD.trimEnd()}\n~~~~\n~~~~~~\n`;
  const line = gLine(guard(['-', '--unit=demo-2'], doc));
  assert.strictEqual(line, 'contract-guard: sonnet unit=demo-2 shape=lead reason=no-contract');
});

console.log(failures === 0 ? '\nAll contract-score checks passed.' : `\n${failures} check(s) failed.`);
```
5. file: `tests/contract-score.test.js`
   anchor: line matching `All contract-score checks passed.`
   indent: 0
   before:
```
console.log(failures === 0 ? '\nAll contract-score checks passed.' : `\n${failures} check(s) failed.`);
```
   after:
```
check('guard-unclosed-block', () => {
  const line = gLine(guard(['-', '--unit=demo-2'], `~~~~~markdown\n${G_LEAD}`));
  assert.strictEqual(line, 'contract-guard: sonnet unit=demo-2 shape=lead reason=no-contract');
});

check('guard-whole-input', () => {
  assert.strictEqual(gLine(guard(['-', '--unit=demo-2'], G_LEAD)), 'contract-guard: haiku unit=demo-2 shape=lead score=7/7');
});

check('guard-crlf', () => {
  const line = gLine(guard(['-', '--unit=demo-2'], gWrap(G_LEAD).replace(/\n/g, '\r\n')));
  assert.strictEqual(line, 'contract-guard: haiku unit=demo-2 shape=lead score=7/7');
});

check('guard-size-over', () => {
  const big = `${G_LEAD.trimEnd()}\n\n\`\`\`\n${'x\n'.repeat(81)}\`\`\`\n`;
  const line = gLine(guard(['-', '--unit=demo-2'], gWrap(big)));
  assert.strictEqual(line, 'contract-guard: sonnet unit=demo-2 shape=lead score=7/7 reason=sizeOver');
});

check('guard-usage', () => {
  for (const args of [['-'], ['-', '--unit=demo-2', '--shape=toString'], ['--unit=demo-2'], ['-', '--unit=a/b']]) {
    const r = guard(args, G_LEAD);
    assert.strictEqual(r.status, 2, `${args.join(' ')}: exit ${r.status}`);
    assert.strictEqual(r.stdout, '', `${args.join(' ')}: stdout ${r.stdout}`);
  }
});

check('guard-plan-files', () => {
  const plan = 'docs/plans/2026-10-08-haiku-default-cleanup.md';
  assert.strictEqual(gLine(guard([plan, '--unit=hdc-1'])), 'contract-guard: haiku unit=hdc-1 shape=lead score=7/7');
  assert.strictEqual(gLine(guard([plan, '--unit=hdc-6', '--shape=scribe'])), 'contract-guard: sonnet unit=hdc-6 shape=scribe score=6/7 failed=S7');
});

console.log(failures === 0 ? '\nAll contract-score checks passed.' : `\n${failures} check(s) failed.`);
```
6. command: `node tests/contract-score.test.js > /dev/null`
   expect: 0
7. command: `git add bin/contract-guard.js tests/contract-score.test.js && git commit -m "feat(csg-1): contract-score guard helper and tests (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
8. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `bin/contract-score.js` (the guard spawns it; its output is unchanged)
- `tests/validate.sh` (SENSITIVE_PATHS; `tests/contract-score.test.js` is already registered at lines 1216-1220)
- `tests/fixtures/contract-score/` (the guard checks read three existing fixtures; add none)
- `agents/orchestrator.md` (unit csg-2)

## Acceptance criteria
1. run: `node tests/contract-score.test.js | /usr/bin/grep -cE '^OK   guard-'`
   exit: 0
   stdout: `12`
   mutation: skip edits 4 and 5; prints `0`, exit 1.
   proof: spec-master ran the suite with edits 4 and 5 applied in a scratch worktree of 9f12c80; twelve `OK   guard-` lines. Without them no `guard-` line exists.
2. run: `node tests/contract-score.test.js > /dev/null; echo rc=$?`
   exit: 0
   stdout: `rc=0`
   mutation: in `bin/contract-guard.js` change `if (failed.length > 0)` to `if (failed.length > 1)` (M2); `guard-sonnet-below-pass-mark` and `guard-plan-files` FAIL, prints `rc=1`. Each of M1-M9 in the plan's mutation table also prints `rc=1`.
   proof: spec-master applied M1-M9 one at a time in a scratch copy; each failed the check named in the table.
3. run: `node bin/contract-guard.js docs/plans/2026-10-08-haiku-default-cleanup.md --unit=hdc-6 --shape=scribe`
   exit: 0
   stdout: `contract-guard: sonnet unit=hdc-6 shape=scribe score=6/7 failed=S7`
   mutation: M2; prints `contract-guard: haiku unit=hdc-6 shape=scribe score=6/7`.
   proof: measured by spec-master in a scratch worktree.
4. run: `for s in lead scribe; do node bin/contract-guard.js docs/plans/2026-10-08-haiku-default-tier-contracts.md --unit=htd-1 --shape=$s; done | cut -d' ' -f2 | tr '\n' ' '`
   exit: 0
   stdout: `haiku haiku `
   mutation: M1 (replace the `const found = ...filter(...)` line by `const found = blocks(lines, id);`); prints `sonnet sonnet ` (two blocks share `Unit: htd-1`).
   proof: measured by spec-master in a scratch worktree.
5. run: `node bin/contract-guard.js docs/plans/2026-10-08-haiku-default-cleanup.md --unit=a/b 2>/dev/null; echo rc=$?`
   exit: 0
   stdout: `rc=2`
   mutation: M9; prints `contract-guard: sonnet unit=a/b shape=lead reason=no-contract` then `rc=0`.
   proof: measured by spec-master in a scratch worktree.
6. run: `git ls-files -s bin/contract-guard.js | cut -c1-6`
   exit: 0
   stdout: `100755`
   mutation: skip edit 3; prints `100644`.
   proof: not run by spec-master (the scratch commit carried mode 100755 with edit 3 applied).
7. run: `git diff --name-only "$(git log --format=%H -F --grep='(csg-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-1)' | head -1)" | tr '\n' ' '`
   exit: 0
   stdout: `bin/contract-guard.js tests/contract-score.test.js `
   mutation: also commit an edit to `tests/validate.sh`; the list gains it.
   proof: measured by spec-master on the scratch commit (this exact list).
8. run: `git log --format=%s "$(git log --format=%H -F --grep='(csg-1)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-1)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: not run by spec-master (same form as hdc-1 criterion 9, which passed review).
9. run: `R="$(git log --format=%H -F --grep='(csg-1)' | tail -1)~1..$(git log --format=%H -F --grep='(csg-1)' | head -1)"; for c in $(git rev-list "$R"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   check: prints the distinct per-commit trailer-line counts over the unit's range, so `1 ` means every commit (the original and each fix-round commit) carries exactly one trailer line. Empty stdout (no `(csg-1)` commit) fails.
   mutation: drop one commit's trailer; prints `0 1 ` (or `0 ` for a one-commit unit).
   proof: spec-master ran this loop on scratch commits (`1 `), and on a one-commit unit amended without its trailer (`0 `).
10. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave `tests/contract-score.test.js` unstaged at commit time; prints `1`.
   proof: not run by spec-master.
11. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: in `bin/contract-guard.js` apply M2; the contract-score block fails and it prints `validate-exit=1`.
   proof: not run by spec-master (about 11 minutes; run it in the main checkout).

## Pre-resolved context
precondition: `git log --format=%H -F --grep='(csg-1)' | wc -l` prints `0` and `test -e bin/contract-guard.js` exits 1. Anything else: STOP.
precondition: FIRST, `/usr/bin/grep -cF 'All contract-score checks passed.' tests/contract-score.test.js` prints `1` and the `before:` payload of edits 4 and 5 is the file's last-but-one line verbatim (edit 5 runs after edit 4, so the line is still last-but-one). On any mismatch STOP and report; do not adapt the text.
tdd: yes the twelve `guard-` checks are written in the same edit as the script; criterion 2's mutation proves they bite
blast-radius: tests/contract-score.test.js:220, bin/contract-score.js:389, tests/validate.sh:1217
note: the checks spawn `bin/contract-guard.js`, which spawns `bin/contract-score.js` with `process.execPath`; they read fixtures `v2-all-pass.md`, `v2-scribe-all-pass.md` and `v2-minus-R5-packet.md`, and the tracked plan `docs/plans/2026-10-08-haiku-default-cleanup.md` (its hdc-1 and hdc-6 blocks).
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff (no sensitive path).
explorer: not needed (provenance: explorer blast-radius pass plus grep by spec-master at 9f12c80).
commit-message: feat(csg-1): contract-score guard helper and tests (#529)
review-packet:
```
unit: csg-1 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criteria 1-11: <FILL: exit and stdout of each>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit csg-2

~~~~~markdown
Unit: csg-2

## Objective
`agents/orchestrator.md` `## Per-unit model routing` gains a **Contract-score guard.** paragraph between **Haiku-default cutover** and **Implementer-tier fail ratchet expiry**. Before every dispatch of a unit whose ladder starts at `haiku`, the orchestrator runs `node bin/contract-guard.js` over the unit's contract of record; any output other than a `contract-guard: haiku ` line moves the unit onto the ladder that starts at `sonnet`, and the orchestrator tells the user and writes a `RULING` line. Version 0.31.147, mirrors refreshed by `--update`, one commit (plus one per fix round after a FAIL, each with its own bump).

## Retrieval
Plan file: `docs/plans/2026-10-08-contract-score-guard.md`, `## Unit csg-2`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Affected files
- `agents/orchestrator.md` (anchor below)
- `.claude-plugin/plugin.json`, `package.json` (anchor: line matching `"version": "0.31.146",`)
- `CHANGELOG.md` (anchor: line matching `## [Unreleased]`)
- the 14 `.claude/` paths that `node bin/cli.js --update` rewrites; never edit them by hand

## Ordered edits
1. file: `agents/orchestrator.md`
   anchor: line matching `**Implementer-tier fail ratchet expiry.**`
   indent: 0
   before:
```
**Implementer-tier fail ratchet expiry.** A fail record for unit `X` stops
```
   after:
```
**Contract-score guard.** When the ladder above starts at `haiku`, run the
guard before every dispatch of the unit: `node bin/contract-guard.js
<plan-file> --unit=<task-id>` on the fast path (the `docs/plans/` file the
dispatch cites), or the retrieval contract's `gh issue view <N>` command with
`--json body -q .body` piped into `node bin/contract-guard.js - --unit=<task-id>`
on the standard path. Unless it exits 0 and its first stdout line starts with
`contract-guard: haiku `, the unit uses the ladder that starts at `sonnet`
(`sonnet`, `sonnet`, `opus`, `opus`, so ladder exhaustion comes at n = 4): a
**guard demotion**. A contract held in no file or issue body, a missing script
and a scorer error all count the same. On a guard demotion, tell the user in
one line that quotes the guard's line, and append `RULING <UTC ISO-8601
timestamp> unit=<task-id> decision=contract-guard sonnet: <guard line>` to
`.claude/orchestrator-rulings.log` (**Rulings ledger** above). Scoring is pure,
so the guard re-runs on every dispatch and a fresh session computes the same
ladder from n and the contract; it can only move a unit onto a more capable
ladder, and a `Suggested model` tag can still raise the tier. It scores the
unit's contract of record, never a fix contract. A scribe dispatch that
carries a scribe dispatch contract and would go on `haiku` runs the same check
with `--shape=scribe`, and goes on `sonnet` when it fails. `dispatchHygiene.mode`
stays `warn` and scribe stays out of `gatedAgents`.

**Implementer-tier fail ratchet expiry.** A fail record for unit `X` stops
```
2. file: `.claude-plugin/plugin.json` (version 0.31.147)
   anchor: line matching `"version": "0.31.146",`
   before: `  "version": "0.31.146",`
   after: `  "version": "0.31.147",`
3. file: `package.json` (version 0.31.147)
   anchor: line matching `"version": "0.31.146",`
   before: `  "version": "0.31.146",`
   after: `  "version": "0.31.147",`
4. file: `CHANGELOG.md`
   anchor: line matching `## [Unreleased]`
   indent: 0
   insert-after:
```

**Contract-score guard (csg-2, 0.31.147).** `agents/orchestrator.md`: before every dispatch of a unit whose Escalation ladder starts at `haiku`, the orchestrator runs `node bin/contract-guard.js` over the unit's contract of record (the cited `docs/plans/` file, or the issue body piped in). Unless it prints a `contract-guard: haiku ` line, the unit uses the ladder that starts at `sonnet`, the user is told, and a `decision=contract-guard sonnet:` line goes to the rulings ledger. Scribe dispatches that carry a scribe dispatch contract are checked with `--shape=scribe`. `dispatchHygiene.mode` stays `warn`.
```
5. command: `node bin/cli.js --update`
   expect: 0
6. command: `git status --porcelain --untracked-files=no -- .claude | wc -l`
   expect: 0
   stdout: `14`
7. command: `git add agents/orchestrator.md .claude-plugin/plugin.json package.json CHANGELOG.md && git add -u -- .claude && git commit -m "feat(csg-2): orchestrator runs the contract-score guard before haiku dispatch (0.31.147) (#529)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0
8. command: `git status --porcelain --untracked-files=no | wc -l`
   expect: 0
   stdout: `0`

## Do NOT touch
- `tests/` (every pinned orchestrator.md substring is kept; criterion 3 runs both suites)
- `bin/contract-guard.js` (unit csg-1; criterion 4 reads its output)
- `docs/adr/0040-implementer-tier-haiku-default.md` (unit csg-3)
- `CONTEXT.md` and `docs/harness-glossary.md` (unit csg-4)
- `adapters/` (the cursor port has no ladder text)
- `.claude/persona-config.json` (`dispatchHygiene` stays `warn`; `--update` may restamp it, never hand-edit it)

## Acceptance criteria
1. run: `for p in 'Contract-score guard.' 'node bin/contract-guard.js' 'decision=contract-guard sonnet:' 'so ladder exhaustion comes at n = 4' 'never a fix contract' 'runs the same check'; do tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 2 1 1 1 1 `
   mutation: skip edit 1; prints `0 0 0 0 0 0 `.
   proof: measured by spec-master in a scratch worktree of 9f12c80, with and without edit 1.
2. run: `/usr/bin/grep -c 'Contract-score guard' .claude/agents/orchestrator.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; prints `0`, exit 1.
   proof: measured by spec-master after `--update` in the scratch worktree (`1`).
3. run: `node tests/writer-tier-consistency.test.js > /dev/null && node tests/default-implementer-model.test.js > /dev/null && echo tier-tests-ok`
   exit: 0
   stdout: `tier-tests-ok`
   mutation: in edit 1's after-text write the AC-D9 banned clause (never dispatch on haiku, with haiku in backticks) into the paragraph; AC-D9 fails, exit 1.
   proof: not run by spec-master for the mutation; with edit 1 as written both suites printed their all-passed line in the scratch worktree.
4. run: `P="$(node bin/contract-guard.js docs/plans/2026-10-08-haiku-default-cleanup.md --unit=hdc-1 | cut -d' ' -f1-2) "; tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -oF -- "$P" | wc -l`
   exit: 0
   stdout: `1`
   check: the pass prefix named in the prose is taken from the script's own output (branch agreement), not copied by hand.
   mutation: in edit 1's after-text write `guard: haiku ` in place of `contract-guard: haiku `; prints `0`.
   proof: measured by spec-master in the scratch worktree.
5. run: `bash hooks/scripts/version-stamp-check.sh "$(git log --format=%H -F --grep='(csg-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-2)' | head -1)" | /usr/bin/grep -c '^version-stamp-check: ok'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the line no longer reads `ok`, prints `0`, exit 1 (the script exits 0 on a violation, so this gates on stdout).
   proof: the passing run was measured on the scratch commit (`version-stamp-check: ok touched: yes old: 0.31.146 new: 0.31.147`); the skip-edit variant was not run by spec-master.
6. run: `node -e "const a=require('./package.json').version,b=require('./.claude-plugin/plugin.json').version;const ok=a===b&&a==='0.31.147';console.log(ok?'version-sync: ok':'version-sync: mismatch');process.exit(ok?0:1)"`
   exit: 0
   stdout: `version-sync: ok`
   mutation: skip edit 3; prints `version-sync: mismatch`, exit 1.
   proof: not run by spec-master (same form as hdc-1 criterion 6).
7. run: `diff <(git diff --name-only "$(git log --format=%H -F --grep='(csg-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-2)' | head -1)" | /usr/bin/grep -v '^\.claude/' | sort) <(printf '%s\n' .claude-plugin/plugin.json CHANGELOG.md agents/orchestrator.md package.json | sort) && echo scope-2-ok`
   exit: 0
   stdout: `scope-2-ok`
   mutation: skip edit 4; exit 1.
   proof: the passing run was measured on the scratch commit; the mutation was not run by spec-master.
8. run: `git diff --name-only "$(git log --format=%H -F --grep='(csg-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-2)' | head -1)" -- .claude | wc -l`
   exit: 0
   stdout: `14`
   mutation: skip edit 5; prints `0`.
   proof: measured by spec-master on the scratch commit (`14`).
9. run: `git log --format=%s "$(git log --format=%H -F --grep='(csg-2)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-2)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: not run by spec-master.
10. run: `R="$(git log --format=%H -F --grep='(csg-2)' | tail -1)~1..$(git log --format=%H -F --grep='(csg-2)' | head -1)"; for c in $(git rev-list "$R"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   check: prints the distinct per-commit trailer-line counts over the unit's range, so `1 ` means every commit (the original and each fix-round commit) carries exactly one trailer line. Empty stdout (no `(csg-2)` commit) fails.
   mutation: drop one commit's trailer; prints `0 1 ` (or `0 ` for a one-commit unit).
   proof: measured by spec-master on scratch commits (see csg-1 criterion 9).
11. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave one tracked file modified; prints `1`.
   proof: not run by spec-master.
12. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of `.claude/agents/orchestrator.md`; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by spec-master (about 11 minutes; run it in the main checkout).

## Pre-resolved context
precondition: `node -p "require('./.claude-plugin/plugin.json').version"` and `node -p "require('./package.json').version"` both print `0.31.146`. Anything else: STOP; the orchestrator re-derives every version literal as HEAD version + 1.
precondition: csg-1 has landed (`git log --format=%H -F --grep='(csg-1)' | wc -l` prints `1` or more, and `test -x bin/contract-guard.js` exits 0); `git log --format=%H -F --grep='(csg-2)' | wc -l` prints `0`. Anything else: STOP.
precondition: FIRST, for every `anchor:`, `/usr/bin/grep -cF '<literal>' <file>` prints `1` and every `before:` payload appears verbatim in its file. On any mismatch STOP and report; do not adapt the text.
tdd: no prose-only edit; the checks are greps, a branch-agreement grep against `bin/contract-guard.js` output, two existing suites that pin orchestrator.md text, and validate.sh mirror parity
blast-radius: agents/orchestrator.md:492, tests/writer-tier-consistency.test.js:73, tests/writer-tier-consistency.test.js:120, tests/default-implementer-model.test.js:109
note: the paragraph keeps every pinned substring (the Escalation ladder sentence, the precedence pin, and exactly one Haiku-default cutover timestamp for AC-D11) and adds none of the banned literals.
note: the reviewer tier is decided at dispatch time by the orchestrator running `hooks/scripts/reviewer-tier.sh` over this unit's diff (`agents/` is sensitive: `opus`).
explorer: not needed (provenance: explorer blast-radius pass plus grep by spec-master at 9f12c80).
commit-message: feat(csg-2): orchestrator runs the contract-score guard before haiku dispatch (0.31.147) (#529)
review-packet:
```
unit: csg-2 (#529)
changed files: <FILL: changed files>
commits: <FILL: commit SHA and subject>
criteria 1-12: <FILL: exit and stdout of each>
```
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit csg-3

~~~~~markdown
Unit: csg-3

## Objective
ADR-0040 records the contract-score guard. A new Decision item 5 is added. The forward-rule population excludes the units the guard kept off `haiku`, both in the prose and in the jq: the audit command reads `decision=contract-guard sonnet:` lines from `.claude/orchestrator-rulings.log` and fails when that log is missing. An `## Amendments` entry records the change. No threshold changes. One commit, plus one per fix round after a FAIL.

## Retrieval
Plan file: `docs/plans/2026-10-08-contract-score-guard.md`, `## Unit csg-3`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
none

## Doc edits
1. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Decision`
   before:
```
   unchanged. The exporter, the contract rubric and the audits stay.
```
   text:
```
   unchanged. The exporter, the contract rubric and the audits stay.
5. Contract-score guard (amendment, csg-3): before every dispatch of a unit
   whose ladder starts at `haiku`, the orchestrator scores the unit's contract
   of record with `node bin/contract-guard.js` (rubric v2). Unless every row
   passes (lead shape: and the contract is not oversize), the unit uses the
   ladder that starts at `sonnet`. Scoring is pure, so the check re-runs on
   every dispatch; each demotion appends a `decision=contract-guard sonnet:`
   line to `.claude/orchestrator-rulings.log`.
```
2. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Forward rule (pre-registered)`
   before:
```
`sonnet` before the flip and closed after the cutover), all three must hold:
```
   text:
```
`sonnet` before the flip and closed after the cutover, and except units with a
`decision=contract-guard sonnet:` line in `.claude/orchestrator-rulings.log`,
which the contract-score guard kept off `haiku`), all three must hold:
```
3. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Forward rule (pre-registered)`
   before:
```
Audit command (`<F>` the export file, `<T0>` the cutover timestamp):
```
   text:
```
Audit command, run from the repository root (`<F>` the export file, `<T0>` the
cutover timestamp). It reads `.claude/orchestrator-rulings.log`, a per-clone
file, so it runs in the clone that dispatched the units; a missing log stops it
rather than counting guard-demoted units. The number of units it leaves out for
the guard is reported alongside, for information:
`grep -oE 'unit=[^ ]+ decision=contract-guard sonnet:' .claude/orchestrator-rulings.log | sort -u | wc -l`.
```
4. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Forward rule (pre-registered)`
   before: `--arg t0 "<T0>" '[.[] | select(.terminal_ts >= $t0 and (.id | startswith("htd-") | not))] as $p`
   text: `--arg t0 "<T0>" --rawfile r .claude/orchestrator-rulings.log '[$r | scan("(?m)^RULING \\S+ unit=(\\S+) decision=contract-guard sonnet:") | .[0]] as $g | [.[] | select(.terminal_ts >= $t0 and (.id | startswith("htd-") | not) and (.id as $i | $g | index([$i]) | not))] as $p`
   (a substring replacement inside the single indented `    jq -rs` line; nothing else on that line changes; each `\\S` is two backslash characters followed by `S`, written exactly as shown)
5. file: `docs/adr/0040-implementer-tier-haiku-default.md`
   heading: `## Amendments`
   before:
```
  closed after the cutover. No threshold changed.
```
   text:
```
  closed after the cutover. No threshold changed.
- 2026-10-08 (csg-3, `docs/plans/2026-10-08-contract-score-guard.md`): Decision
  item 5 adds the contract-score guard; the forward-rule population also
  excludes the units the guard kept off `haiku`, which the audit command reads
  from `.claude/orchestrator-rulings.log`. No threshold changed.
```
prune: none

## ADR
none

## Close conditions
- issue #529 is the umbrella [spec] issue and no per-unit issue exists: close nothing, and never close #529
- task-id: csg-3
- marker first line: "PASS csg-3 "
- commit: one commit of the one file (plus one per fix round after a FAIL), subject `docs(csg-3): ADR-0040 contract-score guard and forward-rule exclusion (#529)`, then a second `-m` argument holding exactly the line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; stage with `git add docs/adr/0040-implementer-tier-haiku-default.md`
- precondition: csg-2 has landed (`git log --format=%H -F --grep='(csg-2)' | wc -l` prints `1` or more); `git log --format=%H -F --grep='(csg-3)' | wc -l` prints `0`; `test -f .claude/orchestrator-rulings.log` exits 0 (criterion 4 reads it); every `before:` payload appears verbatim exactly once in the ADR. Anything else: STOP and report.

## Do NOT touch
- every other file under `docs/adr/` (ADR-0026 in particular)
- `CONTEXT.md` and `docs/harness-glossary.md` (unit csg-4)
- `agents/`, `bin/`, `scripts/`, `tests/` (the phrases AC-D8b pins in this ADR must stay verbatim; criterion 5 checks them)
- `.claude/orchestrator-rulings.log` (read by criterion 4, never written by this unit)

## Acceptance criteria
1. run: `A=docs/adr/0040-implementer-tier-haiku-default.md; for p in '5. Contract-score guard (amendment, csg-3)' 'which the contract-score guard kept off' 'a missing log stops it' '--rawfile r .claude/orchestrator-rulings.log' '(csg-3, '; do tr '\n' ' ' < $A | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 1 1 1 1 `
   mutation: skip Doc edit 1; prints `0 1 1 1 1 `.
   proof: measured by spec-master in a scratch worktree with all five edits applied, and with item 5 removed.
2. run: `T=$(tr '\n' ' ' < agents/orchestrator.md | tr -s ' ' | /usr/bin/grep -oE 'RULING <UTC ISO-8601 timestamp> unit=<task-id> decision=[a-z-]+ [a-z]+:'); C=$(/usr/bin/grep -E '^    jq -rs' docs/adr/0040-implementer-tier-haiku-default.md | sed "s/^    //; s/<T0>/2026-10-08T17:28:48Z/; s#<F>#/dev/stdin#"); D=$(mktemp -d); mkdir "$D/.claude"; for i in 1 2 3 4 5 6 7 8; do echo "$T x" | sed "s/<UTC ISO-8601 timestamp>/2026-10-09T00:00:00Z/; s/<task-id>/g-$i/"; done > "$D/.claude/orchestrator-rulings.log"; echo 'RULING 2026-10-09T00:00:00Z unit=x-1 decision=haiku FAIL 1, not a decision=contract-guard sonnet: line' >> "$D/.claude/orchestrator-rulings.log"; for i in $(seq 1 20); do printf '{"id":"x-%s","terminal_ts":"2026-10-09T00:00:00Z","fail_blocks":%s}\n' $i $([ $i -le 7 ] && echo 2 || echo 0); done > "$D/f.jsonl"; for i in $(seq 1 8); do printf '{"id":"g-%s","terminal_ts":"2026-10-09T00:00:00Z","fail_blocks":0}\n' $i; done >> "$D/f.jsonl"; (cd "$D" && bash -c "$C" < f.jsonl); rm -rf "$D"`
   exit: 0
   stdout: `tripwire`
   check: the log lines are built from the orchestrator's own `RULING` template (csg-2), so the ADR's regex and the orchestrator's template must agree. With the eight zero-FAIL guard-demoted `g-` units excluded, the population is 20 units with 7 at two FAIL blocks (0.35 > 0.30). The `x-1` line, which is not a guard demotion, must not exclude `x-1`.
   mutation: skip Doc edit 4; prints `insufficient` (28 units, 0.25). Writing `decision=guard sonnet:` in the orchestrator template also prints `insufficient`.
   proof: both measured by spec-master in a scratch worktree.
3. run: `C=$(/usr/bin/grep -E '^    jq -rs' docs/adr/0040-implementer-tier-haiku-default.md | sed "s/^    //; s/<T0>/2026-10-08T17:28:48Z/; s#<F>#/dev/stdin#"); D=$(mktemp -d); echo '{"id":"a","terminal_ts":"2026-10-09T00:00:00Z","fail_blocks":0}' | (cd "$D" && bash -c "$C" > /dev/null 2>&1); echo rc=$?; rm -rf "$D"`
   exit: 0
   stdout: `rc=2`
   check: with no rulings log the audit stops instead of counting demoted units.
   mutation: skip Doc edit 4; prints `rc=0`.
   proof: measured by spec-master (jq 1.8.2: "Could not open .claude/orchestrator-rulings.log", exit 2).
4. run: `for t in 2026-08-25T00:00:00Z 2026-10-05T00:00:00Z; do /usr/bin/grep -E '^    jq -rs' docs/adr/0040-implementer-tier-haiku-default.md | sed "s/^    //; s/<T0>/$t/; s#<F>#docs/audits/unit-outcomes/2026-10-06.jsonl#" | bash; done | tr '\n' ' '`
   exit: 0
   stdout: `met insufficient `
   check: on the tracked export the amendment changes no verdict (no unit in it has a guard-demotion line).
   mutation: in a scratch copy replace `<= 0.35` by `<= 0.30` in the jq line; the first word becomes `not-met`.
   proof: spec-master ran the amended line with a copy of this clone's rulings log; it printed `met insufficient `. The mutation was measured in hdc-4's proof on the same export; not re-run by spec-master.
5. run: `node tests/writer-tier-consistency.test.js > /dev/null && echo wtc-ok`
   exit: 0
   stdout: `wtc-ok`
   mutation: delete the word `tripwire` from the ADR; AC-D8b fails, prints nothing, exit 1.
   proof: the passing run was measured by spec-master in the scratch worktree; the mutation was not run by spec-master.
6. run: `git diff --name-only "$(git log --format=%H -F --grep='(csg-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-3)' | head -1)" | tr '\n' ' '`
   exit: 0
   stdout: `docs/adr/0040-implementer-tier-haiku-default.md `
   mutation: also commit an edit to `CONTEXT.md`; the list gains it.
   proof: measured by spec-master on the scratch commit.
7. run: `git log --format=%s "$(git log --format=%H -F --grep='(csg-3)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-3)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: not run by spec-master.
8. run: `R="$(git log --format=%H -F --grep='(csg-3)' | tail -1)~1..$(git log --format=%H -F --grep='(csg-3)' | head -1)"; for c in $(git rev-list "$R"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   check: prints the distinct per-commit trailer-line counts over the unit's range, so `1 ` means every commit (the original and each fix-round commit) carries exactly one trailer line. Empty stdout (no `(csg-3)` commit) fails.
   mutation: drop one commit's trailer; prints `0 1 ` (or `0 ` for a one-commit unit).
   proof: measured by spec-master on scratch commits (see csg-1 criterion 9).
9. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave the ADR unstaged at commit time; prints `1`.
   proof: not run by spec-master.
10. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: hand-edit one line of `.claude/agents/orchestrator.md`; the mirror-parity checks fail and it prints `validate-exit=1`.
   proof: not run by spec-master (about 11 minutes; run it in the main checkout).

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

## Unit csg-4

~~~~~markdown
Unit: csg-4

## Objective
CONTEXT.md gains a new entry, **Contract-score guard**, placed after **Haiku-default cutover**. It defines the guard, a guard demotion and the contract of record. **default tier** now says a guard-demoted unit's ladder entry is `sonnet`. **Haiku-default cutover** now says the forward rule also leaves out guard-demoted units. One commit, plus one per fix round after a FAIL.

## Retrieval
Plan file: `docs/plans/2026-10-08-contract-score-guard.md`, `## Unit csg-4`. No per-unit issue exists. Umbrella: `gh issue view 529 --repo Storreslara/AntiSlop`. The contract outranks the plan prose; a conflict is a spec gap: STOP.

## Glossary edits
Each `before:` is one whole line. Replace that line with the `text:` lines.
1. file: `CONTEXT.md`
   heading: `**default tier**:`
   before:
```
  tier).
```
   text:
```
  tier, or `sonnet` for a unit the [[Contract-score guard]] keeps off
  `haiku`).
```
2. file: `CONTEXT.md`
   heading: `**Haiku-default cutover**:`
   before:
```
  the `htd-` units of the haiku-default programme itself.
```
   text:
```
  the `htd-` units of the haiku-default programme itself and the units the
  [[Contract-score guard]] kept off `haiku`.
```
3. file: `CONTEXT.md`
   heading: `**Haiku-default cutover**:`
   before:
```
_Avoid_: cutover unit (the commit that set it), flip commit
```
   text:
```
_Avoid_: cutover unit (the commit that set it), flip commit

**Contract-score guard**:
(ADR-0040 amendment, unit csg-4, 2026-10-08) — the check the orchestrator runs
  before every dispatch of a unit whose [[Escalation ladder]] would start at
  `haiku`: the unit's contract of record (its `Unit:` contract block in the
  plan file or issue body the dispatch cites, never a fix contract) is scored
  under rubric v2, and unless every row passes (and, for a lead-programmer
  contract, it is not oversize) the unit starts its ladder at `sonnet`
  instead. That move is a guard demotion. Scoring is pure, so the guard
  re-runs on every dispatch instead of being remembered; each guard demotion
  is recorded in the orchestrator's Rulings ledger, and ADR-0040's forward rule
  leaves those units out of its population because they never ran on `haiku`.
_Avoid_: escalation (that is FAIL-driven), haiku gate
```

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #529 is the umbrella [spec] issue and no per-unit issue exists: close nothing, and never close #529
- task-id: csg-4
- marker first line: "PASS csg-4 "
- commit: one commit of the one file (plus one per fix round after a FAIL), subject `docs(csg-4): glossary defines the contract-score guard (#529)`, then a second `-m` argument holding exactly the line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; stage with `git add CONTEXT.md`
- precondition: csg-2 and csg-3 have landed (`git log --format=%H -F --grep='(csg-2)' | wc -l` and the same for `(csg-3)` each print `1` or more); `git log --format=%H -F --grep='(csg-4)' | wc -l` prints `0`; each `before:` line matches exactly once as a whole line (`/usr/bin/grep -cxF -- '<before line>' CONTEXT.md` prints `1`). Anything else: STOP and report.

## Do NOT touch
- every other entry in `CONTEXT.md` (in particular **Escalation ladder**, **ladder exhaustion**, **Implementer-tier ratchet**, **defaultImplementerModel**, **Writer tier**)
- `docs/harness-glossary.md` (candidates for a later pass are listed in the plan's Scribe update hint)
- `docs/adr/`, `agents/`, `bin/`, `tests/`

## Acceptance criteria
1. run: `for p in '**Contract-score guard**:' '[[Contract-score guard]]' 'That move is a guard demotion.' 'never a fix contract'; do tr '\n' ' ' < CONTEXT.md | tr -s ' ' | /usr/bin/grep -oF -- "$p" | wc -l; done | tr '\n' ' '`
   exit: 0
   stdout: `1 2 1 1 `
   mutation: skip Glossary edit 3; prints `0 2 0 0 `.
   proof: the passing counts were measured by spec-master in a scratch worktree; the skip-edit-3 counts follow from edit 3 alone carrying three of the four phrases, and were not run by spec-master.
2. run: `node tests/context-glossary-links.test.js > /dev/null && node tests/ubiquitous-language.test.js > /dev/null && echo glossary-tests-ok`
   exit: 0
   stdout: `glossary-tests-ok`
   check: the two `[[Contract-score guard]]` links from edits 1 and 2 resolve only if edit 3's heading is written exactly.
   mutation: write the new heading as `**Contract guard**:`; `context-glossary-links` reports 2 failed checks, exit 1.
   proof: measured by spec-master in a scratch worktree.
3. run: `git diff --name-only "$(git log --format=%H -F --grep='(csg-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-4)' | head -1)" | tr '\n' ' '`
   exit: 0
   stdout: `CONTEXT.md `
   mutation: also commit an edit to `docs/harness-glossary.md`; the list gains it.
   proof: measured by spec-master on the scratch commit.
4. run: `git log --format=%s "$(git log --format=%H -F --grep='(csg-4)' | tail -1)~1".."$(git log --format=%H -F --grep='(csg-4)' | head -1)" | /usr/bin/grep -vc '(#529)$'`
   exit: 1
   stdout: `0`
   mutation: commit with a subject lacking ` (#529)`; prints `1`, exit 0.
   proof: not run by spec-master.
5. run: `R="$(git log --format=%H -F --grep='(csg-4)' | tail -1)~1..$(git log --format=%H -F --grep='(csg-4)' | head -1)"; for c in $(git rev-list "$R"); do git log -1 --format=%B "$c" | /usr/bin/grep -cE '^Co-Authored-By: Claude .+ <noreply@anthropic\.com>$'; done | sort -u | tr '\n' ' '`
   exit: 0
   stdout: `1 `
   check: prints the distinct per-commit trailer-line counts over the unit's range, so `1 ` means every commit (the original and each fix-round commit) carries exactly one trailer line. Empty stdout (no `(csg-4)` commit) fails.
   mutation: drop one commit's trailer; prints `0 1 ` (or `0 ` for a one-commit unit).
   proof: spec-master amended a one-commit scratch `(csg-4)` commit without its trailer; this loop printed `0 `.
6. run: `git status --porcelain --untracked-files=no | wc -l`
   exit: 0
   stdout: `0`
   mutation: leave `CONTEXT.md` unstaged at commit time; prints `1`.
   proof: not run by spec-master.
7. run: `bash tests/validate.sh > /dev/null 2>&1; echo validate-exit=$?`
   exit: 0
   stdout: `validate-exit=0`
   mutation: write the new heading as `**Contract guard**:`; the glossary-link check inside validate.sh fails and it prints `validate-exit=1`.
   proof: not run by spec-master (about 11 minutes; run it in the main checkout).

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
~~~~~

