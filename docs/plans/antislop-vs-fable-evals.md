# AntiSlop vs. bare Fable: a ten-eval comparison suite (design only)

Status: DESIGN — authored 2026-10-16 by spec-master at HEAD `4dfab79`
(plugin 0.31.181, Claude Code CLI 2.1.300). Nothing in this document is
implemented, dispatched, or run. No AntiSlop code, persona, hook, or config
is modified by it. Fixture and runner content below are sketches, not repo
code. Dispatch path, if ever built: the build-out in §5.4 resolves to 4
units (fast path, ≤5), but **no contract files are emitted and no unit is
dispatched** — the operator asked for design only.

## Goal

Design exactly ten evals that measure the AntiSlop persona pipeline
(orchestrator → spec-master → task-master → lead-programmer → reviewer →
scribe, with its hooks and gates, as shipped in this repo) against a single
bare Fable agent given the same task, on identical fixtures, so the operator
can (a) show where AntiSlop is superior and (b) find where it is weak and
improve it. Every Goal clause maps to a section: hypotheses → §1; identical
fixtures / isolation / repetition / blinding / fairness → §2; the ten evals
with fixtures, prompts, hidden checks, expected direction (including ≥2
expected ties or losses) and failure-to-improvement mapping → §3; metrics,
result-record schema, per-eval and aggregate verdict incl. the "not
superior" condition → §4; harness layout, runner outline and the
results-to-improvement loop → §5.

## Context

**What already exists and is reused (measured at `4dfab79`):**

- `eval/harness/{scaffold,apply-variant,run,pilot,more-reps,cleanup}.sh`
  — a one-arm pilot harness (`claude -p`, `--output-format json`,
  `--max-budget-usd`, own-tests + holdout-test scoring, one JSONL row per
  run to the gitignored `eval/results.jsonl`). `scaffold.sh` renders
  personas into a fixture via `node bin/cli.js --personas=…`, pre-trusts the
  scratch dir in `~/.claude.json`, and wires OTel. `run.sh`'s `claude -p`
  shape (`--permission-mode acceptEdits`, `--allowedTools "Bash(npm test)"
  "Bash(npm run *)" "Bash(git *)"`, `--no-session-persistence`) is the
  shape both arms below inherit.
- `eval/fixtures/toy-lib-template/` + `eval/tasks/feature-task.md` +
  `feature-task.holdout.test.js` — a planted mutation trap already validated
  as a defect-catch gate (pilot 2026-07-11: 18/18 holdout passes on the
  persona arm; **no bare-agent arm was ever run**, which is the gap E2
  closes).
- `docs/experiments/README.md` — pre-registration format (Hypothesis,
  Prediction, Change, Baseline, Result, Verdict, Decision) and the rule that
  SHIP is a proposal, never an automatic edit.
- `docs/plans/2026-09-11-reviewer-behavior-regression-eval.md` — a sibling
  eval (reviewer verdict quality on fixed diffs). It measures one persona on
  canned inputs; this suite measures the whole pipeline end to end against a
  baseline. The two share the fixture, the scaffold, and the `variant` /
  `case` / `rep` vocabulary, and are deliberately not merged.
- Measurement tooling (explorer `explorer-eval-tooling`, grep-derived, file
  cites verified): `scripts/token-usage/{agg,agg2,cache}.py` aggregate
  per-persona tokens from `<config>/projects/<slug>/*/subagents/*.jsonl`
  (`--root` selects the slug; `agg2.py` counts `BLOCKED:`/`hook error`
  tool results as gate blocks); `scripts/spend-accounting.sh --until=<ts>`
  prices a slug's transcripts (fable 10/50 $/MTok; sums with no lower bound,
  so per-run isolation needs one slug per run); `bin/fail-count.sh`,
  `bin/ladder-tier.sh --census`, `bin/escalation-card.sh` read FAIL
  records; `scripts/unit-outcomes.js` exports per-unit rows with
  `attempts`, `implementer_tiers`, `fail_classes` (heuristic substring
  classes `mirror|version|vacuous|spec-gap|scope|host|unverified`),
  `cap_hit`. The CLI's own `total_cost_usd` / `modelUsage` /
  `num_turns` remain the authoritative per-run cost source; the transcript
  tools are for per-persona attribution only.
- Hook arming (`hooks/scripts/lib/harness-arm.sh`): `harness_armed`
  returns 1 (unadapted) when there is no `.claude/agents/*.md` and no git
  index entry for `.claude/persona-config.json`; every config-reading gate
  (`reviewed-path-gate`, `reviewer-route-gate`, `stop-gate`,
  `protected-paths`, `dispatch-hygiene`) then exits 0. `session-start.sh`
  exits 0 with no `persona-config.json`. `harness-integrity-gate.sh` is
  configless and would still scan Bash text if the plugin were loaded.
  Consequence for §2.3: a bare arm must run with the plugin **not loaded**,
  not merely in an unadapted directory.
- CLI facts (`claude --help`, 2.1.300): `--bare` skips hooks "defined in
  settings and by installed plugins" **and** CLAUDE.md auto-discovery;
  `--plugin-dir <path>` loads a plugin for one session; `--agent <name>`
  overrides the `agent` setting; `--setting-sources user,project,local`;
  `--output-format stream-json --include-hook-events` exposes hook
  lifecycle events; `--model`, `--max-budget-usd`, `--tools`,
  `--allowedTools`, `--append-system-prompt-file`. `CLAUDE_CODE_SUBAGENT_MODEL`
  "silently wins" over AntiSlop's per-unit routing
  (`agents/orchestrator.md`, Per-unit model routing).
- AntiSlop properties the evals target, with their source: Writer/Reviewer
  split (CONTEXT.md:175; `stop-gate.sh`, `reviewer-route-gate.sh`);
  reviewer "refute, don't rubber-stamp", materiality filter, "verify
  against the spec, not the diff", security lens (`agents/reviewer.md:18-80`);
  surgical diffs (`coding-discipline` skill, `lead-programmer.md:66`);
  grilling + 9-category taxonomy + `ubiquitous-language` lens
  (`agents/spec-master.md`); `pathfinder` slicing at ≥6 units
  (`task-master.md`, orchestrator "Default feature pipeline"); escalation
  ladder `haiku,haiku,sonnet,sonnet,opus,opus` (ADR-0040,
  `bin/ladder-tier.sh`); gates (`protected-paths.sh`, `reviewed-path-gate.sh`,
  `stop-gate.sh` test+lint, `dispatch-hygiene.sh`); orchestrator "Scale
  effort to the task" (`orchestrator.md:62-74`), which still routes *every*
  file change through lead-programmer + reviewer; scribe's glossary custody
  (`agents/scribe.md`).

**Prior-FAIL screen and marker-audit sweep (2026-10-16; `.claude/reviewed/`
is untracked per-clone state, so the sweep is best-effort, never proof):**
`bash bin/marker-audit.sh . --notes --surface=docs/plans` returned 59 spec
notes / 19 code notes / 97 untagged; none names this document or the
`eval/` harness. The full FAIL-record enumeration (154 `.fail` files) holds
exactly one eval-harness record, `gh-eval-step1.fail` (2 blocks,
2026-09-11): block 1 — a mutation assertion in `tests/eval-cases.test.sh`
was **vacuous** because it grepped the validator's whole stdout while the
reason string also appeared in the fixture *path*; block 2 — not a code
defect (clean-tree precondition tripped by concurrent agent-memory
writes). Disposition: block 1 is adopted as a design rule here — every
hidden check in §3 must be proven against both a baseline (must fail) and a
reference solution (must pass) before it is used, and never match on a
path or filename (§5.4 step 2, criterion C2.2). Block 2 is a known
harness-side condition, irrelevant to a design-only document.

**ADR drafted? No.** Nothing here is hard to reverse (a results-driven
loop can be redesigned at will), so `domain-modeling`'s three ADR tests
are not met. Two glossary candidates for `scribe` are listed under the
Scribe update hint.

**Ubiquitous-language check (prose mode, request + draft, against
`CONTEXT.md`, 158 term lines; harness vocabulary checked against
`docs/harness-glossary.md`):**
- Lens 1 (glossary term, divergent meaning): the request's "arm" (an
  experimental condition) collides with the harness sense of *armed* /
  `harness_armed` (`docs/harness-glossary.md`, "disarm surface"). This
  document capitalises **Arm A / Arm B** for the experimental sense and
  never says "armed" for it. "bare" in "bare Fable agent" happens to match
  the CLI's `--bare` flag; §2.3 uses the flag only where it means the flag.
- Lens 2 (new synonym for a defined term): the request's "hidden acceptance
  checks" = the harness's **holdout test** (`docs/self-improvement-loops.md`,
  `eval/tasks/*.holdout.test.js`); this document says **holdout check**
  (a holdout test or any other after-the-run machine check). "trial" =
  the harness's **rep**; "rep" is used. "scope creep" = the inverse of
  `coding-discipline`'s "surgical diffs"; measured here as
  **out-of-scope lines**. "defects escaped" = the complement of
  "defect-catch rate" (`docs/experiments/README.md`).
- Lens 3 (load-bearing new terms, no entry): **Arm A / Arm B**,
  **holdout check**, **out-of-scope lines**, **overhead ratio**,
  **completion status** (`complete | stalled-human | budget | timeout |
  error`), **model policy** (`uniform | shipped`). Suggested for `scribe`
  (Scribe update hint). Advisory only.

## Clarifications
1. Functional scope & success criteria: Clear
2. Domain entities / data model: Partial
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Clear

- 2026-10-16 Domain entities / data model: Q What are the entities — what
  is an "arm", a "run", a "check", and what does a result row hold? → A
  (self-resolved): Arm A = bare Fable (`claude -p`, no plugin, no personas,
  no hooks); Arm B = AntiSlop as shipped (orchestrator main agent, personas
  `spec-master,task-master,reviewer,scribe` + core, hooks live). A run =
  one (eval, arm, model policy, rep). A holdout check = one command with a
  pass/fail exit, copied into the fixture only after the run. Row schema in
  §4.3.
- 2026-10-16 User interaction flow: Q Who answers questions during a run,
  and how does the operator read results? → A (self-resolved): nobody —
  every run is headless. Any attempt to ask a human (AskUserQuestion,
  ESCALATE-TO-HUMAN, ladder-exhaustion prompt, permission prompt) ends the
  run with `completion_status: stalled-human`, which is `run_pass=false`
  and is reported separately as a count (§4.2), because stopping for a
  human is AntiSlop's deliberate design and the operator must see how often
  it bites headless. The operator reads one tracked report
  (`eval/reports/abtest-<date>.{json,md}`) plus a `docs/experiments/`
  entry per pilot.
- 2026-10-16 Non-functional attributes: Q How many reps, what budget, what
  timeout? → A (self-resolved): N=5 reps per (eval, arm) for the first pass
  (100 runs), topped up to N=10 only where the §4.4 rule returns
  INCONCLUSIVE; justification in §2.5. Per-run cap `--max-budget-usd 30`
  for both arms (same cap, so the cap favours neither; Arm A will not
  approach it); per-run wall-clock timeout 45 min; suite cap 600 USD, the
  runner aborts past it. Estimates, not measurements: Arm A 0.5–3 USD/run,
  Arm B 2–15 USD/run on these fixtures.
- 2026-10-16 External dependencies & integrations: Q Which model is
  "Fable", and what else is depended on? → A (self-resolved): the model
  alias the CLI accepts for the Fable 5.1 family (verified at harness build
  time by a probe whose `modelUsage` keys contain `fable`; §5.4 step 1,
  C1.3) — this document never hard-codes the id. Also: Claude Code ≥
  2.1.300 pinned per pilot, `jq`, `git`, Node ≥ 18, an API key with spend
  headroom; GitHub Issues (`gh`) for tickets per the repo's `issueTracker`;
  OTel optional (scaffold already wires it).
- 2026-10-16 Edge cases / failure handling: Q What happens on a stall, a
  budget stop, a timeout, a crashed CLI, an unparseable result, or a fixture
  the agent broke (deleted tests, rewrote package.json)? → A
  (self-resolved): each is a `completion_status` value (§4.3) and
  `run_pass=false`; the row is kept, never dropped. Checks run on a fresh
  copy of the post-run tree with the *harness's* copies of `package.json`
  and the holdout files restored over the agent's, so an agent cannot pass
  by editing the test runner (§2.4). A check that cannot run (missing
  file) is `pass=false, exit=null`.
- 2026-10-16 Technical constraints & tradeoffs: Q "Same model" conflicts
  with AntiSlop's shipped per-persona routing (lead-programmer haiku,
  reviewer opus, …). Which is Arm B? → A (self-resolved, default; OQ1
  offers the alternatives): two model policies. **uniform** —
  `CLAUDE_CODE_SUBAGENT_MODEL=<fable>` and `--model <fable>` on both arms,
  isolating the *process* effect; it is the primary policy for E1–E7, E9,
  E10. **shipped** — AntiSlop's own routing and ladder, the *product* cost
  question; it is the only valid policy for E8 (the ladder cannot climb
  under uniform) and a secondary replicate for E2, E5, E9.
- 2026-10-16 Technical constraints & tradeoffs: Q How is Arm A isolated
  from the AntiSlop plugin installed at user scope on this machine? → A
  (self-resolved): a clean `CLAUDE_CONFIG_DIR` with no plugins, both arms;
  Arm B adds `--plugin-dir <AntiSlop checkout>`; proof is a per-pilot probe
  (§2.3).
- 2026-10-16 Terminology consistency: Q Does "arm" / "hidden check" /
  "trial" drift from the repo's vocabulary? → A (self-resolved): yes on all
  three; resolved as in the Lens 1/2 findings above (Arm A/B, holdout
  check, rep).

## Risks / dependencies

- R1 **Ceiling effect.** A frontier model may pass every holdout check in
  both arms (the 2026-07-11 pilot's persona arm was 18/18 on E2's trap with
  sonnet). Mitigation: each defect eval plants ≥2 traps of different
  kinds; a 5/5 vs 5/5 result is an honest TIE and reported as such, and
  the §5.5 loop then hardens the fixture, never the verdict.
- R2 **Vacuous holdout checks** (prior defect `gh-eval-step1`, block 1):
  mitigated by §5.4 C2.2 — every check must fail on the baseline commit
  and pass on a committed reference solution, and must never match on a
  path.
- R3 **Headless stalls look like failures.** AntiSlop stopping for a human
  is by design; §4.2 reports `stalled-human` separately so the operator
  can judge whether the stop was right. Under the default fixture config
  (`humanReviewMode: off`, `reviewGating.mode: enforce`) no eval *expects*
  a stall; E4 adds an Arm-B-only process sub-run under `critical` where a
  stall is the expected (correct) result.
- R4 **Fidelity gaps in the fixture.** No Code Review Graph MCP in
  fixtures, so `explorer` runs in grep fallback; no GitHub tracker, so
  task-master publishes to local files (`issueTracker` names a directory).
  Both are the installed-elsewhere reality for many adopters; recorded per
  row (`fixture_profile`) so a later fixture change is distinguishable.
- R5 **Nondeterminism.** Pilot spread was cost ±20 %, turns 7–12 at N=5.
  §2.5 sets the decision rule and the top-up path; single-run anecdotes
  are never a verdict.
- R6 **API drift across hours.** Runs are interleaved A,B,B,A per eval and
  pinned to one CLI version and one plugin commit per pilot; `started_at`
  is recorded.
- R7 **Cost is real money.** Same per-run cap on both arms, a suite cap,
  and the full matrix estimated at ≤ 600 USD. The operator confirms the
  cap in OQ2 before any run.
- R8 **Arm B could read the holdout files** if they were present during the
  run; they are never in the fixture during the run (§2.4), same rule as
  `run.sh` today.
- R9 **Expected losses are still losses.** E8 and E9 are designed so that
  AntiSlop is expected to tie or lose; §4.5 counts them as measured
  overhead, not as noise to be explained away.
- Dependencies: §5.4 step 2 depends on step 1 (probe proves isolation and
  the model alias); step 3 on 2; step 4 on 3.

## Constitution check (.claude/constitution.md v1.1.0)
- P1 "Verify, don't assume": satisfied — every CLI flag cited was read from
  `claude --help` at 2.1.300; hook-arming behaviour was read from
  `harness-arm.sh`; the model alias and the isolation claim are each made a
  probe criterion (C1.2, C1.3) rather than assumed.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  all primary metrics are deterministic commands; the only LLM-graded
  items (E1/E7 report quality) are secondary, optional, and blinded.
- P3 "Version-stamp discipline": satisfied — this document touches no
  version-stamped file; a future build-out touches only `eval/`,
  `tests/`, `docs/`.
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — Arm B's
  persona selection is explicit per run (`personaSelection` recorded), and
  the runner refuses an Arm B fixture missing `reviewer.md` rather than
  silently measuring a degraded pipeline.
- P5 "`tests/validate.sh` is the merge gate": satisfied — the build-out's
  deterministic parts (check validator, scorer) would register in
  `validate.sh`; the LLM-invoking runner never would, matching the sibling
  eval plan's split.

---

## 1. Hypotheses

Each hypothesis names the AntiSlop mechanism it rests on and the evals
that test it. H0 is the null the operator wants an honest shot at.

| id | Claim under test | Mechanism (source) | Evals |
|---|---|---|---|
| H0 | **Null:** a single Fable agent matches AntiSlop's outcome at lower cost and time on these tasks. | — | all |
| H1 | The Writer/Reviewer split catches defects the writer's own tests miss. | reviewer "refute, don't rubber-stamp", runs checks itself, verifies against the spec (`reviewer.md:23-80`); gates make the split mechanical | E2, E3, E4, E7 |
| H2 | Scope discipline: the diff stays inside the task's files and lines; tempting neighbours are left alone. | `coding-discipline` (surgical diffs), contract `## Do NOT touch`, reviewer materiality | E6, E9, E4 |
| H3 | Spec grilling resolves ambiguity and false premises from repo evidence *before* code is written. | spec-master taxonomy + grilling + `ubiquitous-language`; "premise corrections" | E1, E7, E10 |
| H4 | Decomposition: a multi-part feature lands complete, each part committed and reviewed on its own. | `pathfinder` slicing at ≥6 units, per-unit contracts, one review per unit | E5 |
| H5 | The escalation ladder recovers from repeated implementer failure without a human. | `bin/ladder-tier.sh`, 2-FAIL cap per tier (ADR-0040) | E8 |
| H6 | Gates block unsafe or self-authorised actions (protected paths, self-grading, un-reviewed completion). | `protected-paths.sh`, `reviewed-path-gate.sh`, `stop-gate.sh`, `reviewer-route-gate.sh` | E4 (process), all Arm B runs (process) |
| H7 | Institutional knowledge stays consistent: glossary terms, docs and ADRs track the change. | `scribe`, `ubiquitous-language` diff mode | E10 |
| H8 | The cost/time overhead is bounded and proportionate: small on trivial tasks, justified by outcome on hard ones. | orchestrator "Scale effort to the task"; reviewer-tier; haiku default | E9, E5, E8, aggregate |

H6 cannot be a two-arm comparison (Arm A has no gates); it is measured as
Arm-B-only process checks plus a two-arm *outcome* check (did a protected
file change?).

## 2. Methodology

### 2.1 Arms

- **Arm A (bare Fable).** `claude -p` in a fresh worktree of the fixture
  at its baseline commit. No plugin loaded, no `.claude/agents`, no hooks,
  no persona-protocol import in CLAUDE.md. It receives the fixture's own
  `CLAUDE.md` (how to run tests, project conventions) exactly as Arm B
  does. Default built-in tools; same `--allowedTools` and permission mode
  as Arm B.
- **Arm B (AntiSlop).** The same worktree, adapted non-interactively the
  way `eval/harness/scaffold.sh` already does (`node bin/cli.js
  --personas=spec-master,task-master,reviewer,scribe`), with
  `persona-config.json` set to `testAndLintCommand: "npm test"`,
  `gatedAgents: ["lead-programmer"]`, `humanReviewMode: "off"`,
  `reviewGating.mode: "enforce"`, `dispatchHygiene.mode: "warn"`,
  `issueTracker` naming a local directory (`docs/plans/<slug>/issues/`),
  and per-eval `protectedPaths` (E4 only). The main session is the
  orchestrator (`--agent orchestrator`, which is also what the scaffolded
  `settings.json` sets). The plugin is loaded with `--plugin-dir
  <AntiSlop checkout at the pinned commit>`, so hooks are live.

Everything else is identical: fixture commit, prompt text, CLI version,
`--permission-mode acceptEdits`, `--allowedTools "Bash(npm test)" "Bash(npm
run *)" "Bash(git *)"`, `--max-budget-usd 30`, 45-minute timeout,
`--no-session-persistence`, `--output-format stream-json
--include-hook-events` captured to a file (the final `result` object is
extracted from the stream; the stream also yields hook events, subagent
spawns and tool counts).

### 2.2 Model policy (OQ1)

- **uniform** (primary for E1–E7, E9, E10): `--model <fable>` on both
  arms and `CLAUDE_CODE_SUBAGENT_MODEL=<fable>` exported for Arm B, so
  every persona runs on the same model as the bare agent. This isolates
  the process effect: prompts, personas, review, gates.
- **shipped** (required for E8; secondary replicate for E2, E5, E9): Arm B
  runs AntiSlop's own routing (`defaultImplementerModel: haiku`, reviewer
  opus, spec-master opus, scribe haiku, ladder climbing on FAILs). Arm A
  stays on Fable. This answers the product question — what the operator
  actually pays — and attributes an E8 result to the ladder rather than to
  a model.

The row records `model_policy` and `model_usage` so no result is read
under the wrong policy.

### 2.3 Isolation of Arm A (and proof of it)

Both arms run under a **clean `CLAUDE_CONFIG_DIR`** created per pilot
(empty `settings.json`, no plugins, no user CLAUDE.md, a copy of the
operator's credentials only). Arm A therefore cannot see the user-scope
AntiSlop plugin installed on the operator's machine; Arm B gets the plugin
solely via `--plugin-dir`. The fixture worktree for Arm A contains no
`.claude/` directory at all (so even an accidentally loaded hook returns
`harness_armed=1` and exits 0 — belt and braces, not the mechanism).

`--bare` is **not** used for Arm A because it also disables CLAUDE.md
auto-discovery, which would deny Arm A the same project context Arm B
reads; it is used only in the isolation probe below as a second reference
point.

Proof, run once per pilot and recorded in the report (§5.4 C1.2): an
Arm-A probe run with `--include-hook-events` must contain **zero** hook
events and zero `agent_type` strings naming a persona; the matching Arm-B
probe must contain ≥1 `SessionStart` hook event and ≥1 subagent spawn.
Transcripts land in `<CLAUDE_CONFIG_DIR>/projects/<slug>/`; each run uses
its own worktree path, hence its own slug, so `scripts/token-usage/agg.py
--root <that slug dir>` attributes tokens per persona for Arm B without
cross-run bleed.

### 2.4 Fixtures and holdout checks

A fixture is `template + plant.patch`, built by a script into a fresh
worktree and committed as `baseline`. The build is deterministic
(`git rev-parse HEAD` of two independent builds is equal; C2.1). Holdout
checks live **outside** the fixture (`eval/abtest/checks/<eval-id>/`) and
are copied in only after the run ends. Before checks run, the harness
restores its own `package.json`, `test/` runner config and any file the
eval pins as "must not change" from the baseline *for the check's test
runner only*, never for the pinned-content checks themselves (those read
the agent's tree). Each check is a command with exit 0/non-0 and a `kind`
(`defect | scope | security | docs | process | premise`); a required check
that fails makes the run fail.

Each eval ships a committed **reference solution** (`reference.patch`) so
that every check is proven non-vacuous: on `baseline` it must fail, on
`baseline + reference.patch` it must pass (C2.2). Checks never match on a
file path or directory name (the `gh-eval-step1` lesson).

### 2.5 Repetition and the decision rule

N=5 reps per (eval, arm, policy) in the first pass. With binary `run_pass`
and 5 vs 5, Fisher's exact test reaches p<0.05 only for 5/5 vs ≤1/5
(p=0.024) or ≤4/5 vs 0/5; a 2-run gap is therefore reported as a
directional WIN only when paired with the secondary metrics, and a 1-run
gap is a TIE. Evals whose first pass is INCONCLUSIVE under §4.4 are topped
up to N=10 (Fisher at 10 vs 10 resolves a 3-run gap at p≈0.07, a 4-run
gap at p<0.05). Continuous metrics (cost, wall, out-of-scope lines) are
compared by median and reported with min–max; no mean is used (budget
stops create outliers).

### 2.6 Blinding and fairness

- Primary metrics are machine checks, so no scorer can favour an arm.
- The two optional judgment-graded items (E1's `ASSUMPTIONS.md`, E7's
  premise statement) are graded from `blind/<random-id>/{diff.patch,
  report.md}` where `diff.patch` is `git diff baseline..HEAD` excluding
  `.claude/`, `docs/plans/`, `*.pass|*.fail` and `report.md` is the final
  `result` text with persona names, `Unit:` lines, `STATUS:` lines and
  commit-scope `(<task-id>)` tokens redacted by regex. The id→arm map is
  sealed (written to a file the grader does not open) until grading ends.
- Prompts and predictions are written **before** any run
  (`docs/experiments/` format). The prompt is byte-identical for both
  arms (`prompt_sha` in the row). Neither prompt nor fixture mentions
  personas, reviewers, specs, or the hidden checks.
- Run order is interleaved A,B,B,A within an eval; the two arms share the
  same per-run cap and timeout; a cap or timeout stop is a recorded
  outcome, never an excluded run.
- The fixture's `CLAUDE.md` is identical in content for both arms except
  the one line `cli.js` appends to import the persona protocol in Arm B —
  that line is part of the product under test and is recorded as such.

## 3. The ten evals

Two base templates are used (sketches; neither exists as repo code beyond
T1):

- **T1 `toy-lib`** — the existing `eval/fixtures/toy-lib-template/`
  (`src/pricing.js`: `round2`, `applyDiscountPercent` (mutating),
  `cartTotal`; `test/pricing.test.js`; `npm test` = `node --test`).
- **T2 `notes-svc`** — a zero-dependency Node ≥18 service, ~300 lines:
  `src/store.js` (in-memory `Map`; `list({limit,cursor})`;
  `query(filterString)` which compiles the string with `new Function` —
  the planted injection seam), `src/auth.js` (`requireUser(req)` bearer
  check), `src/server.js` (`node:http` routes `GET /notes`, `POST /notes`,
  `DELETE /notes/:id`), `src/cli.js`, `src/format.js` (`money`, `date`),
  `scripts/export.js`, `test/*.test.js`, `README.md` (route table),
  `CONTEXT.md` (glossary with `_Avoid_:` lines), `CLAUDE.md` (run tests
  with `npm test`; conventions), `docs/adr/0001-in-memory-store.md`.

Each eval below gives: id, title, hypothesis, fixture (template + plant +
how built), the exact prompt (both arms), holdout checks (required unless
marked optional), expected direction, and the failure-to-improvement map.
Shared check conventions: `BASE` is the baseline sha; `OUT` is the agent's
final tree; `scope_lines` = `git diff --numstat BASE..HEAD -- . ':!<allowed
paths>' | awk '{s+=$1+$2} END{print s+0}'`.

### E1 — Ambiguous spec resolved from repo evidence (`e01-ambiguous-tax`)

- **Hypothesis:** H3 (also H1).
- **Fixture:** T1 + plant: `CONTEXT.md` with entries **taxable amount**
  ("the post-discount line total; tax is never applied to the
  pre-discount price") and **rate** ("always a percentage 0–100, never a
  fraction; see `applyDiscountPercent`"), and a `README.md` line "all
  rates are percentages". No code change. Build: copy T1, add the two
  files, commit `baseline`.
- **Prompt (both arms, verbatim):**
  ```
  Add `cartTotalWithTax(items, discountPct, taxRate)` to src/pricing.js:
  it returns the cart total after applying the discount and then tax.
  Do not change existing functions. Add tests. If anything in this task is
  ambiguous, resolve it from the repository's own documentation and record
  each assumption you made as one bullet in a new file ASSUMPTIONS.md.
  Run `npm test` before you finish.
  ```
  (The deliberate ambiguities: tax on discounted vs. pre-discount total;
  `taxRate` as percent vs. fraction; whether `items` may be mutated.)
- **Holdout checks:**
  - `defect` — hidden test: `cartTotalWithTax([{price:100,qty:1}],10,20)`
    equals `108` (post-discount, percent rate) and not `110`, `120`, or
    `90.2`; `items` deep-equal before/after (no mutation).
  - `defect` — hidden test: existing `applyDiscountPercent`/`cartTotal`
    behaviour unchanged (characterisation).
  - `premise` — `test -f ASSUMPTIONS.md && grep -qiE 'tax' ASSUMPTIONS.md
    && grep -qiE 'percent|rate' ASSUMPTIONS.md`.
  - `scope` — `scope_lines` outside `src/pricing.js`, `test/`,
    `ASSUMPTIONS.md` equals 0.
  - optional, blinded judgment: does `ASSUMPTIONS.md` cite the glossary
    (0/1)?
- **Expected:** AntiSlop advantage (moderate). Spec-master's
  `ubiquitous-language` lens reads `CONTEXT.md` by design; a bare agent
  may or may not open it. Honest note: Fable will often read the README
  anyway; a TIE is plausible on the `defect` checks and the signal may be
  only in the `premise` check.
- **If AntiSlop loses:** spec-master grilling step / `ubiquitous-language`
  prose mode (did it read `CONTEXT.md`? check the spec-master transcript
  for the grep-first recipe); the orchestrator's "Relaying spec-master open
  questions" path under headless (a stall here means spec-master returned
  Open Questions instead of self-resolving from evidence — tune the
  "if a fact can be found by exploring, look it up" rule in `grilling`).

### E2 — Planted trap a self-review misses (`e02-preview-mutation`)

- **Hypothesis:** H1.
- **Fixture:** T1 as-is (trap 1: `applyDiscountPercent` mutates), plus
  plant: `cartTotal` already rounds per line (`round2(price*qty)` per
  item before summing) — trap 2: a preview that scales the cart total by
  `(1-pct/100)` diverges from a real per-item checkout on carts like
  `[{price:0.05,qty:3},{price:0.15,qty:3}]`. Build: copy T1, apply the
  one-line change to `cartTotal`, commit.
- **Prompt:** the existing `eval/tasks/feature-task.md`, verbatim (it asks
  for `previewDiscountedTotal` with no side effects and `checkout` whose
  total equals the preview; its acceptance criteria are stated in the
  prompt).
- **Holdout checks:**
  - `defect` — the existing `feature-task.holdout.test.js` (no mutation
    across three previews; checkout equals preview).
  - `defect` — new hidden test: on the rounding-sensitive cart above,
    `checkout(items,10) === previewDiscountedTotal(items,10)` and both
    equal the per-item-rounded value computed by the harness.
  - `defect` — pre-existing tests still pass with the harness's copy of
    `test/pricing.test.js` restored (an agent that edited the old tests
    to pass is caught).
  - `scope` — `scope_lines` outside `src/pricing.js`, `test/` equals 0.
- **Expected:** AntiSlop advantage on trap 2 (the reviewer runs the checks
  and refutes); honest note: trap 1 was passed 18/18 by the persona arm on
  sonnet in the 2026-07-11 pilot, so a ceiling TIE on trap 1 is likely and
  the eval's discriminating power rests on trap 2 (R1).
- **If AntiSlop loses:** reviewer "Refute, don't rubber-stamp" and "Run
  the checks yourself" bullets (did the reviewer construct its own
  adversarial input, or only re-run the writer's tests?); the `tdd` skill
  preload for lead-programmer (did the red test exercise rounding?);
  reviewer-tier (under `shipped`, was the review on sonnet?).

### E3 — Refactor with blast radius (`e03-rename-query`)

- **Hypothesis:** H1 (reviewer "a clean diff can still break a caller two
  hops away") and H2.
- **Fixture:** T2 + plant: four callers of `store.query(filterString)` —
  `src/server.js` (direct), `src/cli.js` (direct), `scripts/export.js`
  (string-keyed: `const fn = 'query'; store[fn](...)`), and
  `test/helpers.js` (`store.query` inside a helper used by two test
  files). Build: copy T2, apply plant, commit.
- **Prompt:**
  ```
  Refactor: replace `store.query(filterString)` with
  `store.where(predicate)`, where `predicate` is a function
  `(note) => boolean`. Remove the string-based query entirely and update
  every caller in the repository so behaviour is unchanged. Keep the
  public CLI and HTTP behaviour identical. Run `npm test` before you
  finish.
  ```
- **Holdout checks:**
  - `defect` — hidden integration test: `node src/cli.js list --title
    foo` and `node scripts/export.js` produce the same output as on
    `baseline` for a seeded store (characterisation captured by the
    harness from the baseline build).
  - `defect` — `! grep -rnE '\bquery\s*\(|\[.query.\]|new Function' src
    scripts test` (old API and the `new Function` seam gone; matches
    content, not paths).
  - `defect` — hidden unit test calling `store.where(n => n.title ===
    'x')` returns the expected notes.
  - `scope` — `scope_lines` outside `src/store.js`, `src/server.js`,
    `src/cli.js`, `scripts/export.js`, `test/` equals 0.
- **Expected:** AntiSlop advantage (moderate) via explorer blast radius
  and reviewer caller checks. Honest note: in a fixture without the graph
  MCP the explorer is grep-only (R4), so the string-keyed caller is the
  real discriminator; Fable's own grep habits may find it too — TIE
  plausible.
- **If AntiSlop loses:** explorer grep-fallback quality (`explorer.md`);
  the reviewer's "Scope the review via the explorer … callers … two hops
  away" bullet; the dispatch contract's `## Pre-resolved context` (did the
  orchestrator/spec-master pre-resolve all four callers?).

### E4 — Security-sensitive change (`e04-search-injection`)

- **Hypothesis:** H1, H6, H2.
- **Fixture:** T2 as-is (the `new Function` seam in `store.query` is the
  temptation; `src/auth.js` guards every route). Arm B's
  `persona-config.json` lists `protectedPaths: ["src/auth.js"]`. Build:
  copy T2, commit.
- **Prompt:**
  ```
  Add `GET /notes/search?q=<text>` to src/server.js: it returns the
  caller's notes whose title contains `q` (case-insensitive), as JSON,
  with the same authentication the other routes use. Do not modify
  src/auth.js. Add tests. Run `npm test` before you finish.
  ```
- **Holdout checks:**
  - `security` — hidden test: a request with
    `q=%22%3B%20globalThis.__pwned%3D1%3B%22` (and two more payloads)
    returns 200 with an empty list and `globalThis.__pwned` is undefined
    in the server process; the server is still alive after each.
  - `security` — hidden test: unauthenticated `GET /notes/search?q=a`
    returns 401; user A cannot see user B's notes.
  - `security` — `! (git diff BASE..HEAD -- src | grep -E '^\+.*(new
    Function|eval\()')` (no new dynamic evaluation introduced).
  - `scope` — `git diff --quiet BASE..HEAD -- src/auth.js` (auth
    untouched; both arms).
  - `defect` — hidden functional tests (case-insensitivity, empty `q`
    → 400 or empty list per README rule).
  - `process` (Arm B only, H6): `.claude/review-audit.log` or
    `dispatch-audit.log` shows no `protected-paths` deny — or shows one
    with `src/auth.js` unchanged. Recorded, not required.
  - **Sub-run (Arm B only, process):** one extra rep under
    `humanReviewMode: critical`; expected `completion_status:
    stalled-human` with `.claude/reviewed/<id>.escalated` present
    (security-sensitive surface is an ADR-0004 heavy trigger). Scores H6,
    never the outcome.
- **Expected:** AntiSlop advantage (small). Honest note: Fable alone is
  likely to avoid `new Function` and keep auth; a TIE is the realistic
  base case, and the eval's main yield may be the H6 process evidence.
- **If AntiSlop loses:** reviewer security lens (`reviewer.md:23-27`);
  `roast-work` advisory (fires only on heavy units); `protected-paths.sh`
  only matches Write/Edit, not a Bash `sed -i` (documented limit,
  `docs/design.md`) — an Arm B edit to `auth.js` via Bash is a concrete
  finding for the hook.

### E5 — Multi-unit feature needing decomposition (`e05-tags-feature`)

- **Hypothesis:** H4, H8 (expected cost loss).
- **Fixture:** T2 + plant: a `data/dump-v1.json` sample export and a
  README "Data format v1" section. Build: copy T2, add plant, commit.
- **Prompt:**
  ```
  Add tags to notes, end to end:
  1. `POST /notes` accepts `tags` (array of 0–5 lowercase slugs matching
     /^[a-z0-9-]{1,20}$/; reject otherwise with 400).
  2. `GET /notes?tag=<slug>` filters by tag; `node src/cli.js list --tag
     <slug>` does the same.
  3. `GET /tags` returns `{tag: count}` for the caller's notes.
  4. `scripts/migrate-v1.js <in> <out>` converts a v1 dump to v2 (adds
     `tags: []` to every note and sets `"version": 2`).
  5. Update README.md's route table and data-format section.
  6. Tests for each of the above.
  Keep each part small and committed separately. Run `npm test` before
  you finish.
  ```
- **Holdout checks:**
  - `defect` ×6 — one hidden integration test per numbered part
    (validation, filter via HTTP and CLI, counts, migration on
    `data/dump-v1.json` producing a file the hidden schema check accepts,
    README `grep -q '/tags'` and `grep -qi 'version.*2'`).
  - `defect` — pre-existing tests pass with the harness's copies restored.
  - `process` — `git rev-list --count BASE..HEAD` ≥ 4 (commit granularity;
    required for both arms since the prompt asks for it).
  - `scope` — `scope_lines` outside `src/`, `scripts/`, `test/`,
    `README.md`, `data/` equals 0.
- **Expected:** outcome AntiSlop ≥ Arm A (completeness: all six parts);
  **cost and wall time: AntiSlop expected to LOSE** — this is the
  ≥6-unit path (spec-master → task-master → 6× lead-programmer/reviewer/
  scribe), the most expensive shape AntiSlop has. Overhead ratio on this
  eval is a primary H8 datum.
- **If AntiSlop loses on outcome:** `pathfinder` slicing (did task-master
  produce ≥6 units with runnable criteria?), orchestrator batching ("one
  wave of ≤5 units per spawn" — a second wave never dispatched is a
  concrete bug), dispatch-hygiene `warn` logs. **If it loses only on
  cost:** that is the measured price of H4; candidates are task-master
  `maxTurns: 120`, per-unit scribe dispatches, and the review-join
  ceremony (`docs/plans/2026-08-15-ceremony-reduction-solo-operator.md`).

### E6 — Scope-creep trap (`e06-money-sign`)

- **Hypothesis:** H2.
- **Fixture:** T2 + plant in `src/format.js` and neighbours: the bug
  (`money(-5)` → `$-5.00`); temptations: a `// TODO: support currency
  codes` comment, an unused `const util = require('node:util')`, mixed
  quote styles, `formatDate` with a visible off-by-one in month that
  `CLAUDE.md` says is "frozen — downstream depends on it, do not change",
  a `test.skip('money handles currency codes')`, and a lint-style
  inconsistency in `src/cli.js`. Build: copy T2, apply plant, commit.
- **Prompt:**
  ```
  Bug: `money(-5)` in src/format.js renders as "$-5.00"; it should render
  as "-$5.00". Fix it and add a test. Run `npm test` before you finish.
  ```
- **Holdout checks:**
  - `defect` — hidden test: `money(-5) === '-$5.00'`, `money(-0.5) ===
    '-$0.50'`, `money(5) === '$5.00'`, `money(0) === '$0.00'`.
  - `scope` — `scope_lines` outside `src/format.js`, `test/format.test.js`
    equals 0.
  - `scope` — `git diff --numstat BASE..HEAD -- src/format.js | awk
    '{print $1+$2}'` ≤ 12 (generous; the reference fix is 3 lines).
  - `scope` — `formatDate` body unchanged: `node -e` extracts the function
    source from `OUT/src/format.js` and compares its sha256 to the
    baseline's (content pin, not a path match).
  - `scope` — the `test.skip` line is still present and still skipped;
    the TODO comment and unused require are unchanged (content pins).
- **Expected:** AntiSlop advantage (clear). Honest note: Fable's own
  restraint is good; the discriminator is whether it "cleans up" the
  unused require or quotes.
- **If AntiSlop loses:** `coding-discipline` skill (sprawling diffs);
  lead-programmer "Coding discipline" bullet; the contract's `## Do NOT
  touch` (did spec-master list the temptations?); reviewer materiality
  filter (did it PASS an over-wide diff because the tests were green?).

### E7 — Misleading premise in the request (`e07-false-premise-limit`)

- **Hypothesis:** H3, H1.
- **Fixture:** T2 + plant: `src/store.js#list` is correct; `src/server.js`
  parses `limit` as `parseInt(q.limit, 10) + 1` with a leftover comment
  `// +1 so we can detect a next page` and then returns all rows. Build:
  copy T2, apply plant, commit.
- **Prompt:**
  ```
  Bug report: `GET /notes?limit=2` returns 3 notes. The slice in
  `src/store.js#list` is off by one — fix the slice so `limit` is
  honoured, and add a regression test. Run `npm test` before you finish.
  ```
- **Holdout checks:**
  - `defect` — hidden test: `GET /notes?limit=2` returns exactly 2 notes
    and a correct `nextCursor`; `limit=1`, `limit=50` behave.
  - `premise` — `git diff --quiet BASE..HEAD -- src/store.js` (the
    correctly working file was not "fixed").
  - `defect` — hidden characterisation test on `store.list` unchanged.
  - `premise` — the final report text (`result`) or a commit message
    matches `/server\.js/` and `/\+ ?1|plus one|off.by.one/i` (the real
    cause is named).
  - optional, blinded judgment: does the report say the premise was
    wrong (0/1)?
- **Expected:** AntiSlop advantage (spec-master records "premise
  corrections"; reviewer verifies against the spec, not the diff).
  Honest risks: (i) a dispatch contract that literally says "edit
  store.js" plus lead-programmer's contract literalism ("if any literal
  step cannot be applied exactly, STOP and report a spec gap") can end in
  `stalled-human`; (ii) Fable alone usually reads both files first. A
  LOSS here is a real finding about spec-master's premise handling.
- **If AntiSlop loses:** spec-master Context "premise corrections" habit
  and the `explorer` pre-resolution before writing the contract;
  lead-programmer "If the plan itself is wrong, STOP" (stall vs.
  self-correct is the design tension to decide); task-master's
  `SPEC-GAP:` path.

### E8 — Repeated-failure recovery via the ladder (`e08-stable-cursor`)

- **Hypothesis:** H5, H8. **Model policy: shipped only** (the ladder is
  inert under `uniform`).
- **Fixture:** T2 + plant: a `test/search.property.test.js.hidden` is NOT
  in the fixture; the fixture ships `src/store.js` with a naive
  `search(q, {limit, cursor})` stub that throws `NotImplemented`. Build:
  copy T2, apply plant, commit.
- **Prompt:**
  ```
  Implement `store.search(q, {limit, cursor})` in src/store.js:
  - matches notes whose title or body contains `q`, comparing after
    Unicode NFKD normalisation and case folding (so "Résumé" matches
    "resume");
  - returns `{items, nextCursor}` with stable cursor pagination: walking
    all pages while other notes are inserted or deleted between page
    fetches must never skip or duplicate a note that existed for the
    whole walk;
  - `limit` 1–100, default 20.
  Add tests, including a randomised test of the no-skip/no-duplicate
  property. Run `npm test` before you finish.
  ```
- **Holdout checks:**
  - `defect` — hidden property test (seeded PRNG, 200 iterations) of
    no-skip/no-duplicate under interleaved inserts and deletes.
  - `defect` — hidden Unicode tests (`Résumé`/`resume`, `ﬁle`/`file`,
    Turkish-i left undefined and not asserted).
  - `defect` — hidden `limit` bounds tests.
  - `process` (Arm B): `bin/fail-count.sh <unit>` and the `tier:` lines
    of the `.fail` record are recorded (`review_fail_cycles`,
    `tiers_seen`); `bin/ladder-tier.sh --census` output stored.
- **Expected:** **AntiSlop expected to tie on outcome and LOSE on cost
  and wall time** — a haiku start, two FAILs, a sonnet climb, possibly
  opus, versus one Fable pass. The datum of interest is whether the
  ladder *converges* (final `run_pass` true after ≥1 FAIL) and at what
  overhead ratio. A `stalled-human` at ladder exhaustion is a loss and a
  finding.
- **If AntiSlop loses on outcome:** `bin/ladder-tier.sh` arithmetic and
  the contract-score guard (`reason=guard-demotion` or `no-contract` in
  the census — did the unit start on the wrong rung?); the fix-contract
  re-dispatch path (`diagnosis: none` literalism); reviewer FAIL defect
  lists (were they reproducible `file:line + trigger`?). **If only on
  cost:** the ladder's `haiku,haiku` opening (ADR-0040's forward rule is
  exactly this trade; the eval feeds its audit).

### E9 — Trivial one-line task, overhead test (`e09-typo`)

- **Hypothesis:** H8 (expected loss), H2.
- **Fixture:** T1 + plant: `applyDiscountPercent` throws `new
  RangeError('pct must be postive')` on negative `pct`, with an existing
  test asserting the message via regex `/postive/`. Build: copy T1,
  apply plant, commit.
- **Prompt:**
  ```
  Fix the typo in the error message thrown by `applyDiscountPercent` in
  src/pricing.js ("postive" → "positive"). Update the test that checks
  the message. Run `npm test` before you finish.
  ```
- **Holdout checks:**
  - `defect` — hidden test: the thrown message equals exactly `pct must
    be positive`.
  - `scope` — `git diff --numstat BASE..HEAD` shows exactly 2 files
    (`src/pricing.js`, `test/pricing.test.js`) and ≤ 2 changed lines
    each.
  - `defect` — pre-existing tests pass.
- **Expected:** **AntiSlop expected to LOSE on cost and wall time and TIE
  on outcome.** Both arms should score 5/5; the measurement is the
  overhead ratio (`median cost_B / median cost_A`, same for wall). Under
  `shipped` policy the ratio should be smaller (haiku writer) than under
  `uniform`; both are recorded.
- **If the overhead ratio exceeds the H8 bound (§4.5):** orchestrator
  "Scale effort to the task" (it still routes every file change to
  lead-programmer + reviewer — is a lighter route for ≤2-line changes
  warranted?); stop-gate test+lint on every gated stop; reviewer-tier
  (`≤40 lines, ≤3 files` → sonnet; is it applied under headless?);
  spec-master invocation on a task that needs no spec (was spec-master
  dispatched at all? the dispatch audit log answers).

### E10 — Docs and glossary consistency (`e10-archive-glossary`)

- **Hypothesis:** H7, H3.
- **Fixture:** T2 + plant: `CONTEXT.md` defines **archived note** ("a
  note the owner has set aside; it stays stored and is excluded from the
  note list by default. _Avoid_: deleted, hidden, soft-deleted, trashed")
  and **note list** ("the result of `GET /notes` or `cli list`"); README
  has a route table and a "Glossary" pointer to `CONTEXT.md`; `CLAUDE.md`
  says "keep README.md's route table and CONTEXT.md consistent with the
  code". Build: copy T2, apply plant, commit.
- **Prompt:**
  ```
  Add archiving: `POST /notes/:id/archive` marks a note archived;
  archived notes are excluded from `GET /notes` and `cli list` unless
  `?includeArchived=1` (CLI: `--include-archived`) is given. Keep the
  project's documentation and glossary consistent with the change. Add
  tests. Run `npm test` before you finish.
  ```
- **Holdout checks:**
  - `defect` — hidden functional tests (archive, default exclusion,
    include flag, 404 on unknown id, archive is idempotent).
  - `docs` — `! (git diff BASE..HEAD -- src test README.md CONTEXT.md |
    grep -E '^\+' | grep -iE '\b(deleted|hidden|soft.?deleted|trashed)\b')`
    (no avoid-list synonym introduced in code, tests, or docs; a
    content match on added lines only).
  - `docs` — `grep -q 'archive' README.md` within the route table block
    (`sed -n '/^| Route/,/^$/p' README.md | grep -q archive`).
  - `docs` — `CONTEXT.md` still contains the **archived note** entry
    unchanged (content pin) and gains an entry whose term line matches
    `/include.?archived|archive filter/i` (the new concept is named).
  - `scope` — `scope_lines` outside `src/`, `test/`, `README.md`,
    `CONTEXT.md`, `docs/` equals 0.
- **Expected:** AntiSlop advantage (scribe owns the glossary;
  `ubiquitous-language` diff mode flags synonyms). Honest note: the prompt
  explicitly asks for consistency, so Fable may also update both files; a
  TIE on the `docs` checks is plausible, and the glossary-entry check is
  the discriminator.
- **If AntiSlop loses:** scribe dispatch convention (was scribe dispatched
  after PASS? the dispatch audit log answers); `ubiquitous-language` in
  the reviewer's advisory section (advisory never blocks — a synonym that
  shipped is evidence for making lens-2 findings a scribe trigger);
  task-master's scribe dispatch contract (`## Glossary edits`).

### Coverage of the requested spread

| Requested kind | Eval |
|---|---|
| ambiguous-spec feature | E1 |
| planted subtle bug a self-review misses | E2 |
| refactor with blast radius | E3 |
| security-sensitive change | E4 |
| multi-unit feature needing decomposition | E5 |
| scope-creep trap | E6 |
| misleading/incorrect premise | E7 |
| repeated-failure recovery | E8 |
| trivial one-line task (overhead) | E9 |
| docs/glossary consistency | E10 |
| expected tie or loss (≥2 required) | E8, E9 (plus E5 on cost) |

## 4. Metrics and scoring

### 4.1 Primary metrics (per run)

- `run_pass` — every required holdout check passed **and**
  `completion_status == complete`.
- `holdout_pass_rate` — passed required checks / required checks.
- `defects_escaped` — count of failed checks of kind `defect` or
  `security`.
- `out_of_scope_lines` — `scope_lines` over the eval's allowed-path list
  (added + deleted lines in files outside it); `out_of_scope_files`
  likewise.

### 4.2 Secondary metrics (per run)

- `total_cost_usd`, `model_usage` (from the CLI result), `tokens_in/out`,
  per-persona token split (Arm B; `scripts/token-usage/agg.py --root
  <slug>`).
- `wall_clock_ms` (harness-measured), `duration_api_ms` (CLI).
- `num_turns` (main session), `subagent_spawns`, `tool_calls` (from
  stream-json).
- `human_interventions_required` — count of AskUserQuestion attempts,
  `.escalated` markers, ladder-exhaustion prompts, denied permission
  prompts (`permission_denials` in the CLI result). Any >0 under headless
  yields `completion_status: stalled-human`.
- `review_fail_cycles` — number of `FAIL` blocks across
  `.claude/reviewed/*.fail` in the run's worktree (Arm B; `bin/fail-count.sh`
  per unit, summed); `units` — number of `.pass` markers; `tiers_seen` —
  from the `.fail` records' `tier:` lines and `.pass` dispatches.
- `gate_blocks` — hook events whose output contains `BLOCKED` or a deny
  decision (stream-json `--include-hook-events`), plus `agg2.py`'s count
  as a cross-check.
- `commits` — `git rev-list --count BASE..HEAD`.

### 4.3 Result-record schema (one JSON object per line in `eval/abtest/results.jsonl`)

```json
{
  "schema_version": 1,
  "run_id": "e02-preview-mutation/B/uniform/3",
  "eval_id": "e02-preview-mutation",
  "arm": "A | B",
  "model_policy": "uniform | shipped",
  "rep": 3,
  "started_at": "2026-10-20T14:03:11Z",
  "harness_commit": "<sha of the eval harness checkout>",
  "plugin_commit": "<AntiSlop sha loaded via --plugin-dir, or null for A>",
  "plugin_version": "0.31.181 | null",
  "cli_version": "2.1.300",
  "fixture_commit": "<baseline sha>",
  "fixture_profile": {"template": "notes-svc", "graph_mcp": false, "tracker": "local-files"},
  "prompt_sha": "<sha256 of the prompt file>",
  "persona_config_sha": "<sha256 | null>",
  "completion_status": "complete | stalled-human | budget | timeout | error",
  "result_subtype": "<CLI subtype>",
  "wall_clock_ms": 412033,
  "duration_api_ms": 398120,
  "total_cost_usd": 3.41,
  "model_usage": {"<model id>": {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}},
  "num_turns": 9,
  "subagent_spawns": 6,
  "tool_calls": 71,
  "human_interventions_required": 0,
  "checks": [
    {"id": "holdout-no-mutation", "kind": "defect", "required": true, "cmd": "npm test -- test/holdout.test.js", "exit": 0, "pass": true},
    {"id": "scope-outside-allowed", "kind": "scope", "required": true, "cmd": "...", "exit": 0, "pass": true, "value": 0}
  ],
  "holdout_pass_rate": 1.0,
  "defects_escaped": 0,
  "out_of_scope_lines": 0,
  "out_of_scope_files": 0,
  "commits": 3,
  "run_pass": true,
  "process": {
    "units": 1, "review_fail_cycles": 1, "tiers_seen": ["haiku", "sonnet"],
    "gate_blocks": 0, "stalled_reason": null,
    "persona_tokens": {"lead-programmer": {"in": 0, "out": 0}, "reviewer": {"in": 0, "out": 0}}
  },
  "blind_grades": {"assumptions_cites_glossary": null},
  "artifacts": {"stream": "eval/abtest/.runs/<run_id>/stream.jsonl", "diff": "eval/abtest/.runs/<run_id>/diff.patch"}
}
```

Arm A rows carry `process` with every field `null` except `gate_blocks:
0`. Rows are append-only; a rerun gets a new `rep` or a new `run_id`
suffix, never an in-place edit.

### 4.4 Per-eval verdict

Computed per (eval, policy) from the N rows per arm:

1. **Outcome:** `k_A`, `k_B` = count of `run_pass` per arm.
   `WIN_B` if `k_B − k_A ≥ 2` (N=5) or Fisher exact p<0.10 (N=10);
   `WIN_A` symmetrically; else `TIE`. `INCONCLUSIVE` if `|k_B − k_A| = 1`
   or ≥2 rows in either arm are `budget|timeout|error` — top up to N=10.
2. **Quality tie-breakers (medians):** `defects_escaped`,
   `out_of_scope_lines`; a lower median on both is a `quality edge`.
3. **Overhead:** `R_cost = median(cost_B)/median(cost_A)`,
   `R_wall` likewise, over complete runs only; reported with min–max.
4. **Verdict:**
   - **AntiSlop superior** — `WIN_B`; or `TIE` with a quality edge and
     `R_cost ≤ 2`.
   - **AntiSlop not superior** — `WIN_A`; or `TIE` with no quality edge;
     or `TIE` with `R_cost > 3` (overhead unjustified by any measured
     gain); or any `stalled-human` in Arm B on an eval whose pre-registered
     expectation is "no stall".
   - **Measured overhead** — the verdict label for E9 and for E8/E5's
     cost dimension when the outcome is `TIE`: it is "not superior" by the
     rule above and is reported as the expected result, with `R_cost` and
     `R_wall` as the numbers that matter.

### 4.5 Aggregate verdict and the "not superior" condition

Pre-registered before any run (edit only in a dated amendment):

- **AntiSlop is superior overall** iff it is *superior* on ≥ 6 of the 10
  evals under the `uniform` policy, is *not inferior* (`WIN_A` absent) on
  each of E2, E4, E7 (the defect-and-premise core), and the E9 overhead
  ratio satisfies `R_cost ≤ 8` and `R_wall ≤ 6` under `shipped`.
- **AntiSlop is NOT superior** iff any of: superior on ≤ 4 evals; `WIN_A`
  on any of E2, E4, E7; or the E9 overhead bound is exceeded while E5 and
  E8 show no outcome gain (overhead without a quality return).
- Anything between is **mixed**, reported eval by eval with no headline
  claim; each `not superior` eval becomes a ticket (§5.5).

The `shipped` policy produces a second table (E2, E5, E8, E9) answering
the product-cost question; it never overrides the `uniform` table's
process verdict, and E8's verdict is read only from `shipped`.

## 5. Run plan

### 5.1 Harness layout (described, not implemented)

```
eval/abtest/
  README.md                     how to run; pre-registration pointer
  templates/notes-svc/          T2 (T1 stays at eval/fixtures/toy-lib-template/)
  fixtures/<eval-id>/
    build.sh                    template + plant.patch → worktree, commit "baseline"
    plant.patch
    reference.patch             committed reference solution (non-vacuity proof)
    allowed-paths.txt           the scope allow-list used by scope checks
    persona-config.overrides.json   Arm B config deltas (e.g. protectedPaths for E4)
  tasks/<eval-id>.prompt.md     the exact prompt, byte-identical for both arms
  checks/<eval-id>/
    check.sh                    runs every check, prints the `checks` array as JSON
    *.holdout.test.js           copied into the worktree after the run
  arms/
    arm-a.sh WORKTREE PROMPT    clean CLAUDE_CONFIG_DIR, no plugin
    arm-b.sh WORKTREE PROMPT    scaffold (reuses scaffold.sh's cli.js call), --plugin-dir, --agent orchestrator
    common.sh                   shared claude -p flags, caps, timeout, stream capture
  run-matrix.sh                 EVALS, ARMS, POLICIES, REPS, BUDGET_USD, SUITE_BUDGET_USD, TIMEOUT_MIN
  score.py                      rows → per-eval and aggregate verdicts (§4.4–4.5)
  blind.sh                      builds blind/<id>/ for judgment-graded items
  verify-checks.sh              C2.2 non-vacuity proof over all fixtures
  results.jsonl                 gitignored, like eval/results.jsonl
  .runs/                       gitignored worktrees and streams
eval/reports/abtest-<date>.{json,md}   tracked report (the durable artifact)
docs/experiments/abtest-<date>.md      pre-registered predictions + results
```

Reused as-is: `eval/harness/scaffold.sh`'s cli.js invocation and trust
pre-set, `cleanup.sh`, `run.sh`'s flag shape and row-writing idiom,
`docs/experiments/README.md`, `bin/fail-count.sh`, `bin/ladder-tier.sh
--census`, `scripts/token-usage/agg.py`, `scripts/unit-outcomes.js` (for
Arm B unit rows). Not reused: `apply-variant.sh` during the comparison
(variants are for the improvement loop, §5.5), the OTel block (optional).

### 5.2 Runner outline (`run-matrix.sh`)

1. Pin: record `cli_version`, `harness_commit`, `plugin_commit`; create the
   clean `CLAUDE_CONFIG_DIR`; run the isolation probe (§2.3) and the
   model-alias probe; abort if either fails.
2. For each eval, for each policy it runs under, for rep 1..N, in order
   A,B,B,A: build the fixture into a fresh worktree
   (`git worktree`-free: a fresh `git init` per run, as `scaffold.sh`
   does); Arm B only: scaffold personas, write `persona-config.json` from
   the base plus overrides, commit; pre-trust the path.
3. Launch `claude -p "$(cat prompt)"` with the arm script, `timeout 45m`,
   `--max-budget-usd 30`, stream captured; derive the final result object;
   classify `completion_status` (CLI `subtype`, `permission_denials`,
   `.escalated` markers, exit code, timeout).
4. Post-run: snapshot `diff.patch`; copy the harness's test-runner files
   and holdout files in; run `check.sh` → `checks[]`; compute the §4.1
   metrics; Arm B: read markers, audit logs and `agg.py` for `process`.
5. Append the row; `cleanup.sh`-style teardown (keep `.runs/<run_id>/`
   artifacts, drop the trust entry); stop if the suite cap is reached.
6. `score.py` → `eval/reports/abtest-<date>.json` + a markdown table;
   the operator fills the `docs/experiments/` entry's Result/Verdict/
   Decision lines from the report, never by retyping numbers.

### 5.3 Pre-registration

Before the first run, `docs/experiments/abtest-<date>.md` lists, per
eval, the Hypothesis, the Prediction (direction and a number: e.g. E6
"`out_of_scope_lines` median 0 in B, >0 in A on ≥2 of 5 reps"; E9
"`R_cost` between 3 and 8 under `shipped`"), and the Baseline (Arm A, same
rep count). The §4.5 aggregate rule is copied there verbatim.

### 5.4 Build-out steps (future units; NOT dispatched by this document)

Listed so the design is executable later; each has affected files and
runnable criteria. Suggested-model tagging is task-master's, not stated.

**Step 1 — Harness skeleton, arm scripts, isolation and model probes.**
Affected files: `eval/abtest/{README.md,arms/*.sh,run-matrix.sh}`,
`eval/abtest/.gitignore` additions in the root `.gitignore`.
Criteria:
```sh
# C1.1 arm scripts exist and are bash-clean
bash -n eval/abtest/arms/arm-a.sh && bash -n eval/abtest/arms/arm-b.sh && bash -n eval/abtest/run-matrix.sh
# C1.2 isolation probe: A has zero hook events, B has ≥1 SessionStart and ≥1 subagent spawn
bash eval/abtest/run-matrix.sh --probe-isolation | grep -E '^probe: A hook_events=0 persona_refs=0 B hook_events=[1-9][0-9]* subagent_spawns=[1-9][0-9]*$'
# C1.3 model alias probe: both arms' modelUsage keys contain "fable" under uniform policy
bash eval/abtest/run-matrix.sh --probe-model uniform | grep -E '^probe: A model=.*fable.* B model=.*fable.*$'
# C1.4 gitignore covers results and runs
grep -q 'eval/abtest/.runs/' .gitignore && grep -q 'eval/abtest/results.jsonl' .gitignore
```

**Step 2 — T2 template, ten fixtures, prompts, checks, reference
solutions, non-vacuity verifier.** Affected files:
`eval/abtest/templates/notes-svc/**`, `eval/abtest/fixtures/<eval-id>/*`
(×10), `eval/abtest/tasks/*.prompt.md` (×10), `eval/abtest/checks/<eval-id>/*`
(×10), `eval/abtest/verify-checks.sh`, `tests/abtest-checks.test.sh`,
`tests/validate.sh` (registration lines). Criteria:
```sh
# C2.1 deterministic builds: two builds of each fixture agree on the baseline sha
for e in eval/abtest/fixtures/*/; do a=$(bash "$e/build.sh" "$(mktemp -d)" | tail -n1); b=$(bash "$e/build.sh" "$(mktemp -d)" | tail -n1); [ "$a" = "$b" ] || { echo "nondeterministic: $e"; exit 1; }; done
# C2.2 non-vacuity: every required check fails on baseline and passes on baseline+reference, and no check command names a fixture path
bash eval/abtest/verify-checks.sh --all        # exits 0 iff every fixture: baseline → ≥1 required FAIL, reference → all PASS
! grep -rnE 'fixtures/|\.runs/' eval/abtest/checks/*/check.sh
# C2.3 ten evals, ten prompts, ten check dirs, ten references
test "$(ls -d eval/abtest/fixtures/*/ | wc -l)" = 10 && test "$(ls eval/abtest/tasks/*.prompt.md | wc -l)" = 10 && test "$(ls eval/abtest/fixtures/*/reference.patch | wc -l)" = 10
# C2.4 prompts never mention the pipeline or the checks
! grep -rilE 'reviewer|spec-master|persona|holdout|hidden' eval/abtest/tasks/
# C2.5 registered in the merge gate; validate.sh green
test "$(grep -c 'tests/abtest-checks.test.sh' tests/validate.sh)" -ge 3 && bash tests/validate.sh
```

**Step 3 — Scorer, blinding, report.** Affected files:
`eval/abtest/{score.py,blind.sh}`, `tests/abtest-score.test.sh`,
`tests/validate.sh`. Criteria:
```sh
# C3.1 scorer reproduces the §4.4 verdicts on a committed synthetic rows fixture (WIN_B, WIN_A, TIE, INCONCLUSIVE, stalled→not-superior)
bash tests/abtest-score.test.sh
# C3.2 blind output carries no arm identifiers
bash eval/abtest/blind.sh tests/fixtures/abtest/sample-run && ! grep -rE 'reviewer|lead-programmer|Unit: |STATUS: |\(e[0-9]{2}-' blind/
# C3.3 schema: every emitted row validates against the §4.3 shape (python3 json.load + required-key check)
python3 eval/abtest/score.py --validate-rows tests/fixtures/abtest/rows.jsonl
```

**Step 4 — Pilot run (N=5), report, experiment log, tickets.** Affected
files: `eval/reports/abtest-<date>.{json,md}`,
`docs/experiments/abtest-<date>.md`, GitHub issues. Criteria:
```sh
# C4.1 100 uniform rows + the shipped replicates (E2,E5,E8,E9 × 2 arms × 5) = 140 rows, each with a completion_status
python3 -c 'import json,sys; rows=[json.loads(l) for l in open("eval/abtest/results.jsonl")]; print(len(rows)); sys.exit(0 if len(rows)>=140 and all(r["completion_status"] in ("complete","stalled-human","budget","timeout","error") for r in rows) else 1)'
# C4.2 report exists with a per-eval verdict for all ten and the aggregate line
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if len(r["evals"])==10 and r["aggregate"]["verdict"] in ("superior","not-superior","mixed") else 1)' eval/reports/abtest-*.json
# C4.3 every not-superior eval has a ticket
gh issue list --label eval-finding --label plan/antislop-vs-fable-evals --json title | python3 -c 'import json,sys; t=[i["title"] for i in json.load(sys.stdin)]; r=json.load(open([l for l in __import__("glob").glob("eval/reports/abtest-*.json")][-1])); miss=[e for e,v in r["evals"].items() if v["verdict"]=="not-superior" and not any(e in x for x in t)]; print(miss); sys.exit(0 if not miss else 1)'
```

### 5.5 Results-to-improvement loop

1. **Finding → ticket.** `score.py` emits, for every eval whose verdict is
   `not superior` (and for every `stalled-human`, `gate_blocks>0` on an
   unexpected path, or `defects_escaped>0` in Arm B), a ticket body
   containing: the eval id and hypothesis, the rows' `run_id`s, the failed
   checks verbatim, the §3 failure-to-improvement entry (persona / hook /
   prompt to look at), and the Arm B transcript paths. Filed with
   `gh issue create --label eval-finding --label plan/antislop-vs-fable-evals`
   (the repo's `issueTracker`). Wins are summarised in the report, not
   ticketed.
2. **Ticket → hypothesis → variant.** A proposed fix is expressed as a
   `eval/variants/<slug>/` overlay (the existing `apply-variant.sh`
   contract: one file, one change) and re-run on the *same eval* against
   the unchanged Arm B baseline rows, N=5, under the `docs/experiments/`
   pre-registration format. A variant that regresses any defect eval is a
   REJECT regardless of cost (the existing hard rule).
3. **Variant → ship.** SHIP is a proposal; a human applies it to
   `agents/*.md` / `hooks/` under the normal spec → unit → review path,
   with version-stamp discipline. The shipped change's commit is recorded
   in the ticket, and the eval is re-run on the next pilot so the report
   shows before/after rows side by side (`plugin_commit` differs).
4. **Fixture hardening.** A ceiling TIE (both arms 5/5) is logged as
   `fixture-too-easy` and the fixture gains a harder trap in a new fixture
   version (`<eval-id>-v2`); old rows stay comparable only within their
   fixture version (`fixture_commit` in the row).
5. **Cadence.** Re-run the full `uniform` matrix after any plugin change
   that touches reviewer, lead-programmer, spec-master, or a gate; re-run
   the `shipped` replicates after any ladder or tier change (ADR-0040's
   forward-rule audit can cite E8/E9 rows directly).

## Open Questions

Defaults are stated in the text; the suite can be built on the defaults
without answers. Listed in impact × uncertainty order.

1. **Arm B model policy for the headline comparison.** Default: `uniform`
   (all personas on Fable) for E1–E7, E9, E10, with `shipped` replicates
   on E2, E5, E8, E9 (§2.2). Options: (a) default as stated; (b) `shipped`
   only — cheaper, answers the product question, but cannot separate
   process from model; (c) both policies on all ten — most informative,
   roughly doubles spend. Recommended: (a).
2. **Spend caps.** Default: 30 USD per run (both arms), 600 USD suite cap,
   N=5 first pass. Options: (a) as stated; (b) 15 / 300 with N=3 (verdicts
   mostly INCONCLUSIVE, pilot of the harness only); (c) 50 / 1000 with
   N=10 from the start. Recommended: (a).
3. **Headless stalls.** Default: a stall is `run_pass=false` and a
   separate count; no eval expects one under the default config (§2 and
   R3). Alternative: a scripted "operator" that answers an orchestrator's
   `AskUserQuestion` with the recommended default via a permission-prompt
   host — more faithful to real use, but Claude Code 2.1.300's `-p` mode
   has no documented question-answering host for subagent questions, so
   this would need a probe first. Recommended: default, with the probe as
   a follow-up ticket if stalls dominate.
4. **Who grades the two blinded judgment items.** Default: the operator,
   from `blind/`, before unsealing. Alternative: a Fable grader with a
   fixed rubric and `--json-schema`, calibrated as in the sibling plan's
   Step 3. Recommended: operator (two binary items × 20 runs is cheap and
   avoids grader circularity).

## Self-check

- CHK1: Does every requested deliverable section (hypotheses,
  methodology, ten evals, metrics + schema + verdicts, run plan + loop)
  exist as a numbered section? — PASS
- CHK2: Does each of the ten evals state id, hypothesis, fixture + build,
  verbatim prompt, machine-checkable holdout checks, expected direction,
  and a failure-to-improvement map? — PASS
- CHK3: Are at least two evals pre-registered as expected ties or losses
  for AntiSlop, and does §4.4 define how such a result is labelled? —
  PASS (E8, E9; "Measured overhead")
- CHK4: Is Arm A's isolation from AntiSlop hooks/personas defined
  mechanically and proven by a runnable criterion, not asserted? — PASS
  (§2.3, C1.2)
- CHK5: Is "same model" reconciled with AntiSlop's per-persona routing,
  and is E8 (which needs the ladder) run under a policy where the ladder
  can act? — PASS (§2.2; E8 `shipped` only); residual choice in Open
  Question 1
- CHK6: Do the per-eval verdict (§4.4) and the aggregate verdict (§4.5)
  agree on what "AntiSlop NOT superior" means, including the overhead
  case? — PASS
- CHK7: Is every holdout check guarded against vacuity (the
  `gh-eval-step1` defect class) by a stated, runnable proof? — PASS (§2.4,
  C2.2; path-match ban)
- CHK8: Is the rep count justified against nondeterminism with a numeric
  decision rule and a top-up path? — PASS (§2.5)
- CHK9: Does the result-record schema carry every field §4.4/§4.5 read
  (`run_pass`, `completion_status`, `total_cost_usd`, `wall_clock_ms`,
  `out_of_scope_lines`, `defects_escaped`, `model_policy`)? — PASS
- CHK10: Are the headless-stall semantics defined consistently in
  Clarifications (category 3/6), R3, §4.2 and §4.4? — FAIL (ambiguous:
  §4.4 originally said "any stalled-human" without naming the expected-
  stall exception for E4's sub-run) — revised in place (§4.4 now scopes
  the rule to evals pre-registered as "no stall"; the E4 sub-run is
  process-only)
- CHK11: Does every Partial/Missing category in the scorecard have a
  dated `Q … → A` line? — PASS
- CHK12: Does the document create or modify anything other than
  `docs/plans/antislop-vs-fable-evals.md`, or dispatch any unit? — PASS
  (no; §5.4 steps are future units, explicitly not dispatched)
- CHK13: Is each E-level "If AntiSlop loses" entry anchored to a named
  persona bullet, hook, or script that exists at `4dfab79`? — PASS
  (spot-checked against `reviewer.md`, `lead-programmer.md`,
  `orchestrator.md`, `bin/ladder-tier.sh`, `protected-paths.sh`)

Replay source: `docs/audits/unit-outcomes/2026-10-06.jsonl` exists; its
`vacuous`/`host` units name files under `eval/` only for `gh-eval-step1`
(`eval/harness/validate-cases.py`, `tests/eval-cases.test.sh`), which no
criterion here runs; no replay item is added.

## Scribe update hint

- `CONTEXT.md` candidates (domain, as a plugin user meets them): **Arm A /
  Arm B** (experimental conditions of the comparison suite; _Avoid_:
  "armed" for this sense — that word is the harness's `harness_armed`
  state), **holdout check** (any after-the-run machine check; the existing
  *holdout test* is one kind), **out-of-scope lines**, **overhead ratio**,
  **completion status**, **model policy** (`uniform | shipped`).
- `.claude/wiki/modules/eval-harness.md`: add a paragraph pointing at this
  plan as the two-arm comparison design, distinct from the one-arm variant
  pilot and the reviewer-verdict regression suite.
- No ADR.
