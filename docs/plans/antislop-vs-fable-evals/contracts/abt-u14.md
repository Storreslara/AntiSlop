Unit: abt-u14

## Objective
eval/abtest/score.py computes per-eval verdicts (outcome WIN_B/WIN_A/TIE/INCONCLUSIVE, quality edge, R_tokens/R_wall/R_turns, stall override, usage-limit rows excluded) and an aggregate line that reads not-evaluated until all ten evals exist, writes a JSON report and a markdown table, and validates rows; tests/abtest-score.test.sh passes over synthetic rows. One commit.

## Retrieval
GitHub issues: `gh issue view 583 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/score.py` (anchor: new file)
- `tests/abtest-score.test.sh` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/score.py && test ! -e tests/abtest-score.test.sh && test -f eval/abtest/lib/make-row.py && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/score.py`
   anchor: new file
   indent: 0
   insert-after:
~~~~
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
~~~~
3. file: `eval/abtest/score.py`
   anchor: line matching `    return b / a`
   indent: 0
   insert-after:
~~~~


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
~~~~
4. file: `eval/abtest/score.py`
   anchor: line matching `        by_eval.setdefault(r["eval_id"], []).append(r)`
   indent: 0
   insert-after:
~~~~
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
~~~~
5. file: `tests/abtest-score.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Tests eval/abtest/score.py: the per-eval verdict rules, usage-limit exclusion,
# the stall override, the N=10 Fisher rule, the aggregate line and the row
# validator, over synthetic rows built here.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCORE="$REPO_ROOT/eval/abtest/score.py"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# Build the synthetic rows. One eval per scenario; a row is
# (arm, pass, status, defects, out_of_scope, tokens, wall, turns).
python3 -I - "$T/rows.jsonl" << 'PYEOF'
import json, sys

def row(ev, arm, rep, passed, status="complete", defects=0, oos=0, tokens=100, wall=1000, turns=5):
    return {
        "schema_version": 1, "run_id": f"{ev}/{arm}/uniform/{rep}", "eval_id": ev, "arm": arm,
        "model_policy": "uniform", "rep": rep, "started_at": "t", "harness_commit": "h",
        "plugin_commit": None, "plugin_version": None, "cli_version": "c", "fixture_commit": "f",
        "fixture_profile": {}, "prompt_sha": "p", "persona_config_sha": None,
        "completion_status": status, "result_subtype": None, "wall_clock_ms": wall,
        "duration_api_ms": None, "total_cost_usd": None, "model_usage": {}, "tokens_in": 1,
        "tokens_out": 1, "tokens_cache_write": 0, "tokens_cache_read": 0, "tokens_total": tokens,
        "num_turns": turns, "subagent_spawns": 0, "tool_calls": 0, "human_interventions_required": 0,
        "checks": [], "holdout_pass_rate": None, "defects_escaped": defects,
        "out_of_scope_lines": oos, "out_of_scope_files": 0, "commits": 1,
        "run_pass": passed and status == "complete", "process": {}, "blind_grades": {}, "artifacts": {},
    }

rows = []
def add(ev, a_pass, b_pass, a_kw=None, b_kw=None, n=5):
    for i in range(n):
        rows.append(row(ev, "A", i + 1, i < a_pass, **(a_kw or {})))
        rows.append(row(ev, "B", i + 1, i < b_pass, **(b_kw or {})))

add("x-winb", 1, 4)
add("x-wina", 4, 1)
add("x-tie-edge", 3, 3, dict(defects=1, oos=4, tokens=100), dict(defects=0, oos=0, tokens=150))
add("x-tie-noedge", 3, 3)
add("x-tie-costly", 3, 3, dict(defects=1, oos=4, tokens=100), dict(defects=0, oos=0, tokens=400))
add("x-tie-mid", 3, 3, dict(defects=1, oos=4, tokens=100), dict(defects=0, oos=0, tokens=250))
add("x-diff1", 3, 4)
add("x-errors", 1, 4)
for r in rows:
    if r["eval_id"] == "x-errors" and r["arm"] == "B" and r["rep"] <= 2:
        r["completion_status"], r["run_pass"] = "error", False
add("x-stall", 1, 5)
for r in rows:
    if r["eval_id"] == "x-stall" and r["arm"] == "B" and r["rep"] == 5:
        r["completion_status"], r["run_pass"] = "stalled-human", False
add("x-limit", 1, 4)
for i in range(3):
    rows.append(row("x-limit", "A", 90 + i, False, status="usage-limit"))
add("x-fisher-win", 2, 7, n=10)
add("x-fisher-tie", 4, 6, n=10)
add("e05-tags-feature", 3, 3, dict(tokens=100), dict(tokens=900))
with open(sys.argv[1], "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
PYEOF

python3 "$SCORE" --validate-rows "$T/rows.jsonl" > "$T/v.txt" 2>&1
check "the synthetic rows validate" "$(tail -n1 "$T/v.txt" | cut -d: -f1)" "rows ok"

python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/r.json" --out-md "$T/r.md" > /dev/null
rep() { python3 -I -c 'import json,sys;d=json.load(open(sys.argv[1]));print(eval(sys.argv[2]))' "$T/r.json" "$1"; }

check "a 3-run gap for B is WIN_B and superior" "$(rep 'd["evals"]["x-winb"]["outcome"], d["evals"]["x-winb"]["verdict"]')" "('WIN_B', 'superior')"
check "a 3-run gap for A is WIN_A and not superior" "$(rep 'd["evals"]["x-wina"]["outcome"], d["evals"]["x-wina"]["verdict"]')" "('WIN_A', 'not-superior')"
check "a tie with a quality edge and R_tokens 1.5 is superior" "$(rep 'd["evals"]["x-tie-edge"]["outcome"], d["evals"]["x-tie-edge"]["verdict"]')" "('TIE', 'superior')"
check "a tie with no quality edge is not superior" "$(rep 'd["evals"]["x-tie-noedge"]["verdict"]')" "not-superior"
check "a tie with R_tokens 4 is not superior" "$(rep 'd["evals"]["x-tie-costly"]["verdict"]')" "not-superior"
~~~~
6. file: `tests/abtest-score.test.sh`
   anchor: line matching `check "a tie with R_tokens 4 is not superior" "$(rep 'd["evals"]["x-tie-costly"]["verdict"]')" "not-superior"`
   indent: 0
   insert-after:
~~~~
check "a tie with an edge and R_tokens 2.5 is mixed" "$(rep 'd["evals"]["x-tie-mid"]["verdict"]')" "mixed"
check "a 1-run gap is INCONCLUSIVE" "$(rep 'd["evals"]["x-diff1"]["outcome"], d["evals"]["x-diff1"]["verdict"]')" "('INCONCLUSIVE', 'inconclusive')"
check "two error rows make the eval INCONCLUSIVE" "$(rep 'd["evals"]["x-errors"]["outcome"]')" "INCONCLUSIVE"
check "a stalled-human row in arm B overrides a win" "$(rep 'd["evals"]["x-stall"]["outcome"], d["evals"]["x-stall"]["verdict"], d["evals"]["x-stall"]["stalled_human_B"]')" "('WIN_B', 'not-superior', 1)"
check "usage-limit rows are excluded from the counts" "$(rep 'd["evals"]["x-limit"]["n_A"], d["evals"]["x-limit"]["k_A"]')" "(5, 1)"
check "usage-limit rows are tallied" "$(rep 'd["usage_limit_rows_excluded"]')" "3"
check "N=10 uses Fisher: 2/10 vs 7/10 is WIN_B" "$(rep 'd["evals"]["x-fisher-win"]["outcome"]')" "WIN_B"
check "N=10 uses Fisher: 4/10 vs 6/10 is a TIE" "$(rep 'd["evals"]["x-fisher-tie"]["outcome"]')" "TIE"
check "a tied cost eval is labelled measured overhead" "$(rep 'd["evals"]["e05-tags-feature"]["label"], d["evals"]["e05-tags-feature"]["verdict"]')" "('measured-overhead', 'not-superior')"
check "the aggregate is not evaluated without all ten evals" "$(rep 'd["aggregate"]["verdict"]')" "not-evaluated"
check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "12"
check "the markdown states the cost basis" "$(grep -c 'dollar cost is not used' "$T/r.md")" "1"

head -n 1 "$T/rows.jsonl" | python3 -I -c 'import json,sys;d=json.loads(sys.stdin.read());del d["tokens_total"];print(json.dumps(d))' > "$T/bad.jsonl"
python3 "$SCORE" --validate-rows "$T/bad.jsonl" > "$T/vbad.txt"; rc=$?
check "a row missing a key is rejected" "$rc" "1"
check "the missing key is named" "$(grep -c 'missing tokens_total' "$T/vbad.txt")" "1"
head -n 1 "$T/rows.jsonl" | sed 's/"completion_status": "complete"/"completion_status": "budget"/; s/"completion_status":"complete"/"completion_status":"budget"/' > "$T/bad2.jsonl"
python3 "$SCORE" --validate-rows "$T/bad2.jsonl" > /dev/null; rc=$?
check "the retired budget status is rejected" "$rc" "1"

echo "abtest-score: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-score checks passed."
exit "$fail"
~~~~
7. command: `chmod +x eval/abtest/score.py tests/abtest-score.test.sh`
   expect: 0
8. command: `git add eval/abtest/score.py tests/abtest-score.test.sh && git commit -m "feat(abt-u14): scorer with token overhead and usage-limit exclusion (#583)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/lib/` (units abt-u02 and abt-u03 own the stream summariser and the row assembler; the scorer only reads their output)
- `eval/abtest/run-matrix.sh`, `eval/abtest/arms/`, `eval/abtest/checks/`, `eval/abtest/fixtures/` (other units own them)
- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-score.test.sh`
   exit: 0
   stdout: `All abtest-score checks passed.`
   mutation: skip edit 4 (the last part of score.py, which holds main); the rows FAIL, the script exits non-zero and the fragment is absent.
2. run: `python3 -I eval/abtest/score.py --validate-rows /dev/null`
   exit: 0
   stdout: `rows ok: 0`
   mutation: skip edit 4; main is missing, nothing prints and the fragment is absent.
3. run: `grep -c '^def ' eval/abtest/score.py`
   exit: 0
   stdout: `10`
   mutation: skip edit 4; main and render_md are gone, so the count is lower.
4. run: `test -x eval/abtest/score.py && test -x tests/abtest-score.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 7; the files are not executable and nothing prints.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u14\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/score.py tests/abtest-score.test.sh`
   mutation: skip edit 8 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u14\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; no unit commit exists and the exit is 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u14\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/score.py tests/abtest-score.test.sh | grep -vcE "^[a-z]+\(abt-u14\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
8. run: `git status --porcelain -- eval/abtest/score.py tests/abtest-score.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-score.test.sh (criterion 1 is the red-then-green check; neither file exists at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 8 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
no-real-claude: nothing here runs the claude CLI; the test builds its own synthetic rows in a temp directory.
depends-on: abt-u03 must have landed (edit 1 checks for make-row.py and STOPs otherwise); the scorer reads rows of the shape make-row.py writes but imports nothing from it.
commit-message: feat(abt-u14): scorer with token overhead and usage-limit exclusion (#583)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u14 (#583)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
