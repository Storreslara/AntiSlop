#!/usr/bin/env python3
"""Turn a score report into the experiment-log lines and the eval-finding tickets.

  report.py fill-log SCORE_JSON EXPERIMENT_MD
  report.py tickets SCORE_JSON ROWS_JSONL OUT_DIR

fill-log rewrites the Result and Decision lines of each `### E<n>: ... (<eval-id>)`
entry from the score report (the numbers are never retyped); Verdict stays pending
for the operator, who judges the prediction. tickets writes OUT_DIR/<eval-id>.md for
every eval that is not superior, or whose Arm B stalled or let a defect escape.
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


def fmt(v):
    return "n/a" if v is None else f"{v:.2f}"


def result_line(e, v):
    o = v["overhead"]
    tally_b = ", ".join(f"{k} {n}" for k, n in v["status_tally_B"].items() if n)
    tally_a = ", ".join(f"{k} {n}" for k, n in v["status_tally_A"].items() if n)
    return (f"run_pass A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']} ({v['outcome']}); "
            f"R_tokens {fmt(o['R_tokens'])}, R_wall {fmt(o['R_wall'])}, R_turns {fmt(o['R_turns'])}; "
            f"B stalled-human {v['stalled_human_B']}; statuses A [{tally_a}], B [{tally_b}]; "
            f"rows in eval/abtest/results.jsonl, verdict {v['verdict']}"
            f"{' (' + v['label'] + ')' if v['label'] else ''}")


def decision_line(v):
    if v["verdict"] == "inconclusive":
        reason = str(v.get("outcome_reason") or "")
        if reason.startswith("mixed provenance"):
            return f"RERUN: the rows mix provenance ({reason}); repeat the stale rows with run-matrix.sh (OD-14), a top-up does not cure it"
        return "NEEDS MORE DATA: top up this eval to N=10 with run-matrix.sh --reps 10 --evals <eval-id>"
    if v["verdict"] == "superior":
        return "no action: recorded as a measured advantage"
    return "ticket filed under the eval-finding label (see the report); no change is shipped by this log"


def fill_log(score_path, md_path):
    report = json.load(open(score_path))
    lines = open(md_path).read().split("\n")
    current = None
    for i, line in enumerate(lines):
        m = re.match(r"### E\d+: .*\(([a-z0-9-]+)\)\s*$", line)
        if m:
            current = m.group(1)
        elif line.startswith("### "):
            current = None
        if current in report["evals"]:
            v = report["evals"][current]
            if line.startswith("- **Result**:"):
                lines[i] = f"- **Result**: {result_line(current, v)}"
            elif line.startswith("- **Decision**:"):
                lines[i] = f"- **Decision**: {decision_line(v)}"
    open(md_path, "w").write("\n".join(lines))
    return 0


def needs_ticket(v, rows):
    if v["verdict"] == "not-superior" or v["stalled_human_B"] > 0:
        return True
    return any(r["arm"] == "B" and r["defects_escaped"] > 0 for r in rows)


def tickets(score_path, rows_path, out_dir):
    report = json.load(open(score_path))
    rows = [json.loads(l) for l in open(rows_path) if l.strip()]
    os.makedirs(out_dir, exist_ok=True)
    written = 0
    for eval_id, v in report["evals"].items():
        rs = [r for r in rows if r["eval_id"] == eval_id and r["completion_status"] != "usage-limit"]
        if not needs_ticket(v, rs):
            continue
        failed = []
        for r in rs:
            for c in r["checks"]:
                if not c["pass"]:
                    failed.append(f"- {r['run_id']}: {c['id']} ({c['kind']}) cmd: {c['cmd']}")
        streams = [f"- {r['run_id']}: {r['artifacts']['stream']}" for r in rs if r["arm"] == "B"]
        body = [f"[eval-finding] {eval_id}: {v['verdict']}", "",
                f"Eval: {eval_id}. Hypothesis: {HYPOTHESIS.get(eval_id, 'see the design')}.",
                f"Outcome: {v['outcome']} (A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']}); {result_line(eval_id, v).split('; ', 1)[1]}", "",
                "Rows: " + ", ".join(v["run_ids"]), "", "Failed checks (verbatim):"]
        body += failed or ["- none"]
        body += ["", "Where to look (design section 3):", LOOK_AT.get(eval_id, "see the design"), "",
                 "Arm B transcripts:"] + (streams or ["- none"]) + [""]
        with open(os.path.join(out_dir, f"{eval_id}.md"), "w") as f:
            f.write("\n".join(body))
        written += 1
    print(f"tickets: wrote {written}")
    return 0


def main(argv):
    if len(argv) == 3 and argv[0] == "fill-log":
        return fill_log(argv[1], argv[2])
    if len(argv) == 4 and argv[0] == "tickets":
        return tickets(argv[1], argv[2], argv[3])
    print("usage: report.py fill-log SCORE_JSON EXPERIMENT_MD | tickets SCORE_JSON ROWS_JSONL OUT_DIR", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
