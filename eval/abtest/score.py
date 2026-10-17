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
MIN_N = 5      # usable rows per arm in the first pass; the gap rule applies only here
FULL_N = 10    # usable rows per arm after the top-up; Fisher decides from here
ALPHA = 0.10   # spec 4.4: Fisher exact p < 0.10 at N >= 10
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
    """Two-sided exact p-value for ka/na against kb/nb successes.

    Sums the probability of every table (same margins) no more likely than the
    observed one. Checked against exact fractions on 20 tables (tests/abtest-score.test.sh).
    Errata to design 2.5 (OD-12): 5/5 vs 1/5 is p=1/21=0.048 (not 0.024: with 6 successes in 10 runs the
    tables x=1..5 weigh 5,50,100,50,5 of 210, and x=1 and x=5 are the two no likelier than 5/210);
    a 3-run gap at 10 vs 10 is p between 0.2105 (0 vs 3) and 0.3698 (3 vs 6), not ~0.07; a 4-run gap
    is p between 0.0867 (0 vs 4) and 0.1789 (3 vs 7), not below 0.05.
    """
    total, k = na + nb, ka + kb

    def prob(x):
        return comb(na, x) * comb(nb, k - x) / comb(total, k)

    lo, hi = max(0, k - nb), min(na, k)
    observed = prob(ka)
    return sum(prob(x) for x in range(lo, hi + 1) if prob(x) <= observed * (1 + 1e-9))


def p_decisive(p):
    return p < ALPHA


def med(values):
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None


def ratio(b, a):
    if b is None or a is None or a == 0:
        return None
    return b / a


def outcome(rows_a, rows_b):
    """Returns (outcome, k_A, k_B, fisher_p, rule, reason).

    Pre-registered N: 5 usable (non-usage-limit) rows per arm decide by the
    2-run gap; 10 or more per arm, equal in both, decide by Fisher at p < 0.10
    (a 1-run gap is only INCONCLUSIVE at N=5, because the top-up is its cure).
    Fewer than 5 rows in either arm (a pilot, a run stopped by a usage limit), unequal
    counts, or 6-9 rows (a top-up in progress) are INCONCLUSIVE, never a verdict.
    The Fisher p is computed whenever both arms have a row, whatever the rule.
    """
    na, nb = len(rows_a), len(rows_b)
    ka = sum(1 for r in rows_a if r["run_pass"])
    kb = sum(1 for r in rows_b if r["run_pass"])
    p = fisher_two_sided(ka, na, kb, nb) if na and nb else None

    def inconclusive(reason):
        return "INCONCLUSIVE", ka, kb, p, None, reason

    if min(na, nb) < MIN_N:
        return inconclusive(f"short N: A={na} B={nb}")
    if na != nb:
        return inconclusive(f"unequal N: A={na} B={nb}")
    if na < FULL_N and na != MIN_N:
        return inconclusive(f"top-up in progress: A={na} B={nb}, needs {FULL_N} per arm")
    bad = lambda rows: sum(1 for r in rows if r["completion_status"] in BAD)
    if bad(rows_a) >= 2 or bad(rows_b) >= 2:
        return inconclusive("two or more turn-cap, timeout or error rows")
    if na >= FULL_N:
        if p_decisive(p):
            return ("WIN_B" if kb > ka else "WIN_A"), ka, kb, p, "fisher", None
        return "TIE", ka, kb, p, "fisher", None
    if abs(kb - ka) == 1:
        return inconclusive("1-run gap")
    if kb - ka >= 2:
        return "WIN_B", ka, kb, p, "gap", None
    if ka - kb >= 2:
        return "WIN_A", ka, kb, p, "gap", None
    return "TIE", ka, kb, p, "gap", None


def summarize_eval(eval_id, rows):
    ra = [r for r in rows if r["arm"] == "A"]
    rb = [r for r in rows if r["arm"] == "B"]
    out, ka, kb, p, rule, reason = outcome(ra, rb)
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
    # OD-12: a WIN_B decided by the 2-run gap whose Fisher p is not below ALPHA is only directional.
    directional = bool(verdict == "superior" and out == "WIN_B" and not p_decisive(p))
    tally = lambda rows: {s: sum(1 for r in rows if r["completion_status"] == s) for s in STATUSES if s != "usage-limit"}
    return {
        "n_A": len(ra), "n_B": len(rb), "k_A": ka, "k_B": kb, "fisher_p": p, "outcome": out,
        "outcome_rule": rule, "outcome_reason": reason, "directional": directional,
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
             "| eval | A pass | B pass | outcome | Fisher p | R_tokens | R_wall | R_turns | B stalls | verdict |",
             "|---|---|---|---|---|---|---|---|---|---|"]
    f = lambda v: "n/a" if v is None else f"{v:.2f}"
    for e, v in report["evals"].items():
        o = v["overhead"]
        outc = v["outcome"] + (f" ({v['outcome_reason']})" if v["outcome_reason"] else "")
        verd = v["verdict"] + (f" (directional, p={v['fisher_p']:.2f})" if v["directional"] else "")
        lines.append(f"| {e} | {v['k_A']}/{v['n_A']} | {v['k_B']}/{v['n_B']} | {outc} | {f(v['fisher_p'])} | "
                     f"{f(o['R_tokens'])} | {f(o['R_wall'])} | {f(o['R_turns'])} | {v['stalled_human_B']} | {verd}"
                     f"{' (' + v['label'] + ')' if v['label'] else ''} |")
    a = report["aggregate"]
    lines += ["", f"Aggregate: {a['verdict']} ({a['reason']}).",
              f"Usage-limit rows excluded from every count: {report['usage_limit_rows_excluded']}.",
              "Fisher p is the two-sided exact p-value, shown for every eval; a WIN_B decided by the 2-run gap at N=5 "
              "with p >= 0.10 is marked directional (OD-12).",
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
