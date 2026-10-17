Unit: abt-u19

## Objective
The pilot smoke gate passes: fixtures proven non-vacuous, the isolation and model probes pass on the real CLI (max-turns accepted), the 10 pilot runs (one per arm per eval) have rows with no Arm B stall and no harness error, and the probe findings are committed in the pre-registration log under Pilot findings.

## Retrieval
GitHub issues: `gh issue view 589 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `docs/experiments/abtest-2026-10.md` (anchor: line matching `## Verdict rules (copied from the design, with the operator's token amendment)`)
- `eval/abtest/results.jsonl` (anchor: new file; git-ignored, written by the runner)

## Ordered edits
1. command: `test -f eval/abtest/run-matrix.sh && test -f eval/abtest/score.py && test -f docs/experiments/abtest-2026-10.md && test ! -e eval/abtest/results.jsonl && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. command: `bash eval/abtest/verify-checks.sh --all`
   expect: 0
3. command: `mkdir -p eval/abtest/.runs`
   expect: 0
4. command: `bash -c 'set -o pipefail; bash eval/abtest/run-matrix.sh --probe-isolation --probe-model uniform | tee eval/abtest/.runs/probe.txt'`
   expect: 0
5. command: `bash eval/abtest/run-matrix.sh --pilot`
   expect: 0
6. command: `bash -c 'python3 -I -c "import json,shutil;[shutil.copy(r[\"artifacts\"][\"stream\"], \"tests/fixtures/abtest/streams/pinned-limit-\"+r[\"run_id\"].replace(\"/\",\"_\")+\".jsonl\") for r in map(json.loads, open(\"eval/abtest/results.jsonl\")) if r[\"completion_status\"]==\"usage-limit\"]" && git add tests/fixtures/abtest/streams && { git diff --cached --quiet || git commit -m "test(abt-u19): pinned real limit-hit streams (#589)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"; }'`
   expect: 0
7. command: `python3 eval/abtest/score.py eval/abtest/results.jsonl --out-md eval/abtest/.runs/pilot.md`
   expect: 0
8. command: `bash -c '{ echo; echo "## Pilot findings (2026-10)"; echo; grep -E "^probe(-detail)?:" eval/abtest/.runs/probe.txt | sed "s/^/- /"; } >> docs/experiments/abtest-2026-10.md'`
   expect: 0
9. command: `git add docs/experiments/abtest-2026-10.md && git commit -m "docs(abt-u19): pilot findings (#589)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/` (no harness change in this unit; a defect found here becomes a new unit)
- `tests/` and `agents/` (nothing is edited)
- `docs/plans/` (never edit a plan or contract by hand)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump)

## Acceptance criteria
1. run: `python3 -I -c 'import json;r=[json.loads(l) for l in open("eval/abtest/results.jsonl")];print(len({x["run_id"] for x in r if x["completion_status"]!="usage-limit" and x["rep"]==1}))'`
   exit: 0
   stdout: `10`
   mutation: skip edit 5 (the pilot); results.jsonl does not exist and the exit is 1.
2. run: `grep -cE '^probe: A hook_events=0 persona_refs=0 B hook_events=[1-9][0-9]* subagent_spawns=[1-9][0-9]*$' eval/abtest/.runs/probe.txt`
   exit: 0
   stdout: `1`
   mutation: skip edit 4 (the probe); probe.txt does not exist and the exit is 2.
3. run: `grep -cE '^probe: A model=.*fable.* B model=.*fable.*$' eval/abtest/.runs/probe.txt`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; probe.txt does not exist and the exit is 2.
4. run: `grep -c 'max-turns flag accepted=yes' eval/abtest/.runs/probe.txt`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; probe.txt does not exist and the exit is 2.
5. run: `grep -c '^probe: A root_claude_md=not-loaded$' eval/abtest/.runs/probe.txt`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; probe.txt does not exist and the exit is 2.
6. run: `grep -c '^probe: mention-case ok A=complete B=complete$' eval/abtest/.runs/probe.txt`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; probe.txt does not exist and the exit is 2.
7. run: `python3 -I -c 'import json;r=[json.loads(l) for l in open("eval/abtest/results.jsonl")];print(sum(1 for x in r if x["arm"]=="B" and x["completion_status"]=="stalled-human"))'`
   exit: 0
   stdout: `0`
   mutation: skip edit 5; results.jsonl does not exist and the exit is 1.
   proof: read-only check; a pilot in which an Arm B run stalls prints a number above 0 and the gate fails.
8. run: `python3 -I -c 'import json;r=[json.loads(l) for l in open("eval/abtest/results.jsonl")];print(sum(1 for x in r if x["completion_status"]=="error"))'`
   exit: 0
   stdout: `0`
   mutation: skip edit 5; results.jsonl does not exist and the exit is 1.
   proof: read-only check; a pilot with a harness error row prints a number above 0 and the gate fails.
9. run: `bash eval/abtest/verify-checks.sh --all | tail -n 1`
   exit: 0
   stdout: `verify-checks: ok`
   mutation: break one reference patch; the last line reads verify-checks: FAILED.
   proof: abt-u04 and the fixture units replayed this: a reference that fails a required check prints FAILED and exits 1.
10. run: `grep -c '^## Pilot findings' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 8 (the findings append); stdout 0 and the exit is 1.
11. run: `git log -1 --format=%s -- docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `docs(abt-u19): pilot findings (#589)`
   mutation: skip edit 9 (the commit); the newest commit on the file is abt-u16's.
12. run: `python3 -I -c 'import json;r=[json.loads(l) for l in open("eval/abtest/results.jsonl")];print(sum(1 for x in r if x["completion_status"]=="usage-limit" and not __import__("os").path.exists("tests/fixtures/abtest/streams/pinned-limit-"+x["run_id"].replace("/","_")+".jsonl")))'`
   exit: 0
   stdout: `0`
   mutation: skip edit 6 (the pinning step); every usage-limit row seen by the pilot lacks its pinned capture and stdout is the number of such rows (0 when the pilot saw no limit, which is a pass).
   proof: read-only check; with a usage-limit row and no pinned file it prints 1 and the gate fails.
13. run: `git status --porcelain --untracked-files=no -- docs eval tests`
   exit: 0
   stdout: empty
   mutation: skip edit 9; the findings stay uncommitted and are listed.

## Pre-resolved context
tdd: no operator-run unit: it runs scripts and records results; the acceptance criteria are the checks
blast-radius: none
executor: OPERATOR (or the orchestrator on the operator's word). Never dispatch this unit to lead-programmer; it starts commands that use the operator's Max subscription.
usage-limit: a runner exit of 75 is not a failure. Wait for the limit to reset and run the same command again; do not edit results.jsonl by hand.
no-bypass: if a hook or gate refuses a command, STOP and report the refusal text; never route around it.
stop-rule: if criteria 2 to 6 fail, the isolation or flag assumption is wrong (a root_claude_md=loaded line means the CLAUDE.md of this repository reached Arm A, a mention-case failure means a reply that mentions rate limits was mistaken for a limit hit or never exercised): STOP and report the probe-detail lines. If criterion 7 fails, Arm B stalled headlessly: STOP; do not start abt-u20. Criterion 13 passes only after edit 9 (edit 6 pins any real limit-hit stream under tests/fixtures/abtest/streams/ as pinned-limit-<run id>.jsonl and commits it; give such a capture its own row in tests/abtest-stream.test.sh through a new unit, because the wording list may need widening).
cost: about 2 probe runs plus 10 pilot runs; the pilot rows are reused as rep 1 by abt-u20, so do not delete results.jsonl afterwards.
proof-lines: criteria 7, 8 and 9 are read-only guards; their proof lines say what a failing pilot prints.
commit-message: docs(abt-u19): pilot findings (#589)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u19 (#589)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
