# Dream-RSI and the spec-master / task-master personas

Research note, 2026-10-06. Author: `researcher` persona. Status: proposals
only — nothing here is implemented, and no persona file was edited.

## 1. Paper identity

"Dream IRS" (voice dictation) resolves to **Dream-RSI: Recursive
Self-Improvement through Evolving Worlds**, arXiv **2609.14858** (v1, posted
2026-09-14, cs.CL). Authors: Tong Zheng, Xidong Wu, Zheng Zhang, Zhankui He,
Chaoyi Zhang, Benjamin Coleman, Ruoqiao Wei, Di Bai, Haolin Liu, Rui Liu, Xue
Wang, Yue Zhuan, Wang-Cheng Kang, Renkai Xiang, Heng Huang, Xinwu Cheng,
Yunsong Guo. Code: github.com/zhengkid/Dream-RSI; site: dream-rsi.com.

Confidence: high. "RSI" → "IRS" is a one-letter transposition, "Dream" is
literally in the title, and it is the only 2026 Google/DeepMind-affiliated
paper with both tokens. Affiliation (Google, Google DeepMind, UMD, UVA) is
web-reported (the-decoder.com, dev.to, others), not read off the arXiv
metadata — the MCP abstract did not carry affiliations. The one adjacent
candidate considered and rejected: *RRSI: Regularized Recursive
Self-Improvement of Agent Harnesses* (arXiv 2609.24972, 2026-09-21, Pfister /
Chen-Yu Lee group) — no "Dream", different group, different mechanism.

Coverage: I read Abstract, Introduction, Motivation, Method (§3), Experiments
(§4.1–4.3), Further Analysis (§5), Related Work (§6), Conclusion (§7) in full
via the arXiv HTML extraction. Not read: Appendix A (task definitions),
Appendix B (prompts), Appendix C (discovered solver), reference list.

## 2. Paper summary

**Problem.** Agent-driven discovery loops (AlphaEvolve-style) run thousands
of propose→evaluate cycles. What decides where to branch, how many attempts
to run in parallel, and when to stop is an *exploration policy*. Fixed,
hand-written policies cannot adapt as the search grows; optimising the policy
online is prohibitive because a policy's quality is only visible after a whole
long-horizon rollout (delayed, expensive meta-feedback) and the space of
policies is vast.

**Core insight.** A completed discovery run already *is* a simulator. Each
node of a discovery tree stores the attempt's workspace snapshot, artifact,
evaluator diagnostics and score. An alternative policy can be run *against
that recorded tree* — choosing a different subset of branches, a different
order, different parallel batching, an earlier stop — and every outcome it
"generates" is just read back, at zero execution cost. History becomes an
off-policy replay simulator ("world"); evaluating a policy becomes
"dreaming".

**Mechanism (three-stage loop).**
1. *Online explore.* Policy π_t drives a **fixed** coding agent for ≤K₁
   decision rounds with W parallel workers. Action = a batch of eligible
   nodes (root or leaves) to expand. The evaluator (also fixed) scores each
   child. Tree T_t is appended to history H_t.
2. *Construct replay simulator.* H_t is the pool of worlds.
3. *Dreaming-based policy improvement.* A fixed LLM "policy-development
   agent" produces M policy versions π_t⁰..π_t^{M−1} (π_t⁰ = incumbent). Each
   is replayed over every recorded tree; replay reveals recorded children
   deterministically and never generates new outcomes. Score per
   (policy, world) — eq. (1):
   `V = max_score_revealed − β₁·(attempts revealed) + β₂·(attempts per round)`
   i.e. quality minus cost plus a parallelism bonus. The next online policy is
   the argmax of mean replay score over all worlds. Because the incumbent is
   in the candidate set, the chosen policy is **never worse than the incumbent
   on the fixed history** (a monotone non-regression guarantee on H_t only).

Only the exploration-policy *code* changes; model weights, evaluator and
execution interfaces stay fixed.

**Results (all vs. the same first-round policy held fixed — "Recursive Fixed
Exploration" — plus domain baselines).**
- Lasso regularisation path (algorithm engineering): with Gemini-3.1-Pro,
  317 discovery-agent calls vs 550 fixed, better held-out runtime (2931 ms vs
  3587 ms avg across six datasets); SimpleTES used 51,200 generations. Beats
  sklearn and glmnet on all six held-out sets. Gemini-3.7-Flash: 1879 vs 3200
  calls.
- Maths optimisation: Sum-Difference 1.145427 (best listed), Circle Packing
  2.635983 (ties best), Autocorrelation 1.456375 (competitive) under <1k
  generations.
- KernelBench: VGG16 / LayerNorm reach comparable speed with 2.43× / 1.79×
  fewer generations; ConvDiv / ConvMax 2.09× / 1.44× higher performance at
  equal budget.
- §5.1 (the finding most relevant here): distilling history into
  **prompt-level directional guidance** ("insights injected into the prompt")
  *underperformed* the unguided baseline for both fixed and Dream-RSI
  exploration. Replay-as-simulator beat history-as-guidance. The authors'
  reading: strong semantic priors over-constrain parallel exploration.
- §5.2: the learned policy cut attempts per round from 110 to 50 while scores
  rose, then ramped effort back up when progress plateaued.

**Stated limitations.** The paper has no section titled Limitations (text
search for "limitation": zero hits). The following are *my* inferences from
the method, not the authors' statements:
- Replay only covers realised branches ("no outcomes beyond T_i are
  generated"; root children are revealed in creation order). Genuinely novel
  directions cannot be scored offline — the simulator is biased toward the
  incumbent's past choices.
- Sim-to-real gap: online transitions are stochastic, replay is
  deterministic. The non-regression guarantee holds only on H_t.
- β₁, β₂ are fixed hand-set coefficients; sensitivity not reported in the
  sections read.
- Single-run results on 8 tasks; the controlled baseline is the authors' own
  fixed-policy system.
- The policy-development agent is itself an LLM reading replay traces; its
  revisions are selected on the same history they were tuned on
  (overfitting risk; not discussed in the sections read).

## 3. How the project maps onto the paper

| Dream-RSI | AntiSlop |
|---|---|
| Fixed discovery (coding) agent | `lead-programmer` |
| Fixed evaluator + diagnostics | `reviewer` (PASS/FAIL verdict + verbatim defect list) |
| Exploration policy (branch / batch / stop) | the orchestration layer: `spec-master` decomposition + `task-master` slicing, ordering, model tag, dispatch contract (+ orchestrator routing) |
| Discovery-tree node | one unit attempt: `.fail` block(s) → fix commit(s) → `.pass` marker |
| Replay world pool H_t | `.claude/reviewed/*.{pass,fail}` (~400 PASS, ~100+ FAIL records, gitignored, per-clone), 108 `docs/plans/*.md` with Clarifications scorecards and itemised Self-checks, `.claude/{review,dispatch}-audit.log`, `.claude/orchestrator-rulings.log`, `CHANGELOG.md`, git |
| Policy-development agent | nothing today — persona rules change by human-authored spec units |

Two structural differences shape every proposal below:

1. **The project's "policy" is prose, not code.** There is no executable
   object to mutate and replay. The honest analogue is: *evaluate a candidate
   rule change (a slicing heuristic, a tagging rule, a criterion-writing rule)
   against recorded unit outcomes before adopting it* — the paper's offline
   evaluation step — rather than letting a persona rewrite itself.
2. **The project already uses history as prompt guidance** — `.fail` screens,
   "include prior defect history in the dispatch prompt", `memory: project`
   notes. §5.1 says that is the *weaker* use of history. The paper's lesson
   for this project is therefore not "inject more lessons into prompts" but
   "score candidate rules on recorded outcomes".

A hard prerequisite: the paper's simulator needs *structured* nodes (parent,
attempt, diagnostics, score, cost). The project's history is real but
scattered and partly per-clone. See P0.

## 4. Proposals

Legend: **[S]** well-supported by the paper's mechanism and by data the
project already records; **[?]** speculative — plausible analogy, thin data
or untested transfer. Effort is for a spec-master plan + units, not for this
note.

### P0 — Cross-cutting enabler: a replayable unit-outcome export [S]

- **Paper mechanism.** Stage 2, simulator construction: history must be a
  structured tree with per-node outcome, diagnostics and cost before anything
  can be replayed.
- **What changes.** No persona behaviour directly. A read-only `bin/`
  helper in the mould of `bin/marker-audit.sh` that joins, per unit id:
  originating plan + step → `Suggested model` tag → affected files → each
  FAIL block (timestamp, defect list, a coarse defect class) → final PASS
  commit → reviewer tier used → attempt count. Output a tracked artifact
  (e.g. `docs/audits/unit-outcomes.jsonl`) that `scribe` refreshes, since
  `.claude/reviewed/` is gitignored and "never authority".
- **Benefit.** Every proposal below needs it; without it each one degrades
  into the §5.1 "guidance" variant.
- **Risks / conflicts.** Design question whether outcome history should be
  tracked at all (the untracked status of `.claude/reviewed/` is deliberate).
  Audit logs are Set A (harness-integrity gate) — read-only joins are fine;
  nothing may write them. Defect-class labelling is a judgment call;
  start with 3–4 classes the reviewer already names verbatim ("vacuous
  criterion", "host-dependent precondition", "ambiguous range", "spec gap").
- **Effort.** Medium.

### spec-master

**S1 — Replay acceptance criteria against the FAIL corpus [S]**
- *Mechanism.* Offline evaluation of a candidate policy on recorded worlds.
- *Change.* The Self-check bullet already calls itself "unit tests for the
  spec" and fails items as missing / conflicting / ambiguous. Add a fourth
  source of CHK items: for each step's acceptance criteria, pull the recorded
  FAIL defect classes for units that touched the same files (via P0) and ask
  "would this criterion be satisfiable under the mutation the reviewer used
  to prove the prior criterion vacuous?" — e.g. `gh441.fail` records a fixture
  that "passes under ANY implementation", and the 2026-10-05 outcomeci plan's
  CHK12 records a host-dependent precondition the reviewer caught only
  post-FAIL. These become CHK items with a concrete recorded counterexample,
  not a generic reminder.
- *Benefit.* Turns the reviewer's recorded mutation proofs into regression
  tests for criterion-writing — the closest available analogue to replaying a
  policy on a stored tree. Directly targets the two most expensive recorded
  failure classes (vacuous test, host-dependent criterion).
- *Risks.* Per-clone corpus (spec-master is already told an empty sweep
  proves nothing). Must stay a *check*, not injected "always do X" prose
  (§5.1). Fits the Writer/Reviewer split: spec-master checks its own writing
  pre-approval, the reviewer still re-derives everything.
- *Effort.* Low once P0 exists.

**S2 — Incumbent-included non-regression for debug specs and convergence
follow-ups [S]**
- *Mechanism.* Selection over {incumbent, revisions} so the deployed policy is
  never worse on fixed history.
- *Change.* The "Debug spec on 2-FAIL-cap escalation" bullet rewrites the
  failed step. Add: the revised step's criteria must be shown to detect
  *every* defect block in that unit's `.fail` record (the record is
  append-only and holds both attempts), and the original criterion is kept
  alongside as the baseline being beaten. Same for `## Convergence
  follow-ups`.
- *Benefit.* Prevents a rewrite that fixes attempt-2's defect but regresses
  on attempt-1's; cheap, mechanical, already half-implied by `fail-triage`.
- *Risks.* None structural. Marginal if the two FAILs share one cause.
- *Effort.* Low.

**S4 — Calibrate the 9-category scorecard from outcomes [S for the
measurement, ? for the payoff]**
- *Mechanism.* The scorecard plus "impact × uncertainty" question ranking is
  spec-master's exploration policy: where to spend ≤4 questions per round.
  Dream-RSI scores such allocation policies on recorded trees.
- *Change.* A periodic audit (milestone-auditor or scribe, not spec-master
  per run) joins each plan's scorecard with its units' later FAIL defect
  classes: which categories were marked *Clear* in plans whose units then
  failed on a defect belonging to that category? The result is a per-category
  prior that re-orders questions *within* a round. The convergence rule and
  the scorecard format are untouched.
- *Benefit.* Replaces a flat prior with a measured one; the paper's §5.2
  shows adaptive allocation is where its gains came from.
- *Risks.* FAIL → category mapping is a judgment; 108 plans is a small pool;
  §5.1 warns against turning this into prescriptive guidance — keep it to
  ordering, never to adding mandatory questions.
- *Effort.* Medium.

**S3 — M candidate decompositions scored offline [?]**
- *Mechanism.* M policy versions per dreaming phase.
- *Change.* spec-master drafts 2–3 alternative step decompositions and ranks
  them with an eq.(1)-style objective: expected units × historical FAIL rate
  for that unit's file class, minus dispatch/review cost.
- *Why speculative.* No reliable per-class FAIL rates yet; prose plans aren't
  replayable; roughly M× opus cost inside a 40-turn one-shot persona.
  Revisit only after P0/S4 produce stable rates.

**S5 — Learned stopping for interrogation rounds [?]**
- *Mechanism.* The policy decides when to stop.
- *Change.* Measure whether plans with more Open-Questions rounds had fewer
  downstream FAILs; if the curve flattens, allow convergence at "remaining
  Partial categories explicitly deferred" earlier.
- *Why speculative.* Confounded by spec size; current rule is explicitly
  "convergence, not a count", and changing it is a design decision.

### task-master

**T2 — Offline-evaluate the model-tagging policy (keep the reactive rule,
measure its alternatives) [S as evaluation; ? as outcome]**
- *Mechanism.* Policy comparison by replay score with the incumbent included.
- *Change.* Nothing in task-master's live behaviour. Using P0, replay two or
  three alternative tagging rules against recorded units — the incumbent
  (gh-217 reactive: sonnet default, opus only after a recorded `.fail`), and
  e.g. "opus when any affected file matches `reviewer-tier.sh`'s
  `SENSITIVE_PATHS`". Score = FAIL rounds avoided × cost of a FAIL round
  (sonnet attempt + review + opus retry + review, all in the audit logs)
  minus extra opus cost on units that would have passed on sonnet anyway.
  Favourable result → a normal spec unit amending gh-217 and the Implementer-
  tier ratchet text; unfavourable → the reactive rule gains a measured
  justification.
- *Benefit.* The data exists today (`Suggested model` in issues, `.fail`
  timestamps, `reviewer-tier.sh`'s own sensitivity list); this is the single
  cheapest "dream" available.
- *Risks / conflicts.* The reactive-not-predictive rule was a deliberate
  decision; this proposal does **not** override it, it tests it. Note §5.1
  cuts both ways: a strong predictive prior may hurt, which is exactly why it
  should be scored rather than argued.
- *Effort.* Low (after P0).

**T1 — Replay slicing granularity (pathfinder rule 1) [S]**
- *Mechanism.* The policy's branching/batching decisions are what replay
  evaluates; eq.(1) penalises attempt count and rewards parallel batching.
- *Change.* P0 lets you group units by parent spec (`gh348-2..17`,
  `gh385-1..9`, `spec2-unitA..E`, `item03-1..3`) and compare per-unit FAIL
  rate and total review calls against unit count and unit size (changed
  lines/files from the PASS marker's commit). Output a calibration table
  task-master consults when pathfinder's "one unit, one decision" and
  to-tickets disagree — e.g. a measured size above which FAIL probability
  jumps.
- *Benefit.* Sizing is task-master's own territory (pathfinder wins over
  to-tickets), so this improves its judgment without touching spec substance.
- *Risks.* Heavily confounded (spec difficulty, model tier, era of the
  harness); small N. Must remain a table task-master reads, not a rule that
  overrides pathfinder.
- *Effort.* Medium.

**T3 — Sibling-unit pre-resolved context from recorded defects [S with a
caveat]**
- *Mechanism.* Replay reveals recorded children deterministically — the
  information is already there to be read, not regenerated.
- *Change.* Element 8 (`## Pre-resolved context`) gains one line per recorded
  FAIL on a *sibling* unit in the same spec that touched the same file:
  "unit X failed on <defect class> at <path:anchor>; the criterion for this
  unit must survive the mutation named there." The orchestrator already does
  this for the *same* unit; the extension is cross-unit within a spec.
- *Benefit.* Cheap; targets the "same bug recurs in a sibling file" pattern
  recorded in the rulings log (item18, bare-`\n` regex recurring in 5 sites).
- *Caveat.* This *is* history-as-guidance, which §5.1 found inferior for
  exploratory search. The difference argued here: the executor is a
  mechanical haiku/sonnet tier following a contract, where diversity is not
  the goal and precision is — so the §5.1 result may not transfer. Treat as a
  hypothesis to measure with P0, not settled.
- *Effort.* Low. Keep under `maxPromptBytes`.

**T4 — Parallel frontier from blocking edges [?]**
- *Mechanism.* Eq.(1)'s parallelism bonus.
- *Change.* From `Depends on / blocked by` edges and affected-files
  disjointness, emit a dispatch-round grouping ("round 1: A, B, D").
- *Conflicts.* Review is one-unit-at-a-time by invariant; rulings log line
  8 records a scribe/lead-programmer same-file collision. Any grouping must be
  file-disjoint and respect unit exclusivity for review. Low value until
  agent-teams parallel implementation is the norm.

**Not a task-master proposal — stopping decisions.** The paper's policy also
learns *when to stop*; in this project stop decisions belong to the
orchestrator (2-FAIL cap, "diminishing returns" rulings in
`orchestrator-rulings.log`). Replaying those rulings against later outcomes
is an orchestrator-side idea and out of scope here.

## 5. Ranked shortlist (value ÷ effort)

*Superseded by §8.7 after the 2026-10-06 haiku-implementer requirement; kept
for the record.*

1. **P0** replayable unit-outcome export — enabler; nothing else is honest
   without it.
2. **S1** criteria replay against recorded FAIL defect classes — highest
   direct payoff on the two costliest recorded failure modes.
3. **T2** offline evaluation of the model-tagging policy — cheapest real
   "dream"; data exists; resolves a standing design debate with numbers.
4. **S2** incumbent-included non-regression for debug specs — trivial to
   state, closes a real gap.
5. **S4** scorecard calibration — medium effort, needs defect→category
   labelling.
6. **T1** slicing-granularity replay — useful but confounded.
7. **T3** sibling-unit pre-resolved context — low effort, but it is the
   guidance variant the paper found weaker; measure before adopting.
8. **T4**, **S3**, **S5** — speculative; park.

## 6. Open questions for the user / orchestrator

1. Should unit outcomes become a *tracked* artifact (docs/audits) so the
   "simulator pool" survives clones, or is the per-clone, untracked status of
   `.claude/reviewed/` a constraint to keep?
2. Who runs replays — a periodic milestone-auditor pass, scribe, or a new
   read-only helper only? (spec-master per-run is too expensive at 40 turns.)
3. What is the project's β₁ — the cost of one dispatch + review round — and
   is PASS/FAIL too coarse a score (the paper uses continuous scores)?
4. Does §5.1 (guidance < replay) transfer from code-search exploration to
   prose interrogation and contract authoring? T3 is the test case.
5. Statistical power: the paper's trees hold 110–640 nodes per round; the
   project has ~500 heterogeneous units in total. Which proposals survive at
   that N?

## 8. Addendum (2026-10-06): "task-master does all the thinking; lead-programmer and scribe run on Haiku"

The user appended a requirement after §1–7 were written: task-master should
slice specs into chunks a lightweight model can implement, so that
`lead-programmer` and `scribe` can run on `haiku`. This section surfaces the
history that requirement runs into, applies the Dream-RSI replay mechanism to
it with the data the repo actually has, and re-ranks the proposals. It does
not argue the requirement away.

### 8.1 History: what the requirement reverses or conflicts with

Evidence read: `docs/adr/0010-implementer-haiku-default.md`,
`docs/adr/0026-writer-tier-reversed-to-sonnet.md`,
`docs/plans/2026-08-25-agent-throughput-performance-dampeners.md` (§B4 and
Unit D), `CONTEXT.md` entries **Writer tier**, **Implementer-tier ratchet**,
**Suggested model vocabulary**, **defaultImplementerModel**,
`docs/plans/2026-09-25-item06-model-routing-prose.md`,
`tests/writer-tier-consistency.test.js`, `bin/cli.js:338-351`,
`templates/persona-config.schema.json`, `.claude/persona-config.json`.

1. **ADR-0010 (2026-08-02) already did this once.** Implementer default
   `haiku`; task-master's pre-emptive tier prediction removed because it had
   reached "roughly 0% of units in practice" (no unit was ever tagged haiku
   when it was optional); judgment moved into the nine-element dispatch
   contract and the H4 hook (issue #209/#214). ADR-0010 §7 is literally the
   user's thesis: *"The judgment did not disappear; it moved from a per-unit
   tier guess into a per-dispatch completeness requirement a hook can check."*
2. **ADR-0026 (2026-08-25) reversed the default to `sonnet`, ratified by the
   repo owner.** Measured basis (plan §B4): 269 units; pre-ADR-0010 sonnet
   era 66 units / 11 FAIL = **16.7%**; haiku era 203 units / 66 FAIL =
   **32.5%**; haiku was 4.6% of spend ($207 of $4,521) while opus
   re-reviews were 58.6%. The argument: each avoidable FAIL costs an extra
   opus review plus a full redispatch, so the downside draws on the 58.6%
   line while the upside is bounded by the 4.6% one. The confounds (mtime
   proxy, differing populations, 66 vs 203) were disclosed and acknowledged.
3. **The specific shape now requested was rejected on the record.** Plan
   Unit D: *"Option (b) — reserving `haiku` for task-master-tagged mechanical
   units — is rejected on the record, not merely unchosen"*, and §B4:
   *"Any proposal that reintroduces pre-emptive 'this unit looks mechanical'
   tagging is re-running a measured failure. The two live options are
   therefore a flat default change or a cheaper escalation path — not a
   smarter predictor."* ADR-0026 decision 3: "No pre-emptive tier prediction
   is reintroduced."
4. **ADR-0026 carries a pre-registered forward rule that has not been
   checked.** *"After ≥60 units dispatched under the `sonnet` default, the
   FAIL rate must have fallen below the 32.5% haiku-era rate … total spend
   must not materially worsen."* No audit record exists (`docs/audits/` holds
   only the 2026-08-01 efficiency re-audit). I ran the ADR's own tool,
   `scripts/spend-accounting.sh --until=2026-10-07T00:00:00Z`: 475 units,
   pre-08-02 51/9 = 17.6%, post-08-02 424/133 = **31.4%** blended. The
   script splits only at 08-02, so the sonnet-era rate is derived by
   subtracting the 08-25 snapshot: ≈221 units, ≈67 with FAIL, **≈30%**
   (approximate — both counts are mtime-based). That is below 32.5%, so the
   rule's letter is met, but by two points on a confounded comparison; the
   spend half cannot be checked because the transcript corpus has since been
   pruned (total $3,129 now vs $4,521 at ratification; a `--until=2026-08-25`
   run errors with "no usage records"). Sonnet's share rose from 32% to 41%,
   opus fell from 59% to 48% on the surviving corpus.
5. **Mechanical conflicts today.** `templates/persona-config.schema.json`
   enum and `bin/cli.js` `IMPLEMENTER_MODEL_TIERS` are `['sonnet','opus']`;
   `resolveDefaultImplementerModel` resolves any *unrecognised* value to
   `opus` — so writing `defaultImplementerModel: "haiku"` into the live
   config today silently dispatches **opus**, the opposite of the intent.
   The `Suggested model` vocabulary is `sonnet|opus` (CONTEXT.md, pinned by
   `tests/writer-tier-consistency.test.js` AC-D5/D7/D9, which also assert
   that `agents/orchestrator.md` *never* names haiku as a default, tag value
   or ladder rung). The first-FAIL ladder is `sonnet → opus`. `agents/
   lead-programmer.md` is `model: sonnet`. `agents/scribe.md` is already
   `model: haiku` — half of the requirement is already in force.

Plainly: the requirement reverses ADR-0026's ratified default, reintroduces
the option Unit D rejected by name, and contradicts ADR-0026 decision 3 and
the §B4 "no smarter predictor" constraint. It is consistent with ADR-0010's
philosophy (judgment in the packet) and with ADR-0026's own invitation to
*revisit rather than defend* once forward data exists — and that forward
check is overdue regardless of this requirement.

### 8.2 Replay: what the recorded units say about "haiku-safe"

Method (Dream-RSI stage 2–3 on the data that exists; read-only). Units:
105 gh-numbered units (gh3xx, gh4xx) whose PASS marker names a commit; era
by PASS date relative to 2026-08-25; FAIL = a `.fail` record exists; size and
path class from `git show --numstat` of the marker's `commit:` SHA;
"sensitive" = `reviewer-tier.sh`'s own `SENSITIVE_PATHS`. Defect classes by
case-insensitive substring over all 142 `.fail` records (classes overlap).
Script: scratchpad `replay.py`, not committed.

| Property | haiku era (n=70) | sonnet era (n=35) |
|---|---|---|
| FAIL rate | 24/70 = 34% | 16/35 = 46% |
| touches a `SENSITIVE_PATHS` file | 2/11 = 18% | 3/13 = 23% |
| does not | 22/59 = 37% | 13/22 = 59% |
| touches `agents/*.md` / `templates/` | 3/27 = 11% | 0/3 |
| final commit ≤3 files and ≤40 lines | 15/28 = 54% | 10/16 = 62% |
| larger | 9/42 = 21% | 6/18 = 33% |
| ≥6 acceptance commands | 14/40 = 35% | 7/21 = 33% |

Defect-class census over 142 FAIL records (files matching; overlapping):

| Class (substring) | Files | What it means for a packet |
|---|---|---|
| mirror / `--force-render` / regenerate / `fileHashes` | 64 | mirror regeneration step omitted or stale |
| CHANGELOG / version bump / version-stamp / plugin.json | 64 | Constitution P3 obligation missed |
| vacuous | 53 | criterion or test passes under any implementation |
| spec gap / ambiguous / underspecified / contradict | 48 | criterion or edit not pinned |
| out of scope / Do NOT touch / unrelated | 45 | touched a held-out surface |
| host-dependent / precondition / not on PATH | 32 | criterion depends on the host |
| did not run / unverified / no evidence | 7 | acceptance command not executed |

Reading, with the caveats stated first:

- **The size rows are confounded by construction.** A FAILed unit's marker
  points at its *fix* commit, which is small; a first-time PASS's points at
  the whole change. So "small final commit → more FAIL" is an artefact. A
  real replay needs the unit's `baseline..HEAD` range (P0 export).
- **Path class is not confounded the same way and points the wrong way for
  a "risky-path" predictor.** Units touching hook/CLI/validate/template
  paths failed *less* (18–23%) than ordinary units (37–59%). The
  reviewer-tier risk class does not predict implementer FAIL. This is the
  replay equivalent of ADR-0010's "~0% of units" finding: "looks mechanical"
  and "looks risky" are both poor predictors here.
- **What dominates the FAIL corpus is omitted mechanical obligations and
  weak criteria, not hard reasoning.** Mirror regeneration, version bump,
  CHANGELOG entry, scope discipline and criterion vacuity account for the
  bulk of records. These are exactly the things a dispatch packet can carry
  as literal commands and literal expected outputs. This is the strongest
  empirical support for the user's thesis — and it says the lever is
  **packet completeness**, not unit size.
- **Era comparison is noisy** (35 sonnet-era gh-units; the full-corpus
  estimate is ≈30%). Nothing here shows sonnet-era units fail less than
  haiku-era ones once population is held fixed; nothing shows the reverse
  either. The honest statement is that the ADR-0026 bet is unproven in both
  directions at this sample size.
- **§5.1 of the paper applies.** None of this should be turned into
  prompt-level "be careful about mirrors" guidance. It should become literal
  steps and literal checks in the packet, and a measured rubric.

### 8.3 Derived rubric and decomposition policy

**Haiku-safe unit rubric (empirical, v0 — every row traces to a FAIL class
above or to a dispatch-contract element; to be re-scored under P0).** A unit
is haiku-eligible only if all hold; otherwise it is split further by
task-master or stays on the default tier:

- R1 *Every edit is anchored and literal.* Each `## Ordered edits` item names
  one file, one anchor (heading / symbol / `sha:line-range`) and the exact
  before/after text or an exact insertion. No "update the prose to reflect".
  (FAIL classes: spec gap/ambiguous, scope.)
- R2 *No mechanical obligation is left implicit.* If any affected file is
  version-stamped (`agents/*.md`, `templates/`), the packet carries the exact
  version string to write, the CHANGELOG entry text, and the literal
  `node bin/cli.js --update --force-render && git status --porcelain`
  check with expected empty output. (FAIL classes: mirror 64, version 64 —
  the two largest.)
- R3 *One acceptance command, one expected output, already proven
  non-vacuous.* The criterion's mutation proof (what change would flip it) is
  written in the packet, not left to the implementer. (FAIL class: vacuous
  53.)
- R4 *No host preconditions.* Criteria run from the repo root with no
  dependence on PATH contents or tools outside the repo's own test harness,
  or the precondition is stated and checked first. (FAIL class: host 32.)
- R5 *No structural lookup needed.* `## Pre-resolved context` already names
  callers / blast radius (explorer answer pasted as symbol → file:line) and
  the test file to extend; the TDD decision is made.
- R6 *Scope is enumerable.* `## Do NOT touch` lists every sibling surface
  the unit could plausibly reach (mirrors, adapters, CONTEXT.md, tests).
  (FAIL class: scope 45.)
- R7 *No diagnosis.* The unit is not a bug fix whose cause is unknown;
  anything needing `diagnosing-bugs` is not haiku-eligible.

Units that fail R1–R7 after splitting are the residue that stays on the
default tier; that residue is the honest measure of how much of a spec is
"straightforward". Note ADR-0010's prediction that task-master would tag ~0%
of units cheap: the rubric avoids that failure mode by making eligibility a
*property of the packet task-master itself writes* (checkable, mostly
greppable), not a judgment about the unit's difficulty.

**Decomposition policy scored on history, incumbent included.** Three
candidate policies to replay under P0:

- π₀ (incumbent): current pathfinder sizing, `sonnet` default, reactive
  `sonnet → opus` ladder.
- π₁: same slicing, `haiku` default for every unit, ladder `haiku → sonnet →
  opus` (ADR-0010 verbatim; its measured outcome is the 32.5% row).
- π₂: slice until R1–R7 hold, tag those units `haiku`, residue `sonnet`,
  ladder `haiku → sonnet → opus` for haiku units and `sonnet → opus` for the
  rest.

Replay objective (eq. (1) adapted): for each historical spec, expected cost =
Σ over units of (implementer attempts × tier price) + (reviews × reviewer
tier price), where a FAIL adds one implementer attempt one rung up plus one
opus review (reviewer-gate ratchet); quality term = 1 if all units reached
PASS within the 2-FAIL cap. π₀ is in the candidate set, so the selected
policy is never worse than today on the fixed history. The data needed per
unit — implementer tier, attempts, reviewer tier, FAIL classes, packet
completeness per R1–R7 — is the P0 export; today only the attempts and FAIL
classes exist. π₂'s cost model needs task-master's own extra turns priced in
(it is `sonnet` with `effort: medium`, 40 turns).

### 8.4 What moves from the implementer into task-master's packet

For `lead-programmer` (nine-element contract, unchanged shape; this is about
the *substance* H4 cannot check):

- `## Ordered edits`: literal before/after or insertion text per anchor; the
  commit message text; for version-stamped files the exact version bump,
  CHANGELOG entry, and `--force-render` step as separate numbered edits.
- `## Acceptance criteria`: one command per line with expected exit/output,
  plus the mutation that would flip it, plus the `version-stamp-check.sh
  baseline..HEAD` invocation with expected `ok` where relevant.
- `## Pre-resolved context`: TDD decision and test file; explorer answer
  pasted (symbol → file:line); whether the unit is `.directed`; the
  `baseline` SHA the review packet must cite.
- `## Do NOT touch`: enumerated, not described.
- `## Escalation`: unchanged, but add the literal WIP-sentinel path and the
  ready-for-review packet template pre-filled with everything except the
  final SHA, so the haiku executor fills blanks rather than composes.

Currently exercised by lead-programmer and removed under this policy: TDD
choice, explorer lookups, coding-discipline tradeoffs, blast-radius
judgement, "if the plan is wrong STOP" (becomes "if any literal step cannot be
applied exactly, STOP").

For `scribe` (already `haiku`): its dispatch is currently a digest plus
institutional-knowledge duty. A haiku-safe scribe packet carries: the exact
glossary term(s) and the sentence to add under which heading; the ADR number
and title (next free, hole-preserving — a recorded FAIL class in `gh332`);
the issue number and task-id (its close rule requires both, verbatim); the
four close conditions pre-evaluated with the marker line quoted; the wiki
file and section to touch; `Do NOT touch` for CONTEXT.md regions another
unit is editing (rulings log line 8 collision). Scribe's `domain-modeling`
judgement about *whether* a term deserves an entry moves to spec-master's
"Scribe update hint", which already exists in the plan format.

### 8.5 Persona and config changes implied (not made here)

| Surface | Change | Guard |
|---|---|---|
| `agents/task-master.md` | add rubric R1–R7 as the eligibility test; `Suggested model: haiku|sonnet|opus`; tag `haiku` only when R1–R7 hold *in the packet it wrote*; keep the reactive ratchet for `sonnet`/`opus` | version-stamped (Constitution P3: bump + CHANGELOG + `--force-render`); AC-D5 asserts the default tag is not haiku — test must change with it |
| `agents/orchestrator.md` | ladder `haiku → sonnet → opus` for haiku-tagged units; "Per-unit model routing" vocabulary | AC-D7/AC-D9 forbid `haiku|sonnet|opus` and `haiku → FAIL` in this file — rewrite the test's intent, not just the text; version-stamped |
| `agents/lead-programmer.md` | `model:` default — either stays `sonnet` (π₂, per-unit tag does the work) or goes `haiku` (π₁) | version-stamped; `tests/default-implementer-model.test.js` asserts config default == frontmatter |
| `templates/persona-config.schema.json`, `bin/cli.js:338` | enum / `IMPLEMENTER_MODEL_TIERS` gain `haiku`; decide whether the unrecognised-value fallback still escalates to `opus` (it should) | `bin/cli.js` and templates are `reviewer-tier.sh` SENSITIVE_PATHS (opus review forced); `tests/cli-backfill.test.js` |
| `.claude/persona-config.json` `defaultImplementerModel` | only after the enum change; until then `haiku` → `opus` silently | Set A: `harness-integrity-gate.sh` blocks direct agent writes; route via `node bin/cli.js --update` |
| `CONTEXT.md` Writer tier / ratchet / vocabulary entries | update | `tests/marker-verify.test.sh` mutation-proofs CONTEXT.md in places; `ubiquitous-language` checks |
| `docs/adr/00NN` | new ADR amending ADR-0026, quoting §8.1 item 4's forward-rule result and naming what is reversed | scribe custody |
| `hooks/scripts/reviewer-tier.sh` | **no change** — reviewer gate stays measured (ADR-0009); the reviewer-gate ratchet (never expires) is the safety net | hook; untouched by design |
| 2-FAIL cap | unchanged count; a haiku unit's path becomes haiku FAIL → sonnet FAIL → cap, so the cap is hit one rung lower than today | orchestrator "At the 2-FAIL cap" is the single source |

### 8.6 Risks

- **More FAIL rounds, each ending in an opus review.** The reviewer-gate
  ratchet forces opus on any unit with a `.fail` record and never expires.
  Under ADR-0010 this is what moved cost from the 4.6% line to the 58.6%
  line. The census says most FAILs are omission classes a complete packet
  prevents — but that is a hypothesis until measured under π₂.
- **Task-master cost rises.** Every pre-resolved decision is a task-master
  turn (explorer spawns, reading anchors, writing literal text). It is
  `sonnet`, 40 turns, `effort: medium`; a packet that pastes exact text for
  several files also presses `maxPromptBytes` 30000 and
  `maxInlineBlockLines` 80 (H1/H2). Precision by anchor, not by inlining,
  is the stated remedy; some units will not fit and must split.
- **The reviewer becomes the only safety net.** H4 checks labels and a
  one-line substance floor, not correctness; `dispatchHygiene.mode` is
  `warn` here. A haiku executor that follows a wrong literal instruction
  exactly produces a confident wrong diff; only the reviewer catches it.
- **Prediction failure mode returns.** ADR-0010 recorded ~0% opt-in tagging;
  a rubric task-master must *satisfy* rather than *judge* is the mitigation,
  and its uptake must be measured (share of units tagged haiku per spec).
- **Spec-master load.** R2/R3 need the spec's criteria already non-vacuous
  and version obligations named per step; S1/S2 (above) are prerequisites.
- **Data honesty.** All numbers here are mtime- and keyword-based over a
  per-clone, gitignored corpus. P0 is required before any of this is
  ratified; ADR-0026 made the same point about its own evidence.

### 8.7 Re-ranked shortlist (supersedes §5)

1. **P0** unit-outcome export, now with the unit's `baseline..HEAD` range,
   implementer tier actually used, attempts, reviewer tier, FAIL classes and
   a per-packet R1–R7 score — the replay in §8.2 shows why the marker's
   final commit is not enough.
2. **Close ADR-0026's forward rule** as a recorded audit (`docs/audits/`),
   using §8.1 item 4 and P0: this is owed independently of the requirement
   and is the gate any reversal ADR must cite.
3. **S1 + S2** (criteria replay against FAIL classes; incumbent-included
   non-regression) — prerequisites for R3; they attack the 53 vacuous and
   48 ambiguous records.
4. **Rubric R1–R7 in task-master's packet-writing rules**, tier-neutral at
   first (apply it on `sonnet`, measure the FAIL-class mix before and after).
   This is the §8.4 move and needs no vocabulary or config change.
5. **π₂ replay under P0** with π₀ in the candidate set; only a favourable
   score opens the ADR amending ADR-0026 and the enum/vocabulary changes in
   §8.5.
6. **T2** (tagging-policy offline evaluation) is absorbed into item 5.
7. **S4, T1, T3** as before, lower.
8. **T4, S3, S5** parked.

### 8.8 Open questions (revised)

1. Does the user want π₁ (flat haiku default, ADR-0010 redux) or π₂
   (haiku only for rubric-satisfying units)? π₁ is the measured 32.5% row;
   π₂ is the rejected-on-record option, now with a checkable rubric instead
   of a judgment. Either needs a new ADR; §8.1 lists what each contradicts.
2. Should the rubric be applied tier-neutrally first (item 4) so the
   packet-completeness effect is measured separately from the model effect?
3. Who closes the ADR-0026 forward check, and is a ≈30% vs 32.5% result
   "fallen below" in the spirit of the rule?
4. Is the transcript corpus pruning policy compatible with any spend
   accounting at all? If not, the spend half of future rules needs another
   source.
5. Should `.claude/reviewed/` outcomes be exported to a tracked file so a
   replay survives clones (open question 1 of §6, now load-bearing)?
6. H4 is advisory (`warn`) in this repo: should packet completeness become
   a blocking check before any haiku dispatch, and is a substance check even
   mechanisable beyond labels?

## 9. Sources

- arXiv 2609.14858v1, read via arXiv MCP HTML extraction (sections listed in
  §1).
- Addendum (§8) evidence: `docs/adr/0010-implementer-haiku-default.md`,
  `docs/adr/0026-writer-tier-reversed-to-sonnet.md`,
  `docs/plans/2026-08-25-agent-throughput-performance-dampeners.md`
  (§B4 lines 193–261, Unit D lines 511–617),
  `docs/plans/2026-09-25-item06-model-routing-prose.md`, `CONTEXT.md`
  lines 345–395, `tests/writer-tier-consistency.test.js`,
  `bin/cli.js:338-351`, `templates/persona-config.schema.json`
  (`defaultImplementerModel` enum), `.claude/persona-config.json`,
  `.claude/agents/orchestrator.md` lines 403–474,
  `.claude/agents/lead-programmer.md` lines 16–85,
  `.claude/agents/scribe.md` lines 14–108,
  `hooks/scripts/dispatch-hygiene.sh` lines 60–88,
  `hooks/scripts/reviewer-tier.sh` lines 1–99; live runs of
  `scripts/spend-accounting.sh` (cutoffs 2026-10-07 and 2026-08-25); PASS
  marker first lines for gh3xx/gh4xx units and `grep -rl --include=*.fail`
  censuses over `.claude/reviewed/` (read-only); scratchpad `replay.py`
  (not committed).
- Affiliation and release-date corroboration (web, not MCP):
  the-decoder.com, dev.to/axrisi, daily.dev, aimodeling.com — all consistent
  with the arXiv record.
- Project files read: `.claude/agents/spec-master.md`,
  `.claude/agents/task-master.md`, `.claude/agents/orchestrator.md`
  (lines 430–474), `skills/pathfinder/SKILL.md`, `hooks/scripts/reviewer-
  tier.sh` (header), `docs/plans/2026-10-05-outcomeci-followups.md`
  (Clarifications, Self-check), `.claude/reviewed/gh441.fail`,
  `.claude/orchestrator-rulings.log` (first 12 lines), directory listing of
  `.claude/reviewed/`.
