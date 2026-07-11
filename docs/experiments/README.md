# Experiment log format

Each pilot gets its own dated file (`docs/experiments/pilot-<date>.md`). Each
entry in that file follows this shape — pre-register the prediction *before*
running the experiment, not after:

```markdown
### E<n>: <short name>

- **Hypothesis**: what change, and why we think it helps.
- **Prediction**: a specific numeric prediction, made before running
  (e.g. "total_cost_usd drops >=15% vs baseline, tests_pass_own and
  tests_pass_with_holdout stay true on every rep").
- **Change**: which file(s) under `eval/variants/<slug>/`, one-line summary
  of the diff. Never bundle unrelated changes into one experiment.
- **Baseline**: the baseline run(s) this is compared against (variant
  "baseline", same task, same rep count) — reference by row in
  `eval/results.jsonl`, not by re-describing numbers here.
- **Result**: the measured numbers, written after running — cost, turns,
  wall-clock, tests_pass_own, tests_pass_with_holdout, across all reps.
- **Verdict**: CONFIRMED / REFUTED / INCONCLUSIVE — did the prediction hold?
- **Decision**: SHIP (worth porting into the real `agents/*.md`/`hooks/`),
  REJECT (regressed cost or quality), or NEEDS MORE DATA (variance too high
  at this rep count to call it).

If REFUTED or unexpected, say why in one line before moving on — that's what
makes the log useful to the next experiment, not just a scoreboard.
```

## Rules

- Every experiment needs a baseline run in the *same* task/rep-count
  condition — never compare across different task prompts.
- `tests_pass_with_holdout` regressing (true -> false or null) relative to
  baseline on a reviewer-touching variant is always a REJECT, regardless of
  cost savings — a change that quietly drops the defect-catch rate is not a
  win.
- SHIP decisions are proposals, not actions: nothing in this pilot writes to
  the real `agents/*.md`/`hooks/scripts/*.sh` under `~/seb_claude_setup`
  automatically. A human applies a SHIP decision by hand, same as
  `persona-improver`'s patches.
