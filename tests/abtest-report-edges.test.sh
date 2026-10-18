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
