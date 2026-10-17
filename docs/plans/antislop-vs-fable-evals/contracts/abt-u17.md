Unit: abt-u17

## Objective
tests/validate.sh runs the eight tests/abtest-*.test.sh suites as sections (one insertion before the closing summary) and eval/abtest/README.md is the operator run guide; the lanes gate passes with all eight sections OK. One commit.

## Retrieval
GitHub issues: `gh issue view 586 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/README.md` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `if [ "$fail" -eq 0 ]; then`)

## Ordered edits
1. command: `test ! -e eval/abtest/README.md && ls tests/abtest-*.test.sh | wc -l | grep -qx 8 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/README.md`
   anchor: new file
   indent: 0
   insert-after:
~~~~
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
The runs use your Claude Max subscription, so there is no dollar cap; the caps are `MAX_TURNS`
(default 100) and `TIMEOUT_MIN` (default 45), equal for both arms.

Each run is built as a standalone repository under `ABT_WORK` (default `/tmp/antislop-abtest-work`),
outside this checkout: Claude Code loads a parent directory's `CLAUDE.md`, so a run inside the
checkout would give Arm A this repository's. The runner refuses a work root with a `CLAUDE.md` in it
or above it. Run artifacts (stream, summary, checks, diff) stay under `eval/abtest/.runs/`.

## Order of operations

1. Probe once: `bash eval/abtest/run-matrix.sh --probe-isolation --probe-model uniform`. It prints
   `probe:` lines and exits 0 only when Arm A shows no hook events and no persona, Arm B shows hook
   events and a subagent spawn, and both arms ran on a model whose name contains `fable`. Read the
   `probe-detail:` lines too: whether `--max-turns` was accepted, the stream record types, and the
   hook census in `eval/abtest/.runs/probe/B/hook-names.txt` (a hook listed twice may be registered
   by both the plugin and the scaffolded settings). The probe also asks Arm A whether its instructions
   mention this repository's code-review-graph section (`probe: A root_claude_md=not-loaded` is
   required) and makes both arms write the phrase "rate limit 429" (`probe: mention-case ok`), so a
   reply that merely mentions rate limits cannot be mistaken for a limit hit.
2. Check the fixtures: `bash eval/abtest/verify-checks.sh --all` must print `verify-checks: ok`.
3. Pilot, one run per arm per eval: `bash eval/abtest/run-matrix.sh --pilot`. Look at
   `eval/abtest/results.jsonl` and at `eval/abtest/.runs/<run>/` before going on. Pilot rows are valid
   rep-1 rows while the harness, plugin and prompt stay the same. After a fix, the next run repeats the stale
   rows and moves them to `results.superseded.jsonl`, which the scorer never reads (OD-14).
4. Full pass, five reps: `bash eval/abtest/run-matrix.sh`. Runs are sequential. Rep 1 is A then B,
   rep 2 is B then A, and so on.
5. Score: `python3 eval/abtest/score.py eval/abtest/results.jsonl --out-json eval/reports/abtest-<date>.json --out-md eval/reports/abtest-<date>.md`.
6. Grade the E1 judgment item: `bash eval/abtest/blind.sh eval/abtest/results.jsonl <dir>`, fill
   `<dir>/grades-template.csv` (1 if `ASSUMPTIONS.md` cites the glossary, else 0) while looking only at
   `<dir>/blind/`, then `bash eval/abtest/blind.sh --unseal <dir> <graded csv>`.

## Usage limits and resuming

A subscription usage or rate limit is recorded as `completion_status: usage-limit`. That row is kept,
it is excluded from every count and verdict, and the runner stops with exit 75. Wait for the limit to
reset and run the same command again: a run is done once a row exists for it whose status is not
`usage-limit`, so only the unfinished runs repeat. `--dry-run` prints the plan (`run` or `skip` per run).
If one run id is classified `usage-limit` three times, the runner stops with exit 76 instead of looping:
read that run's `stream.jsonl` under `eval/abtest/.runs/` before retrying (`ABT_MAX_LIMIT_HITS` raises
the cap). Each arm also runs under an outer `timeout -k`, so a `claude` that ignores SIGTERM is ended.

## What a row holds

One JSON line per run: arm, policy, rep, fixture and plugin commits, `completion_status`
(`complete`, `stalled-human`, `turn-cap`, `timeout`, `usage-limit`, `error`), the holdout `checks`,
`run_pass`, `defects_escaped`, `out_of_scope_lines`, token columns (`tokens_in`, `tokens_out`,
`tokens_cache_write`, `tokens_cache_read`, `tokens_total`), `num_turns`, `wall_clock_ms`, and a
`process` block for Arm B. A row is only written when the number of required checks equals the count
`verify-checks.sh` proved for that eval (`make-row.py --expected-required`), so an empty or all-optional
checks array can never give a passing row. `total_cost_usd` is stored when the CLI reports it and is never used.
`process.persona_tokens` is null: the arms run with `--no-session-persistence`, so no transcript exists
for per-persona attribution.

## Layout

- `arms/` the two arm scripts and their shared flags; `run-matrix.sh` the runner.
- `fixtures/<eval>/` build script, plant, reference solution, allowed paths; `checks/<eval>/` the
  holdout checks (copied into a throwaway copy of the final tree, never into the run).
- `tasks/<eval>.prompt.md` the prompt, byte-identical for both arms.
- `lib/` stream summariser, row assembler, blinding; `score.py` verdicts; `verify-checks.sh` the
  non-vacuity proof (every required check fails on the baseline and passes on the reference).
- `results.jsonl` and `.runs/` are git-ignored.
~~~~
3. file: `eval/abtest/README.md`
   anchor: line matching `are git-ignored.`
   indent: 0
   insert-after:
~~~~

**Residual risk (OD-16).** The arms cannot read the hidden checks or the reference solutions by the ordinary
routes: Arm B loads a pruned copy of the plugin, both arms run with deny rules for Read, Edit and Bash commands
that name the harness root, the runs directory or the results, and both run with a per-run HOME outside the
repository. A deny rule cannot stop a shell command that never names the path, so a determined agent with
shell access could still search the filesystem and find the checkout. These measures are defence in depth, not a
proof. `run-matrix.sh --probe-canary` plants a random token in the checks and fixtures directories and fails if
either arm finds it; a pass is a probe of the common routes, not a proof.
~~~~
4. file: `tests/validate.sh`
   anchor: line matching `if [ "$fail" -eq 0 ]; then`
   indent: 0
   before:
~~~~
echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
~~~~
   after:
~~~~
echo
echo "== tests/abtest-arms.test.sh: arm scripts, shared flags and the fake claude (Bash, abt-u01) =="
if bash tests/abtest-arms.test.sh > /dev/null; then
  echo "OK   tests/abtest-arms.test.sh"
else
  echo "FAIL tests/abtest-arms.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-stream.test.sh: stream summariser and completion status (Bash, abt-u02) =="
if bash tests/abtest-stream.test.sh > /dev/null; then
  echo "OK   tests/abtest-stream.test.sh"
else
  echo "FAIL tests/abtest-stream.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-row.test.sh: result-row assembler (Bash, abt-u03) =="
if bash tests/abtest-row.test.sh > /dev/null; then
  echo "OK   tests/abtest-row.test.sh"
else
  echo "FAIL tests/abtest-row.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-checks.test.sh: check conventions and the non-vacuity verifier (Bash, abt-u04) =="
if bash tests/abtest-checks.test.sh > /dev/null; then
  echo "OK   tests/abtest-checks.test.sh"
else
  echo "FAIL tests/abtest-checks.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-runner.test.sh: sequential resumable runner (Bash, abt-u12) =="
if bash tests/abtest-runner.test.sh > /dev/null; then
  echo "OK   tests/abtest-runner.test.sh"
else
  echo "FAIL tests/abtest-runner.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-probe.test.sh: isolation and model probes (Bash, abt-u13) =="
if bash tests/abtest-probe.test.sh > /dev/null; then
  echo "OK   tests/abtest-probe.test.sh"
else
  echo "FAIL tests/abtest-probe.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-score.test.sh: scorer and verdict rules (Bash, abt-u14) =="
if bash tests/abtest-score.test.sh > /dev/null; then
  echo "OK   tests/abtest-score.test.sh"
else
  echo "FAIL tests/abtest-score.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-blind.test.sh: blinded grading set (Bash, abt-u15) =="
if bash tests/abtest-blind.test.sh > /dev/null; then
  echo "OK   tests/abtest-blind.test.sh"
else
  echo "FAIL tests/abtest-blind.test.sh"
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
~~~~
5. command: `git add eval/abtest/README.md tests/validate.sh && git commit -m "test(abt-u17): register the abtest suites in the merge gate and add the operator README (#586)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/` other than the README (units abt-u01..u15 own the scripts; this unit only registers their tests)
- `tests/abtest-*.test.sh` and `tests/fixtures/abtest/` (never edit a test to make it register)
- `tests/validate-lanes.sh` and every existing section of `tests/validate.sh` (one insertion before the closing summary, nothing else)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `grep -c '^echo "== tests/abtest-' tests/validate.sh`
   exit: 0
   stdout: `8`
   mutation: skip edit 4 (the validate.sh insertion); stdout 0 and the exit is 1.
2. run: `grep -c 'tests/abtest-' tests/validate.sh`
   exit: 0
   stdout: `32`
   mutation: skip edit 4; stdout 0 and the exit is 1.
3. run: `for t in tests/abtest-*.test.sh; do grep -qF "bash $t" tests/validate.sh || echo "missing $t"; done | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip edit 4; all eight suites are missing and stdout is 8.
4. run: `grep -c '^## ' eval/abtest/README.md`
   exit: 0
   stdout: `5`
   mutation: skip edit 2 (the README); grep exits 2 on the missing file and prints nothing.
5. run: `grep -c 'exit 75' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; grep exits 2 on the missing file and prints nothing.
6. run: `out=$(bash tests/validate-lanes.sh --lanes 4); rc=$?; echo "$out" | grep -c "OK   tests/abtest-"; exit $rc`
   exit: 0
   stdout: `8`
   mutation: skip edit 4; no abtest section runs, so stdout is 0.
7. run: `grep -c 'exit 76' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; grep exits 2 on the missing file and prints nothing.
8. run: `grep -c 'ABT_WORK' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; grep exits 2 on the missing file and prints nothing.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/README.md tests/validate.sh`
   mutation: skip edit 5 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; no unit commit exists and the exit is 3.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u17\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/README.md tests/validate.sh | grep -vcE "^[a-z]+\(abt-u17\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- eval/abtest/README.md tests/validate.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 5; the new files stay untracked and are listed.
13. run: `grep -c 'results.superseded.jsonl' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; grep exits 2 on the missing file and prints nothing.
14. run: `grep -c 'Residual risk' eval/abtest/README.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 3 (the residual-risk paragraph); stdout 0 and the exit is 1.

## Pre-resolved context
tdd: no registration lines and a README; the registered tests already exist and are the checks (criteria 1-6 are red at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 12 (the scoped clean-tree check) passes at HEAD by design; it turns red only when the commit step is skipped.
depends-on: abt-u01, u02, u03, u04, u12, u12b, u13, u14 and u15 must have landed; edit 1 counts the eight tests and STOPs unless exactly eight exist; abt-u12c, abt-u13b and abt-u01b (the isolation measures the README describes).
gate-run: criterion 6 runs the lanes gate in the foreground (about 3 minutes; pass the 600000 ms timeout; never background it; it refuses a linked worktree, so use the normal checkout). If it fails only in tests/rollout-preflight.test.sh or tests/microworld/dashboard-decision-run.test.js (both timing-flaky), rerun that test alone and the lanes once more and report both runs.
no-real-claude: the registered tests use a fake claude; nothing here spends subscription usage.
commit-message: test(abt-u17): register the abtest suites in the merge gate and add the operator README (#586)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u17 (#586)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
criterion 5: <FILL: exit and stdout>
criterion 6: <FILL: exit and stdout>
criterion 7: <FILL: exit and stdout>
criterion 8: <FILL: exit and stdout>
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
