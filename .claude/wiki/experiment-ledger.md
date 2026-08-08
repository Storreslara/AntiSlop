# Experiment ledger (mirror)

**Canonical source: [`docs/self-improvement-loops.md`](../../docs/self-improvement-loops.md).**
This page is a summary/mirror for wiki readers, not a second source of
truth — if this page and the source doc ever disagree, the source doc wins.
Update the source doc first, then refresh this mirror.

## What the ledger is, and why it exists

This repo has two self-improvement loops (full detail in the source doc):
**Loop A** mines real production telemetry from a separate project
(`~/claude_trace`) for waste, and **Loop B** is a controlled eval harness
(`eval/` in this repo) that tests specific, pre-registered hypotheses about
persona/hook changes under repeated, controlled conditions with an
independent holdout-test quality gate.

Loop B's hypotheses are numbered **E1, E2, E3, …** as they're proposed and
(usually) tested. Not every entry gets tested before shipping, though — the
ledger's whole point is to make that distinction visible at a glance:

- **Measured** — ran through the `eval/` harness as a controlled A/B against
  a same-task baseline, with recorded cost/turns/wall-time deltas and a
  holdout-test result, *before* being shipped.
- **Un-measured** — shipped by human product decision, with **no controlled
  trial, no cost/turns/wall-time data, no holdout run**. Still recorded in
  the ledger as an open hypothesis the harness could validate or refute
  later — just not yet.

A reader auditing "was this persona/hook change actually validated, or just
decided?" should be able to answer it from this table without reading the
full pilot log.

## Entry index

| ID | Change | Measured? | Verdict | Decision | Shipped? |
|----|--------|-----------|---------|----------|----------|
| E1 | `lead-programmer` gets `maxTurns: 30` (was uncapped) | Yes (N=5) | CONFIRMED — cost -10.4%, turns -38.1%, wall -15.4%, holdout 5/5 | SHIP | Yes — CHANGELOG 0.5.1 |
| E2 | Strict terse, verdict-only `reviewer` output contract | Yes (N=5) | CONFIRMED, strongest result in the pilot — cost -17.7%, turns -42.9%, wall -20.1%, holdout 5/5 | SHIP | Yes — CHANGELOG 0.5.1 |
| E3 | Delete `reviewer.md`'s explanatory HTML-comment preamble | Yes (N=2, outlier-tainted) | PLAUSIBLE but unresolved | NEEDS MORE DATA | No — never re-run |
| E4 | Orchestrator pre-builds a diff/log packet for the reviewer instead of ad hoc `git diff`/`git log` | Yes | REFUTED — cost +50.9%, wall +52.3%, one rep hit the budget circuit breaker | REJECT (for this fixture — diff too small to test the premise fairly) | No |
| E5 | Tighten `explorer` `maxTurns` 10 → 6 | Yes (N=2, ~2x variance) | INCONCLUSIVE | REJECT as tested | No |
| E6 | `spec-master`/`task-master` `maxTurns` 30 → 40 | **No — un-measured.** No controlled trial, no cost/turns/wall-time data, no holdout run. | N/A — not a harness verdict | Shipped by product decision (spec-master observed being cut off live at `maxTurns: 30` on 2026-07-28); remains an open hypothesis for the harness to validate or refute later | Yes — see `docs/plans/2026-07-28-maxturns-cutoff-handoff.md`, Step 5 |

A combined E1+E2 variant was proposed as a natural next experiment (they
touch different personas, so plausibly stack) but has not been run.

### Loop A findings, for completeness

Loop A's findings aren't numbered `E*` — they come from real production
telemetry (review 2, 2026-07-12), not a controlled trial, which is a third
category again: real-world signal, but no control group to isolate cause and
effect.

- **W1** (built-in `Explore` colliding with this project's own `explorer`
  persona) and **W3** (an un-truncated Bash output dump) each got a patch
  applied to `templates/persona-protocol.md`, shipped in CHANGELOG 0.5.2.
  Their `outcome` is still `pending` as of the last state check — no
  third telemetry review has landed yet to score whether they actually moved
  the metrics they targeted.
- **W2** (a 50KB single `Read` result) had no patch proposed at all — flagged
  as an open question for a human to judge, not asserted as waste.

## Reading the table

- **Measured** = ran through the `eval/` harness: a controlled A/B against a
  same-task, same-rep-count baseline, scored on both `npm test` and a
  held-out invariant test the implementation never saw during the run.
- **Un-measured** = shipped on human judgment alone, no harness run.
- SHIP / REJECT / NEEDS MORE DATA decision labels come straight from the
  pilot log's own verdict format (`docs/experiments/README.md` defines it).

## Where to look for more

- Full narrative and mechanism detail (Loop A + Loop B architecture): [`docs/self-improvement-loops.md`](../../docs/self-improvement-loops.md) — canonical
- Full E1–E5 pilot log with baseline numbers: `docs/experiments/pilot-2026-07-11.md`
- E6 background (the live cutoff event that motivated the un-measured raise): `docs/plans/2026-07-28-maxturns-cutoff-handoff.md`, Step 5
- Related wiki page: [persona-handoff-mechanisms.md](persona-handoff-mechanisms.md) — the WIP sentinel / pending-review flag / terminal status line mitigations built in response to the same live cutoff event that led to E6's cap raise
