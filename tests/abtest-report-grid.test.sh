#!/usr/bin/env bash
# Walks the whole undecided half of the Decision table of eval/abtest/report.py: every N bucket (pilot, short,
# short with one arm past 5 rows, unequal, unequal large, nine rows in one arm, top-up, N=5, N=10) x bad rows per arm (turn-cap,
# timeout, error: 0, 1 or 2) x provenance (one value or mixed) x Arm B stall / escaped defect, with usage-limit
# rows on every other cell. It runs the REAL score.py and report.py and asserts, per cell, the scorer outcome,
# the one Decision wording of the table (operator decisions OD-4, OD-12, OD-13, OD-14) and the ticket state.
# The wordings are written out below, not taken from report.py. No claude, no usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

python3 -I - "$T" "$REPO_ROOT/eval/abtest/score.py" "$REPO_ROOT/eval/abtest/report.py" << 'PYEOF' | tee "$T/out.txt"
import json, os, shutil, subprocess, sys

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


def row(ev, arm, rep, status="complete", passed=False, defects=0, harness="h"):
    ok = passed and status == "complete"
    return {
        "schema_version": 1, "run_id": f"{ev}/{arm}/uniform/{rep}", "eval_id": ev, "arm": arm,
        "model_policy": "uniform", "rep": rep, "started_at": "t", "plugin_version": None, "cli_version": "c",
        "fixture_profile": {}, "persona_config_sha": None, "completion_status": status, "result_subtype": None,
        "wall_clock_ms": 1000, "duration_api_ms": None, "total_cost_usd": None, "model_usage": {},
        "tokens_in": 100, "tokens_out": 0, "tokens_cache_write": 0, "tokens_cache_read": 0,
        "tokens_total": 100, "num_turns": 5, "subagent_spawns": 0, "tool_calls": 0,
        "human_interventions_required": 0,
        "checks": [{"id": "chk-a", "kind": "defect", "required": True, "cmd": "node --test x", "exit": 0 if ok else 1, "pass": ok}],
        "holdout_pass_rate": None, "defects_escaped": defects, "out_of_scope_lines": 0, "out_of_scope_files": 0,
        "commits": 1, "run_pass": ok, "process": {}, "blind_grades": {},
        "artifacts": {"stream": f"runs/{ev}_{arm}_{rep}/stream.jsonl", "diff": "d"},
        "harness_commit": harness, "plugin_commit": None, "prompt_sha": "p", "fixture_commit": "f",
    }


STUCK = ("turn-cap", "timeout", "error")
# bucket: rows in Arm A, rows in Arm B, the one Decision wording of an undecided cell without two bad rows
ADVICE = {
    "pilot": (1, 1, "NEEDS MORE DATA: a verdict exists only at N=5 per arm (short N: A=1 B=1); finish the first pass with run-matrix.sh --reps 5 --evals {ev}"),
    "short": (3, 5, "NEEDS MORE DATA: a verdict exists only at N=5 per arm (short N: A=3 B=5); finish the first pass with run-matrix.sh --reps 5 --evals {ev}"),
    "short-wide": (7, 3, "NEEDS MORE DATA: a verdict exists only at N=5 or at equal counts of 10 or more (short N: A=7 B=3); bring both arms to 10 with run-matrix.sh --reps 10 --evals {ev}"),
    "unequal": (5, 6, "NEEDS MORE DATA: the arms hold unequal usable rows (unequal N: A=5 B=6); bring both arms to 10 with run-matrix.sh --reps 10 --evals {ev}"),
    "unequal-large": (10, 12, "NEEDS MORE DATA: the arms hold unequal usable rows (unequal N: A=10 B=12); bring both arms to 12 with run-matrix.sh --reps 12 --evals {ev}"),
    "nine": (9, 7, "NEEDS MORE DATA: the arms hold unequal usable rows (unequal N: A=9 B=7); bring both arms to 10 with run-matrix.sh --reps 10 --evals {ev}"),
    "topup": (7, 7, "NEEDS MORE DATA: finish the top-up (top-up in progress: A=7 B=7, needs 10 per arm) with run-matrix.sh --reps 10 --evals {ev}"),
    "n5": (5, 5, None),
    "n10": (10, 10, None),
}
CELLS = []
for bucket, (na, nb, advice) in ADVICE.items():
    for bad_a, bad_b in ((0, 0), (1, 0), (0, 1), (2, 0), (0, 2), (1, 1)):
        for mixed in (False, True):
            for extra in ("none", "stall", "defect", "both"):
                stall = extra in ("stall", "both")
                if na < bad_a or nb < bad_b + stall or (mixed and na < 2):
                    continue
                CELLS.append(dict(bucket=bucket, na=na, nb=nb, advice=advice, bad_a=bad_a, bad_b=bad_b, mixed=mixed, stall=stall,
                                  defect=extra in ("defect", "both"),
                                  name=f"g-{bucket}-a{bad_a}b{bad_b}-{'mix' if mixed else 'one'}-{extra}"))

rows, log = [], ["# grid log", ""]
for idx, c in enumerate(CELLS):
    ev = c["ev"] = "e50-" + c["name"]
    for i in range(c["na"]):
        status = STUCK[i % 3] if i < c["bad_a"] else "complete"
        rows.append(row(ev, "A", i + 1, status, passed=i == c["bad_a"], harness="old" if c["mixed"] and i == c["na"] - 1 else "h"))
    for i in range(c["nb"]):
        status = STUCK[(i + 2) % 3] if i < c["bad_b"] else ("stalled-human" if c["stall"] and i == c["bad_b"] else "complete")
        rows.append(row(ev, "B", i + 1, status, passed=True, defects=1 if c["defect"] and i == 0 else 0))
    if idx % 2:
        rows += [row(ev, "B", 90 + i, "usage-limit", defects=3) for i in range(2)]
    log += [f"### E{idx + 1}: {c['name']} ({ev})", "", "- **Result**: pending", "- **Verdict**: pending", "- **Decision**: pending", ""]
with open(t + "/rows.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
with open(t + "/log.md", "w") as f:
    f.write("\n".join(log))

p = run(score_py, t + "/rows.jsonl", "--out-json", t + "/score.json")
check("score.py scores the grid rows", p.returncode, 0)
report = json.load(open(t + "/score.json"))
p = run(report_py, "fill-log", t + "/score.json", t + "/log.md", t + "/rows.jsonl")
check("fill-log exits 0 over the whole grid", p.returncode, 0)
p = run(report_py, "tickets", t + "/score.json", t + "/rows.jsonl", t + "/tickets")
check("tickets exits 0 over the whole grid", p.returncode, 0)
os.makedirs(t + "/copy")
shutil.copy(report_py, t + "/copy/report.py")
shutil.copy(t + "/rows.jsonl", t + "/copy/results.jsonl")
shutil.copy(t + "/log.md", t + "/log-default.md")
env = {k: val for k, val in os.environ.items() if k != "ABT_RESULTS"}
p = subprocess.run([sys.executable, "-I", t + "/copy/report.py", "fill-log", t + "/score.json", t + "/log-default.md"], capture_output=True, text=True, env=env)
check("fill-log with two arguments and no ABT_RESULTS exits 0", p.returncode, 0)
results = [x for x in open(t + "/log-default.md").read().split("\n") if x.startswith("- **Result**:")]
check("fill-log with two arguments and no ABT_RESULTS names eval/abtest/results.jsonl in every Result line",
      [len(results), sum("rows in eval/abtest/results.jsonl, verdict" in x for x in results)], [len(CELLS), len(CELLS)])
entries = {}
for block in open(t + "/log.md").read().split("### ")[1:]:
    entries[block.split("(")[1].split(")")[0]] = {line.split("**")[1]: line.split(": ", 1)[1] for line in block.split("\n") if line.startswith("- **")}

problems, covered = [], set()
for c in CELLS:
    ev, v = c["ev"], report["evals"][c["ev"]]
    decision = entries[ev]["Decision"]
    stuck = c["bad_a"] >= 2 or c["bad_b"] >= 2
    decided = c["bucket"] in ("n5", "n10") and not stuck and not c["mixed"]
    want_verdict = "not-superior" if c["stall"] else ("superior" if decided else "inconclusive")
    frags, absent = [], []
    if c["mixed"]:
        frags.append("RERUN: the rows mix provenance (mixed provenance: harness_commit)")
        absent += ["NEEDS MORE DATA", "NO MORE RUNS HELP"]
        (frags if stuck else absent).append("also keep it INCONCLUSIVE at every N (OD-12), unless the repeat replaces them")
    elif stuck:
        frags.append("NO MORE RUNS HELP: two or more turn-cap, timeout or error rows stay INCONCLUSIVE at every N (OD-12)")
        absent += ["NEEDS MORE DATA", "RERUN"]
        (absent if c["bucket"] in ("n5", "n10") else frags).append(f"first, but the bad rows (A {c['bad_a']}, B {c['bad_b']}) decide")
    elif not decided:
        frags.append(c["advice"].format(ev=ev))
        absent += ["NO MORE RUNS HELP", "RERUN"]
    else:
        absent += ["NEEDS MORE DATA", "NO MORE RUNS HELP", "RERUN"]
    (absent if (c["stall"] or not decided) else frags).append("recorded as a measured advantage")
    if c["stall"]:
        frags.append("Arm B stalled-human in 1 run(s)")
    if c["defect"]:
        frags.append("an Arm B run let a defect escape in 1 run(s)")
    ticket = c["stall"] or c["defect"]
    got = [v["outcome"], v["verdict"], "ticket filed" in decision, os.path.exists(f"{t}/tickets/{ev}.md")]
    want = ["WIN_B" if decided else "INCONCLUSIVE", want_verdict, ticket, ticket]
    if got != want:
        problems.append(f"{c['name']}: outcome, verdict, ticket in Decision, ticket file: want {want}, got {got}")
    problems += [f"{c['name']}: Decision lacks '{f}': {decision}" for f in frags if f not in decision]
    problems += [f"{c['name']}: Decision holds '{f}': {decision}" for f in absent if f in decision]
    if ticket and f"Decision: {decision}" not in open(f"{t}/tickets/{ev}.md").read().split("\n"):
        problems.append(f"{c['name']}: the ticket carries another Decision")
    covered.add((v["outcome"], v["verdict"]))
    covered.add(("reason", (v["outcome_reason"] or "").split(":")[0].split(" rows")[0][:20]))

check(f"the grid holds {len(CELLS)} cells", len(CELLS), 396)
check("every cell has the Decision wording and ticket state of the table", problems[:5], [])
check("the grid covers every undecided outcome and verdict pair", sorted(c for c in covered if c[0] != "reason"),
      sorted([("INCONCLUSIVE", "inconclusive"), ("INCONCLUSIVE", "not-superior"), ("WIN_B", "not-superior"), ("WIN_B", "superior")]))
check("the grid covers every undecided reason class", sorted(c[1] for c in covered if c[0] == "reason" and c[1]),
      sorted(["mixed provenance", "short N", "top-up in progress", "two or more turn-cap", "unequal N"]))
check("the usage-limit rows were excluded by the scorer", report["usage_limit_rows_excluded"], 2 * (len(CELLS) // 2))
sys.exit(1 if failed_n else 0)

PYEOF
rc=${PIPESTATUS[0]}
pass=$(grep -c '^ok   ' "$T/out.txt")
fail=$(grep -c '^FAIL ' "$T/out.txt")
echo "abtest-report-grid: $pass passed, $fail failed"
if [ "$rc" -eq 0 ] && [ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]; then
  echo "All abtest-report-grid checks passed."
  exit 0
fi
exit 1
