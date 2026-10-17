#!/usr/bin/env python3
"""Per-eval verdicts and the aggregate line (spec 4.4-4.5, amended by the
operator decisions: tokens instead of dollars, usage-limit rows excluded,
no aggregate until all ten evals are present).

Usage:
  score.py ROWS_JSONL [--policy uniform] [--out-json FILE] [--out-md FILE]
  score.py --validate-rows ROWS_JSONL
"""
import argparse
import json
import statistics
import sys
from math import comb

STATUSES = ("complete", "stalled-human", "turn-cap", "timeout", "usage-limit", "error")
BAD = ("turn-cap", "timeout", "error")
REQUIRED = (
    "schema_version", "run_id", "eval_id", "arm", "model_policy", "rep", "started_at", "harness_commit",
    "plugin_commit", "plugin_version", "cli_version", "fixture_commit", "fixture_profile", "prompt_sha",
    "persona_config_sha", "completion_status", "result_subtype", "wall_clock_ms", "duration_api_ms",
    "total_cost_usd", "model_usage", "tokens_in", "tokens_out", "tokens_cache_write", "tokens_cache_read",
    "tokens_total", "num_turns", "subagent_spawns", "tool_calls", "human_interventions_required", "checks",
    "holdout_pass_rate", "defects_escaped", "out_of_scope_lines", "out_of_scope_files", "commits", "run_pass",
    "process", "blind_grades", "artifacts",
)
TEN = tuple(f"e{n:02d}" for n in range(1, 11))
COST_EVALS = ("e05-tags-feature", "e08-stable-cursor", "e09-typo")


def load_rows(path):
    rows = []
    with open(path) as f:
        for n, line in enumerate(f, 1):
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError as e:
                    raise SystemExit(f"score: line {n} is not JSON: {e}")
    return rows


def validate_rows(rows):
    errors = []
    for i, r in enumerate(rows, 1):
        missing = [k for k in REQUIRED if k not in r]
        if missing:
            errors.append(f"row {i}: missing {','.join(missing)}")
        if r.get("completion_status") not in STATUSES:
            errors.append(f"row {i}: bad completion_status {r.get('completion_status')!r}")
        if r.get("arm") not in ("A", "B"):
            errors.append(f"row {i}: bad arm {r.get('arm')!r}")
    return errors


def fisher_two_sided(ka, na, kb, nb):
    """Two-sided exact p-value for ka/na against kb/nb successes."""
    total, k = na + nb, ka + kb

    def prob(x):
        return comb(na, x) * comb(nb, k - x) / comb(total, k)

    lo, hi = max(0, k - nb), min(na, k)
    observed = prob(ka)
    return min(1.0, sum(prob(x) for x in range(lo, hi + 1) if prob(x) <= observed * (1 + 1e-9)))


def med(values):
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None


def ratio(b, a):
    if b is None or a is None or a == 0:
        return None
    return b / a


def outcome(rows_a, rows_b):
    ka = sum(1 for r in rows_a if r["run_pass"])
    kb = sum(1 for r in rows_b if r["run_pass"])
    if not rows_a or not rows_b:
        return "INCONCLUSIVE", ka, kb, None
    bad = lambda rows: sum(1 for r in rows if r["completion_status"] in BAD)
    if bad(rows_a) >= 2 or bad(rows_b) >= 2:
        return "INCONCLUSIVE", ka, kb, None
    if abs(kb - ka) == 1:
        return "INCONCLUSIVE", ka, kb, None
    if len(rows_a) >= 10 and len(rows_b) >= 10:
        p = fisher_two_sided(ka, len(rows_a), kb, len(rows_b))
        if p < 0.10:
            return ("WIN_B" if kb > ka else "WIN_A"), ka, kb, p
        return "TIE", ka, kb, p
    if kb - ka >= 2:
        return "WIN_B", ka, kb, None
    if ka - kb >= 2:
        return "WIN_A", ka, kb, None
    return "TIE", ka, kb, None


def summarize_eval(eval_id, rows):
    ra = [r for r in rows if r["arm"] == "A"]
    rb = [r for r in rows if r["arm"] == "B"]
    out, ka, kb, p = outcome(ra, rb)
    q = {
        "defects_median_A": med([r["defects_escaped"] for r in ra]),
        "defects_median_B": med([r["defects_escaped"] for r in rb]),
        "out_of_scope_median_A": med([r["out_of_scope_lines"] for r in ra]),
        "out_of_scope_median_B": med([r["out_of_scope_lines"] for r in rb]),
    }
    q["edge"] = bool(
        q["defects_median_A"] is not None and q["defects_median_B"] is not None
        and q["defects_median_B"] < q["defects_median_A"]
        and q["out_of_scope_median_B"] < q["out_of_scope_median_A"]
    )
    ca = [r for r in ra if r["completion_status"] == "complete"]
    cb = [r for r in rb if r["completion_status"] == "complete"]
    over = {}
    for name, key in (("R_tokens", "tokens_total"), ("R_wall", "wall_clock_ms"), ("R_turns", "num_turns")):
        va, vb = [r[key] for r in ca if r[key] is not None], [r[key] for r in cb if r[key] is not None]
        over[name] = ratio(med(vb), med(va))
        over[name + "_range_A"] = [min(va), max(va)] if va else None
        over[name + "_range_B"] = [min(vb), max(vb)] if vb else None
    stalled_b = sum(1 for r in rb if r["completion_status"] == "stalled-human")
    r_tok = over["R_tokens"]
    if stalled_b > 0 or out == "WIN_A":
        verdict = "not-superior"
    elif out == "INCONCLUSIVE":
        verdict = "inconclusive"
    elif out == "WIN_B":
        verdict = "superior"
    elif not q["edge"] or (r_tok is not None and r_tok > 3):
        verdict = "not-superior"
    elif r_tok is not None and r_tok <= 2:
        verdict = "superior"
    else:
        verdict = "mixed"
    label = "measured-overhead" if (out == "TIE" and eval_id in COST_EVALS) else None
    tally = lambda rows: {s: sum(1 for r in rows if r["completion_status"] == s) for s in STATUSES if s != "usage-limit"}
    return {
        "n_A": len(ra), "n_B": len(rb), "k_A": ka, "k_B": kb, "fisher_p": p, "outcome": out,
        "quality": q, "overhead": over, "stalled_human_B": stalled_b,
        "status_tally_A": tally(ra), "status_tally_B": tally(rb),
        "verdict": verdict, "label": label,
        "run_ids": sorted(r["run_id"] for r in rows),
    }


def score(rows, policy):
    limited = [r for r in rows if r["completion_status"] == "usage-limit"]
    used = [r for r in rows if r["completion_status"] != "usage-limit" and r["model_policy"] == policy]
    by_eval = {}
    for r in used:
        by_eval.setdefault(r["eval_id"], []).append(r)
    evals = {e: summarize_eval(e, rs) for e, rs in sorted(by_eval.items())}
    present = {e[:3] for e in evals}
    core = {e: (evals[e]["outcome"] != "WIN_A") for e in evals if e[:3] in ("e02", "e04", "e07")}
    return {
        "policy": policy,
        "usage_limit_rows_excluded": len(limited),
        "evals": evals,
        "aggregate": {
            "verdict": "not-evaluated" if present != set(TEN) else "mixed",
            "reason": "E6-E10 deferred" if present != set(TEN) else "the ten-eval aggregate rule is not implemented in this scorer",
            "evals_present": sorted(evals),
            "core_no_win_a": core,
        },
    }


def render_md(report):
    lines = [f"# AntiSlop vs bare Fable ({report['policy']} policy)", "",
             "| eval | A pass | B pass | outcome | R_tokens | R_wall | R_turns | B stalls | verdict |",
             "|---|---|---|---|---|---|---|---|---|"]
    f = lambda v: "n/a" if v is None else f"{v:.2f}"
    for e, v in report["evals"].items():
        o = v["overhead"]
        lines.append(f"| {e} | {v['k_A']}/{v['n_A']} | {v['k_B']}/{v['n_B']} | {v['outcome']} | {f(o['R_tokens'])} | "
                     f"{f(o['R_wall'])} | {f(o['R_turns'])} | {v['stalled_human_B']} | {v['verdict']}"
                     f"{' (' + v['label'] + ')' if v['label'] else ''} |")
    a = report["aggregate"]
    lines += ["", f"Aggregate: {a['verdict']} ({a['reason']}).",
              f"Usage-limit rows excluded from every count: {report['usage_limit_rows_excluded']}.",
              "Cost columns are tokens (input + output + cache write), turns and wall time; dollar cost is not used."]
    return "\n".join(lines) + "\n"


def main(argv):
    ap = argparse.ArgumentParser(prog="score.py")
    ap.add_argument("rows")
    ap.add_argument("--policy", default="uniform")
    ap.add_argument("--out-json")
    ap.add_argument("--out-md")
    ap.add_argument("--validate-rows", action="store_true")
    a = ap.parse_args(argv)
    rows = load_rows(a.rows)
    if a.validate_rows:
        errors = validate_rows(rows)
        for e in errors:
            print(e)
        print(f"rows {'invalid' if errors else 'ok'}: {len(rows)}")
        return 1 if errors else 0
    errors = validate_rows(rows)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    report = score(rows, a.policy)
    if a.out_json:
        with open(a.out_json, "w") as f:
            json.dump(report, f, indent=2, sort_keys=True)
            f.write("\n")
    md = render_md(report)
    if a.out_md:
        with open(a.out_md, "w") as f:
            f.write(md)
    sys.stdout.write(md)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
