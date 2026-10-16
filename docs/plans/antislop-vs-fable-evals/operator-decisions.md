# Operator decisions for the E1-E5 build-out and run (2026-10-16)

Applies to `docs/plans/antislop-vs-fable-evals.md` (the design, "the doc"). Where this
file conflicts with the doc, this file wins for the E1-E5 slice. Recorded by task-master
from the operator's dispatch message; the doc's substance is not edited.

- OD-1 Scope: E1-E5 only (`e01-ambiguous-tax`, `e02-preview-mutation`, `e03-rename-query`,
  `e04-search-injection`, `e05-tags-feature`). E6-E10 are not sliced. Counts in the doc's
  C2.3 and C4.1 become 5 fixtures/prompts/check dirs/references and 50 uniform-policy rows
  (5 evals x 2 arms x 5 reps).
- OD-2 Billing: Claude Max subscription, not API billing. The doc's USD caps (30 USD per
  run, 600 USD suite), `--max-budget-usd`, `SUITE_BUDGET_USD` and the `budget`
  completion_status do not apply and must not appear in new harness code. In their place:
  a per-run main-session turn cap `MAX_TURNS` (default 100, passed as `--max-turns`) and a
  per-run wall-clock cap `TIMEOUT_MIN` (default 45), equal for both arms.
- OD-3 Execution: runs are sequential (one `claude` at a time, never parallel). A pilot
  with N=1 per arm per eval (10 runs, uniform policy) runs first as a smoke gate: it
  proves the isolation probe, the model-alias probe, check non-vacuity, and that Arm B
  does not stall headlessly. Only then the full N=5. The runner is resumable.
- OD-4 Usage-limit handling: `completion_status` is one of `complete`, `stalled-human`,
  `turn-cap`, `timeout`, `usage-limit`, `error`. A subscription usage-limit or rate-limit
  hit is `usage-limit`, never a failure and never an outcome: the row is kept, it is
  excluded from every verdict count, the runner stops with exit 75, and the run is repeated
  on resume. A run_id is done iff a row exists for it whose completion_status is not
  `usage-limit`.
- OD-5 Cost columns: dollar cost is dropped from the verdict. Per-run columns are
  `tokens_in`, `tokens_out`, `tokens_cache_write`, `tokens_cache_read`, `tokens_total`
  (= input + output + cache_write; cache_read excluded), `num_turns`, `wall_clock_ms`.
  `total_cost_usd` is stored if the CLI reports it, for information only, never read by the
  scorer. The doc's `R_cost` becomes `R_tokens = median(tokens_total_B) / median(tokens_total_A)`
  over complete runs, with the doc's thresholds (<= 2, > 3) unchanged; `R_wall` unchanged;
  `R_turns` is reported alongside. Per-persona token attribution uses
  `scripts/token-usage/agg.py` as the doc says.
- OD-6 Kept from the doc: uniform model policy (all personas on Fable, `--model <fable>` and
  `CLAUDE_CODE_SUBAGENT_MODEL=<fable>` for Arm B) is the headline; headless stalls count as
  `run_pass=false` with a separate `stalled-human` tally; the operator grades the blinded
  judgment items (E1's `ASSUMPTIONS.md` item only; E7's is deferred with E7).
- OD-7 Deferred (the doc does not need them for E1-E5 verdicts): the shipped-policy
  replicates for E2 and E5 (the doc's section 4.5 reads `shipped` only for E8 and E9, and
  section 4.4 computes each E1-E5 verdict per (eval, policy) from the uniform rows alone);
  the E4 Arm-B-only critical-mode process sub-run (the doc says it "scores H6, never the
  outcome"); the aggregate verdict (it needs all ten evals). The report states
  `aggregate: not-evaluated, E6-E10 deferred` and lists the per-eval verdicts plus the
  pre-registered core condition "no WIN_A on E2 and E4" as a partial reading.
- OD-8 Who launches runs: the orchestrator or the operator launches every run that spawns a
  headless `claude` (the pilot and the full matrix). lead-programmer units never run
  `claude`; their acceptance criteria use a fake `claude` shim.
- OD-9 Not in the doc, chosen here: the per-run turn cap is enforced with the CLI flag
  `--max-turns`; the pilot proves the flag is accepted. Subagent turns inside Arm B are not
  counted by it, so "equal cap" means equal main-session `--max-turns` and equal wall-clock
  timeout, recorded per row.
