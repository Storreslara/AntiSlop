# abtest: AntiSlop vs bare Fable (E1-E5)

A two-arm comparison harness. Arm A is a bare Fable agent (`claude -p`, no plugin, no personas,
no hooks). Arm B is AntiSlop as shipped (orchestrator as the main agent, personas scaffolded,
plugin loaded with `--plugin-dir`). Both get the same fixture, the same prompt, the same turn cap
and the same time cap. Design: `docs/plans/antislop-vs-fable-evals.md`; operator overrides:
`docs/plans/antislop-vs-fable-evals/operator-decisions.md`; pre-registered predictions:
`docs/experiments/abtest-2026-10.md`.

This pass covers five evals: `e01-ambiguous-tax`, `e02-preview-mutation`, `e03-rename-query`,
`e04-search-injection`, `e05-tags-feature`. E6-E10 are deferred.

## Who runs what

The tests under `tests/abtest-*.test.sh` use a fake `claude` and spend no usage; they are part of
`bash tests/validate.sh`. Everything below that starts a real `claude` is launched by the operator
(or the orchestrator on the operator's word), never by a lead-programmer unit, and never in CI.
There is no dollar cap (Max subscription); the caps are `MAX_TURNS` (100) and `TIMEOUT_MIN` (45).

Each run is built as a standalone repository under `ABT_WORK` (default `${TMPDIR:-/tmp}/antislop-abtest-work`),
outside this checkout: Claude Code loads a parent directory's `CLAUDE.md`, so a run inside the
checkout would give Arm A this repository's. The runner refuses a work root with a `CLAUDE.md` in it
or above it. Run artifacts stay under `eval/abtest/.runs/`.

## Order of operations

1. Probe once: `bash eval/abtest/run-matrix.sh --probe-isolation --probe-model uniform`. It prints
   `probe:` lines and exits 0 only when Arm A shows no hook events and no persona, Arm B shows hook
   events and a subagent spawn, and both arms ran on a model whose name contains `fable`. Read the
   `probe-detail:` lines too: whether `--max-turns` was accepted, the stream record types and the
   hook census in `eval/abtest/.runs/probe/B/hook-names.txt`. The probe also asks Arm A whether its instructions
   mention this repository's code-review-graph section (`probe: A root_claude_md=not-loaded` is
   required) and makes both arms write the phrase "rate limit 429" (`probe: mention-case ok`), so a
   reply that merely mentions rate limits cannot be mistaken for a limit hit.
2. Canary probe: `bash eval/abtest/run-matrix.sh --probe-canary` must exit 0 before the pilot (OD-16(c) in
   `docs/plans/antislop-vs-fable-evals/operator-decisions.md`). It plants a random token in the checks and fixtures
   directories and fails if either arm prints it. An arm that is refused the prompt's `find /` (it lies outside the
   run's work directory) and prints no token is `not-found`, not `not-run`: the refusal shows that the direct route
   is closed, not that the token is unreachable by other means (OD-18). Each arm's own work directory also holds a
   control token that the prompt asks it to print, so a `not-found` shows that the probe can see a printed token.
   The runner does not enforce this order: read the exit code.
   - Exit 1 with `A=not-run` or `B=not-run`: that arm hit its turn cap, timed out or errored. Read the summary under `eval/abtest/.runs/probe-canary/A` or `eval/abtest/.runs/probe-canary/B`, fix the cause and rerun the probe. Do not run the pilot.
   - Exit 1 with `A=no-control` or `B=no-control`: that arm answered but did not print the control token from its work directory, so the probe could not have seen a leak in it. Read the `probe-detail: canary-control` line and the stream under `eval/abtest/.runs/probe-canary/A` or `eval/abtest/.runs/probe-canary/B`, fix the cause and rerun the probe. Do not run the pilot.
   - `probe: canary-denials A=<n> B=<n>` and the `probe-detail: <arm> denied <tool>: <command>` lines name every command an arm was refused. A refused `find /` with `not-found` is the expected result and exits 0.
   - Exit 1 with `A=FOUND` or `B=FOUND`: isolation is broken. Do not run the pilot; report it.
   - Exit 75: a usage limit was reached. Wait for the subscription window to reset and rerun the probe.
3. Check the fixtures: `bash eval/abtest/verify-checks.sh --all` must print `verify-checks: ok`.
4. Pilot, one run per arm per eval: `bash eval/abtest/run-matrix.sh --pilot`. Look at
   `eval/abtest/results.jsonl` and at `eval/abtest/.runs/<run>/` before going on. Pilot rows are valid
   rep-1 rows while the harness, plugin and prompt stay the same. After a fix, the next run repeats the stale
   rows and moves them to `results.superseded.jsonl`, which the scorer never reads (OD-14).
5. Full pass, five reps: `bash eval/abtest/run-matrix.sh`. Runs are sequential. Rep 1 is A then B,
   rep 2 is B then A, and so on.
6. Score (the scorer does not create the report directory): `mkdir -p eval/reports && python3 eval/abtest/score.py eval/abtest/results.jsonl --out-json eval/reports/abtest-<date>.json --out-md eval/reports/abtest-<date>.md`.
7. Grade the E1 judgment item: `bash eval/abtest/blind.sh eval/abtest/results.jsonl <dir>`, fill
   `<dir>/grades-template.csv` while looking only at `<dir>/blind/`, then `bash eval/abtest/blind.sh --unseal <dir> <graded csv>`.

## Usage limits and resuming

A subscription usage or rate limit is recorded as `completion_status: usage-limit`. That row is kept,
it is excluded from every count and verdict, and the runner stops with exit 75. Wait for the limit to
reset and run the same command again: a run is done once a row exists for it whose status is not
`usage-limit`, so only the unfinished runs repeat. `--dry-run` prints the plan (`run`, `skip` or `rerun (stale provenance)` per run).
If one run id is classified `usage-limit` three times, the runner stops with exit 76 instead of looping:
read that run's `stream.jsonl` under `eval/abtest/.runs/` before retrying (`ABT_MAX_LIMIT_HITS` raises
the cap). Each arm also runs under an outer `timeout -k`.

## What a row holds

One JSON line per run: arm, policy, rep, fixture and plugin commits, `completion_status`, the holdout
`checks`, `run_pass`, `defects_escaped`, `out_of_scope_lines`, the token columns, `num_turns`,
`wall_clock_ms` and a `process` block for Arm B. A row is only written when the number of required checks
equals the count `verify-checks.sh` proved for that eval (`make-row.py --expected-required`).
`total_cost_usd` is stored when the CLI reports it and is never used; `process.persona_tokens` is null
(the arms run with `--no-session-persistence`).

## Layout

- `arms/` the two arm scripts and their shared flags; `run-matrix.sh` the runner.
- `fixtures/<eval>/` build script, plant, reference solution, allowed paths; `checks/<eval>/` the
  holdout checks (copied into a throwaway copy of the final tree, never into the run).
- `tasks/<eval>.prompt.md` the prompt, byte-identical for both arms.
- `lib/` stream summariser, row assembler, blinding; `score.py` verdicts; `verify-checks.sh` the non-vacuity proof.
- `results.jsonl`, `results.superseded.jsonl` and `.runs/` are git-ignored.

**Residual risk (OD-16).** The arms cannot read the holdout checks or the reference solutions by the ordinary
routes: Arm B loads a pruned copy of the plugin, both arms run with deny rules for Read, Edit and Bash commands
that name the harness root, the runs or the results, and with a per-run HOME outside the repository. A deny
rule cannot stop a shell command that never names the path, so a determined agent with shell access could
still search the filesystem and find the checkout. These measures are defence in depth, not a proof;
`run-matrix.sh --probe-canary` plants a random token in the checks and fixtures directories and fails if
either arm finds it, and a pass is a probe of the common routes, not a proof. A refused search proves that the
direct route (`find /` from the run's work directory) is closed, not that the token is unreachable by other means,
and the control token planted in each arm's own work directory shows only that a token the arm prints reaches the
stream the probe searches, not that the checks or fixtures directories are out of reach (OD-18).
