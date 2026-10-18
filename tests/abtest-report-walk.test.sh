#!/usr/bin/env bash
# Walks the decided cells of eval/abtest/score.py (every WIN, TIE and 1-run-gap verdict, the label, the
# stall and defect overrides, usage-limit and other-policy rows): builds synthetic rows per cell, runs the
# REAL score.py, feeds its real JSON to eval/abtest/report.py (fill-log and tickets) and asserts that the
# scorer fields, the Decision line, the Result line and the ticket files agree for every cell.
# The undecided cells (short, unequal, top-up, bad rows, mixed provenance) are in tests/abtest-report-grid.test.sh.
# No claude, no usage.
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


def row(ev, arm, rep, spec, policy="uniform"):
    passed = spec.get("passed", False)
    status = spec.get("status", "complete")
    tokens = spec.get("tokens", 100)
    ok = bool(passed) and status == "complete"
    prov = {"harness_commit": "h", "plugin_commit": None, "prompt_sha": "p", "fixture_commit": "f"}
    return {
        "schema_version": 1, "run_id": f"{ev}/{arm}/{policy}/{rep}", "eval_id": ev, "arm": arm,
        "model_policy": policy, "rep": rep, "started_at": "t", "plugin_version": None, "cli_version": "c",
        "fixture_profile": {}, "persona_config_sha": None, "completion_status": status, "result_subtype": None,
        "wall_clock_ms": 1000, "duration_api_ms": None, "total_cost_usd": None, "model_usage": {},
        "tokens_in": tokens, "tokens_out": 0, "tokens_cache_write": 0, "tokens_cache_read": 0,
        "tokens_total": tokens, "num_turns": 5, "subagent_spawns": 0, "tool_calls": 0,
        "human_interventions_required": 0,
        "checks": [{"id": "chk-a", "kind": "defect", "required": True, "cmd": "node --test x", "exit": 0 if ok else 1, "pass": ok},
                   {"id": "chk-note", "kind": "docs", "required": False, "cmd": "grep x", "exit": 0, "pass": True}],
        "holdout_pass_rate": None, "defects_escaped": spec.get("defects", 0),
        "out_of_scope_lines": spec.get("oos", 0), "out_of_scope_files": 0, "commits": 1, "run_pass": ok,
        "process": spec.get("process", {}), "blind_grades": {},
        "artifacts": {"stream": f"runs/{ev}_{arm}_{rep}/stream.jsonl", "diff": "d"},
        **prov,
    }


def reps(n, k, **kw):
    return [dict(passed=i < k, **kw) for i in range(n)]


EDGE_A = dict(defects=2, oos=10)
# name, eval id (None: e<idx>-<name>), arm A specs, arm B specs, want
# want: outcome, verdict, reason (substring of outcome_reason), directional, label, ticket, decision substrings
CELLS = [
    ("one-run-gap", None, reps(5, 3), reps(5, 4),
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="1-run gap", ticket=False,
          decision=["NEEDS MORE DATA: 1-run gap at N=5; top up to N=10 per arm with run-matrix.sh --reps 10 --evals e11-one-run-gap (the pre-registered cure, OD-12)"])),
    ("win-a-gap", None, reps(5, 5), reps(5, 2),
     dict(outcome="WIN_A", verdict="not-superior", reason=None, ticket=True,
          decision=["ticket filed under the eval-finding label (Arm A won (WIN_A))"], absent=["no action"])),
    ("win-a-fisher", None, reps(10, 9), reps(10, 3),
     dict(outcome="WIN_A", verdict="not-superior", reason=None, ticket=True,
          decision=["ticket filed under the eval-finding label (Arm A won (WIN_A))"])),
    ("win-b-decisive", None, reps(5, 1), reps(5, 5),
     dict(outcome="WIN_B", verdict="superior", reason=None, directional=False, ticket=False,
          decision=["no action: recorded as a measured advantage"], absent=["directional", "ticket"])),
    ("win-b-directional", None, reps(5, 3), reps(5, 5),
     dict(outcome="WIN_B", verdict="superior", reason=None, directional=True, ticket=False,
          decision=["no action: recorded as a measured advantage (directional: a 2-run gap at N=5 with Fisher p=", ", not below 0.10, OD-12)"])),
    ("win-b-directional-3", None, reps(5, 0), reps(5, 3),
     dict(outcome="WIN_B", verdict="superior", reason=None, directional=True, ticket=False,
          decision=["no action: recorded as a measured advantage (directional: a 3-run gap at N=5 with Fisher p="], absent=["2-run"])),
    ("win-b-fisher-n10", None, reps(10, 2), reps(10, 7),
     dict(outcome="WIN_B", verdict="superior", reason=None, directional=False, ticket=False,
          decision=["no action: recorded as a measured advantage"], absent=["directional"])),
    ("win-b-defect-escape", None, reps(5, 1), [dict(passed=True, defects=1 if i == 0 else 0) for i in range(5)],
     dict(outcome="WIN_B", verdict="superior", reason=None, directional=False, ticket=True,
          decision=["ticket filed under the eval-finding label (an Arm B run let a defect escape in 1 run(s))", "verdict superior: recorded as a measured advantage"],
          absent=["no action"])),
    ("win-b-stall", None, reps(5, 1), reps(4, 4) + [dict(passed=False, status="stalled-human")],
     dict(outcome="WIN_B", verdict="not-superior", reason=None, directional=False, ticket=True,
          decision=["ticket filed under the eval-finding label (Arm B stalled-human in 1 run(s))"], absent=["no action", "measured advantage"])),
    ("tie-no-edge", None, reps(5, 3), reps(5, 3),
     dict(outcome="TIE", verdict="not-superior", reason=None, ticket=True,
          decision=["ticket filed under the eval-finding label (tie with no quality edge)"])),
    ("tie-n10-no-edge", None, reps(10, 5), reps(10, 6),
     dict(outcome="TIE", verdict="not-superior", reason=None, ticket=True,
          decision=["ticket filed under the eval-finding label (tie with no quality edge)"], absent=["NEEDS MORE DATA"])),
    ("tie-edge-expensive", None, reps(5, 3, **EDGE_A), reps(5, 3, tokens=400),
     dict(outcome="TIE", verdict="not-superior", reason=None, ticket=True,
          decision=["ticket filed under the eval-finding label (tie with R_tokens above 3)"], absent=["no quality edge"])),
    ("tie-edge-cheap", None, reps(5, 3, **EDGE_A), reps(5, 3, tokens=150),
     dict(outcome="TIE", verdict="superior", reason=None, directional=False, ticket=False,
          decision=["no action: recorded as a measured advantage"])),
    ("tie-edge-mid", None, reps(5, 3, **EDGE_A), reps(5, 3, tokens=250),
     dict(outcome="TIE", verdict="mixed", reason=None, ticket=False,
          decision=["no ticket: verdict mixed (a tie with a quality edge and R_tokens 2.50, above 2 and up to 3 or not computable): reported eval by eval with no headline claim"])),
    ("tie-edge-no-ratio", None, reps(5, 3, tokens=0, **EDGE_A), reps(5, 3),
     dict(outcome="TIE", verdict="mixed", reason=None, ticket=False,
          decision=["no ticket: verdict mixed (a tie with a quality edge and R_tokens n/a, above 2 and up to 3 or not computable)"])),
    ("tie-edge-mid-defect", None, reps(5, 3, **EDGE_A), [dict(passed=i < 3, tokens=250, defects=1 if i == 0 else 0) for i in range(5)],
     dict(outcome="TIE", verdict="mixed", reason=None, ticket=True,
          decision=["ticket filed under the eval-finding label (an Arm B run let a defect escape in 1 run(s))", "verdict mixed (a tie with a quality edge"], absent=["no ticket:"])),
    ("label-tie-no-edge", "e05-tags-feature", reps(5, 3), reps(5, 3),
     dict(outcome="TIE", verdict="not-superior", reason=None, label="measured-overhead", ticket=True,
          decision=["ticket filed under the eval-finding label (tie with no quality edge)", "label measured-overhead: the expected result, R_tokens 1.00 and R_wall 1.00 are the numbers that matter"])),
    ("label-tie-superior", "e08-stable-cursor", reps(5, 3, **EDGE_A), reps(5, 3, tokens=150),
     dict(outcome="TIE", verdict="superior", reason=None, label="measured-overhead", ticket=False,
          decision=["no action: recorded as a measured advantage; label measured-overhead: the expected result"])),
    ("usage-limit-ignored", None, reps(5, 1), reps(5, 5) + [dict(passed=False, status="usage-limit", defects=3)] * 2,
     dict(outcome="WIN_B", verdict="superior", reason=None, directional=False, ticket=False,
          decision=["no action: recorded as a measured advantage"], absent=["ticket filed"])),
    ("other-policy-ignored", None, reps(5, 1), reps(5, 5),
     dict(outcome="WIN_B", verdict="superior", reason=None, directional=False, ticket=False,
          decision=["no action: recorded as a measured advantage"], absent=["ticket filed"])),
    # OPEN QUESTION for the operator: design 5.5 lists gate_blocks>0 on an unexpected path as a ticket trigger, and no
    # operator decision says which path is unexpected. Until one does, gate_blocks never files a ticket: this cell pins that.
    ("gate-blocks-no-ticket", None, reps(5, 1), [dict(passed=True, process={"gate_blocks": 3}) for _ in range(5)],
     dict(outcome="WIN_B", verdict="superior", reason=None, directional=False, ticket=False,
          decision=["no action: recorded as a measured advantage"], absent=["ticket filed", "gate"])),
]

rows, log, ids = [], ["# walk log", ""], {}
for idx, (name, ev, a, b, want) in enumerate(CELLS):
    ev = ev or f"e{11 + idx}-{name}"
    ids[name] = ev
    for arm, specs in (("A", a), ("B", b)):
        for rep, spec in enumerate(specs, 1):
            rows.append(row(ev, arm, rep, spec))
    if name == "other-policy-ignored":
        rows += [row(ev, "B", 10 + i, dict(passed=False, defects=4), policy="shipped") for i in range(2)]
    log += [f"### E{idx + 1}: {name} ({ev})", "", "- **Result**: pending", "- **Verdict**: pending", "- **Decision**: pending", ""]
log += ["## Verdict rules", "", "- **Decision**: pending (outside every entry)", ""]
with open(t + "/rows.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
with open(t + "/log.md", "w") as f:
    f.write("\n".join(log))

p = run(score_py, t + "/rows.jsonl", "--out-json", t + "/score.json")
check("score.py scores the synthetic rows", p.returncode, 0)
report = json.load(open(t + "/score.json"))
p = run(report_py, "fill-log", t + "/score.json", t + "/log.md", t + "/rows.jsonl")
check("fill-log exits 0 over the whole table", p.returncode, 0)
p = run(report_py, "tickets", t + "/score.json", t + "/rows.jsonl", t + "/tickets")
check("tickets exits 0 over the whole table", p.returncode, 0)
text = open(t + "/log.md").read()
entries = {}
for block in text.split("### ")[1:]:
    ev = block.split("(")[1].split(")")[0]
    entries[ev] = {line.split("**")[1]: line.split(": ", 1)[1] for line in block.split("\n## ")[0].split("\n") if line.startswith("- **")}

covered = set()
for name, ev0, a, b, want in CELLS:
    ev = ids[name]
    v = report["evals"][ev]
    check(f"{name}: scorer outcome", v["outcome"], want["outcome"])
    check(f"{name}: scorer verdict", v["verdict"], want["verdict"])
    if want.get("reason"):
        check(f"{name}: scorer reason", want["reason"] in (v["outcome_reason"] or ""), True)
    if "directional" in want:
        check(f"{name}: scorer directional", v["directional"], want["directional"])
    check(f"{name}: scorer label", v["label"], want.get("label"))
    decision = entries[ev]["Decision"]
    result = entries[ev]["Result"]
    for frag in want["decision"]:
        check(f"{name}: decision holds '{frag[:60]}'", frag in decision, True)
    for frag in want.get("absent", []):
        check(f"{name}: decision lacks '{frag}'", frag in decision, False)
    if want.get("directional"):
        note = f"(directional: a {v['k_B'] - v['k_A']}-run gap at N=5 with Fisher p={v['fisher_p']:.2f}, not below 0.10, OD-12)"
        check(f"{name}: the directional note names the gap and the Fisher p", note in decision, True)
    exists = os.path.exists(f"{t}/tickets/{ev}.md")
    check(f"{name}: a ticket exists exactly when the decision says ticket filed", ("ticket filed" in decision, exists), (want["ticket"], want["ticket"]))
    if exists:
        check(f"{name}: the ticket carries the same decision", f"Decision: {decision}" in open(f"{t}/tickets/{ev}.md").read().split("\n"), True)
    check(f"{name}: the result line keeps the Fisher p", f"Fisher p {v['fisher_p']:.2f}" in result, True)
    check(f"{name}: the result line marks a directional verdict", "(directional, p=" in result, bool(v["directional"]))
    check(f"{name}: the result line carries the per-check tallies",
          f"A [chk-a {v['k_A']}/{v['n_A']}, chk-note {v['n_A']}/{v['n_A']} (reported)]" in result and f"B [chk-a {v['k_B']}/{v['n_B']}, chk-note {v['n_B']}/{v['n_B']} (reported)]" in result, True)
    covered.add((v["outcome"], v["verdict"]))
    covered.add(("reason", (v["outcome_reason"] or "").split(":")[0].split(" rows")[0][:20]))

check("the walk covers every decided outcome and verdict pair", sorted(c for c in covered if c[0] != "reason"),
      sorted([("INCONCLUSIVE", "inconclusive"), ("TIE", "mixed"), ("TIE", "not-superior"), ("TIE", "superior"),
              ("WIN_A", "not-superior"), ("WIN_B", "not-superior"), ("WIN_B", "superior")]))
check("the walk covers the 1-run-gap reason class", sorted(c[1] for c in covered if c[0] == "reason" and c[1]), ["1-run gap"])
check("the usage-limit rows were excluded by the scorer", report["usage_limit_rows_excluded"], 2)
check("the other-policy rows were dropped by the scorer", report["rows_dropped_other_policy"], 2)

before = open(t + "/log.md").read()
p = run(report_py, "fill-log", t + "/score.json", t + "/log.md", t + "/rows.jsonl")
check("fill-log is idempotent", (p.returncode, open(t + "/log.md").read() == before), (0, True))
check("a header after the last entry resets the entry scope", "- **Decision**: pending (outside every entry)" in before, True)
p = run(report_py, "tickets", t + "/score.json", t + "/rows.jsonl", t + "/tickets")
check("tickets refuses a non-empty output directory", (p.returncode != 0, "not an empty directory" in p.stderr), (True, True))
check("the stale tickets are untouched", len(os.listdir(t + "/tickets")), sum(1 for c in CELLS if c[4]["ticket"]))
sys.exit(1 if failed_n else 0)

PYEOF
rc=${PIPESTATUS[0]}
pass=$(grep -c '^ok   ' "$T/out.txt")
fail=$(grep -c '^FAIL ' "$T/out.txt")
echo "abtest-report-walk: $pass passed, $fail failed"
if [ "$rc" -eq 0 ] && [ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]; then
  echo "All abtest-report-walk checks passed."
  exit 0
fi
exit 1
