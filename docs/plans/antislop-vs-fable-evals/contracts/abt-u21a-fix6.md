Unit: abt-u21a

## Objective
Fix of the FAIL of 2026-10-17T22:50:08Z, round 6 (after the round 4 review of 2c09d44c, which ran 37 report.py and 22 score.py mutants). tests/abtest-report-edges.test.sh walks 17 boundary cells through the real score.py, fill-log and tickets: R_tokens exactly 2, 2.01, 3 and 3.01 with and without a quality edge, the quality edge when only one median is strictly lower, a 2-run-gap WIN_A, the measured-overhead label with distinct R_tokens, R_wall and R_turns, the label on a cost eval that is not a TIE, two stalled Arm B runs, two Arm B runs with an escaped defect, and the ratios over complete rows only (Arm A and Arm B). Expectations are written out in the test from the verdict rules of docs/experiments/abtest-2026-10.md. tests/validate.sh runs it. One commit, after round 5 (abt-u21a-fix5.md) has landed.

## Retrieval
GitHub issues: `gh issue view 588 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `tests/abtest-report-edges.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "FAIL tests/abtest-report-grid.test.sh"`)

## Ordered edits
1. command: `git log --format=%s | grep -q "^fix(abt-u21a): grid the undecided" && test -f tests/abtest-report-grid.test.sh && test -f tests/abtest-report-walk.test.sh && test ! -e tests/abtest-report-edges.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `tests/abtest-report-edges.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Walks the boundary cells of the verdict rules of eval/abtest/score.py and of the Decision wording of
# eval/abtest/report.py that the walk (tests/abtest-report-walk.test.sh) and the grid (tests/abtest-report-grid.test.sh)
# leave open: R_tokens exactly 2, just above 2, exactly 3 and just above 3 (with and without a quality edge), the quality
# edge when only one of the two medians is strictly lower, the 2-run gap win of Arm A, the measured-overhead label with
# distinct token, wall and turn ratios, the label on a cost eval that is not a TIE, two stalled Arm B runs, two Arm B runs
# with an escaped defect and R_tokens taken over complete rows only. The rules are the verdict rules of
# docs/experiments/abtest-2026-10.md. The expectations below are written out, not taken from report.py. No claude, no usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

python3 -I - "$T" "$REPO_ROOT/eval/abtest/score.py" "$REPO_ROOT/eval/abtest/report.py" << 'PYEOF' | tee "$T/out.txt"
import json, os, subprocess, sys

t, score_py, report_py = sys.argv[1:4]
passed_n = 0
failed_n = 0


def check(name, got, want):
    global passed_n, failed_n
    if got == want:
        passed_n += 1
        print(f"ok   {name}")
    else:
        failed_n += 1
        print(f"FAIL {name} (want {want!r}, got {got!r})")


def run(*args):
    return subprocess.run([sys.executable, "-I", *args], capture_output=True, text=True)


def row(ev, arm, rep, spec):
    status = spec.get("status", "complete")
    ok = bool(spec.get("passed", False)) and status == "complete"
    tokens = spec.get("tokens", 100)
    return {
        "schema_version": 1, "run_id": f"{ev}/{arm}/uniform/{rep}", "eval_id": ev, "arm": arm,
        "model_policy": "uniform", "rep": rep, "started_at": "t", "plugin_version": None, "cli_version": "c",
        "fixture_profile": {}, "persona_config_sha": None, "completion_status": status, "result_subtype": None,
        "wall_clock_ms": spec.get("wall", 1000), "duration_api_ms": None, "total_cost_usd": None, "model_usage": {},
        "tokens_in": tokens, "tokens_out": 0, "tokens_cache_write": 0, "tokens_cache_read": 0,
        "tokens_total": tokens, "num_turns": spec.get("turns", 5), "subagent_spawns": 0, "tool_calls": 0,
        "human_interventions_required": 0,
        "checks": [{"id": "chk-a", "kind": "defect", "required": True, "cmd": "node --test x", "exit": 0 if ok else 1, "pass": ok}],
        "holdout_pass_rate": None, "defects_escaped": spec.get("defects", 0),
        "out_of_scope_lines": spec.get("oos", 0), "out_of_scope_files": 0, "commits": 1, "run_pass": ok,
        "process": {}, "blind_grades": {},
        "artifacts": {"stream": f"runs/{ev}_{arm}_{rep}/stream.jsonl", "diff": "d"},
        "harness_commit": "h", "plugin_commit": None, "prompt_sha": "p", "fixture_commit": "f",
    }


def reps(n, k, **kw):
    return [dict(passed=i < k, **kw) for i in range(n)]


EDGE_A = dict(defects=2, oos=10)
NOEDGE = "ticket filed under the eval-finding label (tie with no quality edge)"
# name, eval id (None: e<idx>-<name>), arm A specs, arm B specs, want
# want: outcome, verdict, label, ticket, decision substrings, absent substrings, Result-line substrings
CELLS = [
    ("edge-r2", None, reps(5, 3, **EDGE_A), reps(5, 3, tokens=200),
     dict(outcome="TIE", verdict="superior", label=None, ticket=False,
          decision=["no action: recorded as a measured advantage"], absent=["mixed", "ticket"], result=["R_tokens 2.00,"])),
    ("edge-r2p01", None, reps(5, 3, **EDGE_A), reps(5, 3, tokens=201),
     dict(outcome="TIE", verdict="mixed", label=None, ticket=False,
          decision=["no ticket: verdict mixed (a tie with a quality edge and R_tokens 2.01, above 2 and up to 3 or not computable)"],
          absent=["measured advantage", "ticket filed"], result=["R_tokens 2.01,"])),
    ("edge-r3", None, reps(5, 3, **EDGE_A), reps(5, 3, tokens=300),
     dict(outcome="TIE", verdict="mixed", label=None, ticket=False,
          decision=["no ticket: verdict mixed (a tie with a quality edge and R_tokens 3.00, above 2 and up to 3 or not computable)"],
          absent=["R_tokens above 3", "ticket filed"], result=["R_tokens 3.00,"])),
    ("edge-r3p01", None, reps(5, 3, **EDGE_A), reps(5, 3, tokens=301),
~~~~
3. file: `tests/abtest-report-edges.test.sh`
   anchor: line matching `    ("edge-r3p01", None, reps(5, 3, **EDGE_A), reps(5, 3, tokens=301),`
   indent: 0
   insert-after:
~~~~
     dict(outcome="TIE", verdict="not-superior", label=None, ticket=True,
          decision=["ticket filed under the eval-finding label (tie with R_tokens above 3)"], absent=["no quality edge", "mixed"], result=["R_tokens 3.01,"])),
    ("noedge-r2", None, reps(5, 3), reps(5, 3, tokens=200),
     dict(outcome="TIE", verdict="not-superior", label=None, ticket=True,
          decision=[NOEDGE], absent=["R_tokens above 3"], result=["R_tokens 2.00,"])),
    ("noedge-r2p5", None, reps(5, 3), reps(5, 3, tokens=250),
     dict(outcome="TIE", verdict="not-superior", label=None, ticket=True,
          decision=[NOEDGE], absent=["R_tokens above 3"], result=["R_tokens 2.50,"])),
    ("noedge-r3", None, reps(5, 3), reps(5, 3, tokens=300),
     dict(outcome="TIE", verdict="not-superior", label=None, ticket=True,
          decision=[NOEDGE], absent=["R_tokens above 3"], result=["R_tokens 3.00,"])),
    ("noedge-r3p01", None, reps(5, 3), reps(5, 3, tokens=301),
     dict(outcome="TIE", verdict="not-superior", label=None, ticket=True,
          decision=["ticket filed under the eval-finding label (tie with no quality edge and R_tokens above 3)"], absent=[], result=["R_tokens 3.01,"])),
    ("edge-defects-equal", None, reps(5, 3, **EDGE_A), reps(5, 3, defects=2, oos=0),
     dict(outcome="TIE", verdict="not-superior", label=None, ticket=True,
          decision=["ticket filed under the eval-finding label (tie with no quality edge; an Arm B run let a defect escape in 5 run(s))"],
          absent=["measured advantage", "mixed"], result=["R_tokens 1.00,"])),
    ("edge-oos-equal", None, reps(5, 3, **EDGE_A), reps(5, 3, defects=0, oos=10),
     dict(outcome="TIE", verdict="not-superior", label=None, ticket=True,
          decision=[NOEDGE], absent=["measured advantage", "mixed"], result=["R_tokens 1.00,"])),
    ("win-a-gap-2", None, reps(5, 5), reps(5, 3),
     dict(outcome="WIN_A", verdict="not-superior", label=None, ticket=True,
          decision=["ticket filed under the eval-finding label (Arm A won (WIN_A))"], absent=["no action", "TIE"], result=["run_pass A 5/5, B 3/5 (WIN_A)"])),
    ("label-distinct", "e05-tags-feature", reps(5, 3, tokens=100, wall=1000, turns=5), reps(5, 3, tokens=250, wall=4000, turns=20),
     dict(outcome="TIE", verdict="not-superior", label="measured-overhead", ticket=True,
          decision=[NOEDGE, "label measured-overhead: the expected result, R_tokens 2.50 and R_wall 4.00 are the numbers that matter"],
          absent=["R_wall 2.50", "R_tokens 4.00"], result=["R_tokens 2.50, R_wall 4.00, R_turns 4.00;", "(measured-overhead)"])),
    ("label-not-tie", "e09-typo", reps(5, 1), reps(5, 5),
     dict(outcome="WIN_B", verdict="superior", label=None, ticket=False,
          decision=["no action: recorded as a measured advantage"], absent=["label", "measured-overhead"], result=["verdict superior"])),
    ("stall-two", None, reps(5, 1), reps(3, 3) + [dict(passed=False, status="stalled-human")] * 2,
     dict(outcome="WIN_B", verdict="not-superior", label=None, ticket=True,
          decision=["ticket filed under the eval-finding label (Arm B stalled-human in 2 run(s))"], absent=["measured advantage", "in 1 run(s)"],
          result=["B stalled-human 2;"])),
    ("defect-two", None, reps(5, 1), [dict(passed=True, defects=1 if i < 2 else 0) for i in range(5)],
     dict(outcome="WIN_B", verdict="superior", label=None, ticket=True,
          decision=["ticket filed under the eval-finding label (an Arm B run let a defect escape in 2 run(s))", "verdict superior: recorded as a measured advantage"],
          absent=["in 1 run(s)", "no action"], result=["B stalled-human 0;"])),
    ("ratio-complete-only", None,
     reps(2, 2, tokens=100, wall=1000, turns=5) + [dict(passed=False, status="stalled-human", tokens=1, wall=1, turns=1)] * 2 + [dict(passed=False, status="timeout", tokens=1, wall=1, turns=1)],
     reps(5, 5, tokens=200, wall=4000, turns=15),
     dict(outcome="WIN_B", verdict="superior", label=None, ticket=False,
          decision=["recorded as a measured advantage"], absent=["ticket filed"], result=["R_tokens 2.00, R_wall 4.00, R_turns 3.00;"])),
    ("ratio-complete-only-b", None, reps(5, 0, tokens=100, wall=1000, turns=5),
     reps(2, 2, tokens=200, wall=4000, turns=15) + [dict(passed=False, status="stalled-human", tokens=9999, wall=99999, turns=99)] * 2
     + [dict(passed=False, status="timeout", tokens=9999, wall=99999, turns=99)],
     dict(outcome="WIN_B", verdict="not-superior", label=None, ticket=True,
          decision=["ticket filed under the eval-finding label (Arm B stalled-human in 2 run(s))"], absent=["measured advantage"],
          result=["R_tokens 2.00, R_wall 4.00, R_turns 3.00;"])),
]

rows, log, ids = [], ["# edges log", ""], {}
for idx, (name, ev, a, b, want) in enumerate(CELLS):
    ev = ev or f"e{21 + idx}-{name}"
    ids[name] = ev
    for arm, specs in (("A", a), ("B", b)):
        for rep, spec in enumerate(specs, 1):
            rows.append(row(ev, arm, rep, spec))
    log += [f"### E{idx + 1}: {name} ({ev})", "", "- **Result**: pending", "- **Verdict**: pending", "- **Decision**: pending", ""]
with open(t + "/rows.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
with open(t + "/log.md", "w") as f:
    f.write("\n".join(log))

p = run(score_py, t + "/rows.jsonl", "--out-json", t + "/score.json")
check("score.py scores the boundary rows", p.returncode, 0)
report = json.load(open(t + "/score.json"))
p = run(report_py, "fill-log", t + "/score.json", t + "/log.md", t + "/rows.jsonl")
check("fill-log exits 0 over the boundary cells", p.returncode, 0)
p = run(report_py, "tickets", t + "/score.json", t + "/rows.jsonl", t + "/tickets")
check("tickets exits 0 over the boundary cells", p.returncode, 0)
entries = {}
for block in open(t + "/log.md").read().split("### ")[1:]:
    entries[block.split("(")[1].split(")")[0]] = {line.split("**")[1]: line.split(": ", 1)[1] for line in block.split("\n") if line.startswith("- **")}

for name, ev0, a, b, want in CELLS:
~~~~
4. file: `tests/abtest-report-edges.test.sh`
   anchor: line matching `for name, ev0, a, b, want in CELLS:`
   indent: 0
   insert-after:
~~~~
    ev = ids[name]
    v = report["evals"][ev]
    decision, result = entries[ev]["Decision"], entries[ev]["Result"]
    exists = os.path.exists(f"{t}/tickets/{ev}.md")
    got = [v["outcome"], v["verdict"], v["label"], "ticket filed" in decision, exists]
    exp = [want["outcome"], want["verdict"], want["label"], want["ticket"], want["ticket"]]
    problems = [] if got == exp else [f"outcome, verdict, label, ticket in Decision, ticket file: want {exp}, got {got}"]
    problems += [f"Decision lacks '{f}': {decision}" for f in want["decision"] if f not in decision]
    problems += [f"Decision holds '{f}': {decision}" for f in want["absent"] if f in decision]
    problems += [f"Result lacks '{f}': {result}" for f in want["result"] if f not in result]
    check(f"cell {name} has the verdict, label, Decision wording, Result figures and ticket state of the rules", problems, [])
check("the boundary walk holds 17 cells", len(CELLS), 17)
sys.exit(1 if failed_n else 0)

PYEOF
rc=${PIPESTATUS[0]}
pass=$(grep -c '^ok   ' "$T/out.txt")
fail=$(grep -c '^FAIL ' "$T/out.txt")
echo "abtest-report-edges: $pass passed, $fail failed"
if [ "$rc" -eq 0 ] && [ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]; then
  echo "All abtest-report-edges checks passed."
  exit 0
fi
exit 1
~~~~
5. command: `chmod +x tests/abtest-report-edges.test.sh`
   expect: 0
6. file: `tests/validate.sh`
   anchor: line matching `echo "FAIL tests/abtest-report-grid.test.sh"`
   indent: 0
   before:
~~~~
  echo "FAIL tests/abtest-report-grid.test.sh"
  fail=1
fi
~~~~
   after:
~~~~
  echo "FAIL tests/abtest-report-grid.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-report-edges.test.sh: the verdict-rule and Decision boundaries the walk and the grid leave open (Bash, abt-u21a) =="
if bash tests/abtest-report-edges.test.sh > /dev/null; then
  echo "OK   tests/abtest-report-edges.test.sh"
else
  echo "FAIL tests/abtest-report-edges.test.sh"
  fail=1
fi
~~~~
7. command: `git add tests/abtest-report-edges.test.sh tests/validate.sh && git commit -m "fix(abt-u21a): bound the verdict rules and Decision wording at R_tokens 2 and 3, the quality edge, the gap, the label and the counts (#588)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/report.py` and `eval/abtest/score.py` (the test reads their output; the verdict rules are already as pre-registered, no code change)
- `tests/abtest-report-walk.test.sh`, `tests/abtest-report-grid.test.sh` and `tests/abtest-report.test.sh` (landed rounds; this round adds a test beside them)
- `CHANGELOG.md`, `docs/harness-glossary.md`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)
- `docs/plans/` and `docs/experiments/abtest-2026-10.md` (never edit a plan or contract by hand; the pre-registered rules are read, not changed)
- `eval/abtest/results.jsonl` and `eval/reports/` (written by the operator unit abt-u21, not by a fix round)
- `tests/validate.sh` (every existing section stays; one insertion after the abtest-report-grid section, nothing else)

## Acceptance criteria
1. run: `bash tests/abtest-report-edges.test.sh`
   exit: 0
   stdout: `All abtest-report-edges checks passed.`
   mutation: skip edit 4 (the last part of the test); the file ends inside the heredoc, the Python never closes and the fragment is absent.
2. run: `bash tests/abtest-report-edges.test.sh | grep -cE '^ok   cell noedge-r(2p5|3) '`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, replace "if rt is not None and rt > 3:" in eval/abtest/report.py with "if rt is not None and rt > 2:" (cells noedge-r2p5 and noedge-r3 then print FAIL, count 0 of 2 passing in the exit 1 run) or with "rt >= 3" (cell noedge-r3 prints FAIL and the count is 1).
   proof: scratch runs (python str.replace on eval/abtest/report.py, then the edges test): rt > 2 failed noedge-r2p5, noedge-r3 and label-distinct; rt >= 3 failed noedge-r3. Each made the count differ from 2.
3. run: `bash tests/abtest-report-edges.test.sh | grep -cE '^ok   cell edge-r(2|2p01|3|3p01) '`
   exit: 0
   stdout: `4`
   mutation: in a scratch copy of the finished change, edit eval/abtest/score.py: replace "r_tok is not None and r_tok <= 2:" with "r_tok is not None and r_tok < 2:", or with "r_tok is not None and r_tok <= 3:", or replace "(r_tok is not None and r_tok > 3)" with "(r_tok is not None and r_tok >= 3)"; cells edge-r2, edge-r2p01 and edge-r3 print FAIL and the count is below 4.
   proof: scratch runs (python str.replace on eval/abtest/score.py, then the edges test): < 2 failed edge-r2; <= 3 failed edge-r2p01 and edge-r3; >= 3 failed edge-r3.
4. run: `bash tests/abtest-report-edges.test.sh | grep -c '^ok   cell label-distinct '`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, make the label wording of eval/abtest/report.py print R_tokens where it prints R_wall (replace "R_wall {fmt(o['R_wall'])} are the numbers" with "R_wall {fmt(o['R_tokens'])} are the numbers"); the cell prints FAIL and the count is 0 (exit 1). Printing R_wall in the R_tokens place fails it the same way.
   proof: scratch runs (python str.replace on eval/abtest/report.py, then the edges test): both swaps failed label-distinct.
5. run: `bash tests/abtest-report-edges.test.sh | grep -c '^ok   cell stall-two '`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, count one stalled run whatever the number (replace 'stalled = v["stalled_human_B"]' with 'stalled = 1 if v["stalled_human_B"] else 0' in eval/abtest/report.py); the cell prints FAIL and the count is 0 (exit 1).
   proof: scratch run (python str.replace on eval/abtest/report.py, then the edges test): stall-two printed FAIL. Raising the Arm B gap rule in eval/abtest/score.py ("if kb - ka >= 2:" to ">= 3") fails it too.
6. run: `bash tests/abtest-report-edges.test.sh | grep -c '^ok   cell defect-two '`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, cap the escaped-defect count at 1 (wrap the sum in finding_reasons of eval/abtest/report.py in min(1, ...)); the cell prints FAIL and the count is 0 (exit 1).
   proof: scratch run (python str.replace on eval/abtest/report.py, then the edges test): defect-two and edge-defects-equal printed FAIL.
7. run: `bash tests/abtest-report-edges.test.sh | grep -c '^ok   cell win-a-gap-2 '`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, replace "if ka - kb >= 2:" with "if ka - kb >= 3:" in eval/abtest/score.py; the cell prints FAIL (outcome TIE) and the count is 0 (exit 1).
   proof: scratch run (python str.replace on eval/abtest/score.py, then the edges test): win-a-gap-2 printed FAIL.
8. run: `bash tests/abtest-report-edges.test.sh | grep -cE '^ok   cell edge-(defects|oos)-equal '`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, turn the strict comparison of either quality-edge median into <= in eval/abtest/score.py, or delete either clause of q["edge"]; the matching cell prints FAIL and the count is 1.
   proof: scratch runs (python str.replace on eval/abtest/score.py, then the edges test): defects <= and the deleted defects clause failed edge-defects-equal; out_of_scope <= and the deleted out-of-scope clause failed edge-oos-equal.
9. run: `bash tests/abtest-report-edges.test.sh | grep -c '^ok   cell label-not-tie '`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, replace 'label = "measured-overhead" if (out == "TIE" and eval_id in COST_EVALS) else None' in eval/abtest/score.py with 'label = "measured-overhead" if eval_id in COST_EVALS else None'; the cell prints FAIL and the count is 0 (exit 1).
   proof: scratch run (python str.replace on eval/abtest/score.py, then the edges test): label-not-tie printed FAIL.
10. run: `bash tests/abtest-report-edges.test.sh | grep -cE '^ok   cell ratio-complete-only(-b)? '`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, take the ratios over every row: replace the line starting "ca = [r for r in ra if" in eval/abtest/score.py with "ca = ra", or the line starting "cb = [r for r in rb if" with "cb = rb"; the matching cell prints FAIL and the count is 1.
   proof: scratch runs (python str.replace on eval/abtest/score.py, then the edges test): ca = ra failed ratio-complete-only; cb = rb failed ratio-complete-only-b.
11. run: `bash tests/abtest-report-edges.test.sh | grep -c '^ok   the boundary walk holds 17 cells$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, delete the cell "win-a-gap-2" from CELLS; the count of cells changes, the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run (python deleting the cell, then the edges test): the row printed FAIL.
12. run: `grep -c "tests/abtest-report-edges" tests/validate.sh`
   exit: 0
   stdout: `4`
   mutation: skip edit 6 (the validate.sh section); stdout 0 and the exit is 1.
13. run: `test -x tests/abtest-report-edges.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 5; the file is not executable and nothing prints.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): bound the verdict' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `tests/abtest-report-edges.test.sh tests/validate.sh`
   mutation: skip edit 7 (the commit); no round commit exists and the run prints no-unit-commit with exit 3.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): bound the verdict' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; no round commit exists and the exit is 3.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u21a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- tests/abtest-report-edges.test.sh tests/validate.sh | grep -vcE "^[a-z]+\(abt-u21a\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the round commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
17. run: `git status --porcelain -- tests/abtest-report-edges.test.sh tests/validate.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 7; the changed files stay modified (or new files untracked) and are listed.

## Pre-resolved context
tdd: yes tests/abtest-report-edges.test.sh (criteria 1 to 13 are the red-then-green checks; the file does not exist at HEAD)
blast-radius: eval/abtest/report.py:137 eval/abtest/score.py:220 eval/abtest/score.py:226
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
order: this round follows abt-u21a-fix5 (the grid test); edit 1 checks that it landed. Both rounds insert into tests/validate.sh, so they never run in parallel.
oracle-source: the cells follow the verdict rules in docs/experiments/abtest-2026-10.md ("Scorer verdict, decided in this order"): a TIE with no quality edge or R_tokens > 3 is not-superior; a TIE with a quality edge and R_tokens <= 2 is superior; a quality edge with 2 < R_tokens <= 3 (or R_tokens not computable) is mixed; the quality edge needs strictly lower medians of both defects_escaped and out_of_scope_lines in Arm B; a 2-run gap decides at N=5. The ratios come from complete rows only. Do not change a cell to match report.py or score.py output; a cell that fails is a finding, STOP and report it.
already-green: criteria 16 and 17 (untagged tail, clean tree) pass at HEAD by design; the others are red at HEAD because tests/abtest-report-edges.test.sh does not exist.
performance: 17 cells, one score.py run, one fill-log run and one tickets run; about 0.1 s in a scratch clone (the walk test takes 0.15 s, the grid test 0.5 s).
skipped: none of the four review items is skipped. The review packet of round 4 is answered cell by cell: item 1 by edge-r2..noedge-r3p01, item 2 by label-distinct, item 3 by stall-two (and defect-two for the escaped count), item 4 by win-a-gap-2, edge-defects-equal, edge-oos-equal, label-not-tie, ratio-complete-only and ratio-complete-only-b.
commit-message: fix(abt-u21a): bound the verdict rules and Decision wording at R_tokens 2 and 3, the quality edge, the gap, the label and the counts (#588)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u21a (#588)
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
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
