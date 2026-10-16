import sys
sys.path.insert(0, '.')
from cg import *
DOC = 'docs/experiments/abtest-2026-10.md'
RES = 'eval/abtest/results.jsonl'
PY = "python3 -I -c 'import json;r=[json.loads(l) for l in open(\"" + RES + "\")];print(%s)'"
CLEAN = 'test -z "$(git status --porcelain --untracked-files=no -- . \':!.claude/agent-memory\')"'

def finish(U, I, obj, affected, e, dont, crit, extra, subj):
    ncrit = crit.count('\n   mutation:')
    ctx = context('no operator-run unit: it runs scripts and records results; the acceptance criteria are the checks', 'none', [subj], ncrit, U, I, extra=extra)
    md = assemble(U, I, obj, affected, e.render(), dont, crit, ctx)
    open(f'../out/{U}.md', 'w').write(md)
    print(U, len(md), 'bytes', ncrit, 'criteria')

COMMON = ['executor: OPERATOR (or the orchestrator on the operator\'s word). Never dispatch this unit to lead-programmer; it starts commands that use the operator\'s Max subscription.',
          'usage-limit: a runner exit of 75 is not a failure. Wait for the limit to reset and run the same command again; do not edit results.jsonl by hand.',
          'no-bypass: if a hook or gate refuses a command, STOP and report the refusal text; never route around it.']

# ---------------- u19
U, I = 'abt-u19', 589
e = Edits()
e.command(f'test -f eval/abtest/run-matrix.sh && test -f eval/abtest/score.py && test -f {DOC} && test ! -e {RES} && ' + CLEAN, 0)
e.command('bash eval/abtest/verify-checks.sh --all', 0)
e.command('mkdir -p eval/abtest/.runs', 0)
n_probe = e.command("bash -c 'set -o pipefail; bash eval/abtest/run-matrix.sh --probe-isolation --probe-model uniform | tee eval/abtest/.runs/probe.txt'", 0)
n_pilot = e.command('bash eval/abtest/run-matrix.sh --pilot', 0)
e.command('python3 eval/abtest/score.py ' + RES + ' --out-md eval/abtest/.runs/pilot.md', 0)
n_find = e.command("bash -c '{ echo; echo \"## Pilot findings (2026-10)\"; echo; grep -E \"^probe(-detail)?:\" eval/abtest/.runs/probe.txt | sed \"s/^/- /\"; } >> " + DOC + "'", 0)
subj = 'docs(abt-u19): pilot findings (#589)'
n_commit = e.command(commit_cmd([DOC], subj), 0)
crit = ''
crit += criterion(1, PY % 'len({x["run_id"] for x in r if x["completion_status"]!="usage-limit" and x["rep"]==1})', 0, '10', f'skip edit {n_pilot} (the pilot); results.jsonl does not exist and the exit is 1.')
crit += criterion(2, "grep -cE '^probe: A hook_events=0 persona_refs=0 B hook_events=[1-9][0-9]* subagent_spawns=[1-9][0-9]*$' eval/abtest/.runs/probe.txt", 0, '1', f'skip edit {n_probe} (the probe); probe.txt does not exist and the exit is 2.')
crit += criterion(3, "grep -cE '^probe: A model=.*fable.* B model=.*fable.*$' eval/abtest/.runs/probe.txt", 0, '1', f'skip edit {n_probe}; probe.txt does not exist and the exit is 2.')
crit += criterion(4, "grep -c 'max-turns flag accepted=yes' eval/abtest/.runs/probe.txt", 0, '1', f'skip edit {n_probe}; probe.txt does not exist and the exit is 2.')
crit += criterion(5, PY % 'sum(1 for x in r if x["arm"]=="B" and x["completion_status"]=="stalled-human")', 0, '0', f'skip edit {n_pilot}; results.jsonl does not exist and the exit is 1.',
                  proof='read-only check; a pilot in which an Arm B run stalls prints a number above 0 and the gate fails.')
crit += criterion(6, PY % 'sum(1 for x in r if x["completion_status"]=="error")', 0, '0', f'skip edit {n_pilot}; results.jsonl does not exist and the exit is 1.',
                  proof='read-only check; a pilot with a harness error row prints a number above 0 and the gate fails.')
crit += criterion(7, 'bash eval/abtest/verify-checks.sh --all | tail -n 1', 0, 'verify-checks: ok', 'break one reference patch; the last line reads verify-checks: FAILED.',
                  proof='abt-u04 and the fixture units replayed this: a reference that fails a required check prints FAILED and exits 1.')
crit += criterion(8, f"grep -c '^## Pilot findings' {DOC}", 0, '1', f'skip edit {n_find} (the findings append); stdout 0 and the exit is 1.')
crit += criterion(9, f'git log -1 --format=%s -- {DOC}', 0, subj, f'skip edit {n_commit} (the commit); the newest commit on the file is abt-u16\'s.')
crit += criterion(10, f'git status --porcelain --untracked-files=no -- docs eval tests', 0, 'empty', f'skip edit {n_commit}; the findings stay uncommitted and are listed.')
finish(U, I,
       'The pilot smoke gate passes: fixtures proven non-vacuous, the isolation and model probes pass on the real CLI (max-turns accepted), the 10 pilot runs (one per arm per eval) have rows with no Arm B stall and no harness error, and the probe findings are committed in the pre-registration log under Pilot findings.',
       f'- `{DOC}` (anchor: line matching `## Verdict rules (copied from the design, with the operator\'s token amendment)`)\n- `{RES}` (anchor: new file; git-ignored, written by the runner)',
       e, '\n'.join(['- `eval/abtest/` (no harness change in this unit; a defect found here becomes a new unit)', '- `tests/` and `agents/` (nothing is edited)',
                    '- `docs/plans/` (never edit a plan or contract by hand)', '- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump)']),
       crit, COMMON + ['stop-rule: if criteria 2, 3 or 4 fail, the isolation or flag assumption is wrong: STOP and report the probe-detail lines. If criterion 5 fails, Arm B stalled headlessly: STOP; do not start abt-u20. Criterion 10 passes only after edit 8.',
                       'cost: about 2 probe runs plus 10 pilot runs; the pilot rows are reused as rep 1 by abt-u20, so do not delete results.jsonl afterwards.',
                       'proof-lines: criteria 5, 6 and 7 are read-only guards; their proof lines say what a failing pilot prints.'], subj)

# ---------------- u20
U, I = 'abt-u20', 590
e = Edits()
e.command(f"grep -q '^## Pilot findings' {DOC} && test -s {RES} && " + CLEAN, 0)
n_full = e.command('bash eval/abtest/run-matrix.sh', 0)
e.command('python3 eval/abtest/score.py ' + RES + ' --out-md eval/abtest/.runs/full.md', 0)
subj = 'docs(abt-u20): full pass complete (#590)'
crit = ''
crit += criterion(1, PY % 'len({x["run_id"] for x in r if x["completion_status"]!="usage-limit"})', 0, '50', f'skip edit {n_full} (the full pass); only the 10 pilot run ids exist and stdout is 10.')
crit += criterion(2, PY % 'len({(x["eval_id"],x["arm"]) for x in r}),min(len({x["rep"] for x in r if x["eval_id"]==e and x["arm"]==a and x["completion_status"]!="usage-limit"}) for e in {y["eval_id"] for y in r} for a in "AB")', 0, '10 5', f'skip edit {n_full}; the smallest rep count is 1 and the fragment reads 10 1.')
crit += criterion(3, 'python3 eval/abtest/score.py ' + RES + ' --validate-rows | tail -n 1', 0, 'rows ok:', 'delete one required key from one row of results.jsonl; the last line reads rows invalid.',
                  proof='abt-u14 replayed this: a row missing tokens_total printed rows invalid and exited 1.')
crit += criterion(4, "bash eval/abtest/run-matrix.sh --dry-run | grep -c ' run$'", 1, '0', f'skip edit {n_full}; 40 runs are still planned and stdout is 40.')
sc = ''
finish(U, I,
       'All 50 runs of the uniform-policy matrix (5 evals x 2 arms x 5 reps) have a row whose status is not usage-limit, the rows validate, and the dry run shows nothing left to run.',
       f'- `{RES}` (anchor: new file; git-ignored, appended by the runner)',
       e, '\n'.join(['- `eval/abtest/` (no harness change in this unit; a defect found here becomes a new unit)', '- `docs/experiments/abtest-2026-10.md` (abt-u21 fills the log)',
                    '- `docs/plans/` (never edit a plan or contract by hand)', '- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump)']),
       crit, COMMON + ['repeat-rule: edit 2 exits 75 on a usage limit. Wait for the reset and run the same command again until it exits 0.',
                       'top-up: an INCONCLUSIVE eval is topped up to N=10 later with run-matrix.sh --reps 10 --evals <ids>; that is outside this unit.',
                       'no-commit: nothing in this unit is committed (results.jsonl is git-ignored); commit-message below is the subject to use only if you choose to record the pass in a note.'], subj)

# ---------------- u21
U, I = 'abt-u21', 591
REP = 'eval/reports/abtest-2026-10'
e = Edits()
e.command(f"! bash eval/abtest/run-matrix.sh --dry-run | grep -q ' run$' && test -f eval/abtest/report.py && test -f eval/abtest/blind.sh && " + CLEAN if False else "bash -c '! bash eval/abtest/run-matrix.sh --dry-run | grep -q \" run$\"' && test -f eval/abtest/report.py && test -f eval/abtest/blind.sh && " + CLEAN, 0)
e.command('mkdir -p eval/reports', 0)
n_score = e.command(f'python3 eval/abtest/score.py {RES} --out-json {REP}.json --out-md {REP}.md', 0)
n_notes = e.command("bash -c 'printf \"\\nNote: process.persona_tokens is null in every row (the arms run with --no-session-persistence, so no transcript exists for per-persona token attribution); per-persona token attribution was not produced.\\n\\nAggregate: E6-E10 are deferred, so no aggregate verdict is given.\\n\" >> " + REP + ".md'", 0)
n_blind = e.command(f'bash eval/abtest/blind.sh {RES} eval/abtest/.runs/blind', 0)
n_unseal = e.command("bash -c 'bash eval/abtest/blind.sh --unseal eval/abtest/.runs/blind eval/abtest/.runs/blind/grades.csv >> " + REP + ".md'", 0)
n_fill = e.command(f'python3 eval/abtest/report.py fill-log {REP}.json {DOC}', 0)
n_tick = e.command(f'python3 eval/abtest/report.py tickets {REP}.json {RES} eval/reports/tickets', 0)
n_file = e.command("bash -c 'for f in eval/reports/tickets/*.md; do [ -e \"$f\" ] || continue; gh issue create --repo Storreslara/AntiSlop --title \"$(head -n1 \"$f\")\" --label eval-finding --label plan/antislop-vs-fable-evals --body-file \"$f\" || exit 1; done'", 0)
subj = 'docs(abt-u21): E1-E5 report, experiment log and eval-finding tickets (#591)'
n_commit = e.command(commit_cmd([REP + '.json', REP + '.md', DOC, 'eval/reports/tickets'], subj), 0)
crit = ''
crit += criterion(1, f'python3 -I -c \'import json;d=json.load(open("{REP}.json"));print(len(d["evals"]),d["aggregate"]["verdict"])\'', 0, '5 not-evaluated', f'skip edit {n_score} (the scoring); the report file does not exist and the exit is 1.')
crit += criterion(2, f'python3 -I -c \'import json;d=json.load(open("{REP}.json"));print(sorted({{v["verdict"] for v in d["evals"].values()}}-{{"superior","not-superior","mixed","inconclusive"}}))\'', 0, '[]', f'skip edit {n_score}; the report file does not exist and the exit is 1.')
crit += criterion(3, f"grep -c 'persona_tokens is null' {REP}.md", 0, '1', f'skip edit {n_notes} (the report notes); stdout 0 and the exit is 1.')
crit += criterion(4, f"grep -c 'unsealed: A assumptions_cites_glossary=' {REP}.md", 0, '1', f'skip edit {n_unseal} (the unsealed tally); stdout 0 and the exit is 1.')
crit += criterion(5, "ls eval/abtest/.runs/blind/blind | wc -l", 0, '10', f'skip edit {n_blind} (the blinded set); ls fails and the pipeline prints 0.')
crit += criterion(6, f"grep -c '^- [*][*]Result[*][*]: pending' {DOC}", 1, '0', f'skip edit {n_fill} (the log fill); five pending Result lines remain and stdout is 5.')
crit += criterion(7, f"grep -cE '^- [*][*]Verdict[*][*]: (CONFIRMED|REFUTED|INCONCLUSIVE)' {DOC}", 0, '5', 'leave one Verdict line as pending; stdout 4.',
                  proof='operator step: set each Verdict by hand before edit 10; a Verdict still reading pending makes the count lower.')
crit += criterion(8, "gh issue list --repo Storreslara/AntiSlop --label eval-finding --label plan/antislop-vs-fable-evals --state all --limit 100 --json title | python3 -I -c 'import json,sys,os;t=\" \".join(i[\"title\"] for i in json.load(sys.stdin));print(sorted(f[:-3] for f in os.listdir(\"eval/reports/tickets\") if f.endswith(\".md\") and f[:-3] not in t))'", 0, '[]', f'skip edit {n_file} (filing the tickets); every ticket eval id is missing and stdout lists them.')
crit += criterion(9, f'git log -1 --format=%s -- {REP}.md', 0, subj, f'skip edit {n_commit} (the commit); the file is untracked and git log prints nothing.')
crit += criterion(10, 'git status --porcelain --untracked-files=no -- docs eval', 0, 'empty', f'skip edit {n_commit}; the report and log changes stay uncommitted and are listed.')
finish(U, I,
       'The E1-E5 report (JSON and markdown) is committed with the persona_tokens and aggregate notes and the E1 blinded tally, the experiment log has generated Result and Decision lines and hand-set Verdicts, and every eval that is not superior (or stalled in Arm B, or let a defect escape) has an eval-finding issue.',
       f'- `{REP}.json` (anchor: new file)\n- `{REP}.md` (anchor: new file)\n- `{DOC}` (anchor: line matching `- **Result**: pending`)\n- `eval/reports/tickets/` (anchor: new files)',
       e, '\n'.join(['- `eval/abtest/` (no harness change in this unit; the scripts it runs are other units\')', '- `docs/plans/` (never edit a plan or contract by hand)',
                    '- `agents/` and `hooks/` (a finding becomes an issue; a fix goes through the normal spec, unit and review path)', '- `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no version bump)']),
       crit, COMMON + ['operator-step-1: after edit 5 builds the blinded set, grade the E1 items: copy eval/abtest/.runs/blind/grades-template.csv to eval/abtest/.runs/blind/grades.csv, set assumptions_cites_glossary to 1 or 0 for each id while looking only at eval/abtest/.runs/blind/blind/, then run edit 6.',
                       'operator-step-2: after edit 7 fills the log, replace each "pending" Verdict line in the log with CONFIRMED, REFUTED or INCONCLUSIVE by hand, judging the written Prediction above it against the Result; then run edits 8 to 10.',
                       'report-requirement: the markdown report must say that process.persona_tokens is null in every row and that per-persona token attribution was not produced (edit 4 appends it).',
                       'tickets: edit 9 may be refused by the permission classifier; if so, file each ticket body in eval/reports/tickets by hand (title = its first line, labels eval-finding and plan/antislop-vs-fable-evals) and report the refusal.'], subj)
