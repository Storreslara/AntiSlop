Unit: abt-u18

## Objective
`CONTEXT.md` defines Arm A / Arm B, holdout check, out-of-scope lines, overhead ratio, completion status and model policy, and `.claude/wiki/modules/eval-harness.md` carries a section on the two-arm comparison suite `eval/abtest/`.

## Retrieval
GitHub issues: `gh issue view 587 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`, "Scribe update hint"; operator overrides: `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Glossary edits
1. file: `CONTEXT.md`
   heading: `**memory archive**:`
   placement: insert after the paragraph of this entry, separated by one blank line
   indent: 3
   text:
   ~~~~
   **Arm A / Arm B**:
   (unit abt-u18, 2026-10-16) — the two experimental conditions of the AntiSlop-vs-Fable comparison suite in `eval/abtest/`. Arm A is a bare Fable agent (`claude -p`, no plugin, no personas, no hooks); Arm B is AntiSlop as shipped (orchestrator as the main agent, personas scaffolded, plugin loaded with `--plugin-dir`). Both get the same fixture, prompt, turn cap and time cap. _Avoid_: "armed" for this sense; that word is the harness's `harness_armed` state.
   ~~~~
2. file: `CONTEXT.md`
   heading: `**Arm A / Arm B**:`
   placement: insert after the paragraph of this entry, separated by one blank line
   indent: 3
   text:
   ~~~~
   **holdout check**:
   (unit abt-u18, 2026-10-16) — any machine check that runs after a comparison run ends, on a throwaway copy of the final tree, and is never visible to the agent during the run. A holdout test (`eval/tasks/*.holdout.test.js`) is one kind; others are greps, diffs and scope counts. A check is only trusted after it fails on the baseline and passes on a reference solution (`eval/abtest/verify-checks.sh`).
   ~~~~
3. file: `CONTEXT.md`
   heading: `**holdout check**:`
   placement: insert after the paragraph of this entry, separated by one blank line
   indent: 3
   text:
   ~~~~
   **out-of-scope lines**:
   (unit abt-u18, 2026-10-16) — added plus deleted lines in files outside an eval's allowed paths; the persona scaffold (`.claude/`) and `docs/plans/` never count. The measured form of the `coding-discipline` surgical-diff rule. _Avoid_: "scope creep" as a metric name.
   ~~~~
4. file: `CONTEXT.md`
   heading: `**out-of-scope lines**:`
   placement: insert after the paragraph of this entry, separated by one blank line
   indent: 3
   text:
   ~~~~
   **overhead ratio**:
   (unit abt-u18, 2026-10-16) — median Arm B divided by median Arm A over complete runs, for tokens (`R_tokens`, input plus output plus cache write), wall time (`R_wall`) or turns (`R_turns`). Dollar cost is not used because the runs are on a subscription.
   ~~~~
5. file: `CONTEXT.md`
   heading: `**overhead ratio**:`
   placement: insert after the paragraph of this entry, separated by one blank line
   indent: 3
   text:
   ~~~~
   **completion status**:
   (unit abt-u18, 2026-10-16) — how one comparison run ended: `complete`, `stalled-human` (the pipeline stopped for a human in a headless run), `turn-cap`, `timeout`, `usage-limit` or `error`. `usage-limit` is a subscription limit hit, not a failure: its row is kept, excluded from every verdict, and the run is repeated.
   ~~~~
6. file: `CONTEXT.md`
   heading: `**completion status**:`
   placement: insert after the paragraph of this entry, separated by one blank line
   indent: 3
   text:
   ~~~~
   **model policy**:
   (unit abt-u18, 2026-10-16) — `uniform` (the bare agent and every persona on the same model, which isolates the process effect) or `shipped` (AntiSlop's own per-persona routing and escalation ladder, which answers the product cost question).
   ~~~~

## Doc edits
1. file: `.claude/wiki/modules/eval-harness.md`
   heading: `# eval/`
   placement: append at the end of the file, separated by one blank line
   indent: 3
   text:
   ~~~~
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
   ~~~~
prune: none

## ADR
none

## Close conditions
- issue #587
- task-id: abt-u18
- marker first line: "PASS abt-u18 "

## Do NOT touch
- `agents/`, `templates/`, `hooks/` and `skills/`
- `docs/adr/` and `docs/harness-glossary.md`
- `eval/`, `tests/` and `docs/plans/` (the scripts, tests and plans these entries describe are other units')

## Acceptance criteria
1. run: `/usr/bin/grep -cE '^[*][*](Arm A / Arm B|holdout check|out-of-scope lines|overhead ratio|completion status|model policy)[*][*]:$' CONTEXT.md`
   exit: 0
   stdout: `6`
   mutation: skip all six glossary edits; stdout 0 and the exit is 1.
2. run: `/usr/bin/grep -cF '_Avoid_: "armed" for this sense' CONTEXT.md`
   exit: 0
   stdout: `1`
   mutation: skip glossary edit 1; stdout 0 and the exit is 1.
3. run: `/usr/bin/grep -cF 'is a subscription limit hit, not a failure' CONTEXT.md`
   exit: 0
   stdout: `1`
   mutation: skip glossary edit 5; stdout 0 and the exit is 1.
4. run: `/usr/bin/grep -cF 'Two-arm comparison (eval/abtest/)' .claude/wiki/modules/eval-harness.md`
   exit: 0
   stdout: `1`
   mutation: skip the doc edit; stdout 0 and the exit is 1.
5. run: `node tests/context-glossary-links.test.js`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: add the link [[no such term]] to one new entry; the test fails.
   proof: scratch run: a CONTEXT.md copy holding the link [[no such term]] in a new entry made the test exit non-zero.
6. run: `node tests/ubiquitous-language.test.js`
   exit: 0
   stdout: `passes all 4 structural/distinguishability checks`
   mutation: set UL_TEST_MUTATE=1; the test exits non-zero (it checks skills/ubiquitous-language/SKILL.md, not the entries).
   proof: UL_TEST_MUTATE=1 node tests/ubiquitous-language.test.js exits non-zero.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap.
