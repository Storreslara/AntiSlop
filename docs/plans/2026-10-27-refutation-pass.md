# Refutation pass: challenge the reviewer's judgment defects before a FAIL verdict

Status: **revision 2, 2026-10-27** (spec-master), plus follow-up unit rfp-u2b (2026-10-27). Revision 2 applies
the four user decisions and the critic's review (verdict "SOUND WITH CHANGES"). Fast path: 6 dispatchable
units plus one human gate, and all six contracts are written. rfp-u1 and rfp-u2 have reviewer PASS markers.
rfp-u2b (Gate G hardening, from rfp-u2's PASS notes) is next and not yet dispatched. Gate G and rfp-u3 to
rfp-u5 wait on it. Open Questions 1 and 2 await the user (their recommended defaults are applied).

## Units and order

Each unit is dispatched only after every unit in its "after" column has a reviewer PASS marker (Gate G: after
G3 printed `replay-gate: pass`). One unit is mid-review at a time.

| unit | owner | after | contract |
|---|---|---|---|
| rfp-u1 | lead-programmer | (none) | [rfp-u1](2026-10-27-refutation-pass/contracts/rfp-u1.md): the brief script |
| rfp-u2 | lead-programmer | rfp-u1 (its `run.sh` dry-run calls the brief script) | [rfp-u2](2026-10-27-refutation-pass/contracts/rfp-u2.md): the replay corpus and gate tooling |
| rfp-u2b | lead-programmer | rfp-u2 (it hardens rfp-u2's files) | [rfp-u2b](2026-10-27-refutation-pass/contracts/rfp-u2b.md): per-id gate scoring, the history-limited replay clone and the guard hook |
| Gate G | the human operator (G1, G2), anyone (G3) | rfp-u2b | none: not a dispatchable unit (see "Gate G") |
| rfp-u3 | lead-programmer | rfp-u1, rfp-u2, Gate G | [rfp-u3](2026-10-27-refutation-pass/contracts/rfp-u3.md): the reviewer pass and the FAIL-record format |
| rfp-u4 | lead-programmer | rfp-u3 (its edit 0 checks the protocol text) | [rfp-u4](2026-10-27-refutation-pass/contracts/rfp-u4.md): the task-master fix-contract bullet and the milestone-auditor sample |
| rfp-u5 | scribe | rfp-u3 and rfp-u4 (its criteria read both; `no-source` otherwise) | [rfp-u5](2026-10-27-refutation-pass/contracts/rfp-u5.md): glossary entries and ADR 0043 |

If Gate G3 prints `fail` or `insufficient`, rfp-u3 to rfp-u5 are not dispatched (Open Question 2).

Revision 1's `rfp-u2` (scribe) is withdrawn and renumbered rfp-u5. Nothing from revision 1 was dispatched.

## Goal

A FAIL defect the reviewer found by reading code (a **judgment defect**) reaches the lead-programmer only
after a fresh-context `explorer` subagent on `sonnet` has tried to disprove it against the real code: the
whole file, its callers and the baseline. The reviewer then re-checks each artifact itself and says, in its
own words, why the artifact proves or defeats the claim.

- If every defect is refuted, the unit passes and no FAIL block is written, so no Escalation-ladder attempt
  is used up.
- A defect left UNCERTAIN in a FAIL that happens anyway stays in the defect list, tagged `[unconfirmed]`.
- Every FAIL block ends with a `refutation:` telemetry line.
- The pass is enabled only after an offline replay of past real defects shows that it almost never refutes
  a real one (Gate G). After that, the milestone auditor samples live refutations.
- Mechanical FAIL grounds are never re-checked. The pass writes no marker. The one-unit-one-review
  invariant, the route gate, the stop gate and the ladder arithmetic are unchanged.

## Resolved decisions (revision 2)

| # | Decision | Source |
|---|---|---|
| D1 | Mixed FAIL: UNCERTAIN defects stay in the FAIL defect list, prefixed `[unconfirmed]`. A fix reproduces an `[unconfirmed]` defect before changing code, and reports one that does not reproduce instead of fixing it. | user, option (c) |
| D2 | The explorer spawn carries `model: sonnet` | user |
| D3 | FAIL-side telemetry now. The last line of every FAIL block is `refutation: confirmed=<a> refuted=<b> uncertain=<c>`, or `refutation: skipped=<mechanical\|over-cap\|resume\|no-subagent>` | user. The skipped grammar is spec-master's |
| D4 | Defect cap is 3, not 5 | critic. The turn budget cannot be passed per spawn (see Cost model) |
| D5 | Replay-corpus gate before enabling (Gate G), plus a milestone-auditor sample of `refuted:` notes | critic BLOCKER. The design is spec-master's |
| D6 | The reviewer states why each artifact defeats or proves the claim. It may keep a defect standing with a reason. For a mitigation, the re-check confirms that the guard stops the defect on the defect's own path. Revision 1's sentence that the reviewer "may not argue away a refutation" is deleted. | critic MAJOR |
| D7 | On the INSUFFICIENT-CONTEXT resume: FAIL a defect the reviewer now reproduces itself. A defect it cannot reproduce becomes a `NOTE[code]: unconfirmed:` line. | critic MAJOR |
| D8 | The explorer brief is a shipped script (`bin/refutation-brief.sh`). Both the reviewer and the replay use it, so the replay tests exactly the brief that ships. This also shrinks the reviewer bullet. | spec-master, from D5 |

## Context

### Where things live (verified at 1073743d)

- **Reviewer rules.**
  - `agents/reviewer.md`: "Verdict" :127-143 ("PASS only when … found no refutation" :137-138; the
    advisory-section order :140-143), "On FAIL" :241-256, "On INSUFFICIENT-CONTEXT" :257-269.
  - `.claude/agents/reviewer.md` is generated by `node bin/cli.js --update`.
- **FAIL-record format.** The canonical text is `templates/persona-protocol.md` "FAIL record" :343-356. It
  is inlined by cli.js into the orchestrator, lead-programmer, reviewer, spec-master and task-master
  mirrors (`bin/cli.js:803-894`), so task-master and the lead-programmer learn the `[unconfirmed]` rule
  from the same section.
- **Hand-synced ports that carry the format.** These are exactly the four files
  `tests/adapter-fail-tier-pin.test.js:12-17` pins:
  - `adapters/codex/agents/reviewer.toml:93`
  - `adapters/codex/agents-md-fragment.md:126`
  - `adapters/cursor/agents/reviewer.md:90`
  - `adapters/cursor/rules/persona-protocol.mdc:132`

  The ports have no verified way to spawn a subagent, so they write `refutation: skipped=no-subagent`.
- **Other writers.** `hooks/scripts/marker-write.sh` writes `<detail>` verbatim after the header, so the
  telemetry line passes through it unchanged. Its fixtures in `tests/fail-marker-format-parity.test.sh` are
  hard-coded and stay valid.
- **Glossary.** `CONTEXT.md` "FAIL block" :1077 spells the block format (rfp-u5 updates it).
  `docs/harness-glossary.md` lists neither the format nor the advisory order. rfp-u5 adds a
  "refutation line" entry there, because that file holds harness-mechanics terms.

### FAIL-record readers: why the new line is safe (verified)

| reader | what it reads | effect of a last-line `refutation:` and `[unconfirmed]` prefix |
|---|---|---|
| `bin/fail-count.sh`, `bin/ladder-tier.sh` (n), `bin/ladder-tier.sh --census` | `^FAIL <id> ` header count | none |
| `bin/escalation-card.sh:25-29` | header, `tier:`, then the **first** non-empty line | none while `refutation:` is the **last** line (rfp-u3 fixture test case b; the mutation moves it first and the test fails) |
| `hooks/scripts/reviewer-tier.sh`, `bin/unit-size.sh:107` | whether the record exists | none |
| `scripts/unit-outcomes.js:11-19,136-139` | substring classes over the block text | none if the line's words avoid every class substring. `refutation`, `confirmed`, `refuted`, `uncertain`, `skipped`, `mechanical`, `over-cap`, `resume`, `no-subagent` and `[unconfirmed]` match none (rfp-u3 fixture test case c reads the live `CLASSES` table) |
| task-master fix contract (`agents/task-master.md:98-107`) | the latest block, verbatim | it must not treat `refutation:` as a defect, and must reproduce `[unconfirmed]` defects first: the protocol section (rfp-u3) plus a task-master bullet (rfp-u4) |
| the reviewer fix-round scope rule (`agents/reviewer.md:62-63`) | paths named in a defect | `[unconfirmed]` defects keep their paths, and the telemetry line has none |

### Gate interaction (verified by running the gates' tests)

- **Route gate.** A reviewer may spawn `explorer` and no review-join stamp is written
  (`hooks/scripts/lib/reviewer-route-gate-core.sh:78`, scoped to `reviewer` targets). spec-master ran the
  new case in a scratch copy, and its mutation made it fail. A reviewer may not spawn a `reviewer`
  (`tests/reviewer-route-gate-caller.test.sh:66`).
- **Markers.** `hooks/scripts/reviewed-path-gate.sh:249` grants reviewer identities only, and `explorer`
  has no Write/Edit tool.
- **Stop gate.** The explorer's `SubagentStop` adds one `grant-denied … identity=explorer` audit line while
  the reviewer's flag stands, as every reviewer-to-explorer spawn already does (R4).
- **State after a refutation.** A PASS reached through a refutation writes exactly the state of any other
  PASS: the same v3 `.pass` first line, the same review-join stamp consumption and the same bounded flag
  clearing. Only its notes differ. A prevented FAIL writes no `.fail` block. An UNCERTAIN-only outcome
  writes `.blocked`, as any INSUFFICIENT-CONTEXT does. No new state file exists.
- **Reviewer-run commands.** When the reviewer reproduces a defect itself with a command, that defect
  becomes mechanical and the pass is skipped for it. This is intended: the defect already has its artifact.

### ADR draft (rfp-u5 numbers and lands it)

> **ADR-draft: the refutation pass runs inside the reviewer's turn, and is enabled only behind a replay
> gate.**
>
> *Context.* A hallucinated or already-mitigated FAIL defect uses up an Escalation-ladder attempt, because
> `n` is the FAIL-block count.
>
> *Decision.* Before returning FAIL, the reviewer spawns one foreground, unnamed `explorer` on `sonnet`. Its
> prompt comes from `bin/refutation-brief.sh` and asks it to disprove each of at most 3 judgment defects.
> The reviewer re-checks each artifact, states its own reason, and may keep a defect standing. Only defects
> that survive reach the FAIL record, which now ends with a `refutation:` telemetry line. The reviewer
> instructions ship only after a replay of past real defects passes a recall threshold.
>
> *Alternatives rejected.*
> - (C) An orchestrator-dispatched refuter after the FAIL. `n` has already gone up, so undoing it needs a
>   new marker or a `ladder-tier.sh` change, plus fix-contract filtering and a second route-gate shape.
> - A nested `Mode: advisory` reviewer. The caller allowlist refuses it.
> - A new `refuter` persona. It costs a persona file, ports, personaSelection and cli.js lists, and buys
>   nothing over `explorer`.
>
> *Consequences.* No hook, marker, ladder or orchestrator change. The FAIL-record format gains a last line.
> The pass's verdict is evidence; the verdict stays the reviewer's.
>
> The three ADR tests: hard to reverse (moving to (C) needs state machinery, and the telemetry format would
> be in consumer records), surprising (a "second gate" is not a second dispatch), and a real trade-off.

### Per-defect protocol

The reviewer pipes one `D<n>: <file:line> <claim>` line per deduplicated judgment defect (1 to 3) into
`bash .claude/bin/refutation-brief.sh <baseline>`. The script refuses 0, more than 3, malformed or
duplicated lines, and a bad baseline. It prints a fixed brief: the baseline, the changed files, the three
questions, the answer grammar `D<n>: REFUTED|CONFIRMED|UNCERTAIN — q1=… q2=… q3=… — artifact: …`, and the
rules: when unsure, answer UNCERTAIN, never CONFIRMED; a verdict with no artifact is UNCERTAIN; a
mitigation's artifact is the guard itself plus why it stops this defect on this path.

The reviewer spawns `explorer` once with that brief as the prompt.

| explorer answer, after the reviewer's own re-check | result |
|---|---|
| REFUTED, and the reviewer confirms the artifact defeats the claim (for a guard: it stops the defect on the defect's path) and states why | dropped. PASS: `NOTE[code]: refuted: D<n> <claim> — <artifact> — <why>`. FAIL: the `refutation` advisory section |
| REFUTED, but the reviewer finds a reason the artifact does not defeat it | **stands**. The reason goes in the `refutation` section |
| REFUTED as already at the baseline (`git show <baseline>:<file>`), not an unmet criterion | dropped as REFUTED |
| CONFIRMED with an artifact that reproduces | stays a defect |
| UNCERTAIN, or an answer with no artifact | `[unconfirmed]` in a FAIL that happens anyway; see the table below |
| artifact does not reproduce, no answer line, or the explorer was truncated | **stands as found** (today's behaviour) |

| standing or CONFIRMED | UNCERTAIN | verdict | FAIL block's last line |
|---|---|---|---|
| ≥1 | any | FAIL: the standing and CONFIRMED defects, plus each UNCERTAIN one prefixed `[unconfirmed]` | `refutation: confirmed=<a> refuted=<b> uncertain=<c>` (`a` counts standing and CONFIRMED) |
| 0 | ≥1 | INSUFFICIENT-CONTEXT, `missing:` naming the evidence. On the resume there is no second pass: a defect the reviewer now reproduces is a FAIL (`refutation: confirmed=…`), and one it cannot reproduce is `NOTE[code]: unconfirmed:` | none, unless the resume FAILs |
| 0 | 0 | the PASS rules, escalation included | none (no FAIL) |
| pass skipped | – | as today | `refutation: skipped=<mechanical\|over-cap\|resume\|no-subagent>` |

**Why UNCERTAIN-only maps to INSUFFICIENT-CONTEXT and not ESCALATE-TO-HUMAN.** ESCALATE-TO-HUMAN gates a
would-be PASS only (`agents/reviewer.md:272`), and it spends a human. INSUFFICIENT-CONTEXT uses no cap slot,
keeps the review blocking, and already has the fetch-and-resume path (`agents/orchestrator.md:276-292`).

**The "PASS is one line" rule** (`agents/reviewer.md:127-131`) governs the verdict line. The `refuted:`
notes go into the marker's non-blocking notes, written by Bash, as every note does. The `refutation`
section is a third advisory section after the verdict, in the order roast-work, ubiquitous-language,
refutation, so the verdict stays the first thing read.

**The word collision** at :137-138 ("found no refutation", meaning a refutation of the *change*) is removed
by rewording it to "found no defect that survived the refutation pass". The glossary (rfp-u5) records that
"Refute, don't rubber-stamp" (:46) still means attacking the change.

### Safety: what can go wrong in each direction, and how each is caught

- **Wrongly confirmed** (the risk the research names): a needless fix, recovered cheaply. This is unchanged
  from today.
- **Wrongly refuted, and the unit passes.** The reviewer's PASS is the terminal gate, so this is the costly
  direction. The critic is right that the `refuted:` count only counts wins. Three layers catch it:
  1. **Before enabling: Gate G (replay).** rfp-u2 builds a seeded corpus of 41 past judgment defects in 24
     groups, drawn from 57 candidates whose unit was later fixed and passed. The proxy label "real" means a `(<unit>)` commit after the FAIL touched the
     cited file and the unit later holds a `.pass`. A human confirms each label (`labels.tsv`) and runs the
     replay: `bin/refutation-brief.sh` at the reviewed commit, headless `claude -p --model sonnet
     --max-turns 10` with read-only tools. `score.py --gate` passes only if:
     - at least 30 confirmed-real defects were replayed;
     - at most 1 of them was answered REFUTED with an artifact;
     - at most 20% of defects got no answer line;
     - no run exceeded 10 turns.

     rfp-u3 carries `score.py --gate` on the committed report as an acceptance criterion, so the reviewer
     instructions cannot reach PASS without a passing replay.

     *Statistical honesty:* 1 miss in 30 bounds the true raw miss rate at about 17% (95% upper, exact
     binomial). 0 in 30 bounds it at about 10%. The replay measures the explorer stage alone. The
     reviewer's own re-check (D6) is a second filter that is not measured, so the live miss rate is at most
     the measured one. Open Question 1 offers a larger corpus.
  2. **After enabling: milestone-auditor sample (rfp-u4).** At each milestone boundary, the auditor
     re-verifies up to 3 `NOTE[code]: refuted:` lines from that milestone's `.pass` markers. A refutation
     that does not hold is a finding, which goes to the human decision the auditor already ends in.
  3. **Downstream:** a later review, unit or audit that hits the defect again. This is unchanged.
- **What is not testable mechanically.** The live reviewer's judgment, and whether a given live refutation
  was right, can only be sampled (layer 2). The prose pins in rfp-u3 prove the instruction text shipped,
  not that it is followed. The behaviour-bearing checks are:
  - the route-gate case (the nested spawn is admitted, with no stamp);
  - the brief script's fixture test (caps, grammar, determinism);
  - the FAIL-record fixture test (the readers are unaffected);
  - the replay gate (the explorer stage on real past defects);
  - the scorer and builder fixture tests.

### Cost model (with base rates from this repo's own records)

**Base rate.** spec-master classified all 193 FAIL blocks in the 174 `.fail` records (a keyword classifier
over each block's defect lines; the script and its output are reproducible by `eval/refutation-replay/`'s
builder):

| class | blocks | share |
|---|---|---|
| any mechanical ground (precheck lines, version-stamp, uncommitted, scope, a criterion's exit or stdout) | 143 | 74% |
| judgment only, 1-3 defects (**eligible at cap 3**) | 37 | 19% |
| judgment only, 4-5 defects | 7 | 4% |
| judgment only, more than 5 | 6 | 3% |

The classifier over-counts "mechanical": defect prose that merely mentions an exit code matches it. So 19%
of FAILs is a floor. With 708 PASS markers, reviews number about 901, so **eligible runs are about 4% of all
reviews** (37 over the project's history to date). The 4-5 band adds only 7 blocks, which is part of why the
cap moves to 3 (D4).

**Turn budget.** The `Agent` tool has no per-spawn turn parameter (its schema is description, prompt,
subagent_type, model, isolation, effort and run_in_background). The explorer's frontmatter `maxTurns: 10`
therefore binds, and `sonnet` does not raise it. Each defect needs about 2 to 3 tool rounds (the whole file
and its callers in parallel, then the baseline), so 3 defects take about 7 to 9 rounds including the
answer. 5 did not fit. The replay records `num_turns` and fails the gate on any run that exceeds 10, so this
estimate is checked before enabling.

**Per run (eligible FAIL only).** One sonnet `explorer` with up to 10 turns and a brief under 2 KB. Plus
reviewer overhead: one script call, one spawn turn, and one re-check per defect, run in parallel; about 3 to
6 reviewer turns out of 50. Latency is one subagent round-trip on the FAIL path. The replay reports the
measured mean `total_cost_usd` and turns, which replace these estimates.

**UNCERTAIN-only round trip.** One orchestrator turn, one explorer or scribe fetch dispatch, and the resumed
reviewer's turns. It is bounded to once per review, because the resume runs no second pass. It is still
cheaper than a fix round, which contains a full review.

**Standing cost.** The bullet in `agents/reviewer.md` is about 35 lines, roughly 450 tokens per reviewer
dispatch, cached by `cacheTtl: 1h`. The brief text lives in the script, not the persona.

**Break-even** (estimates; the replay measures `Cp`):
- `Cp` = per-run cost, about 50k sonnet tokens.
- `Cf` = cost of the fix round a refutation saves: task-master, an implementer attempt and a full sonnet or
  opus review, about 400k tokens.
- `E` = eligible fraction of reviews, about 4%.
- `r` = fraction of eligible FAILs the pass prevents.
- `Cs` = standing cost per review, about 450 tokens.

The pass pays off when `E·r·Cf > Cs + E·Cp`. With these figures that is `r > ~15%`. The **standing cost
alone is not worth carrying if `E < Cs / (r·Cf − Cp)`**. At `r = 20%` that threshold is about 1.5% of
reviews, against an observed floor of about 4%.

**Kill or re-scope criterion** (made computable by D3): after 20 eligible runs, `r` = prevented FAILs over
eligible runs. Prevented FAILs are `.pass` markers carrying `NOTE[code]: refuted:`. Eligible runs are those
plus FAIL blocks whose last line starts `refutation: confirmed=`. If `r < 10%`, open a follow-up to retire or
re-scope the pass. rfp-u4's milestone-auditor bullet prints this ratio as part of its sample.

**Deliberately not skipped:**
- A single defect: one refutation turns FAIL into PASS, the highest-value case.
- Opus-tier units: the most expensive fix rounds, closest to ladder exhaustion.
- `reviewGating.mode: off`: in-session advisory FAILs still drive the ladder count and fix rounds. With no
  record, the `refutation:` line goes in the verdict text.

### Prior FAIL history and audit sweep (dispositions)

- 21 of the 174 `.fail` records name `agents/reviewer.md`, and 27 cite version-stamp/P3 defects. Every unit
  that touches `agents/` or `templates/` bumps the version and adds its CHANGELOG entry **in each commit**
  (criterion `version-stamp-check.sh` over the unit's range). This includes fix rounds.
- `bin/marker-audit.sh --notes`: blf-6 `NOTE[spec]` says to write "FAIL-block count", never "FAIL count"
  (honoured). Untagged 124 is unaffected. The others are historical.
- No re-scoped unit has a prior `.fail`.
- rfp-u2b (2026-10-27):
  - rfp-u1 and rfp-u2 hold PASS markers and no `.fail`.
  - Every non-blocking note in `rfp-u2.pass` has a disposition in the Step 2b table, including the
    dry-run `worktree prune`.
  - `marker-audit.sh --notes` finds no note on `eval/refutation-replay`.
  - On `tests/validate.sh` the sweep finds only historical notes. The relevant two are vsp-1 (the lane
    runner) and vtmp-1 (the 600 s cap); criterion 9 handles both with `ANTISLOP_VALIDATE_LANES=4` and the
    600000 ms timeout.
  - The sweep is best-effort: `.claude/reviewed/` is per-clone.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Partial
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Partial

- 2026-10-27 Functional scope & success criteria: Q Are the orphan check and the Integrity rubric in
  scope? → A (self-resolved): no, both are named follow-ups.
- 2026-10-27 Domain entities / data model: Q Which defects are refutable, and what are the per-defect
  states? → A (self-resolved): only judgment defects. The states are REFUTED, CONFIRMED and UNCERTAIN,
  with an artifact required for the first two. A missing, malformed or non-reproducing answer means the
  defect "stands as found".
- 2026-10-27 User interaction flow: Q Who dispatches the refuter? → A (self-resolved): the reviewer, as a
  nested foreground unnamed `explorer`. The orchestrator flow is unchanged.
- 2026-10-27 Edge cases / failure handling: Q Where do UNCERTAIN defects go in a mixed FAIL? → A: they stay
  in the FAIL list, prefixed `[unconfirmed]` (option c, per user, 2026-10-27).
- 2026-10-27 Non-functional attributes (perf, security, scale): Q On what model does the explorer run? →
  A: `sonnet` (per user, 2026-10-27).
- 2026-10-27 Completion / acceptance signals: Q Is FAIL-side telemetry added now? → A: yes. Every FAIL
  block ends with a `refutation:` line (per user, 2026-10-27).
- 2026-10-27 Completion / acceptance signals: Q How is the safety of a refutation measured? → A
  (self-resolved, from the critic's BLOCKER): Gate G replay with a recall threshold, plus the
  milestone-auditor sample.
- 2026-10-27 External dependencies & integrations: Q Can the replay run without an LLM? → A
  (self-resolved): no. It is headless `claude -p` at the human's cost. The builder, scorer and dry-run are
  deterministic and tested.
- 2026-10-27 Technical constraints & tradeoffs: Q Is 5 defects within the explorer's 10 turns, and can a
  per-spawn budget be passed? → A (self-resolved): no per-spawn parameter exists. The cap is 3, and the
  replay enforces the turn limit.
- 2026-10-27 Edge cases / failure handling: Q What happens on the INSUFFICIENT-CONTEXT resume? → A
  (self-resolved, critic): FAIL a defect the reviewer reproduces itself; a non-reproduced one becomes a
  `NOTE[code]: unconfirmed:` line.
- 2026-10-27 Terminology consistency: Q Does "refutation" collide with existing reviewer prose? → A
  (self-resolved): yes, at :46 and :137-138. :138 is reworded, :46 is kept and acknowledged in the
  glossary, and `refuter` stays avoided.
- 2026-10-27 Terminology consistency: Q How does a fix round name an `[unconfirmed]` defect that does not
  reproduce, when the FAIL block numbers no defect? → A (self-resolved, contract spawn):
  `not-reproduced: <the defect line, without the prefix>`; `D<n>` exists only in the brief.
- 2026-10-27 Technical constraints & tradeoffs: Q Can the milestone auditor's counts be one command? → A
  (self-resolved, contract spawn): no. `reviewed-path-gate.sh` refuses a `$(…)` substitution around the
  reviewed-markers path, so the auditor runs two plain counts and adds them; the fixture test runs exactly
  those commands.
- 2026-10-27 Domain entities / data model: Q Who numbers the ADR, given that the scribe-contract shape needs
  a number? → A (self-resolved, contract spawn): the contract names 0043; the scribe takes the next free
  number if it is gone, and criterion 7 checks "highest before the unit + 1" instead of a literal.
- 2026-10-27 Completion / acceptance signals: Q How do rfp-u5's criteria avoid passing on word presence? → A
  (self-resolved, contract spawn): each reads its claim's value from the live source (reviewer, protocol,
  auditor, unit commits) and fails, printing `missing:` or `no-source`, when the two disagree.
- 2026-10-27 Functional scope & success criteria: Q Are rfp-u2's PASS-note findings on the Gate G measurement
  fixed before the paid replay, and what stays fixed? → A: yes, as unit rfp-u2b before Gate G. Thresholds,
  labels and the corpus stay unchanged, and no paid `claude -p` run happens (per user, 2026-10-27).
- 2026-10-27 Domain entities / data model: Q What does `score.py` count, and how are repeated, unknown and
  absent ids treated? → A (self-resolved): it scores distinct ids. Ids not in `labels.tsv` are `foreign`
  and ignored. An identical repeat counts once, and a repeat that differs in answer or artifact is a
  `dup-conflict`, which fails the gate. Any id labelled real or bogus with no row is `missing`, which makes
  the result `insufficient`. The user asked for real ids; bogus ids are added so that dropping their
  `NONE` rows cannot shrink the unanswered denominator.
- 2026-10-27 Edge cases / failure handling: Q What does `run.sh` write for a group whose setup fails? → A:
  one `NONE` row per defect, tagged `setup: clone|brief` (per user, 2026-10-27).
- 2026-10-27 External dependencies & integrations: Q How is answer leakage prevented, and how is that tested
  without a paid run? → A (self-resolved, rfp-u2b contract spawn):
  - a fresh repository per group, fetched by commit id up to the reviewed commit (spec-master tested this
    on git 2.43 at 0.5 s per group);
  - `--setting-sources local` and `--strict-mcp-config`;
  - `guard.py` as a PreToolUse hook;
  - a fake `claude` on `PATH` in the fixture suite.

  The one claim no offline test reaches, that a `--settings` hook fires in `-p` mode, gets the `run.sh`
  exit-3 tripwire.
- 2026-10-27 Non-functional attributes (perf, security, scale): Q Do `--allowedTools` rules alone restrict
  the replay to `git show`, `git diff` and `git log`? → A (self-resolved, Claude Code docs via
  `claude-code-guide`): no. Read-only commands such as `cat` run without a prompt in every mode, a bare
  `Read` rule reaches any absolute path, and allow rules merge across setting scopes. The user's
  `settings.local.json` allows `Bash(python3 -c ' *)`. A blocking PreToolUse hook overrides allow rules, so
  the guard is the enforcement.
- 2026-10-27 Technical constraints & tradeoffs: Q Fix the `--labels` diffstat in the code or in the
  docstring? → A (self-resolved): the docstring, which is cheaper and leaves the labelling output alone.
  The 300-character cut is stated in the docstring and the README.
- 2026-10-27 Completion / acceptance signals: Q How do rfp-u2b's criteria avoid the precheck's two-line
  literal quirk? → A (self-resolved): every expected stdout is one line (harness note under Step 2b).

## Risks / dependencies

- **R1: wrong refutations.** See Safety: Gate G before enabling, the milestone sample after, and recovery
  downstream.
- **R2: replay fidelity.** The replay runs headless `claude -p` with read-only tools, not the `explorer`
  persona body, and without its graph MCP. It reproduces the brief exactly (D8) but not the persona prose.
  This is stated in the replay README. The persona adds instructions; it removes none of the brief's rules.
  Since rfp-u2b, each run also sees only a clone holding the history up to the reviewed commit. It loads
  no user, project or plugin settings, and its Bash is limited to `git show`, `git diff` and `git log`.
  The live explorer has the whole repository, so the replay is stricter than live use in this respect.
- **R3: proxy labels.** "Fixed and later passed" can label a bogus defect "real" if the implementer complied
  with a non-defect. The human confirmation in `labels.tsv` exists for this. That bias would only make the
  gate stricter, because a bogus defect counted as real and then refuted counts as a miss.
- **R4: audit noise.** One `grant-denied` line per pass. Out of scope.
- **R5: ordering.** As in "Units and order": rfp-u1, then rfp-u2 (its `run.sh` needs the brief script), then
  rfp-u2b (it hardens rfp-u2's files), then Gate G (human), then rfp-u3, then rfp-u4, then rfp-u5 (after both rfp-u3 and rfp-u4). The branch has other
  units in flight, so each bump is +1 on the version current at dispatch.
- **R8: gate-safe commands.** The milestone auditor's sample commands and the range criteria must pass
  `reviewed-path-gate.sh` and `harness-integrity-gate.sh` as written. spec-master probed them: plain `grep -r`
  piped to `sort` or `wc -l` passes; a `$(…)` substitution around the reviewed-markers path is refused, and so
  is any Bash text naming the persona config file. rfp-u4 keeps two plain counts and matches `^\.claude/`.
- **R9: the `not-reproduced:` report has no consumer yet.** The reviewer of the fix round re-judges each
  defect as it does today; a defect it still reproduces FAILs normally. No orchestrator change is planned
  (Out of scope 5).
- **R6: parity seams.** rfp-u3 merges the protocol edit, its four ports, the reviewer source and its
  regenerated mirrors into one gate (spec-master memory: never slice across a parity test).
- **R7: rfp-u3 is large** (about 14 files). It stays one unit by necessity (R6). If the contract-score guard
  demotes it, the ladder handles that.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied. Artifacts are required and re-checked. The replay gate measures
  before enabling. spec-master ran the base-rate classifier, the route-gate mutation and the pin phrases on
  scratch copies.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied. The brief is a script (D8), the
  builder and scorer are deterministic, and the mirrors come from `--update` only.
- P3 "Version-stamp discipline": satisfied. rfp-u3 and rfp-u4 touch `agents/` and `templates/` and bump in
  each commit. rfp-u1 bumps too: it touches no stamped path, but `--update` installs a new helper.
- P5 "`tests/validate.sh` is the merge gate": satisfied. Every lead unit has a validate.sh criterion, and
  rfp-u1, rfp-u2 and rfp-u2b register their new suites. rfp-u2b touches no stamped path and needs no
  bump.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied. `explorer` is a core persona, and a spawn
  failure degrades to `skipped=no-subagent`.

## Step 1 (rfp-u1, lead-programmer): `bin/refutation-brief.sh`

Affected files:
- `bin/refutation-brief.sh`
- `tests/refutation-brief.test.sh`
- `bin/cli.js` (`BIN_HELPER_FILES`)
- `tests/bin-helpers-scaffold.test.sh`
- `tests/validate.sh`
- the version bump files
- generated `.claude/bin/refutation-brief.sh`

Criteria: see the contract (fixture suite, scaffold, cmp, scope, validate).

## Step 2 (rfp-u2, lead-programmer): the replay corpus, runner and scorer

Affected files:
- `eval/refutation-replay/{README.md,build-corpus.py,run.sh,score.py,corpus.jsonl,labels.tsv}`
- `tests/refutation-replay.test.sh`
- `tests/validate.sh`

No stamped path. Criteria: the fixture suite, `--check` on the committed corpus, the vacuity guard on an
empty report, `--dry-run` flags, scope, validate.

## Step 2b (rfp-u2b, lead-programmer, after rfp-u2): Gate G hardening

rfp-u2 reached PASS at 6c8b4b1a. Its reviewer's non-blocking notes show that the Gate G measurement could be
weak or gamed. The user chose to fix that before the paid replay (G2).

| finding (rfp-u2 PASS note) | fix | case in the new suite |
|---|---|---|
| `score.py:35` counts rows, so one real id repeated 30 times passes | score distinct ids; ignore `foreign` ids; a conflicting repeat fails the gate; every id labelled real or bogus must have a row (otherwise `insufficient`) | a, b, c, e, f |
| the worktree shares refs, and Read or grep reach the main checkout's FAIL records and `labels.tsv` | a fresh repository fetched up to the reviewed commit only; `--setting-sources local`, `--strict-mcp-config`, `--permission-mode dontAsk`, `--tools Read,Grep,Glob,Bash`; `guard.py` as a PreToolUse hook refuses paths outside the clone; exit 3 if the hook is not wired | g, h, i, l, m |
| `run.sh:30` `Bash(git *)` is not read-only | pre-approve only `git show`, `git diff` and `git log`, and the guard refuses every other Bash command (`git -c`, aliases, `--output`, `--no-index`, shell operators) | g, j, n, o |
| `run.sh:56,58` drop a group whose worktree or brief fails | one `NONE` row per defect, tagged `setup` | k |
| `build-corpus.py:10` promises a diffstat; the 300-character cut at `:87` is undocumented | fix the docstring (cheaper than changing the labelling output); state the cut in the docstring and the README | p |
| `run.sh:45` prunes worktrees on `--dry-run` too | gone with the worktree: the EXIT trap only removes the scratch directory | n |

Affected files:
- `eval/refutation-replay/{guard.py (new),score.py,run.sh,build-corpus.py,README.md}`
- `tests/refutation-replay-isolation.test.sh` (new)
- `tests/validate.sh` (registration)

No stamped path, so no version bump. `corpus.jsonl` and `labels.tsv` are untouched: no builder logic changes,
and the labels stay `unknown` for G1. The thresholds are unchanged, and no paid run happens (the suite fakes
`claude`).

Criteria:
- both suites pass;
- the new suite fails exactly 14 named cases against rfp-u2's files (red at baseline);
- the corpus and labels are unchanged and there is no report;
- the scorer line on the absent report;
- the dry-run flags on the committed corpus;
- a per-commit scope check;
- file modes;
- `validate.sh` with `ANTISLOP_VALIDATE_LANES=4`.

Every criterion has a single-line expected stdout (see the harness note below).

**Harness note (not a unit).** `review-precheck.sh` `run_one` compares a criterion's whole stdout with one
backtick literal. A two-line expected stdout written as `` `A` then `B` `` can never match: rfp-u2 criterion 3
hit this, and its reviewer overrode the false fail by hand. Until the precheck learns two-line literals,
contract criteria should print one line, or the reviewer must override.

## Gate G (human, between Step 2b and Step 3; not a dispatchable unit)

| step | what | who | how to check it |
|---|---|---|---|
| G1 | confirm or reject each of the 41 proxy labels in `eval/refutation-replay/labels.tsv`, reading the `--labels` checklist; commit | the human operator (an agent labelling would grade its own kind) | `python3 eval/refutation-replay/build-corpus.py --check` prints `unlabeled=0` |
| G2 | `bash eval/refutation-replay/run.sh`: 24 headless sonnet runs at 958f557e (one per group), each capped by `--max-budget-usd 1`; commit `report.jsonl` | the human operator, or the orchestrator on the human's explicit instruction | the report exists, one row per corpus defect |
| G3 | `python3 eval/refutation-replay/score.py --gate eval/refutation-replay/report.jsonl` | anyone | first line `replay-gate: pass …`, exit 0. On `fail` or `insufficient`, do not dispatch rfp-u3; return the report to spec-master |

## Step 3 (rfp-u3, lead-programmer, after Gate G): the refutation pass and the FAIL-record format

Affected files:
- `agents/reviewer.md`
- `templates/persona-protocol.md`
- the four adapter ports above
- `tests/persona-prose-pins.test.sh`
- `tests/reviewer-route-gate-caller.test.sh`
- `tests/adapter-fail-tier-pin.test.js`
- `tests/fail-record-refutation.test.sh` (new)
- `tests/validate.sh`
- the version bump files
- the regenerated `.claude/` mirrors

Criteria include `score.py --gate`.

## Step 4 (rfp-u4, lead-programmer, after rfp-u3): downstream readers

Affected files:
- `agents/task-master.md`: the fix-contract bullet. A defect prefixed `[unconfirmed]` gets a reproduce-first
  `command:` edit and a criterion that holds whether it was fixed or never reproduced; if it does not
  reproduce, the lead-programmer makes no edit for it and reports
  `not-reproduced: <the defect line, without the prefix>`. (Revision 2 said `D<n>`; FAIL defect lines carry
  no D-number, which exists only in the brief.) The `refutation:` line is never a defect.
- `agents/milestone-auditor.md`: a refutation sample of up to 3 `refuted:` notes per milestone, plus the
  counts behind the `r` ratio from the Cost model, printed as
  `refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>`, and the kill-criterion finding.
- `tests/refutation-sample.test.sh` (new): the auditor's three grep commands on a fixture with decoys, and a
  check that the persona and its mirror ship them verbatim.
- `tests/persona-prose-pins.test.sh`, `tests/validate.sh`
- the version bump files and the mirrors

No hand-synced port carries task-master or milestone-auditor. Criteria: prose pins, the fixture test,
per-file diff budgets, a per-commit scope check, a per-commit version-stamp check, a clean tree, validate.

## Step 5 (rfp-u5, scribe, after rfp-u3 and rfp-u4): glossary and ADR

Affected files:
- `CONTEXT.md`: new entries **refutation pass** (it acknowledges the :46 "Refute" sense), **judgment
  defect** and **refutation outcome**; the **FAIL block** entry updated for the last-line `refutation:` and
  the `[unconfirmed]` prefix.
- `docs/harness-glossary.md`: a **refutation line** entry with its grammar.
- `docs/adr/0043-refutation-pass-inside-reviewer-turn.md`. The scribe-contract shape needs a number, so the
  contract names 0043 (next free at 3bd60f56); the scribe takes the next free number if 0043 is gone by
  dispatch, and criterion 7 computes the expected number from the tree before the unit's first commit.

Criteria check each claim against its live source: the cap and the model from `agents/reviewer.md`, the
grammar from `templates/persona-protocol.md`, the sample size from `agents/milestone-auditor.md`, and the
ADR's "no hook, marker, ladder or orchestrator change" from the commits of rfp-u1 to rfp-u4.

## Out of scope (named follow-ups)

1. The orphan check, as a `review-precheck.sh` fix-round extension.
2. An Integrity rubric item (hardcoded expected values, disabled tests, bypassed validation).
3. Exempting read-only identities from the stop gate's `grant-denied` line (R4).
4. The refutation pass in the codex and cursor ports, which write `skipped=no-subagent` only.
5. Any change to the orchestrator body, the route or stop gates, `ladder-tier.sh`, `fail-count.sh` or
   `escalation-card.sh`.
6. A config switch for the pass. Gate G gates the shipping of the instructions instead.

## Open Questions

1. **Replay corpus size.** The measured pool at 958f557e is 57 proxy-real candidates (judgment defect, cited
   file present at the reviewed commit, later fixed, unit later passed). It is smaller than spec-master's
   first estimate of 118, which ignored the reviewed-commit and PASS checks.
   - *(Recommended, applied)* (a) `--size 40`: 41 rows in 24 groups, so 24 sonnet runs, and at least 30
     must be confirmed real. At most 1 miss gives a raw-miss upper bound of about 17%.
   - (b) all 57 candidates (`--size 57`): about 33 runs. Raise `MIN_REAL` to 45; at most 1 miss then
     bounds the raw miss rate at about 11%.
   - (c) (a) now, then re-run (b) once 20 more FAIL records exist. *(from CHK18)*
2. **If Gate G fails.**
   - *(Recommended)* (a) Stop and return the report to spec-master for a brief revision (rfp-u1 debug spec),
     then re-run the replay.
   - (b) Ship anyway with a sample of every refutation by the milestone auditor instead of 3. *(from CHK19)*

## Self-check
- CHK1: Is the verdict defined for every combination of standing, CONFIRMED and UNCERTAIN defects, and for
  a skipped pass? — PASS (both Context tables)
- CHK2: Is behaviour defined for a truncated explorer, a missing answer line, and a non-reproducing
  artifact? — PASS ("stands as found")
- CHK3: Does the plan define what the FAIL block's last line says in each case, including skipped? — PASS
  (verdict table, last column)
- CHK4: Do Step 3 and the readers table agree that `refutation:` is the last line and `[unconfirmed]` a
  prefix? — PASS
- CHK5: Is the `refutation:` vocabulary checked against unit-outcomes.js's class substrings by a runnable
  check, not only by reading? — FAIL (missing) — revised in place (rfp-u3 fixture test case c reads the live
  `CLASSES` table)
- CHK6: Is the replay gate non-vacuous on an empty or small report? — FAIL (missing) — revised in place
  (`score.py` exits 2 with `insufficient` below 30 confirmed-real; rfp-u2 criterion 3)
- CHK7: Is it stated what is manual in Gate G, and who does it? — PASS
- CHK8: Is the PASS-after-refutation state stated (marker, stamps, flags)? — PASS
- CHK9: Does the payload delete the "may not argue away" sentence, and is that checked? — PASS (rfp-u3 pin
  `hasnot`)
- CHK10: Is the turn budget justified, with an enforced check? — PASS (cap 3; the replay fails on more than
  10 turns)
- CHK11: Does the reviewer.md "PASS is one line" rule conflict with the `refuted:` notes? — PASS (notes go
  in the marker; the section is advisory)
- CHK12: Is the :137-138 word collision resolved in a step? — PASS (rfp-u3 edit 3)
- CHK13: Are all four hand-synced ports in rfp-u3's Affected files, with a check? — PASS
  (adapter-fail-tier-pin extended)
- CHK14: Is P3 per-commit discipline stated for every unit touching stamped paths, fix rounds included? —
  PASS (contracts' commit notes, plus version-stamp criteria)
- CHK15: Could any range criterion pass on an empty range? — PASS (each prints `no-commits` and exits 1)
- CHK16: Does each Goal clause map to a criterion?
  - Sonnet: rfp-u3 pin 3.
  - Cap 3: rfp-u1 test case b.
  - Telemetry line: rfp-u3 fixture test.
  - `[unconfirmed]`: rfp-u3 pins and fixture test.
  - Gate: rfp-u3 `score.py`.
  - Milestone sample: rfp-u4 criteria 1 and 2 (pins, and the fixture test of the shipped commands).
  - No marker or stamp: the route-gate case.

  — FAIL (missing) at the revision-2 checkpoint, when rfp-u4's criteria were not yet written — revised in
  place (the rfp-u4 contract now carries them). PASS on re-check.
- CHK17: Does criterion rfp-u3/`validate.sh` still fail under its own `mutation:` line, given that gh317,
  gh320, gh346-2, gh409, gh413, human-review-cleanup-1, mw-step1-3, rollout-map-1 and spec2-unitA/B
  recorded class vacuous or host? — PASS (the mutation breaks a registered suite)
- CHK18: Is the corpus size settled against cost and confidence? — FAIL (ambiguous) — converted to Open
  Question 1
- CHK19: Is the course of action defined when Gate G fails? — FAIL (missing) — converted to Open Question 2
- CHK20: Does criterion rfp-u3/reviewer.md-numstat still fail under its mutation, given that gh307,
  gh348-3, gh385-2, memdirt-1 and mw-step1-3 recorded class vacuous or host? — PASS
- CHK21: Does criterion rfp-u3/version-stamp still fail under its mutation, given that
  ci-fetch-depth-cleanup and item17-4-name-p3-offenders recorded class host? — PASS
- CHK22: Do the units table, R5, the Step headings and each contract's Retrieval agree on every dependency
  (u1, u2, Gate G, u3, u4, u5)? — FAIL (conflicting): Step 5 said "after rfp-u4" while R5 listed u3, u4, u5
  without edges — revised in place ("Units and order"; Step 5 now reads "after rfp-u3 and rfp-u4")
- CHK23: Is P3 checked per commit, fix rounds included, for rfp-u4, and only over this unit's commits? —
  PASS (rfp-u4 criterion 5 runs `version-stamp-check.sh` on each `(rfp-u4): ` commit; its mutation, an
  unbumped fix commit, prints `bad=1`)
- CHK24: Can any rfp-u4 or rfp-u5 range criterion pass with no unit commit? — PASS (each prints
  `no-commits` and exits 1; rfp-u5 criterion 9 needs commits from all four earlier units)
- CHK25: Are the auditor's commands defined so they run under the gates? — FAIL (missing) at drafting: a
  single substituted command was refused — revised in place (two plain counts; R8)
- CHK26: Does each rfp-u5 claim criterion fail when the glossary disagrees with its source, not only when a
  word is absent? — PASS (spec-master mutated both sides on a scratch copy: entry and source)
- CHK27: Does criterion rfp-u4/validate.sh still fail under its own `mutation:` line, given the units
  recorded class vacuous or host in CHK17? — PASS (the mutation breaks a newly registered suite)
- CHK28: Does each non-blocking note in `rfp-u2.pass` map to an rfp-u2b fix, a suite case and a criterion?
  — PASS (Step 2b table; contract criteria 1, 3 to 7)
- CHK29: Do the units table, R5, the Step 2b heading, the Gate G heading and the rfp-u2b contract's
  Retrieval agree that rfp-u2b sits after rfp-u2 and before Gate G? — PASS
- CHK30: Can any rfp-u2b range criterion pass with no `(rfp-u2b)` commit? — PASS (criteria 3, 4 and 7 print
  `no-commits` and exit 1; spec-master ran them on the real tree)
- CHK31: Is the one assumption the offline suite cannot test (a `--settings` hook fires in `-p` mode)
  backed by a mechanical check? — FAIL (missing) at drafting — revised in place (the `run.sh` exit-3
  tripwire, suite case m, mutation (vii) of criterion 1)
- CHK32: Does criterion rfp-u2b/validate.sh still fail under its own `mutation:` line, given the units
  recorded class vacuous or host in CHK17? — PASS (the mutation breaks the newly registered suite; the
  4-lane run exited 0 in scratch in about 250 s)
- CHK33: Is every rfp-u2b expected stdout one line, given the precheck's two-line literal quirk? — PASS
  (spec-master parsed the contract with the precheck's own awk)
- CHK34: Does rfp-u3 criterion 8 (`cut -d" " -f1-2` of the scorer line) still read the verdict after
  rfp-u2b appends fields? — PASS (rfp-u2b criterion 5)

Prose-mode `ubiquitous-language` (advisory):
- Lens 1: "refutation" means the change at `agents/reviewer.md:46,137-138` and the reviewer's own findings
  here. Resolved by rewording :138 and by a glossary acknowledgement.
- Lens 2: "refuter" and "verifier" are avoided. "FAIL-block count" is used per its entry.
- Lens 3: new terms are judgment defect, refutation pass, refutation outcome, refutation line and Gate G
  (Gate G is plan-local, not a glossary term).
- rfp-u2b (advisory):
  - `CONTEXT.md` "Contract-score guard" and "guard demotion" use "guard" for another mechanism, so the
    plan and contract always say `guard.py` or "the guard hook", never a bare "guard".
  - "Replay clone" is distinct from "per-clone review state".
  - The scorer fields `foreign`, `dup-conflict` and `missing` are output fields, not domain terms; no
    glossary entry is proposed.

## Scribe update hint

rfp-u5 is the scribe's unit ([contract](2026-10-27-refutation-pass/contracts/rfp-u5.md)), after rfp-u3 and
rfp-u4 PASS. Quote rfp-u3's and rfp-u4's PASS lines in its dispatch.
