# Reviewer behavior-regression eval suite (openai/evals-inspired)

Status: FINAL — Open Questions 1–3 answered by the operator on 2026-09-11
(each on the recommended default; see the Clarifications log and the
resolved Open Questions section). Published via `to-spec` as umbrella
issue #458 (see the Publication note). Authored 2026-09-11 at HEAD
`0a5115b` by spec-master (model override: fable, at the operator's explicit
request).

Dispatch path: this spec resolves to **7 dispatchable units** (Steps 1–7),
which is at or above the publish threshold (≥6) and above the fast-path
threshold (≤5). **Standard path applies**: `task-master` slices it via
`to-tickets`; no nine-element dispatch contracts are emitted here. The
umbrella `[spec]` issue is published via `to-spec` after OQs resolve, with
this document named as canonical.

## Goal

Add a registry-driven regression eval for the `reviewer` persona's **verdict
quality** — a fixed input (a diff with a known, injected defect or a known
clean change, plus its dispatch packet) mapped to a gold verdict — scored
first deterministically (verdict token match) and then by a calibrated
model-graded scorer (did the reviewer's defect list identify the gold
defects?), run under both `sonnet` and `opus` tiers, producing tracked
per-tier catch-rate data that can inform (never automatically change)
`hooks/scripts/reviewer-tier.sh`'s thresholds. It lives inside the existing
`eval/harness/` as a new case type, is authored as YAML cases under an
openai/evals-style `<name>.<split>.<version>` registry, runs as a
manually-triggered/optionally-scheduled "behavior regression" job, and
**never becomes a hook gate**.

Every Goal clause maps to a step criterion (per the goal-prose/step-table
drift rule): registry + YAML cases → Step 1; fixed input → verdict runner →
Step 2; model-graded scorer + calibration → Step 3; gold corpus → Step 4;
both tiers + tracked catch-rate data + CI job + never-a-gate → Steps 5–6;
vocabulary → Step 7.

## Context

**What exists (measured 2026-09-11 at `0a5115b`):**

- `eval/harness/{scaffold,apply-variant,run,pilot,more-reps,cleanup,probe-namespaced-dispatch}.sh`;
  `eval/fixtures/toy-lib-template/` (cart pricing lib with a planted
  mutation trap: `applyDiscountPercent` mutates its input);
  `eval/tasks/feature-task.{md,holdout.test.js}`; `eval/results.jsonl`
  (31 rows, all `task: feature-task`, dated 2026-07-11).
- `run.sh` invokes `claude -p` headlessly with `--output-format json`,
  `--max-budget-usd` (default 1.00), `--model` (default sonnet),
  `--no-session-persistence`, and appends one JSON row per run.
- `scaffold.sh` renders the persona system into the fixture via
  `node bin/cli.js --personas=spec-master,task-master,reviewer`, writes the
  fixture's `.claude/persona-config.json` **without** a `humanReviewMode`
  key (which the reviewer resolves to `critical`), pre-trusts the workspace
  in `~/.claude.json`, and commits a baseline.
- `apply-variant.sh DEST SLUG` overlays `eval/variants/<slug>/` onto
  `DEST/.claude/`; `baseline` is a no-op. **`eval/variants/` does not exist
  in the tree** — the `inject-skip-review` / `inject-self-pass` variants in
  `docs/specs/2026-07-13-hardening-eval-spec.md` are specifications that
  were never built. "Reuse the variant structure" in the brief therefore
  means reuse the overlay *contract* (`apply-variant.sh` unchanged), not an
  artifact.
- `.gitignore:5-6` ignores `eval/.runs/` and `eval/results.jsonl`. Raw rows
  are untracked by convention; any durable catch-rate evidence needs a
  tracked artifact.
- `tests/validate.sh:89` excludes `eval/` from the npm-pack check and
  registers nothing under `eval/` (explorer, grep-derived). Marker note
  unit 149: "eval/ … has no test/shellcheck/CI coverage … consistent with
  eval/ being a dev-scratch directory."
- Reviewer verdict vocabulary: `templates/persona-protocol.md:216-219`
  (canonical) and `agents/reviewer.md:82-98` — the final message is ONLY the
  verdict; PASS = one line naming criteria checked; FAIL = the verdict line
  then a bare defect list (`file:line` + how to trigger); advisory sections
  (`roast-work`, `ubiquitous-language`) may follow, never precede. No test
  asserts the four tokens; no regex enforces the shape.
- `agents/reviewer.md` frontmatter: `model: opus`, `maxTurns: 50`,
  `tools: Read, Grep, Glob, Bash, Agent, Skill, SendMessage`.
- ESCALATE-TO-HUMAN (`agents/reviewer.md:188-259`) is a gate on a would-be
  PASS driven by `humanReviewMode` (`all`, or `critical` + ADR-0004's
  heavy-unit trigger, criteria 2/3 being reviewer judgment). It is a
  function of fixture config and change surface, not of whether the diff is
  correct.
- `hooks/scripts/reviewer-tier.sh` (ADR-0009): prints `sonnet` iff
  `.fail` absent AND range measurable AND no sensitive path AND ≤40 lines
  AND ≤3 files; else `opus`. Thresholds duplicated in prose at
  `tests/reviewer-tier.test.sh`, `docs/adr/0009:46`, and
  `docs/plans/2026-08-01-efficiency-audit-remediation-pass1.md`. Measured
  2026-08-03: 8/60 commits sonnet-eligible. **Out of scope to modify.**
- `hooks/hooks.json` registers 12 distinct scripts across 6 events
  (PreToolUse×3, PostToolUse, Stop, SubagentStop, SessionStart,
  TaskCompleted). None is eval-related; this plan adds none.
- `claude` CLI (measured live 2026-09-11, haiku probe): `--agent <agent>`
  ("Agent for the current session. Overrides the 'agent' setting"),
  `--append-system-prompt[-file]`, `--json-schema <schema>` (structured
  output), `--model`; `--output-format json` returns `result` (final
  message text), `modelUsage` (map keyed by concrete model id, e.g.
  `claude-haiku-4-5-20251001`), `permission_denials`, `total_cost_usd`,
  `num_turns`, `subtype`, `is_error`.
- PyYAML 6.0.3 is importable by the system `python3`; no `js-yaml`. The
  harness already uses `python3` heredocs for JSON (`run.sh:75-118`).
- Cost reference: prior `feature-task` implementer runs cost $0.49–$0.87
  (sonnet, 4–18 turns). A review of a ≤100-line diff on the toy fixture is
  expected in the same band or below.

**openai/evals mapping adopted (research already vetted; not re-derived):**
registry YAML names a suite `<name>.<split>.<version>` and points at a
dataset; grading is `Match` (string-level) or model-graded (a second LLM
judges against a rubric). Here: `reviewer-verdict.gold.v1` (labelled
corpus) and `reviewer-verdict.grader.v1` (grader-calibration set); `Match`
= verdict token equality; model-graded = per-defect identification.

**Premise corrections to the brief** (recorded so downstream personas do not
re-inherit them): (a) no `inject-*` variant exists on disk; (b) "correct
PASS/FAIL/ESCALATE-TO-HUMAN verdicts" — ESCALATE is not derivable from the
diff (see OQ1); (c) `eval/` currently has zero merge-gate coverage, so "wire
it into the existing harness" adds tests where none exist rather than
extending existing ones; (d) `results.jsonl` is gitignored, so "data that
can inform thresholds" needs a tracked report, not only rows.

**Marker-audit sweep dispositions** (`bin/marker-audit.sh . --notes
--surface=<path>`, 2026-09-11; best-effort, `.claude/reviewed/` is untracked
per-clone state):
- `--surface=eval/`: unit 149 (eval/ uncovered by validate.sh) — disposed of
  by Step 1/2/5: the deterministic parts (case validator, verdict parser,
  summary aggregator) gain `tests/*.test.sh` registered in `validate.sh`;
  the LLM-invoking driver stays out of the merge gate by design.
  rpg-comment-3 N2 (reviewed-path-gate eval/exec/source scan) — unrelated
  to this plan (the word "eval" collides), no action.
- `--surface=hooks/scripts/reviewer-tier.sh`: units 199, 265–267, gh308,
  gh309 (the `<HEAD>` placeholder false positive in orchestrator.md; the
  "run from the repo root" comment) — this plan does not edit
  `reviewer-tier.sh` or `orchestrator.md`; no action. gh348-13 note 4
  (`git diff --exit-code` on a clean tree is trivially 0) — adopted as a
  rule here: every "unchanged" guard below is a **content pin**, never a
  `git diff` check.
- `--surface=tests/` (313 untagged notes): none names `tests/validate.sh`'s
  registration block or any file this plan creates; the only `validate.sh`
  edit here is three registration lines per new test, matching the existing
  `if bash tests/<x>; then echo OK … else echo FAIL …` shape at
  `tests/validate.sh:320-333`.
- `--surface=docs/specs/`: grilling-fix-1 (speckit-ports stale cap) —
  unrelated.
- No `.fail` record exists for any eval-harness unit (full directory
  enumerated, 2026-09-11); no re-scoping hazard.

**Ubiquitous-language check (prose mode, request + this draft, against
`CONTEXT.md`, 183 entries):**
- Lens 1 (glossary term, divergent meaning): the brief's "reusing the
  `inject-skip-review`-style **variant** structure" for gold cases. In
  `.claude/wiki/modules/eval-harness.md:3` and `docs/experiments/README.md`
  a *variant* is a persona/hook overlay — the thing under test — whereas a
  gold case is an *input*. This plan keeps "variant" for overlays and
  introduces "case" for inputs; a run is `variant × tier × case × rep`.
  "Gate" (CONTEXT.md:166, a hook script that mechanically blocks) is used
  here only in that sense.
- Lens 2 (new synonym for a defined term): "catch rate" (brief) =
  "defect-catch rate" (`docs/experiments/README.md:37`); this plan uses
  "catch rate" as the short form and defines it once (Step 5). "tier"
  matches **Measured reviewer tier** (CONTEXT.md:806).
- Lens 3 (load-bearing new terms, no entry — suggestions for `scribe`,
  Step 7): *behavior regression* (suite class), *protocol adherence* (the
  hook chain's check class), *gold case / gold corpus*, *eval registry*,
  *split* (in the `<name>.<split>.<version>` sense), *model-graded scorer*,
  *grader calibration split*, *verdict match*, *eval-mode dispatch*.
  Advisory only; informs the category-8 score below.

## Clarifications
1. Functional scope & success criteria: Partial
2. Domain entities / data model: Missing
3. User interaction flow: Partial
4. Non-functional attributes (perf, security, scale): Partial
5. External dependencies & integrations: Partial
6. Edge cases / failure handling: Missing
7. Technical constraints & tradeoffs: Partial
8. Terminology consistency: Partial
9. Completion / acceptance signals: Missing

- 2026-09-11 Functional scope & success criteria: Q Which verdict tokens
  are in the gold vocabulary — PASS/FAIL only, or also ESCALATE-TO-HUMAN as
  the brief says? → A (default, confirmed by OQ1 below): PASS and FAIL only in
  `reviewer-verdict.gold.v1`; the runner sets the fixture's
  `humanReviewMode` to `off` so a would-be PASS is never converted to
  ESCALATE by config. An observed INSUFFICIENT-CONTEXT or ESCALATE-TO-HUMAN
  is recorded verbatim and scored as a verdict mismatch. An `escalation`
  split under `critical` mode is out of scope for v1.
- 2026-09-11 Functional scope & success criteria: Q What does "suite
  passes" mean? → A (self-resolved): per-tier `min_verdict_match` floors in
  the registry, initially `null` (report-only). Step 6's baseline run sets
  the opus floor to (baseline matched cases − 1)/N and leaves sonnet's
  `null` (sonnet is the thing being measured, not gated). Exit 0 = every
  non-null floor met; exit 1 = a floor missed; exit 2 = infrastructure
  failure (grader uncalibrated, budget exceeded, no rows).
- 2026-09-11 Domain entities / data model: Q What is a case, what is gold,
  where do they live, and what is the row shape? → A (self-resolved): see
  "Data model" under Step 1 (registry YAML, `case.yaml` schema,
  `change.patch`, `packet.md`) and Step 2 (results row: existing `run.sh`
  keys kept, `task: reviewer-verdict`, plus the case/tier/verdict/grader
  fields enumerated there).
- 2026-09-11 Domain entities / data model: Q Who authors and maintains the
  gold corpus? → A (self-resolved): `lead-programmer` authors cases in
  Step 4 under the schema; the human operator (solo, ADR-0024) is corpus
  owner. A case's gold is immutable within a suite version; changing a gold
  label or a patch's semantics requires a new `.v<n+1>` suite id and a new
  case directory, never an in-place edit (Step 1 README rule; the validator
  cannot enforce immutability, so Step 4's criteria pin it with a
  commit-anchored content check).
- 2026-09-11 User interaction flow: Q How does a non-engineer add a case,
  and how does anyone run the suite? → A (self-resolved): copy a case
  directory, edit `case.yaml`/`change.patch`/`packet.md`, run
  `bash tests/eval-cases.test.sh` (or `validate.sh`) — no harness code is
  touched. Running: `bash eval/harness/behavior-regression.sh` with env
  overrides (`TIERS`, `REPS`, `CASES`, `VARIANT`, `MAX_SUITE_BUDGET_USD`),
  or the `workflow_dispatch` job. Output: rows in `results.jsonl`, a tracked
  JSON report under `eval/reports/`, and a printed table.
- 2026-09-11 Non-functional attributes: Q What does a full matrix cost, and
  what bounds it? → A (default, confirmed by OQ2 below): estimate 15 cases × 2 tiers ×
  3 reps = 90 reviewer invocations at ~$0.15 (sonnet) / ~$0.50 (opus) plus
  ~90 grader calls at ~$0.03 ≈ $30–35. Bounds: per-invocation
  `--max-budget-usd` 1.50; suite-level `MAX_SUITE_BUDGET_USD` default 60,
  aborting with exit 2 when the running sum of `total_cost_usd` exceeds it.
  Wall-clock ≈ 90 × ~2 min ≈ 3 h serial; no parallelism in v1.
- 2026-09-11 Non-functional attributes: Q Security — does the reviewer see
  gold, and does the grader have tools? → A (self-resolved): `case.yaml`
  is never copied into the fixture (criterion C2.9); the grader runs in an
  empty temp dir with `--tools ""` equivalent (no tool use), text-in /
  JSON-out only.
- 2026-09-11 External dependencies & integrations: Q What does the runner
  depend on, and how is the reviewer invoked headlessly? → A
  (self-resolved): `claude` CLI with `--agent reviewer`, `--model <tier>`,
  `--append-system-prompt-file eval/harness/reviewer-eval-mode.md`,
  `--output-format json`; PyYAML for the registry; `git apply` for patches;
  `node bin/cli.js` via the unchanged `scaffold.sh`. CI additionally needs
  an `ANTHROPIC_API_KEY` secret and a global install of the CLI.
- 2026-09-11 External dependencies & integrations: Q Who grades the grader?
  → A (self-resolved): a `reviewer-verdict.grader.v1` calibration split of
  hand-written (reviewer message, gold defects, expected grader JSON)
  tuples. Every suite invocation runs calibration first; any mismatch sets
  `grader_calibrated=false` on every row of that invocation, nulls the
  model-graded fields, and exits 2. Step 6 adds a human spot-check table
  (≥3 graded FAIL rows read by the operator) to the experiment log.
- 2026-09-11 Edge cases / failure handling: Q What happens on an
  unparseable verdict, a budget stop, a permission denial, a patch that no
  longer applies, or a non-deterministic reviewer? → A (self-resolved):
  `verdict_observed: UNPARSEABLE` (mismatch, row kept, `verdict_line`
  raw); `result_subtype`/`is_error` recorded as `run.sh` does and the row
  counts as a mismatch; `permission_denials_count` recorded (informational);
  a non-applying patch fails the case validator (merge gate) and, at run
  time, the runner exits 3 for that case without appending a row;
  non-determinism is handled by `REPS` (default 3) and a per-(case,tier)
  majority rule (matched iff ≥ ceil(REPS/2) reps match).
- 2026-09-11 Technical constraints & tradeoffs: Q Is `--agent reviewer` as
  the *main session* attributed as the reviewer by the fixture's gates,
  and does `--model` beat the frontmatter `model: opus` pin? → A
  (self-resolved as a measured criterion, not a guess): unknown today;
  Step 2's smoke criteria require `modelUsage` to name the requested tier
  family and record `permission_denials_count`. The eval-mode prompt tells
  the reviewer not to write markers/packets (the bookkeeping is protocol
  adherence, covered by the gate chain, not verdict quality), so a gate
  refusal cannot corrupt the verdict either way. If `--model` does not win,
  the runner additionally rewrites the fixture copy's `model:` frontmatter
  line and records `tier_mechanism: frontmatter`.
- 2026-09-11 Technical constraints & tradeoffs: Q Should the deterministic
  parts enter `tests/validate.sh` given eval/ is "dev-scratch"? → A
  (self-resolved): yes for the case validator, verdict parser and summary
  aggregator (sub-second, no network, no LLM); never for the driver. This
  is what turns the corpus from scratch into a schema'd, tracked artifact.
- 2026-09-11 Terminology consistency: Q Does "variant" in the brief mean
  the same as the harness's "variant"? → A (self-resolved): no — see the
  Lens 1 finding; the plan separates *variant* (overlay under test) from
  *case* (input). New terms are routed to `scribe` in Step 7.
- 2026-09-11 Functional scope & success criteria: Q (OQ1) Is
  ESCALATE-TO-HUMAN in the v1 gold vocabulary? → A: no — PASS/FAIL only in
  `reviewer-verdict.gold.v1`; the runner sets the fixture to
  `humanReviewMode: off`; an `escalation` split is deferred to a later
  version. Per operator, option (a).
- 2026-09-11 Non-functional attributes: Q (OQ2) How is the suite wired
  into CI and what bounds its spend? → A: `workflow_dispatch` plus a
  monthly `schedule` gated on repo variable `BEHAVIOR_REGRESSION_ENABLED`;
  an `ANTHROPIC_API_KEY` repository secret is required; caps confirmed at
  60 USD per matrix and 1.50 USD per invocation. Per operator, option (a).
- 2026-09-11 Technical constraints & tradeoffs: Q (OQ3) Is a sibling
  per-case runner the right seam? → A: yes — `eval/harness/review-case.sh`
  beside `run.sh`; `run.sh`'s five-arg contract stays byte-stable (C2.10).
  Per operator.
- 2026-09-11 Completion / acceptance signals: Q When is each unit done,
  and when is the whole plan done? → A (self-resolved): each step's fenced
  `sh` criteria block must exit 0 (reviewer-run); the plan is done when
  Step 6's tracked report and experiment log exist with the pre-registered
  predictions filled in and Step 7's glossary entries land. The suite's own
  numbers are evidence, not a completion condition — a low sonnet catch
  rate is a *finding*, not a failed unit.

## Risks / dependencies

- R1 **Cost is real money per run.** Bounded by two caps (Step 2, Step 5)
  and by CI being `workflow_dispatch` + opt-in schedule (OQ2). A runaway
  reviewer (`maxTurns: 50`) is capped per invocation at $1.50.
- R2 **Fidelity gap: no `explorer` in the fixture.** `scaffold.sh` renders
  spec-master, task-master, reviewer only; the reviewer's "scope via the
  explorer" bullet cannot be honoured. The eval-mode prompt states the
  explorer is unavailable and to use Read/Grep directly. Recorded per row
  via `eval_mode_prompt_sha` so a later fixture change is distinguishable.
- R3 **Fidelity gap: the eval scores the verdict, not the process.**
  Whether the reviewer actually ran `npm test` is not captured
  (`--output-format json` has no tool log). A future `stream-json` capture
  is out of scope; noted so nobody reads "verdict matched" as "process
  followed".
- R4 **Non-determinism.** Same input, different verdicts across reps is
  expected; REPS=3 + majority is a floor, not a fix. The report carries
  per-case rep agreement so flaky cases are visible.
- R5 **Grader circularity.** The grader is an LLM judging an LLM. Mitigated
  by (a) the deterministic verdict-match layer being the primary metric,
  (b) the calibration split gating every invocation, (c) a fixed
  `--json-schema` so parsing never depends on prose.
- R6 **Gold labels are authored by the same class of agent being
  evaluated.** Injected defects are correct by construction (the author
  plants them), but a PASS case's "clean" label could be wrong. Step 4
  requires every PASS case to pass `npm test` plus the task's holdout test
  in the fixture, and every FAIL case's patch to *also* pass `npm test`
  (so the defect is not trivially caught by the suite — that is the point
  of a reviewer).
- R7 **`reviewer-tier.sh`'s sensitive-path list is AntiSlop's.** In the
  fixture, `.claude/agents/` and `.claude/hooks/` still match, `src/` and
  `test/` do not — so tier eligibility of toy cases is driven by size only.
  That is the axis we want to measure; stated so nobody expects path-class
  evidence from this corpus.
- R8 **Suite thresholds set from one baseline are perishable** (baselines
  expire). The registry records the baseline's commit and date beside each
  floor; a floor older than the reviewer persona's last content change is
  reported as `stale` (Step 5 aggregator compares `git log -1 --format=%H
  -- agents/reviewer.md` against the recorded commit).
- R9 **CI secrets/spend** — see OQ2. A workflow that runs on `push` would
  spend on every commit; explicitly forbidden below (C5.8).
- R10 **Untracked evidence.** `results.jsonl` stays gitignored (convention,
  "do not invent a parallel results file"). The tracked `eval/reports/`
  JSON is the durable artifact; the experiment log references rows by
  `report` path + `case_id`, never by re-typing numbers.
- Dependencies: Step 2 → Step 1; Step 3 → Step 2; Step 4 → Step 1 (parallel
  with 3); Step 5 → 2, 3, 4; Step 6 → 5; Step 7 → 5 (parallel with 6).

## Constitution check (.claude/constitution.md v1.0.0)
- P1 "Verify, don't assume": satisfied — the invocation mechanism, tier
  attribution (`modelUsage`), and grader adequacy are each proven by a
  live-run criterion rather than assumed; the CLI facts above were measured.
- P2 "Prefer deterministic scripts over LLM re-derivation": satisfied —
  verdict match, case validation, tier eligibility and aggregation are
  deterministic scripts; the LLM grader is confined to the one judgment a
  regex cannot make (semantic defect identification) and is itself gated by
  a deterministic calibration check.
- P3 "Version-stamp discipline": satisfied — no version-stamped file
  (`agents/*.md`, templates) is touched; no plugin version bump or
  CHANGELOG entry is required. (Step 7's wiki/CONTEXT.md edits are not
  version-stamped.)
- P4 "Optional personas degrade gracefully" (SHOULD): satisfied — the
  driver refuses with a one-line message if the fixture has no
  `.claude/agents/reviewer.md`; a project without a reviewer has nothing to
  evaluate, which is the graceful degradation.
- P5 "`tests/validate.sh` is the merge gate": satisfied — the three
  deterministic tests are registered in `validate.sh`; the LLM-invoking
  driver and the CI workflow never are, and `hooks/hooks.json` is pinned
  unchanged (C5.9).

## Steps

Conventions for all criteria blocks: run from the repo root on a committed,
clean tree; `command grep` is used for live-tree counts (bare `grep` is
wrapper-shadowed inline in this harness); no criterion quotes the
reviewer-owned marker directory; every "unchanged" guard is a content pin.

### Step 1 — Registry, case schema, deterministic case validator, merge-gate registration

**Affected files** (all new unless noted):
- `eval/registry/reviewer-verdict.yaml` — registry: two suite ids,
  `reviewer-verdict.gold.v1` and `reviewer-verdict.grader.v1`, each with
  `cases_dir`, `fixture`, `task`, `scoring` (`verdict-match` +
  `model-graded`), `thresholds` (per tier, `null` initially, plus
  `baseline_commit`/`baseline_date` fields, `null` initially), and
  `grader` (`model: sonnet`, `schema: eval/harness/grader-schema.json`).
- `eval/cases/reviewer-verdict/README.md` — authoring guide for
  non-engineers: directory layout, `case.yaml` schema, immutability rule
  (new version, never edit gold), the taxonomy tags, how to run the
  validator.
- `eval/cases/reviewer-verdict/gold/.gitkeep`,
  `eval/cases/reviewer-verdict/grader/.gitkeep`.
- `eval/harness/validate-cases.py` — python3 + PyYAML; validates every case
  under a suite's `cases_dir` and exits non-zero with `file: reason` lines.
- `eval/harness/grader-schema.json` — the `--json-schema` for grader
  output (defined here so Step 1's validator can check calibration cases'
  `expected` against it; used by Step 3).
- `tests/eval-cases.test.sh` — runs the validator over both suites AND over
  a built-in mutation set (a temp copy of a valid case with each required
  field removed / each forbidden condition introduced) asserting each
  mutant is rejected with the right reason.
- `tests/validate.sh` (edit) — register `tests/eval-cases.test.sh` in the
  existing `if bash …; then echo OK … else echo FAIL … fi` shape.

**Data model — `case.yaml` (gold split):**
```yaml
id: <kebab-case, unique within the suite, == directory name>
suite: reviewer-verdict.gold.v1
fixture: toy-lib-template            # must exist under eval/fixtures/
task: feature-task                   # must exist under eval/tasks/<task>.md
patch: change.patch                  # relative; must `git apply --check` on a clean copy of the fixture
packet: packet.md                    # relative; the dispatch packet text given to the reviewer
gold:
  verdict: PASS | FAIL               # exactly one of these two in v1
  defects:                           # required non-empty iff verdict == FAIL; must be [] iff PASS
    - id: <kebab-case, unique within the case>
      file: <path inside the fixture that change.patch touches>
      description: <one paragraph, what is wrong and how to trigger it>
  decoys:                            # optional; PASS cases only: non-material nits present on purpose
    - <one line each>
tags: [<class tag>, <size tag>, ...]  # class tag from the README taxonomy is required
```
Validator rules (each a rejection reason string, pinned by the test):
`missing-field:<name>`, `id-mismatch` (id ≠ dir name), `duplicate-id`,
`bad-suite`, `bad-verdict` (not PASS/FAIL), `defects-required` (FAIL with
none), `defects-forbidden` (PASS with any), `defect-file-not-in-patch`,
`patch-does-not-apply`, `packet-missing`, `packet-lacks-unit-line` (packet
must contain a line starting `Unit: eval-<id>`), `packet-leaks-gold`
(packet contains the string `gold:` or any defect `id`), `tag-class-missing`.
Grader split `case.yaml`: `id`, `suite: reviewer-verdict.grader.v1`,
`gold.defects` (same shape), `reviewer_message: reviewer-message.md`,
`expected: {defects: [{id, identified: bool}], extra_fail_grounds: int}`
validated against `grader-schema.json`.

**Acceptance criteria (C1):**
```sh
# C1.1 registry parses and names both suites
python3 -c 'import yaml,sys; r=yaml.safe_load(open("eval/registry/reviewer-verdict.yaml")); ids=sorted(s["id"] for s in r["suites"]); sys.exit(0 if ids==["reviewer-verdict.gold.v1","reviewer-verdict.grader.v1"] else 1)'
# C1.2 every suite's thresholds start report-only, with baseline fields present
python3 -c 'import yaml,sys; r=yaml.safe_load(open("eval/registry/reviewer-verdict.yaml")); g=[s for s in r["suites"] if s["id"]=="reviewer-verdict.gold.v1"][0]; t=g["thresholds"]; sys.exit(0 if set(t)=={"sonnet","opus"} and all(t[k]["min_verdict_match"] is None and "baseline_commit" in t[k] and "baseline_date" in t[k] for k in t) else 1)'
# C1.3 validator exits 0 on the (possibly empty) tree and the test suite passes, incl. mutation set
python3 eval/harness/validate-cases.py --registry eval/registry/reviewer-verdict.yaml
bash tests/eval-cases.test.sh
# C1.4 every rejection reason listed above is exercised by the mutation set (13 reasons)
test "$(command grep -o -E 'missing-field|id-mismatch|duplicate-id|bad-suite|bad-verdict|defects-required|defects-forbidden|defect-file-not-in-patch|patch-does-not-apply|packet-missing|packet-lacks-unit-line|packet-leaks-gold|tag-class-missing' tests/eval-cases.test.sh | sort -u | wc -l)" = 13
# C1.5 registered in the merge gate (3 lines: if/OK/FAIL), and validate.sh still passes
test "$(command grep -c 'tests/eval-cases.test.sh' tests/validate.sh)" -ge 3
bash tests/validate.sh
# C1.6 README documents the immutability rule and the taxonomy (short pins, no wrapped literals)
command grep -q 'never edit gold' eval/cases/reviewer-verdict/README.md
command grep -q 'class tag' eval/cases/reviewer-verdict/README.md
# C1.7 grader schema is valid JSON and pins the two output fields
python3 -c 'import json,sys; s=json.load(open("eval/harness/grader-schema.json")); sys.exit(0 if set(s["properties"])=={"defects","extra_fail_grounds"} else 1)'
# C1.8 guard: eval/ stays excluded from the npm-pack check (content pin, unchanged from today)
command grep -q "'eval/'" tests/validate.sh
```
Baseline 2026-09-11: C1.1–C1.7 RED (files absent); C1.8 GREEN (guard).

### Step 2 — Per-case reviewer runner, eval-mode prompt, verdict parser, results row, one seed case, live smoke

**Affected files:**
- `eval/harness/review-case.sh DEST CASE_DIR TIER VARIANT REP PROJECT_NAME [MAX_BUDGET_USD]`
  (new) — the analogue of `run.sh` for a case: (1) refuse unless
  `DEST/.claude/agents/reviewer.md` exists; (2) set `humanReviewMode: off`
  in `DEST/.claude/persona-config.json` (python JSON edit, same style as
  `scaffold.sh`); (3) `git apply` `change.patch`, commit as
  `eval case: <id>`, record `range=<baseline-sha>..HEAD`; (4) copy nothing
  else — never `case.yaml`; (5) measure
  `CLAUDE_PROJECT_DIR=DEST bash hooks/scripts/reviewer-tier.sh eval-<id> <range>`
  from inside DEST → `tier_eligibility`; (6) invoke
  `claude -p --agent reviewer --model $TIER --append-system-prompt-file
  eval/harness/reviewer-eval-mode.md --output-format json
  --max-budget-usd … --no-session-persistence "$(cat packet.md)"` with the
  same `--allowedTools` set `run.sh` uses; (7) parse the verdict; (8)
  append one row to `eval/results.jsonl`. `--measure-only` flag performs
  (1)–(5) and prints `tier_eligibility` without invoking the model or
  appending a row.
- `eval/harness/reviewer-eval-mode.md` (new) — the appended system prompt,
  fixed text: eval dispatch; unit id is the packet's `Unit:` line; emit the
  verdict exactly per the Verdict bullet, verdict token first; do not write
  markers, packets, `CHANGES.md` or `EXAMPLES.md`; the `explorer` is
  unavailable in this fixture, use Read/Grep/Glob and run the checks
  yourself.
- `eval/harness/parse-verdict.py` (new) — stdin: the `result` text; stdout:
  one JSON object `{verdict, verdict_line}`; rule: first non-empty line,
  earliest-position match of `\b(PASS|FAIL|INSUFFICIENT-CONTEXT|ESCALATE-TO-HUMAN)\b`
  after stripping leading `#`, `*`, `>`, `-`, whitespace and an optional
  `Verdict:` prefix; none → `UNPARSEABLE`.
- `tests/reviewer-eval-parse.test.sh` (new) — ≥8 fixture messages: bare
  PASS line; PASS line mentioning "no FAIL grounds" (must parse PASS);
  `**FAIL**` bold; `Verdict: FAIL` prefix; FAIL followed by defect list and
  a trailing `## roast-work` advisory; INSUFFICIENT-CONTEXT;
  ESCALATE-TO-HUMAN; leading blank lines then PASS; prose with no token
  (UNPARSEABLE); a message whose FIRST line has no token but the second
  does (UNPARSEABLE — first non-empty line only).
- `tests/validate.sh` (edit) — register `tests/reviewer-eval-parse.test.sh`.
- `eval/cases/reviewer-verdict/gold/seed-preview-mutates-cart/{case.yaml,change.patch,packet.md}`
  (new) — exactly ONE seed case for the smoke: a `previewDiscountedTotal`
  that reuses the fixture's mutating `applyDiscountPercent` (the planted
  trap), whose own tests pass; gold `FAIL`, one defect, tags
  `[input-mutation, size:small]`.

**Results row** — all existing `run.sh` keys are kept (`timestamp`,
`variant`, `task`, `rep`, `project_name`, `dest`, `claude_exit_code`,
`wall_clock_ms`, `tests_pass_own: null`, `holdout_present: false`,
`tests_pass_with_holdout: null`, `result_subtype`, `is_error`,
`total_cost_usd`, `num_turns`, `duration_ms`, `duration_api_ms`, `usage`)
with `task: "reviewer-verdict"`, plus: `suite`, `case_id`, `tier`
(requested), `model_observed` (the `modelUsage` key list),
`tier_mechanism` (`model-flag` | `frontmatter`), `tier_eligibility`
(`sonnet`|`opus` from reviewer-tier.sh), `range`, `verdict_expected`,
`verdict_observed`, `verdict_line`, `verdict_match` (bool),
`permission_denials_count`, `eval_mode_prompt_sha` (sha256 of the prompt
file), `reviewer_message` (the full `result` text — needed by Step 3),
`grader_model: null`, `grader_calibrated: null`, `defects_expected: null`,
`defects_identified: null`, `extra_fail_grounds: null`, `case_pass: null`
(Step 3 fills the last six).

**Acceptance criteria (C2):**
```sh
# C2.1 deterministic tests pass and are registered
bash tests/reviewer-eval-parse.test.sh
test "$(command grep -c 'tests/reviewer-eval-parse.test.sh' tests/validate.sh)" -ge 3
bash tests/validate.sh
# C2.2 parser rule pins (run directly, no fixture needed)
test "$(printf 'PASS — criteria checked: npm test; no FAIL grounds found\n' | python3 eval/harness/parse-verdict.py | python3 -c 'import json,sys; print(json.load(sys.stdin)["verdict"])')" = PASS
test "$(printf '\n\n**FAIL**\n- src/pricing.js:12 mutates input\n' | python3 eval/harness/parse-verdict.py | python3 -c 'import json,sys; print(json.load(sys.stdin)["verdict"])')" = FAIL
test "$(printf 'Looks fine overall.\nPASS\n' | python3 eval/harness/parse-verdict.py | python3 -c 'import json,sys; print(json.load(sys.stdin)["verdict"])')" = UNPARSEABLE
# C2.3 seed case validates and is the only gold case at this step
python3 eval/harness/validate-cases.py --registry eval/registry/reviewer-verdict.yaml
test "$(ls -d eval/cases/reviewer-verdict/gold/*/ | wc -l)" = 1
# C2.4 the seed patch passes the fixture's own tests (the defect is invisible to npm test — that is the point)
T=$(mktemp -d) && cp -r eval/fixtures/toy-lib-template/. "$T" && (cd "$T" && git -c user.email=eval@example.com -c user.name=eval -c commit.gpgsign=false init -q && git add -A && git -c user.email=eval@example.com -c user.name=eval -c commit.gpgsign=false commit -qm base && git apply "$OLDPWD/eval/cases/reviewer-verdict/gold/seed-preview-mutates-cart/change.patch" && npm test >/dev/null 2>&1); echo "seed-npm-test-exit=$?"; rm -rf "$T"
# (the printed exit must be 0)
# C2.5 measure-only mode works with no model call and reports a tier
D=eval/.runs/c2-measure && PN=$(bash eval/harness/scaffold.sh "$D" --force | tail -n1) && bash eval/harness/apply-variant.sh "$D" baseline && bash eval/harness/review-case.sh "$D" eval/cases/reviewer-verdict/gold/seed-preview-mutates-cart sonnet baseline 1 "$PN" --measure-only | tail -n1 | command grep -E '^tier_eligibility=(sonnet|opus)$' && bash eval/harness/cleanup.sh "$D"
# C2.6 live smoke, both tiers, one rep each (spend ≤ $3.00 total); rows appended
N0=$(wc -l < eval/results.jsonl)
for TIER in sonnet opus; do D=eval/.runs/c2-smoke-$TIER; PN=$(bash eval/harness/scaffold.sh "$D" --force | tail -n1); bash eval/harness/apply-variant.sh "$D" baseline; bash eval/harness/review-case.sh "$D" eval/cases/reviewer-verdict/gold/seed-preview-mutates-cart "$TIER" baseline 1 "$PN" 1.50; bash eval/harness/cleanup.sh "$D"; done
test "$(( $(wc -l < eval/results.jsonl) - N0 ))" = 2
# C2.7 tier attribution proven from modelUsage, per row (the last two rows)
tail -n 2 eval/results.jsonl | python3 -c 'import json,sys; rows=[json.loads(l) for l in sys.stdin]; ok=all(r["task"]=="reviewer-verdict" and any(r["tier"] in m for m in r["model_observed"]) and not any(("opus" if r["tier"]=="sonnet" else "sonnet") in m for m in r["model_observed"]) for r in rows); sys.exit(0 if ok else 1)'
# C2.8 verdict was parseable on both rows (PASS/FAIL/INSUFFICIENT-CONTEXT/ESCALATE-TO-HUMAN, not UNPARSEABLE) and expected is FAIL
tail -n 2 eval/results.jsonl | python3 -c 'import json,sys; rows=[json.loads(l) for l in sys.stdin]; sys.exit(0 if all(r["verdict_expected"]=="FAIL" and r["verdict_observed"] in ("PASS","FAIL","INSUFFICIENT-CONTEXT","ESCALATE-TO-HUMAN") and isinstance(r["verdict_match"],bool) and r["tier_eligibility"] in ("sonnet","opus") and len(r["eval_mode_prompt_sha"])==64 for r in rows) else 1)'
# C2.9 no gold leaks into a prepared fixture (checked on a fresh measure-only scaffold)
D=eval/.runs/c2-leak && PN=$(bash eval/harness/scaffold.sh "$D" --force | tail -n1) && bash eval/harness/review-case.sh "$D" eval/cases/reviewer-verdict/gold/seed-preview-mutates-cart sonnet baseline 1 "$PN" --measure-only >/dev/null && test "$(find "$D" -name case.yaml | wc -l)" = 0 && test "$(command grep -rl 'gold:' "$D" --include='*.yaml' --include='*.md' | wc -l)" = 0 && python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1]))["humanReviewMode"]=="off" else 1)' "$D/.claude/persona-config.json" && bash eval/harness/cleanup.sh "$D"
# C2.10 guards: existing harness scripts' contracts untouched (content pins)
command grep -q 'Usage: run.sh DEST TASK_NAME VARIANT REP PROJECT_NAME' eval/harness/run.sh
command grep -q 'Usage: apply-variant.sh DEST VARIANT_SLUG' eval/harness/apply-variant.sh
command grep -q -- '--personas=spec-master,task-master,reviewer' eval/harness/scaffold.sh
```
Baseline 2026-09-11: C2.1–C2.9 RED; C2.10 GREEN (guards). C2.6's verdict
*values* are not a criterion (the seed may be missed on either tier; that
is data), only that rows with the pinned shape exist. The smoke row's
`verdict_match` on opus is recorded in the unit's PASS notes for Step 6.

### Step 3 — Model-graded scorer and grader calibration split

**Affected files:**
- `eval/harness/grade-verdict.py` (new) — inputs: a results row (JSON on
  stdin) + the case's `gold.defects` + `packet.md`; runs the grader
  `claude -p --model <grader.model> --json-schema "$(cat eval/harness/grader-schema.json)" --output-format json --no-session-persistence`
  from an empty temp dir with tool use disabled, prompt = fixed rubric
  (defined in `eval/harness/grader-rubric.md`) + packet + gold defect list +
  reviewer message; output: the schema'd JSON `{defects:[{id, identified,
  evidence}], extra_fail_grounds}`; fills `grader_model`,
  `defects_expected`, `defects_identified`, `extra_fail_grounds`,
  `case_pass` (= `verdict_match` AND, for FAIL gold, every gold defect
  `identified`; for PASS gold, `verdict_match` alone). `--calibrate`
  mode runs every `reviewer-verdict.grader.v1` case and exits 0 iff every
  `identified` boolean and `extra_fail_grounds` equals `expected`, printing
  a per-case table. Grader errors (unparseable JSON, budget) → `grader_error`
  string, model-graded fields null, `case_pass` null.
- `eval/harness/grader-rubric.md` (new) — fixed text; sha recorded per row
  as `grader_rubric_sha`.
- `eval/cases/reviewer-verdict/grader/<id>/{case.yaml,reviewer-message.md}`
  (new, ≥7 cases; each directory name MUST contain its shape token so C3.1
  can find it): `all-identified`; `none-identified`; `partial` (1 of 2);
  `paraphrase` (semantic match, different words, same file);
  `wrong-defect` (right file, different defect — must be
  `identified: false`); `pass-on-fail` (a PASS-verdict message against
  FAIL gold: all false, `extra_fail_grounds: 0`); `extra-ground` (a FAIL
  message with one gold defect plus one unrelated invented defect:
  `extra_fail_grounds: 1`).
- `review-case.sh` (edit) — after appending the row, if `GRADE=1` (default
  1), invoke the grader and rewrite the row in place (rows stay one JSON
  object per line; `review-case.sh` owns the append+rewrite so no parallel
  file exists).

**Acceptance criteria (C3):**
```sh
# C3.1 grader split validates and has ≥7 cases covering the named shapes
python3 eval/harness/validate-cases.py --registry eval/registry/reviewer-verdict.yaml
test "$(ls -d eval/cases/reviewer-verdict/grader/*/ | wc -l)" -ge 7
for s in all-identified none-identified partial paraphrase wrong-defect pass-on-fail extra-ground; do ls -d eval/cases/reviewer-verdict/grader/*"$s"*/ >/dev/null || { echo "missing grader shape: $s"; exit 1; }; done
# C3.2 live calibration passes on the default grader model (spend ≤ $1.00)
python3 eval/harness/grade-verdict.py --calibrate --registry eval/registry/reviewer-verdict.yaml
# C3.3 calibration is non-vacuous: flipping one expected boolean in a temp copy makes it fail
T=$(mktemp -d) && cp -r eval/cases/reviewer-verdict/grader "$T/" && python3 - "$T" <<'PY'
import yaml,sys,glob,os
d=sys.argv[1]; f=sorted(glob.glob(os.path.join(d,'grader','*','case.yaml')))[0]
c=yaml.safe_load(open(f)); c['expected']['defects'][0]['identified']=not c['expected']['defects'][0]['identified']; yaml.safe_dump(c,open(f,'w'))
PY
! python3 eval/harness/grade-verdict.py --calibrate --registry eval/registry/reviewer-verdict.yaml --cases-dir "$T/grader"; rm -rf "$T"
# C3.4 the Step 2 smoke rows can be graded offline from their stored reviewer_message (spend ≤ $0.20); fields filled
tail -n 1 eval/results.jsonl | python3 eval/harness/grade-verdict.py --registry eval/registry/reviewer-verdict.yaml | python3 -c 'import json,sys; r=json.load(sys.stdin); sys.exit(0 if r["grader_calibrated"] is True and isinstance(r["defects_expected"],int) and isinstance(r["defects_identified"],int) and isinstance(r["case_pass"],bool) and len(r["grader_rubric_sha"])==64 else 1)'
# C3.5 grader has no tools: the rubric/invocation forbids tool use and the schema is passed
command grep -q -- '--json-schema' eval/harness/grade-verdict.py
command grep -q -E -- '--tools ""|--disallowedTools|--allowedTools ""' eval/harness/grade-verdict.py
# C3.6 merge gate still green
bash tests/validate.sh
```
Baseline 2026-09-11: all RED.

### Step 4 — Gold corpus (12–20 cases across the taxonomy, both tier strata)

**Affected files:** `eval/cases/reviewer-verdict/gold/<case-id>/{case.yaml,change.patch,packet.md}`
for each new case; `eval/cases/reviewer-verdict/README.md` (edit: the
case index table — id, class tag, gold verdict, measured tier eligibility).
No harness code changes.

**Taxonomy (class tags; minimum one case each):** FAIL classes —
`input-mutation` (the seed), `boundary` (pct 0/100, rounding), `unmet-criterion`
(function present but a stated criterion is not met, tests still pass),
`silent-behavior-change` (an existing function's behaviour altered),
`vacuous-test` (test asserts nothing; impl buggy), `security` (e.g.
`Function`/`eval` on item data, or prototype pollution via item keys),
`unhandled-input` (null items / NaN pct crash where the spec implies
handling), `skipped-test` (an existing test `.skip`ped to go green). PASS
classes — `clean`, `style-decoy` (naming/length nits only),
`robustness-decoy` (a nice-to-have beyond the spec missing), `refactor`
(behaviour-preserving internal reshuffle, larger diff), `unrelated-touch`
(harmless doc/comment change in a second file). Size tags: `size:small`
(intended ≤40 lines/≤3 files) or `size:large`.

**Rules:** every FAIL patch passes `npm test` in the fixture (the defect
must be invisible to the fixture's own tests, else it is a test-suite
finding, not a reviewer finding); every PASS patch passes `npm test` AND
`eval/tasks/feature-task.holdout.test.js`; ≥5 cases measure `sonnet` and
≥5 measure `opus` under `--measure-only`; ≥8 FAIL and ≥5 PASS; each packet
follows the nine-element shape (`Unit:`, `## Objective`, `## Acceptance
criteria` naming `npm test` and the task's stated criteria, `## Affected
files`) and never leaks gold. Immutability: this step's commit is the
corpus's `v1` anchor — the README records its SHA as the line
`v1 anchor: <sha>`.

**Acceptance criteria (C4):**
```sh
# C4.1 validator green; counts
python3 eval/harness/validate-cases.py --registry eval/registry/reviewer-verdict.yaml
N=$(ls -d eval/cases/reviewer-verdict/gold/*/ | wc -l); test "$N" -ge 12 && test "$N" -le 20
python3 - <<'PY'
import yaml,glob,sys,collections
cases=[yaml.safe_load(open(f)) for f in glob.glob('eval/cases/reviewer-verdict/gold/*/case.yaml')]
v=collections.Counter(c['gold']['verdict'] for c in cases)
tags=set(t for c in cases for t in c['tags'])
need={'input-mutation','boundary','unmet-criterion','silent-behavior-change','vacuous-test','security','unhandled-input','skipped-test','clean','style-decoy','robustness-decoy','refactor','unrelated-touch'}
missing=need-tags
print('FAIL',v['FAIL'],'PASS',v['PASS'],'missing',sorted(missing))
sys.exit(0 if v['FAIL']>=8 and v['PASS']>=5 and not missing else 1)
PY
# C4.2 every FAIL patch passes npm test; every PASS patch passes npm test + holdout (no model calls)
python3 - <<'PY'
import yaml,glob,subprocess,tempfile,shutil,os,sys
bad=[]
files=sorted(glob.glob('eval/cases/reviewer-verdict/gold/*/case.yaml'))
if not files: print('no gold cases found — vacuous'); sys.exit(1)
G=['git','-c','user.email=eval@example.com','-c','user.name=eval','-c','commit.gpgsign=false']
for f in files:
    c=yaml.safe_load(open(f)); d=os.path.dirname(f); t=tempfile.mkdtemp()
    shutil.copytree('eval/fixtures/toy-lib-template',t,dirs_exist_ok=True)
    def sh(*a): return subprocess.run(a,cwd=t,capture_output=True).returncode
    sh(*G,'init','-q'); sh(*G,'add','-A'); sh(*G,'commit','-qm','base')
    if sh('git','apply',os.path.abspath(os.path.join(d,c['patch'])))!=0: bad.append((c['id'],'apply')); continue
    if sh('npm','test')!=0: bad.append((c['id'],'npm-test')); continue
    if c['gold']['verdict']=='PASS':
        shutil.copy('eval/tasks/feature-task.holdout.test.js',os.path.join(t,'test','holdout.test.js'))
        if sh('npm','test')!=0: bad.append((c['id'],'holdout'))
    shutil.rmtree(t)
print(bad); sys.exit(0 if not bad else 1)
PY
# C4.3 both tier strata present, measured (scaffold per case, no model calls)
S=0; O=0; for d in eval/cases/reviewer-verdict/gold/*/; do D=eval/.runs/c4-measure; PN=$(bash eval/harness/scaffold.sh "$D" --force | tail -n1); T=$(bash eval/harness/review-case.sh "$D" "$d" sonnet baseline 1 "$PN" --measure-only | tail -n1); case "$T" in tier_eligibility=sonnet) S=$((S+1));; tier_eligibility=opus) O=$((O+1));; esac; bash eval/harness/cleanup.sh "$D" >/dev/null; done; echo "sonnet=$S opus=$O"; test "$S" -ge 5 && test "$O" -ge 5
# C4.4 README index lists every case id and the v1 anchor line
for d in eval/cases/reviewer-verdict/gold/*/; do id=$(basename "$d"); command grep -q "$id" eval/cases/reviewer-verdict/README.md || { echo "unindexed: $id"; exit 1; }; done
command grep -q -E '^v1 anchor: [0-9a-f]{7,40}$' eval/cases/reviewer-verdict/README.md
# C4.5 merge gate green (validator is part of it)
bash tests/validate.sh
```
Baseline 2026-09-11: all RED (one seed case exists after Step 2; C4.1's
count floor is 12). Prior-FAIL history: none for any eval unit. Judgment
note for `task-master`: authoring realistic defects that evade `npm test`
is judgment work, not mechanical — do not tag this unit `haiku`.

### Step 5 — Suite driver, tracked report, thresholds, CI workflow (never a gate)

**Affected files:**
- `eval/harness/behavior-regression.sh` (new) — matrix driver: env
  `TIERS` (default `sonnet opus`), `REPS` (3), `VARIANT` (baseline),
  `CASES` (all gold), `MAX_SUITE_BUDGET_USD` (60), `GRADER_MODEL`
  (registry default); sequence: calibrate grader (exit 2 on failure) →
  for each case × tier × rep: scaffold → apply-variant → review-case
  (graded) → cleanup, tracking cumulative `total_cost_usd` (exit 2 past the
  cap) → summarize → exit per thresholds.
- `eval/harness/summarize-reviewer-eval.py` (new) — pure function over
  rows (stdin JSONL filtered to one invocation id `run_id`, which
  `review-case.sh` gains as a row field): per (case, tier) rep agreement
  and majority `verdict_match`; per tier: `verdict_match_rate`,
  `catch_rate` (FAIL-gold cases matched / FAIL-gold cases),
  `false_alarm_rate` (PASS-gold cases observed FAIL / PASS-gold cases),
  `defect_identification_rate` (mean `defects_identified/defects_expected`
  over FAIL-gold rows with `case_pass` non-null), stratified by
  `tier_eligibility`; `stale_threshold` flag when
  `thresholds.<tier>.baseline_commit` predates the last commit touching
  `agents/reviewer.md`; threshold evaluation → `status: pass|fail|report-only`.
  Writes `eval/reports/reviewer-verdict.gold.v1.<YYYY-MM-DD>.<run_id>.json`
  (tracked — `eval/reports/` is NOT added to `.gitignore`) and prints a
  table.
- `tests/reviewer-eval-summary.test.sh` (new) — feeds synthetic rows:
  asserts majority rule at REPS=3 (2/3 → matched, 1/3 → not), catch/false
  alarm arithmetic on a 3-FAIL/2-PASS synthetic set, `report-only` when
  floors are null, `fail` when a floor is missed by one case, `stale`
  flagging with a fake old commit.
- `tests/validate.sh` (edit) — register the summary test.
- `.github/workflows/behavior-regression.yml` (new) — `on:
  workflow_dispatch` (inputs `tiers`, `reps`, `max_budget_usd`) and
  `schedule` (monthly) with job-level
  `if: github.event_name == 'workflow_dispatch' || vars.BEHAVIOR_REGRESSION_ENABLED == 'true'`;
  installs `@anthropic-ai/claude-code`, `jq`, runs `npm ci` where needed,
  exports `ANTHROPIC_API_KEY` from secrets, runs the driver, uploads
  `eval/reports/*.json` and the invocation's rows as artifacts; job name
  `behavior-regression`; never `pull_request`/`push`; `validate.yml`
  untouched.

**Acceptance criteria (C5):**
```sh
# C5.1 deterministic summary test passes and is registered; merge gate green
bash tests/reviewer-eval-summary.test.sh
test "$(command grep -c 'tests/reviewer-eval-summary.test.sh' tests/validate.sh)" -ge 3
bash tests/validate.sh
# C5.2 driver refuses without a reviewer in the fixture (P4), exit 2, no model call
D=eval/.runs/c5-noreviewer && mkdir -p "$D/.claude/agents" && ( bash eval/harness/review-case.sh "$D" eval/cases/reviewer-verdict/gold/seed-preview-mutates-cart sonnet baseline 1 x --measure-only; echo "rc=$?" ) | tail -n1 | command grep -q '^rc=2$'; rm -rf "$D"
# C5.3 budget cap is enforced: with MAX_SUITE_BUDGET_USD=0.01 the driver exits 2 after at most one invocation (spend ≤ $1.50)
( MAX_SUITE_BUDGET_USD=0.01 TIERS=sonnet REPS=1 CASES=seed-preview-mutates-cart bash eval/harness/behavior-regression.sh; echo "rc=$?" ) | tail -n1 | command grep -q '^rc=2$'
# C5.4 a one-case, one-tier, one-rep live run produces a tracked report with the pinned fields (spend ≤ $2.00)
TIERS=opus REPS=1 CASES=seed-preview-mutates-cart bash eval/harness/behavior-regression.sh; R=$(ls -t eval/reports/reviewer-verdict.gold.v1.*.json | head -n1); python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); t=r["tiers"]["opus"]; sys.exit(0 if r["suite"]=="reviewer-verdict.gold.v1" and r["status"]=="report-only" and set(t)>={"verdict_match_rate","catch_rate","false_alarm_rate","defect_identification_rate","by_eligibility","cases"} and "run_id" in r and "commit" in r and "reviewer_md_commit" in r else 1)' "$R"
# C5.5 reports are tracked, rows are not (content pins on .gitignore)
! command grep -q -E '^eval/reports' .gitignore
command grep -q -E '^eval/results\.jsonl$' .gitignore
# C5.6 workflow parses, has only workflow_dispatch + schedule triggers, gates on the repo variable, names the secret
python3 -c 'import yaml,sys; w=yaml.safe_load(open(".github/workflows/behavior-regression.yml")); on=w[True] if True in w else w["on"]; sys.exit(0 if set(on)=={"workflow_dispatch","schedule"} else 1)'
command grep -q 'BEHAVIOR_REGRESSION_ENABLED' .github/workflows/behavior-regression.yml
command grep -q 'ANTHROPIC_API_KEY' .github/workflows/behavior-regression.yml
# C5.7 validate.yml unchanged (content pins: its single validate step; exactly three two-space keys — push, pull_request, validate — so no job was added)
test "$(command grep -c 'run: bash tests/validate.sh' .github/workflows/validate.yml)" = 1
test "$(command grep -c -E '^  [a-z_-]+:$' .github/workflows/validate.yml)" = 3
test "$(command grep -c '^  validate:$' .github/workflows/validate.yml)" = 1
# C5.8 the driver is never wired as a hook or as a merge-gate test
! command grep -q 'behavior-regression' hooks/hooks.json
! command grep -q -E 'behavior-regression|review-case' tests/validate.sh
# C5.9 hooks.json pinned: still 12 distinct scripts (re-derive with the same command; must equal 12)
test "$(command grep -o '"command": "[^"]*"' hooks/hooks.json | sort -u | wc -l)" = 12
# C5.10 reviewer-tier.sh untouched (content pins on the two thresholds and the NOT A HOOK header)
command grep -q '^MAX_CHANGED_LINES=40$' hooks/scripts/reviewer-tier.sh
command grep -q '^MAX_CHANGED_FILES=3$' hooks/scripts/reviewer-tier.sh
command grep -q '^# NOT A HOOK\.' hooks/scripts/reviewer-tier.sh
```
Baseline 2026-09-11: C5.1–C5.4, C5.6 RED; C5.5 (first half), C5.7, C5.8,
C5.9, C5.10 GREEN (guards — labelled as such; they prove scope was not
exceeded, not that work was done).

### Step 6 — Baseline run under both tiers, experiment log, threshold setting, reviewer-tier data memo

Executed by the operator (or the orchestrator on the operator's explicit
go-ahead — it spends money). No code changes except the registry's
thresholds and one new docs file.

**Affected files:**
- `docs/experiments/reviewer-eval-2026-<MM-DD>.md` (new) — one entry per
  tier in the `docs/experiments/README.md` shape, with predictions
  **pre-registered before the run** (commit the predictions section first,
  then run): E1 opus `verdict_match_rate ≥ 0.85`; E2 sonnet
  `verdict_match_rate` on `tier_eligibility=sonnet` cases ≥ 0.75; E3 sonnet
  `catch_rate` on sonnet-eligible FAIL cases is not more than one case
  below opus's on the same cases; `Result`, `Verdict`
  (CONFIRMED/REFUTED/INCONCLUSIVE), `Decision`. Plus a `## Grader
  spot-check` table with ≥3 graded FAIL rows (`case_id`, `tier`, `rep`,
  grader `identified` booleans, operator `agree|disagree`), and a
  `## reviewer-tier data memo` section stating, from the report, what the
  sonnet-eligible stratum shows and whether it is evidence for or against
  the 40/3 thresholds — **a memo, never a change to `reviewer-tier.sh`**.
- `eval/registry/reviewer-verdict.yaml` (edit) — `thresholds.opus.min_verdict_match`
  = (opus matched cases − 1)/N rounded down to 2 dp; `baseline_commit`,
  `baseline_date` filled; sonnet stays `null`.
- `eval/reports/reviewer-verdict.gold.v1.<date>.<run_id>.json` (produced
  by the run, committed).

**Acceptance criteria (C6):**
```sh
# C6.1 predictions were pre-registered: the experiment file's first commit predates the report's commit
E=$(ls docs/experiments/reviewer-eval-*.md | head -n1); R=$(ls eval/reports/reviewer-verdict.gold.v1.*.json | tail -n1)
test "$(git log --format=%ct --diff-filter=A -- "$E" | tail -n1)" -lt "$(git log --format=%ct --diff-filter=A -- "$R" | tail -n1)"
# C6.2 the report covers the full corpus at REPS≥3 on both tiers
python3 -c 'import json,sys,glob; r=json.load(open(sorted(glob.glob("eval/reports/reviewer-verdict.gold.v1.*.json"))[-1])); n=len(glob.glob("eval/cases/reviewer-verdict/gold/*/case.yaml")); ok=all(len(r["tiers"][t]["cases"])==n and min(c["reps"] for c in r["tiers"][t]["cases"].values())>=3 for t in ("sonnet","opus")); sys.exit(0 if ok else 1)'
# C6.3 grader was calibrated for the run
python3 -c 'import json,sys,glob; r=json.load(open(sorted(glob.glob("eval/reports/reviewer-verdict.gold.v1.*.json"))[-1])); sys.exit(0 if r["grader_calibrated"] is True else 1)'
# C6.4 experiment log has all three pre-registered entries, the spot-check table (≥3 rows), and the memo
E=$(ls docs/experiments/reviewer-eval-*.md | head -n1)
test "$(command grep -c -E '^### E[123]:' "$E")" = 3
command grep -q '^## Grader spot-check' "$E"
test "$(sed -n '/^## Grader spot-check/,/^## /p' "$E" | command grep -c -E '\|\s*(agree|disagree)\s*\|')" -ge 3
command grep -q '^## reviewer-tier data memo' "$E"
test "$(command grep -c -E '^- \*\*Verdict\*\*: (CONFIRMED|REFUTED|INCONCLUSIVE)' "$E")" = 3
# C6.5 opus floor set from the baseline; sonnet still report-only; baseline fields filled
python3 -c 'import yaml,sys; r=yaml.safe_load(open("eval/registry/reviewer-verdict.yaml")); g=[s for s in r["suites"] if s["id"]=="reviewer-verdict.gold.v1"][0]["thresholds"]; sys.exit(0 if isinstance(g["opus"]["min_verdict_match"],float) and g["sonnet"]["min_verdict_match"] is None and len(g["opus"]["baseline_commit"])>=7 and g["opus"]["baseline_date"] else 1)'
# C6.6 the floor is consistent with the report (matched−1)/N, and re-summarizing the same rows under it passes
python3 -c 'import json,yaml,glob,sys,math; r=json.load(open(sorted(glob.glob("eval/reports/reviewer-verdict.gold.v1.*.json"))[-1])); g=[s for s in yaml.safe_load(open("eval/registry/reviewer-verdict.yaml"))["suites"] if s["id"]=="reviewer-verdict.gold.v1"][0]["thresholds"]["opus"]["min_verdict_match"]; c=r["tiers"]["opus"]["cases"]; n=len(c); m=sum(1 for x in c.values() if x["majority_match"]); sys.exit(0 if abs(g-math.floor((m-1)/n*100)/100)<1e-9 else 1)'
# C6.7 reviewer-tier.sh still untouched (same pins as C5.10)
command grep -q '^MAX_CHANGED_LINES=40$' hooks/scripts/reviewer-tier.sh
command grep -q '^MAX_CHANGED_FILES=3$' hooks/scripts/reviewer-tier.sh
```
Baseline 2026-09-11: C6.1–C6.6 RED; C6.7 GREEN (guard).

### Step 7 — Documentation and glossary (scribe)

**Affected files:** `.claude/wiki/modules/eval-harness.md` (edit: add the
case type, registry, reports, driver, and the variant-vs-case distinction);
`docs/self-improvement-loops.md` (edit: a "Loop B′: behavior-regression
eval for the reviewer" subsection under Loop B, stating it is complementary
to, and never part of, the hook chain's protocol-adherence checks);
`CONTEXT.md` (edit: glossary entries — **behavior regression**, **protocol
adherence**, **gold case** / **gold corpus**, **eval registry**, **split**,
**model-graded scorer**, **grader calibration split**, **verdict match**,
**eval-mode dispatch** — each cross-linking **Measured reviewer tier** where
relevant; "ensure present and correct", re-derive current entries with
`command grep -n '^\*\*' CONTEXT.md` at execution time, never append
duplicates). No ADR is required: no existing decision is reversed;
ADR-0009's thresholds are untouched by design.

**Acceptance criteria (C7):**
```sh
# C7.1 glossary entries present exactly once each (heading-anchored, so a mention elsewhere does not count)
for t in 'behavior regression' 'protocol adherence' 'gold case' 'eval registry' 'model-graded scorer' 'grader calibration split' 'verdict match' 'eval-mode dispatch'; do n=$(command grep -c -i -E "^\*\*$t" CONTEXT.md); test "$n" = 1 || { echo "$t: $n"; exit 1; }; done
# C7.2 wiki and loops doc name the driver and the registry, and state the never-a-gate property
command grep -q 'behavior-regression.sh' .claude/wiki/modules/eval-harness.md
command grep -q 'eval/registry/reviewer-verdict.yaml' .claude/wiki/modules/eval-harness.md
command grep -q -i 'never a gate' docs/self-improvement-loops.md
command grep -q 'behavior-regression.sh' docs/self-improvement-loops.md
# C7.3 variant vs case distinction documented
command grep -q -i 'case' .claude/wiki/modules/eval-harness.md && command grep -q -i 'variant' .claude/wiki/modules/eval-harness.md
# C7.4 merge gate green
bash tests/validate.sh
```
Baseline 2026-09-11: C7.1 RED for all eight terms (0 matches each,
verified); C7.2 RED; C7.3 RED — measured: the wiki page contains "variant"
5 times and "case" 0 times today, so the "case" half is a genuine
change-proof (an earlier draft mislabelled it a guard; corrected by running
it). The term "split" is documented inside the **eval registry** entry
rather than as its own heading, which is why C7.1 pins eight headings for
the nine terms named above.

## Open Questions

**All three RESOLVED 2026-09-11 by the operator, each on the recommended
default (option (a) / yes).** The answers are recorded in the
Clarifications log above; the original questions are kept verbatim below
for the audit trail. No open question remains.

1. **ESCALATE-TO-HUMAN in the gold vocabulary?** The brief asks for
   PASS/FAIL/ESCALATE gold; ESCALATE is a config-driven gate on a would-be
   PASS (`humanReviewMode` + heavy trigger), not a property of the diff.
   Options: (a) **recommended** — v1 gold is PASS/FAIL only; the runner
   sets the fixture to `humanReviewMode: off`; an observed ESCALATE is a
   recorded mismatch; a later `reviewer-verdict.escalation.v1` split under
   `critical` can test trigger-honouring separately. (b) Include ESCALATE
   gold cases now, keeping `critical`, which makes every large/security
   PASS case's gold `ESCALATE-TO-HUMAN` and mixes protocol adherence into a
   verdict-quality suite. (c) Both splits in v1 (adds ~1 unit).
2. **CI wiring and spend.** Options: (a) **recommended** — ship
   `.github/workflows/behavior-regression.yml` as `workflow_dispatch` plus
   a monthly `schedule` that only runs when repo variable
   `BEHAVIOR_REGRESSION_ENABLED == 'true'`; requires an
   `ANTHROPIC_API_KEY` repository secret you create; default caps 60 USD
   per matrix / 1.50 USD per invocation. (b) No workflow at all — local
   `behavior-regression.sh` only, cadence by convention. (c) Weekly
   schedule, unguarded. Sub-question for (a): confirm the two cap values.
3. **Seams (per `to-spec`'s check-with-the-user step).** The single new
   seam is `eval/harness/review-case.sh` (fixture-in, results-row-out),
   mirroring `run.sh`; everything else composes existing scripts unchanged
   (`scaffold.sh`, `apply-variant.sh`, `cleanup.sh`, `reviewer-tier.sh`).
   Confirm that a per-case runner beside `run.sh` — rather than extending
   `run.sh` with a case mode — is the seam you expect. Recommended: the
   sibling script (keeps `run.sh`'s five-arg contract byte-stable, C2.10).

## Self-check

- CHK1: Is the gold verdict vocabulary defined for the case where the
  reviewer emits INSUFFICIENT-CONTEXT or ESCALATE-TO-HUMAN? — PASS
  (Clarifications line 1; Step 2 row semantics; OQ1 resolved (a)).
- CHK2: Do Step 2's row fields and Step 3's `case_pass` definition agree
  on what `verdict_match` means for PASS-gold cases? — PASS (Step 3:
  PASS gold → `case_pass = verdict_match`).
- CHK3: Is "suite passes" machine-checkable at every stage (report-only,
  floors set, stale)? — PASS (Step 5 aggregator statuses; C5.4, C6.5,
  C6.6; R8 stale rule).
- CHK4: Is the grader's adequacy proven rather than assumed, and is the
  proof non-vacuous? — PASS (C3.2 calibration, C3.3 mutation control).
- CHK5: Is the tier actually run proven per row, given the frontmatter
  `model: opus` pin? — PASS (C2.7 on `modelUsage`, both directions).
- CHK6: Can any criterion be satisfied by the wrong edit (backwards
  criterion)? — FAIL (ambiguous) on the first draft of C5.9 ("hooks.json
  has no new entries" was phrased as a `git diff`) — revised in place to a
  distinct-command count pin plus a negative name grep (C5.8/C5.9).
- CHK7: Does every "unchanged" guard use a content pin rather than
  `git diff` on a clean tree (gh348-13 note)? — PASS (C1.8, C2.10, C5.5,
  C5.7, C5.9, C5.10, C6.7).
- CHK8: Is the invocation mechanism's unknown (main-session `--agent`
  attribution) resolved by measurement rather than narrative? — PASS
  (Clarifications; C2.6–C2.8; `permission_denials_count` recorded).
- CHK9: Are gold labels protected from being wrong in the trivial way
  (defect caught by `npm test`; clean case failing holdout)? — PASS
  (Step 4 rules; C2.4, C4.2).
- CHK10: Is data leakage of gold into the reviewer's fixture excluded by a
  runnable check? — PASS (C2.9, validator `packet-leaks-gold`).
- CHK11: Do Steps 5 and 6 agree on how the opus floor is computed? — FAIL
  (conflicting) on the first draft (Step 5 said "baseline − 1 case", Step 6
  said "rounded to 2 dp" with no rounding direction) — revised in place:
  both now say `floor((matched−1)/N × 100)/100`, and C6.6 checks exactly
  that.
- CHK12: Is every criterion runnable by the identity that will be held to
  it (no quoted gated paths, no `git diff` mid-review, no bare `grep`
  counts)? — PASS (conventions block; every count uses `command grep` or
  python; the marker directory is never spelled).
- CHK13: Does the plan state which dispatch path applies and why? — PASS
  (header: 7 units → standard path, `task-master` slices; publish after
  OQs).
- CHK14: Are Goal clauses each mapped to a step criterion (no unmapped
  clause ships silently)? — PASS (mapping paragraph under Goal).
- CHK15: Is "never becomes a gate" enforced by criteria, not prose? — PASS
  (C5.8, C5.9; the workflow trigger set in C5.6).
- CHK16: Is cost bounded before any live criterion runs, and is each live
  criterion's spend stated? — PASS (C2.6 ≤ $3, C3.2 ≤ $1, C3.4 ≤ $0.20,
  C5.3 ≤ $1.50, C5.4 ≤ $2; Step 6 ≈ $30–35 under the 60 cap; cap values
  confirmed by OQ2 (a)).
- CHK17: Do the baselines carry dates and a commit, and are RED/GREEN
  labels stated per criterion block? — PASS (each block ends with a dated
  baseline line; guards labelled).
- CHK18: Does every guard's stated count match a live measurement? — FAIL
  (ambiguous) on first draft: C5.7's two-space-key count measured 3, not
  the 1 I wrote (`push:`/`pull_request:` share the indent) — revised in
  place to `= 3` plus a `^  validate:$` pin.
- CHK19: Is every criterion labelled GREEN actually green today, and every
  RED actually red? — FAIL (missing) on first draft: C7.3 was labelled a
  guard but "case" has 0 matches in the wiki today — revised in place
  (baseline line rewritten, C7.3 is a change-proof). Also C4.2 was vacuous
  at zero cases — revised in place with an explicit empty-set exit 1.

## Scribe update hint

After Step 5 lands: update `.claude/wiki/modules/eval-harness.md` and
`docs/self-improvement-loops.md` (Step 7 owns these), and add the nine
glossary terms listed under Step 7 to `CONTEXT.md`, cross-linking
**Measured reviewer tier** (CONTEXT.md:806) and **Mutation-proved**
(CONTEXT.md:826). After Step 6: link the experiment log from the wiki's
eval page. No ADR is required unless OQ1 resolves to (b), in which case the
decision to gate a verdict-quality suite on `humanReviewMode` deserves one.

## Publication note

Per the publish threshold (≥6 units) this spec is published via `to-spec`
as umbrella issue **#458**
(https://github.com/Storreslara/AntiSlop/issues/458, label
`ready-for-agent`), whose body opens with "Canonical spec:
`docs/plans/2026-09-11-reviewer-behavior-regression-eval.md`
(authoritative; this issue is the PRD view)". Published 2026-09-11 after
OQ1–OQ3 were answered.
`task-master` then slices Steps 1–7 with `to-tickets` under
`plan/2026-09-11-reviewer-behavior-regression-eval` and adds its own
slicing-table comment. Suggested dependency edges for slicing: 1 → 2 → 3;
1 → 4; {2,3,4} → 5; 5 → 6; 5 → 7.
