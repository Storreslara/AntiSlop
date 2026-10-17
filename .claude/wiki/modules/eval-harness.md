# eval/

A pilot-evaluation harness comparing persona/hook-file **variants**
against a fixed coding task, to empirically measure whether a prompt/hook
change helps or hurts — not just "does it run."

- **`eval/fixtures/toy-lib-template/`** — a minimal disposable JS library
  (cart pricing lib) used as the sandbox project for every run.
- **`eval/tasks/`** — `feature-task.md` (spec: add
  `previewDiscountedTotal`/`checkout` functions with specific behavioral
  requirements) + `feature-task.holdout.test.js` (a held-out test file
  used to score whether the implementation actually meets the spec, beyond
  just whatever tests the agent itself wrote).
- **`eval/harness/*.sh`**:
  - `scaffold.sh` — fresh fixture + non-interactive `cli.js` install + OTel
    telemetry wiring.
  - `apply-variant.sh` — overlays a named variant's changed persona/hook
    files onto the scaffolded fixture.
  - `run.sh` — drives one headless run, scores it, appends a row to
    `results.jsonl`.
  - `pilot.sh` — drives the full variant × rep matrix.
  - `more-reps.sh` — top up specific variants without rerunning others.
  - `cleanup.sh` — tears down the scratch dir + trust entry.
- **`eval/results.jsonl`** — one JSON row per run: `variant`, `task`,
  `rep`, `tests_pass_own`, `holdout_present`, `tests_pass_with_holdout`,
  `total_cost_usd`, `num_turns`, `wall_clock_ms`.
- **`eval/.runs/`** — disposable per-run scratch dirs (gitignored).

Use this when proposing a persona/hook change with a plausible-but-unproven
"this should help" rationale — the harness turns that into a measured
comparison instead of a guess.

## Two-arm comparison (eval/abtest/)

Distinct from the one-arm variant pilot above and from the reviewer-verdict regression suite,
`eval/abtest/` compares **Arm A** (a bare Fable agent) with **Arm B** (AntiSlop as shipped) on
identical fixtures. Design: `docs/plans/antislop-vs-fable-evals.md`; operator overrides:
`docs/plans/antislop-vs-fable-evals/operator-decisions.md`; pre-registered predictions:
`docs/experiments/abtest-2026-10.md`; run guide: `eval/abtest/README.md`.

- `arms/` the two arm scripts; `run-matrix.sh` the sequential, resumable runner (a subscription
  usage limit is a `usage-limit` row, exit 75, not a failure).
- `fixtures/<eval>/` and `checks/<eval>/` the fixture, reference solution and holdout checks,
  proven non-vacuous by `verify-checks.sh`; `tasks/<eval>.prompt.md` the prompt, identical for both arms.
- `lib/` stream summary, row assembly and blinding; `score.py` the per-eval verdicts.
- Five evals are built (E1-E5); E6-E10 are designed but deferred.
