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
