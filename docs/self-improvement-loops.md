# How this plugin improves itself: the two feedback loops

This repo (`antislop`, formerly `seb-personas`) ships two independent, but
complementary, mechanisms for generating evidence about whether the persona
system is actually working well, and turning that evidence into shipped
changes. Both are "propose, human applies" — neither ever writes to this
repo automatically.

| | **Loop A: telemetry / trace-analysis loop** | **Loop B: cost-efficiency eval harness** |
|---|---|---|
| Lives in | `~/claude_trace` (a separate, real project that runs this plugin) | `~/seb_claude_setup/eval/` (this repo) |
| Data source | Real OTel traces from actual day-to-day usage | Synthetic runs of a toy fixture, repeated N times per variant |
| Question it answers | "Where is *this real project's* usage wasting tokens/$ right now?" | "Does changing *this specific file* measurably help, holding everything else constant?" |
| Trigger | Autonomous — a `SessionStart` hook counts sessions/days and nags when a review is due | Manual — a human runs `pilot.sh` to test a hypothesis |
| Output | Markdown report (3-tier findings) + a proposed patch + a DuckDB row tracking whether the patch worked | A markdown experiment log entry with pre-registered prediction vs. measured result |
| Shipped via | CHANGELOG 0.5.2 | CHANGELOG 0.5.1 |

They're complementary rather than redundant: Loop A finds *what's broken in
production* but can't isolate cause and effect (one project, real workloads,
no control group). Loop B can isolate cause and effect precisely (controlled
A/B, held-out test as an independent quality gate) but only tests hypotheses
someone already thought to propose, on a fixture that may not resemble real
usage. Loop A generates hypotheses Loop B would be well-suited to validate
(see "Where the loops meet" below), though that combination hasn't been run
yet.

---

## Loop A: the telemetry self-improvement loop (`~/claude_trace`)

### Why it exists

`~/claude_trace` is a real project that installed this plugin (ADR
[`docs/adr/0001-adopt-seb-personas.md`](../../claude_trace/docs/adr/0001-adopt-seb-personas.md)
in that repo) and additionally wired up OTel telemetry per
`docs/SETUP_PLAN_token_bleed_tracking.pdf`. Two hand-authored subagents (not
part of the antislop plugin itself — they live only in `~/claude_trace/.claude/agents/`)
turn that telemetry into shipped fixes here:

- **`telemetry-reviewer`** (opus, read-only) — periodically mines the OTel
  DB for token/dollar waste and writes a report. Never touches code.
- **`persona-improver`** (sonnet) — reads those reports, drafts concrete
  patches against `~/seb_claude_setup`, and tracks whether previously-applied
  patches actually helped, using a DuckDB-backed proposal/outcome ledger.

Both are propose-only. Neither can write into `~/seb_claude_setup` — enforced
twice over: `persona-improver` has no `Edit` tool and never targets that path
with `Write`, and this repo's own `protected-paths.sh` `PreToolUse` hook
would block it mechanically even if it tried.

### Trigger mechanism

`~/claude_trace/.claude/hooks/session-start-telemetry.sh` runs on every
`SessionStart`. It:
1. Ensures the `otel-desktop-viewer` collector process is alive (relaunches
   it if not — there's no systemd/launchd on this machine).
2. Increments a `sessions_since_review` counter in
   `.claude/telemetry_review_state.json` under an mkdir-based lock (handles
   concurrent session starts without corrupting the counter).
3. Computes days since the last report filename's UTC timestamp.
4. If `sessions_since_review >= 10` OR `days_since >= 7` (or no report exists
   yet), prints a stderr reminder telling the live session to invoke
   `telemetry-reviewer`.
5. Separately, if the latest report hasn't been consumed yet (compared
   against `persona-improver`'s own `.claude/improvement_state.json`),
   prints a reminder to run `persona-improver` too.

Hooks can't invoke an LLM directly, so this is a nag, not an automatic
trigger — a human or the live session has to actually spawn the subagent in
response.

### `telemetry-reviewer`: how a review runs

Fixed paths: collector DB at `~/otel/otel_data.duckdb`, reports written to
`.scratch/telemetry-review/telemetry_review_<UTC timestamp>.md`, filtered to
this project via `project.name = 'claude-trace-80b9a0f0'` (the DB is shared
across every OTel-enabled project on the machine, including this repo's own
`eval/` pilot runs — the project-name filter is mandatory and self-checked
every review to catch cross-project contamination).

Mechanics worth knowing:
- **Schema-drift check first, always** — a renamed table/column/attribute
  key silently returns zero rows rather than erroring, so every review opens
  by confirming the schema still looks as expected before trusting any
  query.
- **Stop → query → restart, as one uninterruptible script with a `trap ...
  EXIT`** — the collector holds the DuckDB file open exclusively for its
  entire runtime, so a read-only connection needs the collector stopped
  first. The trap guarantees the collector comes back even if the review
  crashes mid-query.
- **A budget-enforced query loop**: `budget = min(6 + n_sessions +
  ceil(events/500), 60)`, wrapped so exceeding it raises rather than
  silently truncating — hitting the ceiling is itself reported as a finding.
- **Six-part standard analysis suite** (§7 of `telemetry-reviewer.md`):
  token totals by session/model/source, a subagent-spawn audit (including a
  specific check for built-in-agent-name collisions with this project's own
  personas), duplicate/retried tool calls, tool-cost outliers (median+MAD,
  falling back to p95 on small samples), cache efficiency (corroborating
  evidence only, never standalone), and a trend-over-time comparison against
  the last ≤3 reports' structured JSON blocks.
- **Output**: a three-tier report (Critical / Warnings / Suggestions, each
  needing session id + evidence + a concrete fix) plus a fenced JSON summary
  block at the top that the *next* review reads back for trend comparison.

### `persona-improver`: how a proposal is generated and tracked

Given a new report, `persona-improver` walks Critical then Warning findings
(skipping Suggestions unless one names a concrete file/persona as root
cause), and for each actionable one:

1. Greps `~/seb_claude_setup` read-only to find the target file(s).
2. Reads the current file, drafts a fixed version to a scratch tmp file
   (never edits the real file in place).
3. Diffs old vs. new with `a/`/`b/` path prefixes so the result applies
   cleanly with `git apply` from inside `~/seb_claude_setup`, and saves it to
   `.scratch/persona-improvements/patches/<id>.patch`.
4. Inserts a row into a `proposals` table in `~/otel/improvements.duckdb`
   (schema in `.scratch/persona-improvements/schema.sql`), recording the
   baseline metric values, the source finding, and which metrics this patch
   is meant to move.

**Outcome tracking is the interesting part** — this is what makes it a loop
rather than a one-shot suggestion box. Every run, *before* processing any new
report, `persona-improver` re-evaluates every `applied` proposal against
every telemetry review that's landed since. For each targeted metric it
computes `delta_pct` against the proposal's recorded baseline, classifies it
`worked` / `no_change` / `worse` / `inconclusive` (±10% noise band, direction
depends on the metric — e.g. lower is better for cost/tokens, higher is
better for cache-hit ratio), and once `evaluate_after_n_reviews` (default 3,
matching the reviewer's own trend window) reports have accumulated, rolls
those per-review verdicts into a final `proposals.outcome` — conservatively:
any single `worse` verdict wins the rollup regardless of how many `worked`.
Whether a proposal was actually applied is auto-detected via a reverse
`git apply --check -R` against the live repo, so a human applying the patch
by hand (the normal path) is picked up automatically without the improver
needing to be told.

### What it's actually found and shipped, so far

**Review 1 (2026-07-09)**: mechanism-validation only — one session, no
subagents spawned, nothing to find. Established the first cache-hit-ratio
baseline (0.825) and flagged one schema gap to re-check later (`agent.name`
absent — expected, since no subagent had run yet).

**Review 2 (2026-07-12)**: the first substantive review — 9 sessions, ~2.16M
tokens, $3.91 real spend (using Claude Code's own computed cost metrics, not
an estimate). Findings:
- **W1**: session `89ad18ba` shows the built-in `Explore` subagent ran
  ($0.10 of that session's $0.23) instead of this project's own `explorer`
  persona — auto-delegation picked the generic built-in over the
  similarly-named custom one, losing Code Review Graph access in the
  process.
- **W2**: a single 50KB `Read` result (~12-13K tokens), 7.3× the project's
  p95 tool-result size — flagged as an open question ("was this necessary?"),
  not asserted as waste, since intent can't be confirmed from telemetry
  alone.
- **W3**: an 18KB `Bash` result outlier, likely an un-truncated command dump.

`persona-improver` turned W1 and W3 into two patches
(`.scratch/persona-improvements/patches/20260712_053424_{w1,w3}.patch`)
against `templates/persona-protocol.md`:
- W1's patch added a name-collision warning: spawn `explorer` by name rather
  than relying on description-based auto-delegation, and treat a
  non-graph-derived answer as a signal the built-in ran instead.
- W3's patch added a "scope Bash output before it enters context" rule:
  pipe verbose commands through `head`/`tail`/`grep` before the output lands
  in context.

A human applied both (per CHANGELOG 0.5.2). W2 (the 50KB Read) had no
proposed patch — it's the kind of finding the design explicitly treats as a
question for a human to judge, not something with a nameable code-level fix.

**Outcome status as of the last state check**: both patches are recorded as
`applied` (`.claude/improvement_state.json` shows
`last_processed_report: telemetry_review_20260712_052612.md`), but their
`outcome` is still `pending` — no subsequent telemetry review has run yet to
score whether the name-collision warning or the Bash-scoping rule actually
moved `subagent_builtin_collision_count` or tool-result-size outliers. That
scoring will happen automatically the next time `persona-improver` runs
after a third telemetry review lands.

---

## Loop B: the cost-efficiency eval harness (`eval/`, this repo)

### Why it exists

Loop A tells you something is wasteful in one real project's usage, but a
single production project has no control group — you can't know whether a
change actually helped, only that a metric moved (and moved for any number
of confounding reasons). The eval harness exists to test specific,
pre-registered hypotheses about persona/hook changes under controlled,
repeated conditions, with an independent quality gate so a "cheaper" variant
that quietly got sloppier gets caught rather than declared a win.

### Harness architecture

All under `eval/harness/`:
- **`scaffold.sh DEST [--force]`** — copies `eval/fixtures/toy-lib-template/`
  into a disposable directory, installs the plugin into it non-interactively
  via `bin/cli.js`, fills in the config `/install-antislop` would normally do
  interactively, pre-trusts the workspace in `~/.claude.json` (a fresh
  scratch dir is otherwise untrusted and headless `claude -p` silently drops
  `settings.json`'s `permissions.allow`), and wires in the same OTel
  telemetry block `~/claude_trace` uses under a fresh `project.name` — so
  pilot runs land in the same shared `~/otel/otel_data.duckdb`, queryable the
  same way.
- **`apply-variant.sh`** — overlays one `eval/variants/<slug>/` directory's
  files onto the scaffolded fixture (each variant is a minimal diff — one
  file, one change, per the "never bundle unrelated changes" rule).
- **`run.sh DEST TASK VARIANT REP PROJECT_NAME`** — the actual measurement:
  runs `claude -p` headless against the fixture with a hard
  `--max-budget-usd` circuit breaker, then scores it two ways — the
  implementer's own `npm test`, and (if the task defines one) a held-out
  invariant test copied in *after* the run completes, so the model never
  sees it. Appends one JSON row to `eval/results.jsonl` with cost, turns,
  wall-clock, and both pass/fail results, straight from the CLI's own
  `--output-format json` (`total_cost_usd`, `num_turns`, `usage`, etc.) —
  nothing here is estimated.
- **`pilot.sh`** — drives the full matrix: for each variant × REPS,
  scaffold → apply-variant → run.
- **`more-reps.sh`**, **`cleanup.sh`** — top up a variant to more reps, and
  tear down + un-trust a scratch dir.

### The fixture and its holdout test

`eval/fixtures/toy-lib-template/` is a small library with a deliberately
planted mutation trap: `applyDiscountPercent` mutates its input in place, so
a naive `previewDiscountedTotal` that reuses it silently corrupts the cart.
`eval/tasks/feature-task.md` is the prompt; `feature-task.holdout.test.js` is
the independent check that the implementation copied before mutating rather
than just passing its own tests. This is what makes "cost went down" and
"quality held" separable, measured claims instead of one bundled vibe.

### Experiment log discipline

`docs/experiments/README.md` defines the format every pilot file follows:
pre-register a **Hypothesis** and a specific numeric **Prediction** *before*
running, record the **Change** (one variant, one file, one diff), compare
against a same-task/same-rep-count **Baseline**, then the measured
**Result**, a **Verdict** (CONFIRMED/REFUTED/INCONCLUSIVE against the
prediction), and a **Decision** (SHIP/REJECT/NEEDS MORE DATA). Hard rule: a
reviewer-touching variant that regresses `tests_pass_with_holdout` is always
a REJECT regardless of cost savings — dropping the defect-catch rate quietly
is never an acceptable trade. SHIP is a proposal, not an action — nothing in
the harness writes to the real `agents/*.md`/`hooks/` automatically; a human
applies it by hand, same discipline as Loop A's patches.

### Pilot 2026-07-11: what was tested and what shipped

Full log: `docs/experiments/pilot-2026-07-11.md`. Baseline: 5 reps, all
passed both test gates, mean cost **$0.641**, mean turns **8.4**, mean
wall-clock **178s** — with real spread (turns 7-12, cost $0.52-0.74) that
every variant result has to clear before a delta means anything.

One full attempt at the variant matrix was invalidated (session-level API
rate limit hit right after baseline reps consumed the budget — 0 real
requests made, not a finding about any hypothesis) — this also surfaced and
fixed a real bug in the harness itself: `scaffold.sh` wasn't pre-trusting
scratch workspaces, so `permissions.allow` was silently ignored.

Five hypotheses were tested, topping the two winners up to N=5 to match
baseline's sample size:

| # | Hypothesis | Result (N=5 where applicable) | Verdict | Decision |
|---|---|---|---|---|
| E1 | `lead-programmer` gets `maxTurns: 30` (was uncapped) | cost -10.4%, turns -38.1%, wall -15.4%, holdout 5/5 | CONFIRMED | **SHIP** |
| E2 | Strict terse, verdict-only `reviewer` output contract | cost -17.7%, turns -42.9%, wall -20.1%, holdout 5/5 | CONFIRMED — strongest result in the pilot | **SHIP** |
| E3 | Delete `reviewer.md`'s explanatory HTML-comment preamble | cost -8.8%, turns -58.3% (rep1=1 turn, suspicious outlier), holdout 2/2 | PLAUSIBLE but outlier-tainted | NEEDS MORE DATA |
| E4 | Orchestrator pre-builds a diff/log packet for the reviewer instead of ad hoc `git diff`/`git log` | cost **+50.9%**, wall **+52.3%**, one rep hit the budget circuit breaker before finishing | REFUTED | REJECT (for this fixture — its diff is too small to test the premise fairly) |
| E5 | Tighten `explorer` `maxTurns` 10 → 6 | cost +6.3% but ~2x variance between the 2 reps | INCONCLUSIVE | REJECT as tested |

Quality never regressed across all 18 reps run in the pilot (12 initial + 6
top-up): `tests_pass_with_holdout` was 18/18, including on the terse-reviewer
variant — the exact failure mode ("terseness silently drops the catch rate")
the source idea itself had flagged as the risk to check for.

E1 and E2 were applied by a human to the real `agents/lead-programmer.md`
and `agents/reviewer.md` and shipped in **CHANGELOG 0.5.1**. E3 was never
re-run to resolve the outlier and was not shipped. E4 and E5 were rejected as
tested; the log explicitly notes E4's underlying premise (ad hoc git
discovery is expensive) wasn't disproven in general, just on a fixture whose
diff is too small — it would need a bigger-diff fixture to test fairly. A
combined E1+E2 variant (they touch different personas, so plausibly stack)
was proposed as a natural next experiment but not run in this pilot.

---

## Where the loops meet

They haven't been formally combined yet, but the natural next step, noted in
both places, is using Loop A's production findings as Loop B hypotheses:
Loop A's W1 (built-in `Explore` colliding with the project's `explorer`) was
patched directly into `persona-protocol.md` without a controlled trial —
reasonable, since it's an instruction-text fix with no real cost/quality
tradeoff to weigh. But a finding with an actual tradeoff (e.g. "is the
review-packet idea worth it on a bigger, more realistic diff?" from E4)
is exactly the kind of question Loop B's controlled harness is built to
answer once someone builds a fixture with a large enough diff.

## File map

```
seb_claude_setup/                                  (this repo — canonical source)
  docs/experiments/README.md                        pilot log format spec
  docs/experiments/pilot-2026-07-11.md               E1-E5 results, shipped in 0.5.1
  eval/harness/{scaffold,apply-variant,run,pilot,more-reps,cleanup}.sh
  eval/fixtures/toy-lib-template/                    fixture with the planted mutation trap
  eval/tasks/feature-task.{md,holdout.test.js}       prompt + independent quality gate
  eval/variants/<slug>/agents/*.md                   one minimal diff per hypothesis
  eval/results.jsonl                                 raw per-run rows (cost/turns/usage/pass-fail)
  CHANGELOG.md                                       0.5.1 (Loop B), 0.5.2 (Loop A) ship notes

claude_trace/                                        (separate real project — telemetry source)
  .claude/agents/telemetry-reviewer.md                report-writing subagent (opus, read-only)
  .claude/agents/persona-improver.md                  patch-proposing + outcome-tracking subagent
  .claude/hooks/session-start-telemetry.sh            SessionStart trigger + collector liveness
  .scratch/telemetry-review/telemetry_review_*.md     reports (JSON header + 3-tier findings)
  .scratch/persona-improvements/schema.sql             DuckDB proposals/outcome_evaluations schema
  .scratch/persona-improvements/patches/*.patch        proposed, human-applied patches
  .claude/improvement_state.json                       last report persona-improver processed
  .claude/telemetry_review_state.json                  sessions-since-last-review counter
  ~/otel/otel_data.duckdb                              raw OTel traces (shared across all projects)
  ~/otel/improvements.duckdb                            proposal + outcome ledger
```
