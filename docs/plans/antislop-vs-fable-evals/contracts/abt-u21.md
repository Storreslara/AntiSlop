Unit: abt-u21

## Objective
The E1-E5 report (JSON and markdown) is committed with the persona_tokens and aggregate notes and the E1 blinded tally, the experiment log has generated Result and Decision lines and hand-set Verdicts, and every eval that is not superior (or stalled in Arm B, or let a defect escape) has an eval-finding issue.

## Retrieval
GitHub issues: `gh issue view 591 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/reports/abtest-2026-10.json` (anchor: new file)
- `eval/reports/abtest-2026-10.md` (anchor: new file)
- `docs/experiments/abtest-2026-10.md` (anchor: line matching `- **Result**: pending`)
- `eval/reports/tickets/` (anchor: new files)

## Ordered edits
1. command: `bash -c '! bash eval/abtest/run-matrix.sh --dry-run | grep -q " run$"' && test -f eval/abtest/report.py && test -f eval/abtest/blind.sh && grep -q "wiki|adr" eval/abtest/lib/blind.py && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. command: `mkdir -p eval/reports`
   expect: 0
3. command: `python3 eval/abtest/score.py eval/abtest/results.jsonl --out-json eval/reports/abtest-2026-10.json --out-md eval/reports/abtest-2026-10.md`
   expect: 0
4. command: `bash -c 'printf "\nNote: process.persona_tokens is null in every row (the arms run with --no-session-persistence, so no transcript exists for per-persona token attribution); per-persona token attribution was not produced.\n\nAggregate: E6-E10 are deferred, so no aggregate verdict is given.\n" >> eval/reports/abtest-2026-10.md'`
   expect: 0
5. command: `bash eval/abtest/blind.sh eval/abtest/results.jsonl eval/abtest/.runs/blind`
   expect: 0
6. command: `bash -c 'bash eval/abtest/blind.sh --unseal eval/abtest/.runs/blind eval/abtest/.runs/blind/grades.csv >> eval/reports/abtest-2026-10.md'`
   expect: 0
7. command: `python3 eval/abtest/report.py fill-log eval/reports/abtest-2026-10.json docs/experiments/abtest-2026-10.md`
   expect: 0
8. command: `python3 eval/abtest/report.py tickets eval/reports/abtest-2026-10.json eval/abtest/results.jsonl eval/reports/tickets`
   expect: 0
9. command: `bash -c 'for f in eval/reports/tickets/*.md; do [ -e "$f" ] || continue; gh issue create --repo Storreslara/AntiSlop --title "$(head -n1 "$f")" --label eval-finding --label plan/antislop-vs-fable-evals --body-file "$f" || exit 1; done'`
   expect: 0
10. command: `git add eval/reports/abtest-2026-10.json eval/reports/abtest-2026-10.md docs/experiments/abtest-2026-10.md eval/reports/tickets && git commit -m "docs(abt-u21): E1-E5 report, experiment log and eval-finding tickets (#591)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/` (no harness change in this unit; the scripts it runs are other units')
- `docs/plans/` (never edit a plan or contract by hand)
- `agents/` and `hooks/` (a finding becomes an issue; a fix goes through the normal spec, unit and review path)
- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump)

## Acceptance criteria
1. run: `python3 -I -c 'import json;d=json.load(open("eval/reports/abtest-2026-10.json"));print(len(d["evals"]),d["aggregate"]["verdict"])'`
   exit: 0
   stdout: `5 not-evaluated`
   mutation: skip edit 3 (the scoring); the report file does not exist and the exit is 1.
2. run: `python3 -I -c 'import json;d=json.load(open("eval/reports/abtest-2026-10.json"));print(sorted({v["verdict"] for v in d["evals"].values()}-{"superior","not-superior","mixed","inconclusive"}))'`
   exit: 0
   stdout: `[]`
   mutation: skip edit 3; the report file does not exist and the exit is 1.
3. run: `grep -c 'persona_tokens is null' eval/reports/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 4 (the report notes); stdout 0 and the exit is 1.
4. run: `grep -c 'unsealed: A assumptions_cites_glossary=' eval/reports/abtest-2026-10.md`
   exit: 0
   stdout: `1`
   mutation: skip edit 6 (the unsealed tally); stdout 0 and the exit is 1.
5. run: `ls eval/abtest/.runs/blind/blind | wc -l`
   exit: 0
   stdout: `10`
   mutation: skip edit 5 (the blinded set); ls fails and the pipeline prints 0.
6. run: `grep -c '^- [*][*]Result[*][*]: pending' docs/experiments/abtest-2026-10.md`
   exit: 1
   stdout: `0`
   mutation: skip edit 7 (the log fill); five pending Result lines remain and stdout is 5.
7. run: `grep -cE '^- [*][*]Verdict[*][*]: (CONFIRMED|REFUTED|INCONCLUSIVE)' docs/experiments/abtest-2026-10.md`
   exit: 0
   stdout: `5`
   mutation: leave one Verdict line as pending; stdout 4.
   proof: operator step: set each Verdict by hand before edit 10; a Verdict still reading pending makes the count lower.
8. run: `gh issue list --repo Storreslara/AntiSlop --label eval-finding --label plan/antislop-vs-fable-evals --state all --limit 100 --json title | python3 -I -c 'import json,sys,os;t=" ".join(i["title"] for i in json.load(sys.stdin));print(sorted(f[:-3] for f in os.listdir("eval/reports/tickets") if f.endswith(".md") and f[:-3] not in t))'`
   exit: 0
   stdout: `[]`
   mutation: skip edit 9 (filing the tickets); every ticket eval id is missing and stdout lists them.
9. run: `git log -1 --format=%s -- eval/reports/abtest-2026-10.md`
   exit: 0
   stdout: `docs(abt-u21): E1-E5 report, experiment log and eval-finding tickets (#591)`
   mutation: skip edit 10 (the commit); the file is untracked and git log prints nothing.
10. run: `git status --porcelain --untracked-files=no -- docs eval`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the report and log changes stay uncommitted and are listed.

## Pre-resolved context
tdd: no operator-run unit: it runs scripts and records results; the acceptance criteria are the checks
blast-radius: none
executor: OPERATOR (or the orchestrator on the operator's word). Never dispatch this unit to lead-programmer; it starts commands that use the operator's Max subscription.
usage-limit: a runner exit of 75 is not a failure. Wait for the limit to reset and run the same command again; do not edit results.jsonl by hand.
no-bypass: if a hook or gate refuses a command, STOP and report the refusal text; never route around it.
operator-step-1: after edit 5 builds the blinded set, grade the E1 items: copy eval/abtest/.runs/blind/grades-template.csv to eval/abtest/.runs/blind/grades.csv, set assumptions_cites_glossary to 1 or 0 for each id while looking only at eval/abtest/.runs/blind/blind/, then run edit 6.
operator-step-2: after edit 7 fills the log, replace each "pending" Verdict line in the log with CONFIRMED, REFUTED or INCONCLUSIVE by hand, judging the written Prediction above it against the Result; then run edits 8 to 10.
report-requirement: the markdown report must say that process.persona_tokens is null in every row and that per-persona token attribution was not produced (edit 4 appends it).
tickets: edit 9 may be refused by the permission classifier; if so, file each ticket body in eval/reports/tickets by hand (title = its first line, labels eval-finding and plan/antislop-vs-fable-evals) and report the refusal.
commit-message: docs(abt-u21): E1-E5 report, experiment log and eval-finding tickets (#591)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u21 (#591)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
