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
- OD-10 (errata, 2026-10-16, E1 premise check) The design's E1 `premise` check (a required keyword grep of
  ASSUMPTIONS.md) is replaced. Two keyword matchers were built and both failed review: the grep passed an
  ASSUMPTIONS.md that records nothing, and the stricter matcher rejected about a third of plausible honest
  files (it did not accept the plant glossary's own term "taxable amount" or common phrasings of "after the
  discount") while still passing files that state no or the wrong assumption. Free-text assumption quality
  cannot be graded fairly by keywords, and a required keyword check tilts the comparison towards whichever
  arm happens to echo the matcher's words. E1 now carries `assumptions-file-present` (kind process, not
  required): ASSUMPTIONS.md exists at the repo root, has at least 2 non-blank lines and 40 non-space
  characters, and is not byte-identical to the baseline CONTEXT.md, the baseline README.md or the task
  prompt; it reads no wording and does not enter run_pass. Whether the assumptions are the right ones is
  judged only by the blinded `assumptions_cites_glossary` grade (unit abt-u15). E1 therefore has 3 required
  checks (tax-after-discount, existing-behaviour, scope-outside-allowed); the baseline fails 1 of 3 and the
  reference 0 of 3. The E1 prediction in the pre-registration changes accordingly: run_pass is a likely tie,
  and the differentiator is the blinded grade.
- OD-11 (2026-10-16, E5 README check) The same keyword-matcher problem applies to E5's README check
  `readme-data-format-v2` (`grep -qi "version.*2" README.md`): it is now a NON-required `docs` check, reported
  but not part of run_pass. `readme-tags-route` (`grep -q "/tags" README.md`, the literal route the prompt
  names) stays required. E5 therefore has 8 required checks; the baseline fails 6 of 8 and the reference 0 of 8.
  The runner reads each eval's required count from `verify-checks.sh` and passes it to `make-row.py`
  (`--expected-required`), so no count is hard-coded.
- OD-12 (2026-10-17, scorer N rule, directional label and Fisher errata; from the abt-u14 review FAIL of 2026-10-17T02:00:10Z)
  (a) A per-eval outcome exists only at the pre-registered N. 5 usable rows in each arm (usable = not
  `usage-limit`, and of the policy being reported) decide by the 2-run gap of the doc's section 4.4 (`k_B - k_A >= 2` is
  WIN_B, `k_A - k_B >= 2` is WIN_A, a 1-run gap is INCONCLUSIVE). 10 or more usable rows in each arm, equal in both,
  decide by the Fisher two-sided exact p < 0.10 (a 1-run gap is then a Fisher TIE: the top-up is what cures
  INCONCLUSIVE, so it must not trap an eval at N=10). Fewer than 5 rows in either arm (the N=1 pilot, a run
  stopped by a usage limit), unequal counts, or 6 to 9 rows per arm (a top-up in progress) are INCONCLUSIVE, with the
  reason in the report ("short N: A=3 B=5", "unequal N: ...", "top-up in progress: ..."). Two or more
  `turn-cap`, `timeout` or `error` rows in an arm stay INCONCLUSIVE at every N. A pilot never produces a verdict:
  pilot rows are ordinary rep-1 rows of the full matrix and carry no marker, so N < 5 is what stops them.
  (b) The doc's section 4.4 verdict semantics are unchanged: a 2-run gap at N=5 is WIN_B as pre-registered. The
  scorer always computes and prints the Fisher two-sided exact p for every eval, even below N=10 (JSON `fisher_p`,
  a markdown column), and the markdown marks a gap-rule WIN_B whose p is not below 0.10 as
  `superior (directional, p=0.xx)`; the JSON verdict stays `superior` and gains `directional: true`. `not-superior` is
  unchanged.
  (c) Errata to the doc's section 2.5: 5/5 vs 1/5 is p = 1/21 = 0.048 two-sided (not 0.024); a 3-run gap at 10 vs 10
  is p between 0.21 and 0.37 (not about 0.07); a 4-run gap is p between 0.087 and 0.179 (not below 0.05); 2/10 vs 7/10
  is p = 0.0698. The scorer's Fisher matches exact fractions on 20 tables, listed in `tests/abtest-score.test.sh`.
  (d) The scorer fails closed: an empty results file, a file with no usable row, a policy that matches no row, a
  duplicate run_id, a non-boolean `run_pass`, a `run_pass` true on a non-complete row, a malformed token or count
  field, or `tokens_total` different from input + output + cache write (OD-5) stops it with a named error and a
  non-zero exit. The report prints the `core_no_win_a` condition (no WIN_A on E2 and E4, OD-7) and the count of
  rows dropped for another `model_policy`.
