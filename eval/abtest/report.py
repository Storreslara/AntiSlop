#!/usr/bin/env python3
"""Turn a score report into the experiment-log lines and the eval-finding tickets.

  report.py fill-log SCORE_JSON EXPERIMENT_MD [ROWS_JSONL]
  report.py tickets SCORE_JSON ROWS_JSONL OUT_DIR

fill-log rewrites the Result and Decision lines of each `### E<n>: ... (<eval-id>)`
entry from the score report (the numbers are never retyped); Verdict stays pending
for the operator, who judges the prediction. ROWS_JSONL defaults to $ABT_RESULTS, else
results.jsonl beside this script. tickets writes OUT_DIR/<eval-id>.md for
every eval that is not superior, or whose Arm B stalled or let a defect escape.
Both commands decide "a ticket exists" with the one function finding_reasons, so the
Decision line and the ticket files cannot disagree. They stop with a non-zero exit,
and write nothing, when the score report and the rows disagree, when the eval ids of
the report and of the log differ, or when the report holds an outcome or verdict this
file has no wording for.
"""
import json
import os
import re
import sys

HYPOTHESIS = {
    "e01-ambiguous-tax": "H3 (spec grilling resolves ambiguity from repo evidence)",
    "e02-preview-mutation": "H1 (the Writer/Reviewer split catches defects the writer's own tests miss)",
    "e03-rename-query": "H1 and H2 (blast radius, caller checks, scope discipline)",
    "e04-search-injection": "H1, H6 and H2 (security lens, gates, scope discipline)",
    "e05-tags-feature": "H4 and H8 (decomposition and its overhead)",
}
LOOK_AT = {
    "e01-ambiguous-tax": "spec-master grilling and the ubiquitous-language prose mode: did it read CONTEXT.md (check the spec-master transcript for the grep-first recipe)? A stall means spec-master returned Open Questions instead of self-resolving from evidence: tune the 'if a fact can be found by exploring, look it up' rule in grilling.",
    "e02-preview-mutation": "the reviewer 'Refute, don't rubber-stamp' and 'Run the checks yourself' bullets: did the reviewer build its own adversarial input or only re-run the writer's tests? Also the tdd skill preload for lead-programmer (did the red test exercise rounding?).",
    "e03-rename-query": "explorer grep-fallback quality, the reviewer 'caller two hops away' bullet, and the dispatch contract's Pre-resolved context (were all callers, including the string-keyed one, pre-resolved?).",
    "e04-search-injection": "the reviewer security lens, the roast-work advisory (heavy units only), and protected-paths.sh, which matches Write/Edit only, not a Bash sed -i: an Arm B edit to auth.js through Bash is a concrete finding for the hook.",
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


def fmt(v):
    return "n/a" if v is None else f"{v:.2f}"


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
    o = v["overhead"]
    tally_b = ", ".join(f"{k} {n}" for k, n in v["status_tally_B"].items() if n)
    tally_a = ", ".join(f"{k} {n}" for k, n in v["status_tally_A"].items() if n)
    why = f"; outcome reason: {v['outcome_reason']}" if v.get("outcome_reason") else ""
    directional = f" (directional, p={fmt(v['fisher_p'])})" if v.get("directional") else ""
    blind = f"; {BLIND[e]}" if e in BLIND else ""
    return (f"run_pass A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']} ({v['outcome']}){why}; "
            f"Fisher p {fmt(v['fisher_p'])}; "
            f"R_tokens {fmt(o['R_tokens'])}, R_wall {fmt(o['R_wall'])}, R_turns {fmt(o['R_turns'])}; "
            f"B stalled-human {v['stalled_human_B']}; statuses A [{tally_a}], B [{tally_b}]; "
            f"checks passed per arm (of the usable rows) A [{check_tally(rows, 'A')}], B [{check_tally(rows, 'B')}]{blind}; "
            f"rows in eval/abtest/results.jsonl, verdict {v['verdict']}{directional}"
            f"{' (' + v['label'] + ')' if v['label'] else ''}")


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
    current = None
    seen = {}
    for i, line in enumerate(lines):
        m = ENTRY.match(line)
        if m:
            current = m.group(1)
        elif HEADING.match(line):
            current = None
        if current in report["evals"]:
            v = report["evals"][current]
            rows = by_eval.get(current, [])
            if line.startswith("- **Result**:"):
                lines[i] = f"- **Result**: {result_line(current, v, rows)}"
                seen[(current, "Result")] = seen.get((current, "Result"), 0) + 1
            elif line.startswith("- **Decision**:"):
                lines[i] = f"- **Decision**: {decision_line(current, v, rows)}"
                seen[(current, "Decision")] = seen.get((current, "Decision"), 0) + 1
    for e in report["evals"]:
        for key in ("Result", "Decision"):
            if seen.get((e, key), 0) != 1:
                die(f"the log entry for {e} must hold exactly one '- **{key}**:' line, found {seen.get((e, key), 0)}")
    with open(md_path, "w") as f:
        f.write("\n".join(lines))
    print(f"fill-log: filled {len(report['evals'])} entries")
    return 0


def tickets(score_path, rows_path, out_dir):
    report = load_json(score_path)
    by_eval = usable_rows(report, load_rows(rows_path))
    if os.path.exists(out_dir) and (not os.path.isdir(out_dir) or os.listdir(out_dir)):
        die(f"{out_dir} exists and is not an empty directory; remove it so no stale ticket survives")
    planned = {}
    for eval_id, v in report["evals"].items():
        rs = by_eval.get(eval_id, [])
        if needs_ticket(v, rs):
            planned[eval_id] = (v, rs, decision_line(eval_id, v, rs), finding_reasons(v, rs))
    os.makedirs(out_dir, exist_ok=True)
    for eval_id, (v, rs, decision, reasons) in planned.items():
        failed = []
        for r in rs:
            for c in r["checks"]:
                if not c["pass"]:
                    failed.append(f"- {r['run_id']}: {c['id']} ({c['kind']}) cmd: {c['cmd']}")
        streams = [f"- {r['run_id']}: {r['artifacts']['stream']}" for r in rs if r["arm"] == "B"]
        body = [f"[eval-finding] {eval_id}: {v['verdict']}", "",
                f"Eval: {eval_id}. Hypothesis: {HYPOTHESIS.get(eval_id, 'see the design')}.",
                "Why a ticket: " + "; ".join(reasons) + ".",
                f"Result: {result_line(eval_id, v, rs)}",
                f"Decision: {decision}", "",
                "Rows: " + ", ".join(v["run_ids"]), "", "Failed checks (verbatim):"]
        body += failed or ["- none"]
        body += ["", "Where to look (design section 3):", LOOK_AT.get(eval_id, "see the design"), "",
                 "Arm B transcripts:"] + (streams or ["- none"]) + [""]
        with open(os.path.join(out_dir, f"{eval_id}.md"), "w") as f:
            f.write("\n".join(body))
    print(f"tickets: wrote {len(planned)}")
    return 0


def main(argv):
    if len(argv) in (3, 4) and argv[0] == "fill-log":
        return fill_log(*argv[1:])
    if len(argv) == 4 and argv[0] == "tickets":
        return tickets(argv[1], argv[2], argv[3])
    print("usage: report.py fill-log SCORE_JSON EXPERIMENT_MD [ROWS_JSONL] | tickets SCORE_JSON ROWS_JSONL OUT_DIR", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
