Unit: abt-u21a

## Objective
Fix of the FAIL of 2026-10-17T22:50:08Z. eval/abtest/report.py decides "a ticket exists" in one function, finding_reasons, used by both the Decision line and the ticket writer, so a Decision says "ticket filed" iff a ticket file is written; every INCONCLUSIVE reason, verdict and outcome score.py can emit has exactly one Decision wording (the decision-table below); the Result line keeps the Fisher p, the directional mark and the per-arm per-check pass counts; fill-log and tickets fail closed. This round only adapts the existing test to the new behaviour; fix2 (docs/plans/antislop-vs-fable-evals/contracts/abt-u21a-fix2.md) holds the Decision table and the rows that pin each change, fix3 the walk-the-table test. One commit.

## Retrieval
GitHub issues: `gh issue view 588 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/report.py` (anchor: line matching `HYPOTHESIS = {`)
- `tests/abtest-report.test.sh` (anchor: line matching `SCORE="$REPO_ROOT/eval/abtest/score.py"`)

## Ordered edits
1. command: `git log --format=%s | grep -q "^feat(abt-u21a): report and ticket tooling" && test -f eval/abtest/report.py && test -f tests/abtest-report.test.sh && ! grep -q finding_reasons eval/abtest/report.py && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/report.py`
   anchor: line matching `report.py tickets SCORE_JSON ROWS_JSONL OUT_DIR`
   indent: 0
   before:
~~~~

  report.py fill-log SCORE_JSON EXPERIMENT_MD
  report.py tickets SCORE_JSON ROWS_JSONL OUT_DIR
~~~~
   after:
~~~~

  report.py fill-log SCORE_JSON EXPERIMENT_MD [ROWS_JSONL]
  report.py tickets SCORE_JSON ROWS_JSONL OUT_DIR
~~~~
3. file: `eval/abtest/report.py`
   anchor: line matching `for the operator, who judges the prediction. tickets writes OUT_DIR/<eval-id>.md for`
   indent: 0
   before:
~~~~
for the operator, who judges the prediction. tickets writes OUT_DIR/<eval-id>.md for
~~~~
   after:
~~~~
for the operator, who judges the prediction. ROWS_JSONL defaults to $ABT_RESULTS, else
results.jsonl beside this script. tickets writes OUT_DIR/<eval-id>.md for
~~~~
4. file: `eval/abtest/report.py`
   anchor: line matching `every eval that is not superior, or whose Arm B stalled or let a defect escape.`
   indent: 0
   insert-after:
~~~~
Both commands decide "a ticket exists" with the one function finding_reasons, so the
Decision line and the ticket files cannot disagree. They stop with a non-zero exit,
and write nothing, when the score report and the rows disagree, when the eval ids of
the report and of the log differ, or when the report holds an outcome or verdict this
file has no wording for.
~~~~
5. file: `eval/abtest/report.py`
   anchor: line matching `"e05-tags-feature": "pathfinder slicing (did task-master produce six or more units with runnable criteria?), orchestrator batching (a second wave never dispatched is a bug), dispatch-hygiene warn logs; if only cost lost, candidates are task-master maxTurns, per-unit scribe dispatches and the review-join ceremony.",`
   indent: 0
   before:
~~~~
    "e05-tags-feature": "pathfinder slicing (did task-master produce six or more units with runnable criteria?), orchestrator batching (a second wave never dispatched is a bug), dispatch-hygiene warn logs; if only cost lost, candidates are task-master maxTurns, per-unit scribe dispatches and the review-join ceremony.",
}
~~~~
   after:
~~~~
    "e05-tags-feature": "pathfinder slicing (did task-master produce six or more units with runnable criteria?), orchestrator batching (a second wave never dispatched is a bug), dispatch-hygiene warn logs; if only cost lost, candidates are task-master maxTurns, per-unit scribe dispatches and the review-join ceremony.",
}
BLIND = {
    "e01-ambiguous-tax": "blinded assumptions_cites_glossary grade: not in the rows; read it from bash eval/abtest/blind.sh --unseal",
}
EVAL_ID = re.compile(r"^e\d{2}-[a-z0-9-]+$")
HEADING = re.compile(r"#{1,3} ")
ENTRY = re.compile(r"### E\d+: .*\((e\d{2}-[a-z0-9-]+)\)\s*$")
VERDICTS = ("superior", "not-superior", "mixed", "inconclusive")
OUTCOMES = ("WIN_A", "WIN_B", "TIE", "INCONCLUSIVE")


def die(msg):
    raise SystemExit(f"report: {msg}")
~~~~
6. file: `eval/abtest/report.py`
   anchor: line matching `def result_line(e, v):`
   indent: 0
   before:
~~~~
def result_line(e, v):
~~~~
   after:
~~~~
def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        die(f"cannot read {path} as JSON: {e}")


def load_rows(path):
    rows = []
    try:
        with open(path) as f:
            for n, line in enumerate(f, 1):
                if line.strip():
                    rows.append(json.loads(line))
    except (OSError, ValueError) as e:
        die(f"cannot read {path} as JSON lines: {e}")
    return rows


def usable_rows(report, rows):
    """The rows each eval was scored from: the report's policy, no usage-limit row (as in score.py)."""
    policy = report.get("policy")
    by_eval = {}
    for r in rows:
        if isinstance(r, dict) and r.get("model_policy") == policy and r.get("completion_status") != "usage-limit":
            by_eval.setdefault(r.get("eval_id"), []).append(r)
    for eval_id, v in report["evals"].items():
        if not EVAL_ID.match(eval_id):
            die(f"eval id {eval_id!r} does not match {EVAL_ID.pattern}")
        got = sorted(r.get("run_id") for r in by_eval.get(eval_id, []))
        if got != v["run_ids"]:
            die(f"the rows do not match the score report for {eval_id}: report {v['run_ids']}, rows {got}")
    return by_eval


def check_tally(rows, arm):
    """Per-check pass counts of one arm, over all usable rows of that arm."""
    arm_rows = [r for r in rows if r.get("arm") == arm]
    ids = []
    required = {}
    for r in arm_rows:
        for c in r.get("checks") or []:
            if c["id"] not in required:
                ids.append(c["id"])
                required[c["id"]] = c["required"]
    parts = []
    for cid in ids:
        k = sum(1 for r in arm_rows if any(c["id"] == cid and c["pass"] for c in r.get("checks") or []))
        parts.append(f"{cid} {k}/{len(arm_rows)}" + ("" if required[cid] else " (reported)"))
    return ", ".join(parts) or "none"


def result_line(e, v, rows):
~~~~
7. file: `eval/abtest/report.py`
   anchor: line matching `return (f"run_pass A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']} ({v['outcome']}); "`
   indent: 0
   before:
~~~~
    return (f"run_pass A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']} ({v['outcome']}); "
~~~~
   after:
~~~~
    why = f"; outcome reason: {v['outcome_reason']}" if v.get("outcome_reason") else ""
    directional = f" (directional, p={fmt(v['fisher_p'])})" if v.get("directional") else ""
    blind = f"; {BLIND[e]}" if e in BLIND else ""
    return (f"run_pass A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']} ({v['outcome']}){why}; "
            f"Fisher p {fmt(v['fisher_p'])}; "
~~~~
8. file: `eval/abtest/report.py`
   anchor: line matching `f"rows in eval/abtest/results.jsonl, verdict {v['verdict']}"`
   indent: 0
   before:
~~~~
            f"rows in eval/abtest/results.jsonl, verdict {v['verdict']}"
~~~~
   after:
~~~~
            f"checks passed per arm (of the usable rows) A [{check_tally(rows, 'A')}], B [{check_tally(rows, 'B')}]{blind}; "
            f"rows in eval/abtest/results.jsonl, verdict {v['verdict']}{directional}"
~~~~
9. file: `eval/abtest/report.py`
   anchor: line matching `def decision_line(v):`
   indent: 0
   before:
~~~~
def decision_line(v):
    if v["verdict"] == "inconclusive":
        reason = str(v.get("outcome_reason") or "")
        if reason.startswith("mixed provenance"):
            return f"RERUN: the rows mix provenance ({reason}); repeat the stale rows with run-matrix.sh (OD-14), a top-up does not cure it"
        return "NEEDS MORE DATA: top up this eval to N=10 with run-matrix.sh --reps 10 --evals <eval-id>"
    if v["verdict"] == "superior":
        return "no action: recorded as a measured advantage"
    return "ticket filed under the eval-finding label (see the report); no change is shipped by this log"
~~~~
   after:
~~~~
def finding_reasons(v, rows):
    """Why this eval gets an eval-finding ticket; empty means no ticket. The one predicate for Decision and tickets."""
    reasons = []
    stalled = v["stalled_human_B"]
    if stalled > 0:
        reasons.append(f"Arm B stalled-human in {stalled} run(s)")
    if v["outcome"] == "WIN_A":
        reasons.append("Arm A won (WIN_A)")
    if v["verdict"] == "not-superior" and stalled == 0 and v["outcome"] != "WIN_A":
        tie = []
        if not v["quality"]["edge"]:
            tie.append("no quality edge")
        rt = v["overhead"]["R_tokens"]
        if rt is not None and rt > 3:
            tie.append("R_tokens above 3")
        reasons.append("tie with " + " and ".join(tie or ["no superior verdict"]))
    escaped = sum(1 for r in rows if r.get("arm") == "B" and r["defects_escaped"] > 0)
    if escaped:
        reasons.append(f"an Arm B run let a defect escape in {escaped} run(s)")
    return reasons
~~~~
10. file: `eval/abtest/report.py`
   anchor: line matching `def fill_log(score_path, md_path):`
   indent: 0
   before:
~~~~
def fill_log(score_path, md_path):
    report = json.load(open(score_path))
    lines = open(md_path).read().split("\n")
~~~~
   after:
~~~~
def needs_ticket(v, rows):
    return bool(finding_reasons(v, rows))


def data_action(eval_id, v):
    """What the operator does about an INCONCLUSIVE outcome. One wording per outcome_reason class (OD-12, OD-14)."""
    reason = str(v.get("outcome_reason") or "")
    run = f"run-matrix.sh --reps {{}} --evals {eval_id}"
    if reason.startswith("mixed provenance"):
        return f"RERUN: the rows mix provenance ({reason}); repeat the stale rows with run-matrix.sh (OD-14), a top-up does not cure it"
    if reason.startswith("short N"):
        return f"NEEDS MORE DATA: a verdict exists only at N=5 per arm ({reason}); finish the first pass with {run.format(5)}"
    if reason.startswith("unequal N"):
        top = max(v["n_A"], v["n_B"])
        target = top if (top <= 5 or top >= 10) else 10
        return f"NEEDS MORE DATA: the arms hold unequal usable rows ({reason}); bring both arms to {target} with {run.format(target)}"
    if reason.startswith("top-up in progress"):
        return f"NEEDS MORE DATA: finish the top-up ({reason}) with {run.format(10)}"
    if reason.startswith("1-run gap"):
        return f"NEEDS MORE DATA: 1-run gap at N=5; top up to N=10 per arm with {run.format(10)} (the pre-registered cure, OD-12)"
    if reason.startswith("two or more turn-cap"):
        return ("NO MORE RUNS HELP: two or more turn-cap, timeout or error rows stay INCONCLUSIVE at every N (OD-12); "
                "a top-up keeps those rows (a resume skips run ids already done), so record the outcome as INCONCLUSIVE")
    die(f"{eval_id}: no wording for the INCONCLUSIVE reason {reason!r}")


def decision_line(eval_id, v, rows):
    if v["verdict"] not in VERDICTS or v["outcome"] not in OUTCOMES:
        die(f"{eval_id}: no wording for verdict {v['verdict']!r} with outcome {v['outcome']!r}")
    reasons = finding_reasons(v, rows)
    parts = []
    if reasons:
        parts.append("ticket filed under the eval-finding label (" + "; ".join(reasons) + "); no change is shipped by this log")
    if v["verdict"] == "superior":
        note = "recorded as a measured advantage"
        if v.get("directional"):
            note += f" (directional: a 2-run gap at N=5 with Fisher p={fmt(v['fisher_p'])}, not below 0.10, OD-12)"
        parts.append(("verdict superior: " if reasons else "no action: ") + note)
    if v["verdict"] == "mixed":
        note = (f"verdict mixed (a tie with a quality edge and R_tokens {fmt(v['overhead']['R_tokens'])}, above 2 and up to 3 or "
                "not computable): reported eval by eval with no headline claim")
        parts.append(note if reasons else "no ticket: " + note)
    if v["outcome"] == "INCONCLUSIVE":
        parts.append(data_action(eval_id, v))
    if v["label"]:
        o = v["overhead"]
        parts.append(f"label {v['label']}: the expected result, R_tokens {fmt(o['R_tokens'])} and R_wall {fmt(o['R_wall'])} are the numbers that matter")
    if not parts:
        die(f"{eval_id}: no wording for verdict {v['verdict']!r} with outcome {v['outcome']!r}")
    return "; ".join(parts)


def fill_log(score_path, md_path, rows_path=None):
    report = load_json(score_path)
    rows_path = rows_path or os.environ.get("ABT_RESULTS") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "results.jsonl")
    by_eval = usable_rows(report, load_rows(rows_path))
    try:
        with open(md_path) as f:
            lines = f.read().split("\n")
    except OSError as e:
        die(f"cannot read {md_path}: {e}")
    in_log = {m.group(1) for m in map(ENTRY.match, lines) if m}
    if in_log != set(report["evals"]):
        die(f"the log and the score report hold different evals: only in the log {sorted(in_log - set(report['evals']))}, "
            f"only in the report {sorted(set(report['evals']) - in_log)}")
~~~~
11. file: `eval/abtest/report.py`
   anchor: line matching `f"only in the report {sorted(set(report['evals']) - in_log)}")`
   indent: 0
   before:
~~~~
            f"only in the report {sorted(set(report['evals']) - in_log)}")
    current = None
~~~~
   after:
~~~~
            f"only in the report {sorted(set(report['evals']) - in_log)}")
    current = None
    seen = {}
~~~~
12. file: `eval/abtest/report.py`
   anchor: line matching `m = re.match(r"### E\d+: .*\(([a-z0-9-]+)\)\s*$", line)`
   indent: 0
   before:
~~~~
        m = re.match(r"### E\d+: .*\(([a-z0-9-]+)\)\s*$", line)
~~~~
   after:
~~~~
        m = ENTRY.match(line)
~~~~
13. file: `eval/abtest/report.py`
   anchor: line matching `elif line.startswith("### "):`
   indent: 0
   before:
~~~~
        elif line.startswith("### "):
~~~~
   after:
~~~~
        elif HEADING.match(line):
~~~~
14. file: `eval/abtest/report.py`
   anchor: line matching `v = report["evals"][current]`
   indent: 0
   insert-after:
~~~~
            rows = by_eval.get(current, [])
~~~~
15. file: `eval/abtest/report.py`
   anchor: line matching `lines[i] = f"- **Result**: {result_line(current, v)}"`
   indent: 0
   before:
~~~~
                lines[i] = f"- **Result**: {result_line(current, v)}"
~~~~
   after:
~~~~
                lines[i] = f"- **Result**: {result_line(current, v, rows)}"
                seen[(current, "Result")] = seen.get((current, "Result"), 0) + 1
~~~~
16. file: `eval/abtest/report.py`
   anchor: line matching `lines[i] = f"- **Decision**: {decision_line(v)}"`
   indent: 0
   before:
~~~~
                lines[i] = f"- **Decision**: {decision_line(v)}"
    open(md_path, "w").write("\n".join(lines))
~~~~
   after:
~~~~
                lines[i] = f"- **Decision**: {decision_line(current, v, rows)}"
                seen[(current, "Decision")] = seen.get((current, "Decision"), 0) + 1
    for e in report["evals"]:
        for key in ("Result", "Decision"):
            if seen.get((e, key), 0) != 1:
                die(f"the log entry for {e} must hold exactly one '- **{key}**:' line, found {seen.get((e, key), 0)}")
    with open(md_path, "w") as f:
        f.write("\n".join(lines))
    print(f"fill-log: filled {len(report['evals'])} entries")
~~~~
17. file: `eval/abtest/report.py`
   anchor: line matching `if v["verdict"] == "not-superior" or v["stalled_human_B"] > 0:`
   indent: 0
   before:
~~~~
def needs_ticket(v, rows):
    if v["verdict"] == "not-superior" or v["stalled_human_B"] > 0:
        return True
    return any(r["arm"] == "B" and r["defects_escaped"] > 0 for r in rows)


~~~~
   after:
~~~~
~~~~
18. file: `eval/abtest/report.py`
   anchor: line matching `report = json.load(open(score_path))`
   indent: 0
   before:
~~~~
    report = json.load(open(score_path))
    rows = [json.loads(l) for l in open(rows_path) if l.strip()]
~~~~
   after:
~~~~
    report = load_json(score_path)
    by_eval = usable_rows(report, load_rows(rows_path))
    if os.path.exists(out_dir) and (not os.path.isdir(out_dir) or os.listdir(out_dir)):
        die(f"{out_dir} exists and is not an empty directory; remove it so no stale ticket survives")
    planned = {}
    for eval_id, v in report["evals"].items():
        rs = by_eval.get(eval_id, [])
        if needs_ticket(v, rs):
            planned[eval_id] = (v, rs, decision_line(eval_id, v, rs), finding_reasons(v, rs))
~~~~
19. file: `eval/abtest/report.py`
   anchor: line matching `written = 0`
   indent: 0
   before:
~~~~
    written = 0
    for eval_id, v in report["evals"].items():
        rs = [r for r in rows if r["eval_id"] == eval_id and r["completion_status"] != "usage-limit"]
        if not needs_ticket(v, rs):
            continue
~~~~
   after:
~~~~
    for eval_id, (v, rs, decision, reasons) in planned.items():
~~~~
20. file: `eval/abtest/report.py`
   anchor: line matching `f"Outcome: {v['outcome']} (A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']}); {result_line(eval_id, v).split('; ', 1)[1]}", "",`
   indent: 0
   before:
~~~~
                f"Outcome: {v['outcome']} (A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']}); {result_line(eval_id, v).split('; ', 1)[1]}", "",
~~~~
   after:
~~~~
                "Why a ticket: " + "; ".join(reasons) + ".",
                f"Result: {result_line(eval_id, v, rs)}",
                f"Decision: {decision}", "",
~~~~
21. file: `eval/abtest/report.py`
   anchor: line matching `written += 1`
   indent: 0
   before:
~~~~
        written += 1
    print(f"tickets: wrote {written}")
~~~~
   after:
~~~~
    print(f"tickets: wrote {len(planned)}")
~~~~
22. file: `eval/abtest/report.py`
   anchor: line matching `if len(argv) == 3 and argv[0] == "fill-log":`
   indent: 0
   before:
~~~~
    if len(argv) == 3 and argv[0] == "fill-log":
        return fill_log(argv[1], argv[2])
~~~~
   after:
~~~~
    if len(argv) in (3, 4) and argv[0] == "fill-log":
        return fill_log(*argv[1:])
~~~~
23. file: `eval/abtest/report.py`
   anchor: line matching `print("usage: report.py fill-log SCORE_JSON EXPERIMENT_MD | tickets SCORE_JSON ROWS_JSONL OUT_DIR", file=sys.stderr)`
   indent: 0
   before:
~~~~
    print("usage: report.py fill-log SCORE_JSON EXPERIMENT_MD | tickets SCORE_JSON ROWS_JSONL OUT_DIR", file=sys.stderr)
~~~~
   after:
~~~~
    print("usage: report.py fill-log SCORE_JSON EXPERIMENT_MD [ROWS_JSONL] | tickets SCORE_JSON ROWS_JSONL OUT_DIR", file=sys.stderr)
~~~~
24. file: `tests/abtest-report.test.sh`
   anchor: line matching `### E2: preview (e02-preview-mutation)`
   indent: 0
   before:
~~~~
### E2: preview (e02-preview-mutation)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E3: rename (e03-rename-query)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending
~~~~
   after:
~~~~
### E2: preview (e02-preview-mutation)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E3: rename (e03-rename-query)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E4: search (e04-search-injection)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E5: tags (e05-tags-feature)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending
~~~~
25. file: `tests/abtest-report.test.sh`
   anchor: line matching `python3 "$REPORT" fill-log "$T/score.json" "$T/log.md"; rc=$?`
   indent: 0
   before:
~~~~
python3 "$REPORT" fill-log "$T/score.json" "$T/log.md"; rc=$?
~~~~
   after:
~~~~
python3 "$REPORT" fill-log "$T/score.json" "$T/log.md" "$T/rows.jsonl" > /dev/null; rc=$?
~~~~
26. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "the verdict lines stay pending for the operator" "$(grep -c '^- \*\*Verdict\*\*: pending' "$T/log.md")" "3"`
   indent: 0
   before:
~~~~
check "the verdict lines stay pending for the operator" "$(grep -c '^- \*\*Verdict\*\*: pending' "$T/log.md")" "3"
check "a not-superior eval points at a ticket" "$(grep -c 'ticket filed under the eval-finding label' "$T/log.md")" "1"
check "a superior eval records no action" "$(grep -c '^- \*\*Decision\*\*: no action' "$T/log.md")" "1"
~~~~
   after:
~~~~
check "the verdict lines stay pending for the operator" "$(grep -c '^- \*\*Verdict\*\*: pending' "$T/log.md")" "5"
check "every not-superior, stalling or defect-escaping eval points at a ticket" "$(grep -c '^- \*\*Decision\*\*: ticket filed under the eval-finding label' "$T/log.md")" "4"
~~~~
27. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "entries outside the report are left alone" "$(grep -c 'e04\|e05' "$T/log.md")" "0"`
   indent: 0
   before:
~~~~
check "entries outside the report are left alone" "$(grep -c 'e04\|e05' "$T/log.md")" "0"
~~~~
   after:
~~~~
~~~~
28. file: `tests/abtest-report.test.sh`
   anchor: line matching `python3 "$REPORT" fill-log "$T/score-mixed.json" "$T/log-mixed.md"`
   indent: 0
   before:
~~~~
python3 "$REPORT" fill-log "$T/score-mixed.json" "$T/log-mixed.md"
~~~~
   after:
~~~~
python3 "$REPORT" fill-log "$T/score-mixed.json" "$T/log-mixed.md" "$T/rows-mixed.jsonl" > /dev/null
~~~~
29. command: `git add eval/abtest/report.py tests/abtest-report.test.sh && git commit -m "fix(abt-u21a): one ticket predicate for Decision lines and ticket files, per-check tallies, fail-closed report commands (#588)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/score.py` and `eval/abtest/lib/` (the report reads the score report; it never edits the scorer)
- `docs/experiments/abtest-2026-10.md` (abt-u16 owns it; abt-u21 runs fill-log on it later)
- `tests/validate.sh` (the abtest-report section already exists; the walk test is registered by the next round)
- `CHANGELOG.md`, `docs/harness-glossary.md`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-report.test.sh`
   exit: 0
   stdout: `All abtest-report checks passed.`
   mutation: in a scratch copy of the finished change, change "    if escaped:" in finding_reasons to "    if False:"; two rows print FAIL, the script exits non-zero and the fragment is absent.
   proof: scratch run (str.replace on report.py, then bash tests/abtest-report.test.sh): FAIL rows printed.
2. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (every not-superior, stalling or defect-escaping eval points at a ticket)$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, make the escaped-defect clause of finding_reasons dead as in criterion 1; E2 gets no ticket line, the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run as in criterion 1: the row printed FAIL.
3. run: `python3 -I eval/abtest/report.py bogus 2>&1 | grep -c 'usage: report.py fill-log SCORE_JSON EXPERIMENT_MD .ROWS_JSONL.'`
   exit: 0
   stdout: `1`
   mutation: skip edit 23 (the usage line); the old usage line prints and the count is 0 (exit 1).
4. run: `python3 -I eval/abtest/report.py fill-log nosuch.json nosuch.md 2>&1 | grep -c '^report: cannot read nosuch.json as JSON'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6 (load_json); the old code prints a traceback and the count is 0 (exit 1).
5. run: `grep -c 'finding_reasons(' eval/abtest/report.py`
   exit: 0
   stdout: `4`
   mutation: in a scratch copy of the finished change, make needs_ticket return its own test (verdict not-superior or a stall) instead of calling finding_reasons; the count is 3.
   proof: scratch run (str.replace of the needs_ticket return line): grep printed 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): one ticket predicate' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/report.py tests/abtest-report.test.sh`
   mutation: skip edit 29 (the commit); no round commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): one ticket predicate' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 29; no round commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u21a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/report.py tests/abtest-report.test.sh | grep -vcE "^[a-z]+\(abt-u21a\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest/report.py tests/abtest-report.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 29; the changed files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-report.test.sh (the rows named in criteria 2 to 8 are the red-then-green checks; they do not exist at HEAD)
blast-radius: tests/abtest-report.test.sh:79 docs/plans/antislop-vs-fable-evals/contracts/abt-u21.md:28 docs/plans/antislop-vs-fable-evals/contracts/abt-u21.md:30
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criteria 1, 8 and 9 pass at HEAD by design (the old test passes against the old code, no later commit exists, the tree is clean); criteria 2 to 7 are red at HEAD because finding_reasons, the new usage line, the named read error and the round commit do not exist.
cli: fill-log keeps its two required arguments (abt-u21 calls it with two) and takes the rows file as an optional third argument, default $ABT_RESULTS, else results.jsonl beside report.py. tickets keeps its four arguments and now refuses a non-empty OUT_DIR, so abt-u21 edit 8 must run on a directory that does not exist yet.
operator-rulings: a mixed verdict gets no ticket (the pre-registration files a ticket for each not-superior eval only); two or more bad rows get no ticket and no top-up advice (OD-12a: INCONCLUSIVE at every N); an Arm A stall is not a finding; the E1 blinded grade is not in the rows (make-row.py writes blind_grades as given, blind.py unseal prints the tally), so the E1 Result line points at blind.sh --unseal.
commit-message: fix(abt-u21a): one ticket predicate for Decision lines and ticket files, per-check tallies, fail-closed report commands (#588)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
