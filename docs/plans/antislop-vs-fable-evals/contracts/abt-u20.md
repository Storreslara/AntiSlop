Unit: abt-u20

## Objective
All 50 runs of the uniform-policy matrix (5 evals x 2 arms x 5 reps) have a row whose status is not usage-limit, the rows validate, and the dry run shows nothing left to run.

## Retrieval
GitHub issues: `gh issue view 590 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/results.jsonl` (anchor: new file; git-ignored, appended by the runner)

## Ordered edits
1. command: `grep -q '^## Pilot findings' docs/experiments/abtest-2026-10.md && grep -q supersede_run eval/abtest/run-matrix.sh && grep -q PROVENANCE eval/abtest/score.py && test -s eval/abtest/results.jsonl && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. command: `bash eval/abtest/run-matrix.sh`
   expect: 0
3. command: `python3 eval/abtest/score.py eval/abtest/results.jsonl --out-md eval/abtest/.runs/full.md`
   expect: 0

## Do NOT touch
- `eval/abtest/` (no harness change in this unit; a defect found here becomes a new unit)
- `docs/experiments/abtest-2026-10.md` (abt-u21 fills the log)
- `docs/plans/` (never edit a plan or contract by hand)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump)

## Acceptance criteria
1. run: `python3 -I -c 'import json;r=[json.loads(l) for l in open("eval/abtest/results.jsonl")];print(len({x["run_id"] for x in r if x["completion_status"]!="usage-limit"}))'`
   exit: 0
   stdout: `50`
   mutation: skip edit 2 (the full pass); only the 10 pilot run ids exist and stdout is 10.
2. run: `python3 -I -c 'import json;r=[json.loads(l) for l in open("eval/abtest/results.jsonl")];print(len({(x["eval_id"],x["arm"]) for x in r}),min(len({x["rep"] for x in r if x["eval_id"]==e and x["arm"]==a and x["completion_status"]!="usage-limit"}) for e in {y["eval_id"] for y in r} for a in "AB"))'`
   exit: 0
   stdout: `10 5`
   mutation: skip edit 2; the smallest rep count is 1 and the fragment reads 10 1.
3. run: `python3 eval/abtest/score.py eval/abtest/results.jsonl --validate-rows | tail -n 1`
   exit: 0
   stdout: `rows ok:`
   mutation: delete one required key from one row of results.jsonl; the last line reads rows invalid.
   proof: abt-u14 replayed this: a row missing tokens_total printed rows invalid and exited 1.
4. run: `bash eval/abtest/run-matrix.sh --dry-run | grep '^plan: ' | grep -vc ' skip$'`
   exit: 1
   stdout: `0`
   mutation: skip edit 2; 40 runs are still planned and stdout is 40.

## Pre-resolved context
tdd: no operator-run unit: it runs scripts and records results; the acceptance criteria are the checks
blast-radius: none
executor: OPERATOR (or the orchestrator on the operator's word). Never dispatch this unit to lead-programmer; it starts commands that use the operator's Max subscription.
usage-limit: a runner exit of 75 is not a failure. Wait for the limit to reset and run the same command again; do not edit results.jsonl by hand.
no-bypass: if a hook or gate refuses a command, STOP and report the refusal text; never route around it.
repeat-rule: edit 2 exits 75 on a usage limit. Wait for the reset and run the same command again until it exits 0. An exit of 76 means one run id was classified usage-limit three times: read its stream.jsonl under eval/abtest/.runs/ before running again; do not just raise ABT_MAX_LIMIT_HITS.
provenance: OD-14. Edit 2 repeats every pilot row whose harness commit, plugin commit or prompt hash differs from the current checkout and moves the old row to eval/abtest/results.superseded.jsonl; the dry run in criterion 4 plans such a row as rerun (stale provenance), which counts as still to run. Never edit either file by hand. If the scorer reports an eval as INCONCLUSIVE with mixed provenance, repeat the stale rows with the same command; a top-up does not cure it.
top-up: an INCONCLUSIVE eval is topped up to N=10 later with run-matrix.sh --reps 10 --evals <ids>; that is outside this unit. Until both arms of an eval have 10 usable rows (the 6 to 9 rows in between, or unequal counts) the scorer keeps it INCONCLUSIVE with the reason in the report (OD-12).
no-commit: nothing in this unit is committed (results.jsonl is git-ignored); commit-message below is the subject to use only if you choose to record the pass in a note.
commit-message: docs(abt-u20): full pass complete (#590)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u20 (#590)
changed files: <FILL: changed files>
commit: <FILL: commit SHA>
criterion 1: <FILL: exit and stdout>
criterion 2: <FILL: exit and stdout>
criterion 3: <FILL: exit and stdout>
criterion 4: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
