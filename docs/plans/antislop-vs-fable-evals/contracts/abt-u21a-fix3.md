Unit: abt-u21a

## Objective
Fix of the FAIL of 2026-10-17T22:50:08Z, round 3 of 3. tests/abtest-report-walk.test.sh builds synthetic rows for 31 cells (every outcome, verdict and INCONCLUSIVE reason score.py can emit, plus a stalled Arm B, an escaped defect, usage-limit rows and rows of another policy), runs the real score.py once, runs report.py fill-log and tickets on its real output and asserts per cell the scorer fields, the Decision wording of the decision table in docs/plans/antislop-vs-fable-evals/contracts/abt-u21a-fix2.md, the Result line (Fisher p, directional mark, per-check tallies) and that the Decision says "ticket filed" iff the ticket file exists. tests/validate.sh runs it. One commit.

## Retrieval
GitHub issues: `gh issue view 588 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `tests/abtest-report-walk.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "FAIL tests/abtest-report.test.sh"`)

## Ordered edits
1. command: `git log --format=%s | grep -q "^fix(abt-u21a): pin the Decision table" && grep -q "def finding_reasons" eval/abtest/report.py && test ! -e tests/abtest-report-walk.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `tests/abtest-report-walk.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Walks every scorer outcome / verdict / reason cell that eval/abtest/score.py can emit: builds synthetic
# rows per cell, runs the REAL score.py, feeds its real JSON to eval/abtest/report.py (fill-log and tickets)
# and asserts that the Decision line, the Result line and the ticket files agree for every cell.
# The table of cells is the Decision table of docs/plans/antislop-vs-fable-evals/contracts/abt-u21a-fix1.md.
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
    prov.update(spec.get("prov", {}))
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
        "process": {}, "blind_grades": {}, "artifacts": {"stream": f"runs/{ev}_{arm}_{rep}/stream.jsonl", "diff": "d"},
        **prov,
    }


def reps(n, k, **kw):
    return [dict(passed=i < k, **kw) for i in range(n)]


EDGE_A = dict(defects=2, oos=10)
# name, eval id (None: e<idx>-<name>), arm A specs, arm B specs, want
# want: outcome, verdict, reason (substring of outcome_reason), directional, label, ticket, decision substrings
CELLS = [
    ("short-n-pilot", None, reps(1, 1), reps(1, 1),
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="short N", ticket=False,
          decision=["NEEDS MORE DATA: a verdict exists only at N=5 per arm (short N: A=1 B=1)", "run-matrix.sh --reps 5 --evals e11-short-n-pilot"])),
    ("short-n-stall", None, reps(1, 1), [dict(passed=False, status="stalled-human")],
     dict(outcome="INCONCLUSIVE", verdict="not-superior", reason="short N", ticket=True,
          decision=["ticket filed under the eval-finding label (Arm B stalled-human in 1 run(s))", "NEEDS MORE DATA: a verdict exists only at N=5"])),
    ("short-n-one-arm", None, reps(5, 5), reps(3, 3),
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="short N: A=5 B=3", ticket=False,
          decision=["NEEDS MORE DATA: a verdict exists only at N=5 per arm (short N: A=5 B=3)"])),
    ("unequal-n", None, reps(5, 3), reps(6, 3),
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="unequal N", ticket=False,
          decision=["NEEDS MORE DATA: the arms hold unequal usable rows (unequal N: A=5 B=6)", "bring both arms to 10 with run-matrix.sh --reps 10 --evals e14-unequal-n"])),
    ("unequal-n-large", None, reps(10, 5), reps(12, 5),
~~~~
3. file: `tests/abtest-report-walk.test.sh`
   anchor: line matching `    ("unequal-n-large", None, reps(10, 5), reps(12, 5),`
   indent: 0
   insert-after:
~~~~
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="unequal N", ticket=False,
          decision=["bring both arms to 12 with run-matrix.sh --reps 12 --evals e15-unequal-n-large"])),
    ("topup-in-progress", None, reps(7, 4), reps(7, 4),
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="top-up in progress", ticket=False,
          decision=["NEEDS MORE DATA: finish the top-up (top-up in progress: A=7 B=7, needs 10 per arm) with run-matrix.sh --reps 10 --evals e16-topup-in-progress"])),
    ("one-run-gap", None, reps(5, 3), reps(5, 4),
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="1-run gap", ticket=False,
          decision=["NEEDS MORE DATA: 1-run gap at N=5; top up to N=10 per arm with run-matrix.sh --reps 10 --evals e17-one-run-gap (the pre-registered cure, OD-12)"])),
    ("bad-rows-n5", None, reps(5, 3), reps(3, 3) + [dict(passed=False, status="turn-cap")] * 2,
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="two or more turn-cap", ticket=False,
          decision=["NO MORE RUNS HELP: two or more turn-cap, timeout or error rows stay INCONCLUSIVE at every N (OD-12)", "record the outcome as INCONCLUSIVE"],
          absent=["NEEDS MORE DATA", "top up"])),
    ("bad-rows-n10-arm-a", None, reps(8, 5) + [dict(passed=False, status="timeout")] * 2, reps(10, 5),
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="two or more turn-cap", ticket=False,
          decision=["NO MORE RUNS HELP"], absent=["NEEDS MORE DATA"])),
    ("bad-rows-and-stall", None, reps(5, 3), reps(2, 2) + [dict(passed=False, status="error")] * 2 + [dict(passed=False, status="stalled-human")],
     dict(outcome="INCONCLUSIVE", verdict="not-superior", reason="two or more turn-cap", ticket=True,
          decision=["ticket filed under the eval-finding label (Arm B stalled-human in 1 run(s))", "NO MORE RUNS HELP"], absent=["NEEDS MORE DATA"])),
    ("mixed-provenance", None, reps(5, 3), [dict(passed=i < 3, prov={"harness_commit": "old"} if i == 0 else {}) for i in range(5)],
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="mixed provenance", ticket=False,
          decision=["RERUN: the rows mix provenance (mixed provenance: harness_commit); repeat the stale rows with run-matrix.sh (OD-14), a top-up does not cure it"],
          absent=["NEEDS MORE DATA"])),
    ("mixed-provenance-would-win", None, [dict(passed=False, prov={"prompt_sha": "x"} if i == 0 else {}) for i in range(5)], reps(5, 5),
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="mixed provenance: prompt_sha", ticket=False,
          decision=["RERUN: the rows mix provenance (mixed provenance: prompt_sha)"], absent=["NEEDS MORE DATA", "no action"])),
    ("mixed-provenance-stall", None, reps(5, 3), [dict(passed=False, status="stalled-human")] + [dict(passed=True, prov={"fixture_commit": "old"} if i == 1 else {}) for i in range(4)],
     dict(outcome="INCONCLUSIVE", verdict="not-superior", reason="mixed provenance", ticket=True,
          decision=["ticket filed under the eval-finding label (Arm B stalled-human in 1 run(s))", "RERUN: the rows mix provenance (mixed provenance: fixture_commit)"])),
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
~~~~
4. file: `tests/abtest-report-walk.test.sh`
   anchor: line matching `    ("other-policy-ignored", None, reps(5, 1), reps(5, 5),`
   indent: 0
   insert-after:
~~~~
     dict(outcome="WIN_B", verdict="superior", reason=None, directional=False, ticket=False,
          decision=["no action: recorded as a measured advantage"], absent=["ticket filed"])),
    ("pilot-escape", None, reps(1, 1), [dict(passed=True, defects=1)],
     dict(outcome="INCONCLUSIVE", verdict="inconclusive", reason="short N", ticket=True,
          decision=["ticket filed under the eval-finding label (an Arm B run let a defect escape in 1 run(s))", "NEEDS MORE DATA: a verdict exists only at N=5"])),
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

check("the walk covers every reachable outcome and verdict pair", sorted(c for c in covered if c[0] != "reason"),
      sorted([("INCONCLUSIVE", "inconclusive"), ("INCONCLUSIVE", "not-superior"), ("TIE", "mixed"), ("TIE", "not-superior"), ("TIE", "superior"),
              ("WIN_A", "not-superior"), ("WIN_B", "not-superior"), ("WIN_B", "superior")]))
check("the walk covers every INCONCLUSIVE reason class", sorted(c[1] for c in covered if c[0] == "reason" and c[1]),
      sorted(["1-run gap", "mixed provenance", "short N", "top-up in progress", "two or more turn-cap", "unequal N"]))
check("the usage-limit rows were excluded by the scorer", report["usage_limit_rows_excluded"], 2)
check("the other-policy rows were dropped by the scorer", report["rows_dropped_other_policy"], 2)

before = open(t + "/log.md").read()
p = run(report_py, "fill-log", t + "/score.json", t + "/log.md", t + "/rows.jsonl")
check("fill-log is idempotent", (p.returncode, open(t + "/log.md").read() == before), (0, True))
check("a header after the last entry resets the entry scope", "- **Decision**: pending (outside every entry)" in before, True)
~~~~
5. file: `tests/abtest-report-walk.test.sh`
   anchor: line matching `check("a header after the last entry resets the entry scope", "- **Decision**: pending (outside every entry)" in before, True)`
   indent: 0
   insert-after:
~~~~
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
~~~~
6. command: `chmod +x tests/abtest-report-walk.test.sh`
   expect: 0
7. file: `tests/validate.sh`
   anchor: line matching `echo "FAIL tests/abtest-report.test.sh"`
   indent: 0
   before:
~~~~
  echo "FAIL tests/abtest-report.test.sh"
  fail=1
fi
~~~~
   after:
~~~~
  echo "FAIL tests/abtest-report.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-report-walk.test.sh: every scorer outcome walked through fill-log and tickets (Bash, abt-u21a) =="
if bash tests/abtest-report-walk.test.sh > /dev/null; then
  echo "OK   tests/abtest-report-walk.test.sh"
else
  echo "FAIL tests/abtest-report-walk.test.sh"
  fail=1
fi
~~~~
8. command: `git add tests/abtest-report-walk.test.sh tests/validate.sh && git commit -m "fix(abt-u21a): walk the Decision table with the real scorer and assert Decision and ticket agree (#588)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/report.py` and `tests/abtest-report.test.sh` (rounds abt-u21a-fix1 and abt-u21a-fix2 landed them; this round adds a test beside them)
- `eval/abtest/score.py` and `eval/abtest/lib/` (the walk runs the real scorer; it never edits it)
- `tests/validate.sh` (every existing section stays; one insertion after the abtest-report section, nothing else)
- `CHANGELOG.md`, `docs/harness-glossary.md`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-report-walk.test.sh`
   exit: 0
   stdout: `All abtest-report-walk checks passed.`
   mutation: skip edit 5 (the last part of the walk test); the file ends before the heredoc terminator and the fragment is absent.
2. run: `bash tests/abtest-report-walk.test.sh | grep -c '^ok   .*: a ticket exists exactly when the decision says ticket filed$'`
   exit: 0
   stdout: `31`
   mutation: in a scratch copy of the finished change, make needs_ticket in report.py return its own old test (verdict not-superior or a stall); the Decision and the ticket files disagree on the cells with an escaped defect, the count is 28 (exit 0, so the fragment 31 is absent).
   proof: scratch run (str.replace of the needs_ticket return line, then the walk test): the count of ok rows fell to 28.
3. run: `bash tests/abtest-report-walk.test.sh | grep -c '^ok   tie-edge-mid: a ticket exists exactly when the decision says ticket filed$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, let finding_reasons treat a mixed verdict like not-superior (replace v["verdict"] == "not-superior" with v["verdict"] in ("not-superior", "mixed")); the Decision for the mixed cell says ticket filed and the ticket file exists, but the cell expects none, so the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run (str.replace, then the walk test): the mixed cells printed FAIL.
4. run: `bash tests/abtest-report-walk.test.sh | grep -c '^ok   bad-rows-n5: decision holds'`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, change "NO MORE RUNS HELP" in data_action to "NEEDS MORE DATA"; the first fragment row prints FAIL and the count is 1 (exit 0, fragment 2 absent).
   proof: scratch run (str.replace, then the walk test): the count fell below 2.
5. run: `bash tests/abtest-report-walk.test.sh | grep -c '^ok   win-b-directional: the result line marks a directional verdict$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, drop the directional text from result_line (replace the directional assignment with an empty string); the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run (str.replace, then the walk test): the row printed FAIL.
6. run: `bash tests/abtest-report-walk.test.sh | grep -c '^ok   .*: the result line carries the per-check tallies$'`
   exit: 0
   stdout: `31`
   mutation: in a scratch copy of the finished change, make check_tally return the single word none; every cell row prints FAIL and the count is 0 (exit 1).
   proof: scratch run (str.replace, then the walk test): 31 rows printed FAIL.
7. run: `bash tests/abtest-report-walk.test.sh | grep -c '^ok   the walk covers every'`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, delete the one-run-gap cell from CELLS; the INCONCLUSIVE reason coverage row prints FAIL and the count is 1 (exit 0, fragment 2 absent).
   proof: scratch run (python re.sub deleting the one-run-gap tuple, then the walk test): the coverage row printed FAIL.
8. run: `grep -c 'tests/abtest-report-walk' tests/validate.sh`
   exit: 0
   stdout: `4`
   mutation: skip edit 7 (the validate.sh section); stdout 0 and the exit is 1.
9. run: `test -x tests/abtest-report-walk.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 6; the file is not executable and nothing prints.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): walk the Decision table' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `tests/abtest-report-walk.test.sh tests/validate.sh`
   mutation: skip edit 8 (the commit); no round commit exists and the run prints no-unit-commit with exit 3.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): walk the Decision table' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; no round commit exists and the exit is 3.
12. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u21a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- tests/abtest-report-walk.test.sh tests/validate.sh | grep -vcE "^[a-z]+\(abt-u21a\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
13. run: `git status --porcelain -- tests/abtest-report-walk.test.sh tests/validate.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; the changed files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-report-walk.test.sh (criteria 1 to 7 are the red-then-green checks; the file does not exist at HEAD)
blast-radius: eval/abtest/report.py:198 tests/validate.sh:1489
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 12 (untagged tail) and criterion 13 (scoped clean tree) pass at HEAD by design; criteria 1 to 11 are red at HEAD because the walk test and its commit do not exist.
performance: the walk runs score.py once, fill-log twice and tickets twice over 31 cells; measured in a scratch clone it takes about 0.3 s, and tests/abtest-report.test.sh about 0.3 s, far under the 60 s budget.
cell-table: the 31 cells are the CELLS list inside the test, one tuple per row of the decision table in contracts/abt-u21a-fix2.md; the test fails if a cell reaches a Decision wording, a ticket state or a scorer field other than the one listed.
commit-message: fix(abt-u21a): walk the Decision table with the real scorer and assert Decision and ticket agree (#588)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
