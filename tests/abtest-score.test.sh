#!/usr/bin/env bash
# Tests eval/abtest/score.py: the per-eval verdict rules, usage-limit exclusion,
# the stall override, the N=10 Fisher rule, the aggregate line and the row
# validator, over synthetic rows built here.
set -u
export PYTHONDONTWRITEBYTECODE=1
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCORE="$REPO_ROOT/eval/abtest/score.py"
T="$(mktemp -d)" && [ -d "${T:-}" ] || { echo "mktemp -d failed" >&2; exit 2; }
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
# tally: run a python checker that prints "ok   name" / "FAIL name" lines; a crash or no output is a FAIL.
tally() {
  local out="$1" rc="$2" what="$3"
  cat "$out"
  pass=$((pass + $(grep -c '^ok   ' "$out")))
  fail=$((fail + $(grep -c '^FAIL ' "$out")))
  if [ "$rc" -ne 0 ] || [ "$(grep -c '^ok   ' "$out")" -eq 0 ]; then bad "$what crashed or printed nothing (rc $rc)"; fi
}

# Build the synthetic rows. One eval per scenario; a row is
# (arm, pass, status, defects, out_of_scope, tokens, wall, turns).
python3 -I - "$T/rows.jsonl" "$T/rows2.jsonl" << 'PYEOF'
import json, sys

def row(ev, arm, rep, passed, status="complete", defects=0, oos=0, tokens=100, wall=1000, turns=5):
    return {
        "schema_version": 1, "run_id": f"{ev}/{arm}/uniform/{rep}", "eval_id": ev, "arm": arm,
        "model_policy": "uniform", "rep": rep, "started_at": "t", "harness_commit": "h",
        "plugin_commit": None, "plugin_version": None, "cli_version": "c", "fixture_commit": "f",
        "fixture_profile": {}, "prompt_sha": "p", "persona_config_sha": None,
        "completion_status": status, "result_subtype": None, "wall_clock_ms": wall,
        "duration_api_ms": None, "total_cost_usd": None, "model_usage": {}, "tokens_in": tokens - 1,
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
# Short-spec builder (OD-12 rows): one letter per row. P complete+pass, f complete+fail, e error, t timeout,
# c turn-cap, s stalled-human, u usage-limit. over: {(arm, letter): row kwargs}; usage-limit rows get reps 90+.
LETTERS = {"P": (True, "complete"), "f": (False, "complete"), "e": (False, "error"), "t": (False, "timeout"),
           "c": (False, "turn-cap"), "s": (False, "stalled-human"), "u": (False, "usage-limit")}

def sadd(rows, ev, a, b, akw=None, bkw=None, policy="uniform", over=None):
    for arm, spec, kw in (("A", a, akw or {}), ("B", b, bkw or {})):
        for i, letter in enumerate(spec):
            passed, status = LETTERS[letter]
            rep = 90 + i if letter == "u" else i + 1
            k = dict(kw)
            k.update((over or {}).get((arm, letter), {}))
            r = row(ev, arm, rep, passed, status=status, **k)
            r["model_policy"], r["run_id"] = policy, f"{ev}/{arm}/{policy}/{rep}"
            rows.append(r)

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
# N rule. 3-vs-5: A has 3 usable rows (2 pass), B 5 (4 pass); A's 4th rep hit a usage limit and is excluded.
sadd(rows, "x-n-3v5", "PPfu", "PPPPf")
# Pilot N=1: both pass; A defects 1 / out-of-scope 3, B tokens 150 (R_tokens 1.5). Must never be superior.
sadd(rows, "x-n-pilot", "P", "P", dict(defects=1, oos=3), dict(tokens=150))
sadd(rows, "x-n-10v9", "PPPPPfffff", "PPPPPPPff")
sadd(rows, "x-n-5v6", "fffff", "PPPPPP")
sadd(rows, "x-n-6v5", "ffffff", "PPPPP")
sadd(rows, "x-n-6v6", "PPffff", "PPPPPf")
sadd(rows, "x-n-9v9", "PPfffffff", "PPPPPPPff")
sadd(rows, "x-n-5v4", "fffff", "PPPP")
# Gap rule at N=5: 0/5 vs 4/5 (gap 4), 2/5 vs 4/5 (gap 2 for B) and 4/5 vs 2/5 (gap 2 for A).
sadd(rows, "x-gap4", "fffff", "PPPPf")
sadd(rows, "x-gap2", "PPfff", "PPPPf")
sadd(rows, "x-wina-gap2", "PPPPf", "PPfff")
# Fisher at N=10: a 1-run gap (5/10 vs 6/10) is a TIE, p=1, not INCONCLUSIVE.
sadd(rows, "x-fisher-gap1", "PPPPPfffff", "PPPPPPffff")
# Policy filter: uniform decides WIN_B; the shipped rows (6 + 5 = 11, one usage-limit) would be WIN_A.
sadd(rows, "x-policy", "fffff", "PPPPf")
sadd(rows, "x-policy", "PPPPfu", "fffff", policy="shipped")
# Second file: the core condition (no WIN_A on E2 and E4); E2 is WIN_A here.
rows2 = []
sadd(rows2, "e02-preview-mutation", "PPPPf", "Pffff")
sadd(rows2, "e04-search-injection", "PPfff", "PPfff")
# Boundary rows that kill the surviving mutants of the first review. A14: A has defects 1 / out-of-scope 4, 100 tokens.
A14 = dict(defects=1, oos=4, tokens=100)
# Bad rows (turn-cap, timeout, error): exactly 2 in one arm is INCONCLUSIVE, 1 is not; each arm counts alone; stalled-human is not bad.
sadd(rows, "x-bad2-B", "fffff", "PPPee")
sadd(rows, "x-bad1-B", "fffff", "PPPPe")
sadd(rows, "x-bad2-A", "fffee", "PPPPP")
sadd(rows, "x-bad1-A", "ffffe", "PPPPP")
sadd(rows, "x-bad-split", "ffffe", "PPPPt")
sadd(rows, "x-bad-tc-to", "fffff", "PPPct")
sadd(rows, "x-stall2-A", "fffss", "PPPPP")
sadd(rows, "x-stall2-B", "fffff", "PPPss")
# 3-vs-3 passes. B 0/0 against A 1/4 is a quality edge; R_tokens is B tokens / 100.
for ev, tok in (("x-r2.0", 200), ("x-r2.01", 201), ("x-r3.0", 300), ("x-r3.01", 301)):
    sadd(rows, ev, "PPPff", "PPPff", A14, dict(defects=0, oos=0, tokens=tok))
# B wall 2500 vs A 1000 -> R_wall 2.5; B turns 10 vs A 5 -> R_turns 2.0; B tokens 200 -> R_tokens 2.0.
sadd(rows, "x-ratios", "PPPff", "PPPff", A14, dict(defects=0, oos=0, tokens=200, wall=2500, turns=10))
# R_tokens uses complete runs only: the stalled rows carry 1 token, the complete rows 100 (A) or 150 (B).
sadd(rows, "x-r-complete", "PPsss", "PPfff", A14, dict(defects=0, oos=0, tokens=150), over={("A", "s"): dict(tokens=1)})
sadd(rows, "x-r-complete-b", "PPfff", "PPsss", A14, dict(defects=0, oos=0, tokens=150), over={("B", "s"): dict(tokens=1)})
# Ratios use the median: B tokens 100,100,100,1000,1000 (median 100, mean 460) against A 100 each.
sadd(rows, "x-median", "PPPff", "PPPff", dict(tokens=100), dict(tokens=100), over={("B", "f"): dict(tokens=1000)})
# Quality edge needs a strictly lower median on BOTH metrics.
sadd(rows, "x-edge-defeq", "PPPff", "PPPff", A14, dict(defects=1, oos=0, tokens=150))
sadd(rows, "x-edge-ooseq", "PPPff", "PPPff", A14, dict(defects=0, oos=4, tokens=150))
sadd(rows, "x-edge-oosup", "PPPff", "PPPff", A14, dict(defects=0, oos=9, tokens=150))
sadd(rows, "x-edge-defup", "PPPff", "PPPff", A14, dict(defects=2, oos=0, tokens=150))
# A WIN_A with an edge and a cheap B is still not superior.
sadd(rows, "x-wina-edge", "PPPPf", "Pffff", A14, dict(defects=0, oos=0, tokens=150))
# Cost evals: a won or inconclusive cost eval carries no measured-overhead label.
sadd(rows, "e08-stable-cursor", "fffff", "PPPPf")
sadd(rows, "e09-typo", "P", "P")
# Provenance (OD-14): the rows of one arm share one value of each provenance field; null is one value; usage-limit rows are exempt.
def patch(ev, arm, rep, **kw):
    for r in rows:
        if r["eval_id"] == ev and r["arm"] == arm and r["rep"] == rep:
            r.update(kw)

def patch_arm(ev, arm, **kw):
    for r in rows:
        if r["eval_id"] == ev and r["arm"] == arm:
            r.update(kw)

sadd(rows, "y-prov-ok", "fffff", "PPPPf")
sadd(rows, "y-prov-harness", "fffff", "PPPPf")
patch("y-prov-harness", "A", 1, harness_commit="old")
sadd(rows, "y-prov-harness-b", "fffff", "PPPPf")
patch("y-prov-harness-b", "B", 3, harness_commit="old")
sadd(rows, "y-prov-plugin", "fffff", "PPPPf")
patch_arm("y-prov-plugin", "B", plugin_commit="p1")
patch("y-prov-plugin", "B", 1, plugin_commit="p0")
sadd(rows, "y-prov-plugin-null", "fffff", "PPPPf")
patch_arm("y-prov-plugin-null", "B", plugin_commit="p1")
patch("y-prov-plugin-null", "B", 2, plugin_commit=None)
sadd(rows, "y-prov-plugin-a", "fffff", "PPPPf")
patch("y-prov-plugin-a", "A", 2, plugin_commit="p9")
sadd(rows, "y-prov-prompt", "fffff", "PPPPf")
patch("y-prov-prompt", "A", 1, prompt_sha="q")
sadd(rows, "y-prov-fixture", "fffff", "PPPPf")
patch("y-prov-fixture", "B", 2, fixture_commit="g")
sadd(rows, "y-prov-two", "fffff", "PPPPf")
patch("y-prov-two", "A", 1, harness_commit="old", prompt_sha="q")
sadd(rows, "y-prov-stall", "fffff", "PPPPs")
patch("y-prov-stall", "B", 1, harness_commit="old")
# Survivors of the abt-u14 re-review: one arm absent, no complete Arm A run, a stall on an undecided outcome.
sadd(rows, "y-only-b", "", "PPPPP")
sadd(rows, "y-only-a", "PPPPP", "")
sadd(rows, "y-no-complete-a", "sssss", "fffff", dict(defects=1, oos=4), dict(defects=0, oos=0, tokens=150))
sadd(rows, "y-pilot-stall", "P", "s")
sadd(rows, "y-diff1-stall", "PPPff", "PPPPs")
# end of the N-rule scenarios
with open(sys.argv[1], "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
with open(sys.argv[2], "w") as f:
    for r in rows2:
        f.write(json.dumps(r) + "\n")
PYEOF

python3 "$SCORE" --validate-rows "$T/rows.jsonl" > "$T/v.txt" 2>&1
check "the synthetic rows validate" "$(tail -n1 "$T/v.txt" | cut -d: -f1)" "rows ok"

python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/r.json" --out-md "$T/r.md" > /dev/null 2> "$T/score.err"
check "the scorer exits 0 on valid rows" "$?" "0"
check "the scorer wrote the JSON report" "$(test -s "$T/r.json" && echo yes || echo no)" "yes"
python3 "$SCORE" "$T/rows.jsonl" --policy shipped --out-json "$T/s.json" > /dev/null 2>&1
check "the scorer exits 0 for the shipped policy" "$?" "0"
python3 "$SCORE" "$T/rows2.jsonl" --out-json "$T/c.json" --out-md "$T/c.md" > /dev/null 2>&1
check "the scorer exits 0 on the core-condition rows" "$?" "0"
rep() { python3 -I -c 'import json,sys;d=json.load(open(sys.argv[1]));print(eval(sys.argv[2]))' "$T/r.json" "$1"; }

check "a 3-run gap for B is WIN_B and superior" "$(rep 'd["evals"]["x-winb"]["outcome"], d["evals"]["x-winb"]["verdict"]')" "('WIN_B', 'superior')"
check "a 3-run gap for A is WIN_A and not superior" "$(rep 'd["evals"]["x-wina"]["outcome"], d["evals"]["x-wina"]["verdict"]')" "('WIN_A', 'not-superior')"
check "a tie with a quality edge and R_tokens 1.5 is superior" "$(rep 'd["evals"]["x-tie-edge"]["outcome"], d["evals"]["x-tie-edge"]["verdict"]')" "('TIE', 'superior')"
check "a tie with no quality edge is not superior" "$(rep 'd["evals"]["x-tie-noedge"]["verdict"]')" "not-superior"
check "a tie with R_tokens 4 is not superior" "$(rep 'd["evals"]["x-tie-costly"]["verdict"]')" "not-superior"
check "a tie with an edge and R_tokens 2.5 is mixed" "$(rep 'd["evals"]["x-tie-mid"]["verdict"]')" "mixed"
check "a 1-run gap is INCONCLUSIVE" "$(rep 'd["evals"]["x-diff1"]["outcome"], d["evals"]["x-diff1"]["verdict"]')" "('INCONCLUSIVE', 'inconclusive')"
check "two error rows make the eval INCONCLUSIVE" "$(rep 'd["evals"]["x-errors"]["outcome"]')" "INCONCLUSIVE"
check "a stalled-human row in arm B overrides a win" "$(rep 'd["evals"]["x-stall"]["outcome"], d["evals"]["x-stall"]["verdict"], d["evals"]["x-stall"]["stalled_human_B"]')" "('WIN_B', 'not-superior', 1)"
check "usage-limit rows are excluded from the counts" "$(rep 'd["evals"]["x-limit"]["n_A"], d["evals"]["x-limit"]["k_A"]')" "(5, 1)"
check "usage-limit rows are tallied" "$(rep 'd["usage_limit_rows_excluded"]')" "4"
check "N=10 uses Fisher: 2/10 vs 7/10 is WIN_B" "$(rep 'd["evals"]["x-fisher-win"]["outcome"]')" "WIN_B"
check "N=10 uses Fisher: 4/10 vs 6/10 is a TIE" "$(rep 'd["evals"]["x-fisher-tie"]["outcome"]')" "TIE"
check "a tied cost eval is labelled measured overhead" "$(rep 'd["evals"]["e05-tags-feature"]["label"], d["evals"]["e05-tags-feature"]["verdict"]')" "('measured-overhead', 'not-superior')"
check "the aggregate is not evaluated without all ten evals" "$(rep 'd["aggregate"]["verdict"]')" "not-evaluated"
check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "46"
check "the markdown states the cost basis" "$(grep -c 'dollar cost is not used' "$T/r.md")" "1"
# Verdict checks, group 1. Each want is a hand-computed value; the arithmetic is in the comment above it.
python3 -I - "$T" << 'PYEOF' > "$T/c.txt" 2>&1
import json, sys
T = sys.argv[1]
d = json.load(open(T + "/r.json"))
md = open(T + "/r.md").read().splitlines()
V = d["evals"]

def chk(name, ev, expr, want):
    got = eval(expr, {"v": V[ev], "d": d})
    print(("ok   " + name) if got == want else f"FAIL {name} (want {want!r}, got {got!r})")

def inc(name, ev, reason):
    chk(name, ev, '(v["outcome"], v["verdict"], v["outcome_reason"], v["directional"])', ("INCONCLUSIVE", "inconclusive", reason, False))

# N rule: fewer than 5 usable rows in an arm, unequal counts, or 6-9 rows are INCONCLUSIVE.
inc("3 vs 5 usable rows is INCONCLUSIVE, short N", "x-n-3v5", "short N: A=3 B=5")
chk("the 3-vs-5 counts exclude the usage-limit row", "x-n-3v5", '(v["n_A"], v["k_A"], v["n_B"], v["k_B"])', (3, 2, 5, 4))
# 2/3 vs 4/5: 6 successes in 8 runs, C(8,6)=28; tables x=1,2,3 weigh 3,15,10; observed 15 is the largest, so p=28/28=1.
chk("the Fisher p is still reported below N=10", "x-n-3v5", 'v["fisher_p"]', 1.0)
inc("a pilot (1 vs 1) never produces a verdict", "x-n-pilot", "short N: A=1 B=1")
inc("10 vs 9 rows is INCONCLUSIVE, unequal N", "x-n-10v9", "unequal N: A=10 B=9")
inc("5 vs 6 rows is INCONCLUSIVE, unequal N", "x-n-5v6", "unequal N: A=5 B=6")
inc("6 vs 5 rows is INCONCLUSIVE, unequal N", "x-n-6v5", "unequal N: A=6 B=5")
inc("6 vs 6 rows is a top-up in progress", "x-n-6v6", "top-up in progress: A=6 B=6, needs 10 per arm")
inc("9 vs 9 rows is a top-up in progress", "x-n-9v9", "top-up in progress: A=9 B=9, needs 10 per arm")
inc("5 vs 4 rows is INCONCLUSIVE, short N", "x-n-5v4", "short N: A=5 B=4")
# Gap rule at N=5. 1/5 vs 4/5: 5 successes in 10 runs, C(10,5)=252; tables x=0..5 weigh 1,25,100,100,25,1; observed x=1 (25), p=(1+25+25+1)/252=0.2063.
chk("a 3-run gap at N=5 is WIN_B, superior, directional at p=0.21", "x-winb", '(v["outcome"], v["verdict"], v["directional"], round(v["fisher_p"], 4), v["outcome_rule"])', ("WIN_B", "superior", True, 0.2063, "gap"))
# 0/5 vs 4/5: 4 successes in 10 runs, C(10,4)=210; tables x=0..4 weigh 5,50,100,50,5; observed 5, p=(5+5)/210=1/21=0.0476.
chk("a 4-run gap at N=5 is WIN_B, superior, not directional at p=0.048", "x-gap4", '(v["outcome"], v["verdict"], v["directional"], round(v["fisher_p"], 4))', ("WIN_B", "superior", False, 0.0476))
# 2/5 vs 4/5: 6 successes in 10 runs, weights 0,5,50,100,50,5 of 210; observed x=2 (50), p=(5+50+50+5)/210=110/210=0.5238.
chk("a 2-run gap at N=5 is WIN_B, directional at p=0.52", "x-gap2", '(v["outcome"], v["verdict"], v["directional"], round(v["fisher_p"], 4))', ("WIN_B", "superior", True, 0.5238))
chk("a 2-run gap for A is WIN_A, not superior, not directional", "x-wina-gap2", '(v["outcome"], v["verdict"], v["directional"])', ("WIN_A", "not-superior", False))
chk("a 1-run gap at N=5 is INCONCLUSIVE", "x-diff1", '(v["outcome"], v["verdict"], v["outcome_reason"])', ("INCONCLUSIVE", "inconclusive", "1-run gap"))
# Fisher at N=10. 2/10 vs 7/10: p=293/4199=0.0698 < 0.10, WIN_B by Fisher and never directional. 4/10 vs 6/10: p=0.6563, TIE.
chk("N=10 uses Fisher: 2/10 vs 7/10 is WIN_B at p=0.0698", "x-fisher-win", '(v["outcome"], v["verdict"], v["directional"], round(v["fisher_p"], 4), v["outcome_rule"])', ("WIN_B", "superior", False, 0.0698, "fisher"))
chk("N=10 uses Fisher: 4/10 vs 6/10 is a TIE at p=0.6563", "x-fisher-tie", '(v["outcome"], round(v["fisher_p"], 4), v["outcome_rule"])', ("TIE", 0.6563, "fisher"))
chk("at N=10 a 1-run gap is a Fisher TIE with p=1, not INCONCLUSIVE", "x-fisher-gap1", '(v["outcome"], v["fisher_p"])', ("TIE", 1.0))
# A tie with an edge and R_tokens 1.5 is superior but not directional (no WIN) and carries no label (not a cost eval).
chk("a tied superior eval is not directional and has no label", "x-tie-edge", '(v["outcome"], v["verdict"], v["directional"], v["label"])', ("TIE", "superior", False, None))
# Markdown.
def mdrow(ev):
    return [l for l in md if l.startswith(f"| {ev} ")][0]
for name, ev, frag in (
    ("the markdown marks a directional win with its p", "x-winb", "| superior (directional, p=0.21) |"),
    ("the markdown shows a Fisher win plainly", "x-fisher-win", "| superior |"),
    ("the markdown shows a strong gap win plainly", "x-gap4", "| superior |"),
    ("the markdown shows the short-N reason", "x-n-3v5", "INCONCLUSIVE (short N: A=3 B=5)"),
    ("the markdown shows the Fisher p of a tie", "x-fisher-tie", "| 0.66 |"),
    ("the markdown shows the measured-overhead label", "e05-tags-feature", "not-superior (measured-overhead) |"),
):
    line = mdrow(ev)
    print(("ok   " + name) if frag in line else f"FAIL {name} (want {frag!r} in {line!r})")
text = "\n".join(md)
for name, frag in (
    ("the markdown states the cost basis", "dollar cost is not used"),
    ("the markdown prints the usage-limit count", "Usage-limit rows excluded from every count: 4."),
    ("the markdown states the directional rule", "marked directional (OD-12)"),
):
    print(("ok   " + name) if text.count(frag) == 1 else f"FAIL {name} (count {text.count(frag)})")
PYEOF
tally "$T/c.txt" "$?" "the verdict checker"
# end of the N-rule and gap checks
# Verdict checks, group 1b: the policy filter, the core condition and the dropped-row count.
python3 -I - "$T" << 'PYEOF' > "$T/c1b.txt" 2>&1
import json, sys
T = sys.argv[1]
d = json.load(open(T + "/r.json"))
md = open(T + "/r.md").read().splitlines()
V = d["evals"]

def chk(name, ev, expr, want):
    got = eval(expr, {"v": V[ev], "d": d})
    print(("ok   " + name) if got == want else f"FAIL {name} (want {want!r}, got {got!r})")

# Policy filter: uniform decides; the 11 shipped rows are dropped and counted; the usage-limit tally is the uniform one (1 in x-n-3v5 + 3 in x-limit).
chk("the policy filter keeps uniform rows only", "x-policy", '(v["outcome"], v["n_A"], v["n_B"])', ("WIN_B", 5, 5))
chk("rows of another policy are counted as dropped", "x-policy", 'd["rows_dropped_other_policy"]', 11)
chk("the usage-limit tally follows the policy", "x-policy", 'd["usage_limit_rows_excluded"]', 4)
chk("the aggregate is not evaluated without all ten evals", "x-policy", 'd["aggregate"]["verdict"]', "not-evaluated")
chk("the core condition is not evaluated without E2 and E4", "x-policy", 'd["aggregate"]["core_no_win_a_e2_e4"]', None)
text = "\n".join(md)
for name, frag in (
    ("the markdown prints the dropped-policy count", "Rows dropped for another model_policy: 11."),
    ("the markdown prints the core condition as not evaluated", "core_no_win_a (no WIN_A on E2 and E4): not evaluated (E2 or E4 absent)."),
):
    print(("ok   " + name) if text.count(frag) == 1 else f"FAIL {name} (count {text.count(frag)})")
# Shipped policy report: the shipped rows only, WIN_A (4/5 vs 0/5), and the one shipped usage-limit row counted.
s = json.load(open(T + "/s.json"))
got = (list(s["evals"]), s["evals"]["x-policy"]["outcome"], s["usage_limit_rows_excluded"])
print("ok   --policy shipped sees the shipped rows only" if got == (["x-policy"], "WIN_A", 1) else f"FAIL --policy shipped sees the shipped rows only (got {got!r})")
# Core condition: E2 is WIN_A (4/5 vs 1/5), E4 a tie -> false.
c = json.load(open(T + "/c.json"))
got = (c["aggregate"]["core_no_win_a_e2_e4"], c["evals"]["e02-preview-mutation"]["outcome"], c["evals"]["e04-search-injection"]["outcome"])
print("ok   the core condition is false with a WIN_A on E2" if got == (False, "WIN_A", "TIE") else f"FAIL the core condition is false with a WIN_A on E2 (got {got!r})")
print(("ok   " if "core_no_win_a (no WIN_A on E2 and E4): false." in open(T + "/c.md").read() else "FAIL ") + "the markdown prints the core condition false")
PYEOF
tally "$T/c1b.txt" "$?" "the policy checker"

# Fail-closed paths: an empty or unusable input must stop the scorer with a named error, never read as a clean report.
python3 -I - "$SCORE" "$T" << 'PYEOF' > "$T/val.txt" 2>&1
import json, os, subprocess, sys
score, T = sys.argv[1], sys.argv[2]
base = json.loads(open(T + "/rows.jsonl").readline())

def run(args):
    return subprocess.run([sys.executable, "-I", score] + args, capture_output=True, text=True)

def write(name, rows):
    with open(f"{T}/{name}", "w") as f:
        for r in rows:
            f.write(r if isinstance(r, str) else json.dumps(r))
            f.write("\n")
    return f"{T}/{name}"

def say(name, good, detail=""):
    print(("ok   " + name) if good else f"FAIL {name} ({detail})")

def mutated(stmt):
    d = json.loads(json.dumps(base))
    exec(stmt, {"d": d, "float": float})
    return d

r = run(["--validate-rows", write("empty.jsonl", [])])
say("--validate-rows accepts an empty file", r.returncode == 0 and r.stdout.strip() == "rows ok: 0", (r.returncode, r.stdout))
r = run([T + "/empty.jsonl", "--out-json", T + "/never.json"])
say("an empty results file stops the scorer, exit 2, named", r.returncode == 2 and "has no rows" in r.stderr and "Traceback" not in r.stderr, (r.returncode, r.stderr))
r = run([write("blank.jsonl", ["", "  "])])
say("a file of blank lines is empty too", r.returncode == 2 and "has no rows" in r.stderr, (r.returncode, r.stderr))
lonely = mutated("d['completion_status']='usage-limit'; d['run_pass']=False")
r = run([write("lonely.jsonl", [lonely])])
say("a file with only usage-limit rows stops the scorer, named", r.returncode == 1 and "no usable" in r.stderr, (r.returncode, r.stderr))
r = run([T + "/rows.jsonl", "--policy", "unifrom"])
say("a policy that matches no row stops the scorer, named", r.returncode == 1 and "matches no row" in r.stderr and "uniform" in r.stderr, (r.returncode, r.stderr))
r = run([write("junk.jsonl", ["{nope"])])
say("a non-JSON line stops the scorer", r.returncode != 0 and "is not JSON" in r.stderr, (r.returncode, r.stderr))
r = run([T + "/does-not-exist.jsonl"])
say("a missing results file stops the scorer with a named error", r.returncode != 0 and "cannot read" in r.stderr and "Traceback" not in r.stderr, (r.returncode, r.stderr))
say("a stopped scorer wrote no report", not os.path.exists(T + "/never.json"))
CASES = [
    ("a string run_pass", "d['run_pass']='true'", "run_pass must be a JSON boolean"),
    ("a numeric run_pass", "d['run_pass']=1", "run_pass must be a JSON boolean"),
    ("run_pass true on an error row", "d['completion_status']='error'; d['run_pass']=True", "run_pass is true on a 'error' row"),
    ("NaN tokens_in", "d['tokens_in']=float('nan')", "tokens_in must be a non-negative integer"),
    ("negative tokens_out", "d['tokens_out']=-5", "tokens_out must be a non-negative integer"),
    ("fractional tokens_cache_write", "d['tokens_cache_write']=1.5", "tokens_cache_write must be a non-negative integer"),
    ("boolean tokens_total", "d['tokens_total']=True", "tokens_total must be a non-negative integer"),
    ("string tokens_cache_read", "d['tokens_cache_read']='5'", "tokens_cache_read must be a non-negative integer"),
    ("tokens_total off by one", "d['tokens_total']=d['tokens_total']+1", "is not tokens_in + tokens_out + tokens_cache_write"),
    ("null defects_escaped", "d['defects_escaped']=None", "defects_escaped must be a non-negative integer"),
    ("null out_of_scope_lines", "d['out_of_scope_lines']=None", "out_of_scope_lines must be a non-negative integer"),
    ("negative wall_clock_ms", "d['wall_clock_ms']=-1", "wall_clock_ms must be null or a finite non-negative number"),
    ("NaN num_turns", "d['num_turns']=float('nan')", "num_turns must be null or a finite non-negative number"),
    ("infinite num_turns", "d['num_turns']=float('inf')", "num_turns must be null or a finite non-negative number"),
    ("an unknown arm", "d['arm']='C'", "bad arm 'C'"),
    ("numeric eval_id", "d['eval_id']=7", "eval_id must be a non-empty string"),
    ("empty model_policy", "d['model_policy']=''", "model_policy must be a non-empty string"),
]
for name, stmt, frag in CASES:
    f = write("v.jsonl", [mutated(stmt)])
    r = run(["--validate-rows", f])
    say(f"{name} is rejected and named", r.returncode == 1 and frag in r.stdout and "Traceback" not in r.stderr, (r.returncode, r.stdout, r.stderr[-200:]))
    r = run([f])
    say(f"{name} stops the scoring path with exit 1, no traceback", r.returncode == 1 and frag in r.stderr and "Traceback" not in r.stderr, (r.returncode, r.stderr[-200:]))
r = run(["--validate-rows", write("dup.jsonl", [base, base])])
say("a duplicate run_id is rejected", r.returncode == 1 and "duplicate run_id" in r.stdout, (r.returncode, r.stdout))
lim = mutated("d['completion_status']='usage-limit'; d['run_pass']=False")
r = run(["--validate-rows", write("lim.jsonl", [lim, lim])])
say("repeated usage-limit rows with one run_id are accepted", r.returncode == 0 and "rows ok: 2" in r.stdout, (r.returncode, r.stdout))
r = run(["--validate-rows", write("res.jsonl", [lim, base])])
say("a usage-limit row followed by its resumed complete row is accepted", r.returncode == 0 and "rows ok: 2" in r.stdout, (r.returncode, r.stdout))
r = run(["--validate-rows", write("arr.jsonl", ["[1, 2]"])])
say("a non-object line is rejected", r.returncode == 1 and "not a JSON object" in r.stdout, (r.returncode, r.stdout))
PYEOF
tally "$T/val.txt" "$?" "the fail-closed checker"
# end of the policy and fail-closed checks
# Verdict checks, group 2: the boundary rows.
python3 -I - "$T" << 'PYEOF' > "$T/c2.txt" 2>&1
import json, sys
d = json.load(open(sys.argv[1] + "/r.json"))
V = d["evals"]

def chk(name, ev, expr, want):
    got = eval(expr, {"v": V[ev], "d": d})
    print(("ok   " + name) if got == want else f"FAIL {name} (want {want!r}, got {got!r})")

BADR = "two or more turn-cap, timeout or error rows"
def inc(name, ev):
    chk(name, ev, '(v["outcome"], v["verdict"], v["outcome_reason"])', ("INCONCLUSIVE", "inconclusive", BADR))

def win(name, ev):
    chk(name, ev, '(v["outcome"], v["verdict"])', ("WIN_B", "superior"))

# Bad rows: gap 3 or more in every case, so only the bad-row rule can make it INCONCLUSIVE.
inc("two error rows in B make the eval INCONCLUSIVE", "x-bad2-B")
win("one error row in B does not", "x-bad1-B")
inc("two error rows in A make the eval INCONCLUSIVE", "x-bad2-A")
win("one error row in A does not", "x-bad1-A")
win("one bad row in each arm does not (the count is per arm)", "x-bad-split")
inc("a turn-cap plus a timeout row make the eval INCONCLUSIVE", "x-bad-tc-to")
chk("two stalled-human rows in A are not bad rows", "x-stall2-A", '(v["outcome"], v["verdict"], v["stalled_human_B"])', ("WIN_B", "superior", 0))
# 0/5 vs 3/5: p=1/6=0.1667, so a WIN_B that stalled would be directional if the stall override did not clear it.
chk("two stalled-human rows in B are not bad rows but override the verdict", "x-stall2-B", '(v["outcome"], v["verdict"], v["stalled_human_B"], v["directional"])', ("WIN_B", "not-superior", 2, False))
# R_tokens = median(B) / median(A) with A at 100: 200 -> 2.0, 201 -> 2.01, 300 -> 3.0, 301 -> 3.01.
chk("R_tokens exactly 2.0 is superior (<= 2)", "x-r2.0", '(v["overhead"]["R_tokens"], v["verdict"])', (2.0, "superior"))
chk("R_tokens 2.01 is mixed", "x-r2.01", 'v["verdict"]', "mixed")
chk("R_tokens exactly 3.0 is mixed (> 3 is required for not-superior)", "x-r3.0", '(v["overhead"]["R_tokens"], v["verdict"])', (3.0, "mixed"))
chk("R_tokens 3.01 is not superior", "x-r3.01", 'v["verdict"]', "not-superior")
chk("R_wall 2.5, R_turns 2.0 and the min-max ranges", "x-ratios", '(v["overhead"]["R_wall"], v["overhead"]["R_turns"], v["overhead"]["R_tokens_range_A"], v["overhead"]["R_tokens_range_B"])', (2.5, 2.0, [100, 100], [200, 200]))
# A: complete rows 100 (median 100), stalled rows 1 (median of all five rows would be 1); B 150 -> 1.5, not 150.
chk("R_tokens counts complete runs only (arm A)", "x-r-complete", '(v["overhead"]["R_tokens"], v["verdict"])', (1.5, "superior"))
chk("R_tokens counts complete runs only (arm B)", "x-r-complete-b", 'v["overhead"]["R_tokens"]', 1.5)
chk("ratios use the median, not the mean", "x-median", '(v["overhead"]["R_tokens"], v["overhead"]["R_tokens_range_B"])', (1.0, [100, 1000]))
# Quality edge: defects and out-of-scope medians must both be strictly lower in B.
chk("an edge needs both medians strictly lower", "x-tie-edge", 'v["quality"]["edge"]', True)
chk("equal defect medians are no edge", "x-edge-defeq", '(v["quality"]["edge"], v["verdict"])', (False, "not-superior"))
chk("equal out-of-scope medians are no edge", "x-edge-ooseq", '(v["quality"]["edge"], v["verdict"])', (False, "not-superior"))
chk("lower defects with higher out-of-scope is no edge", "x-edge-oosup", '(v["quality"]["edge"], v["verdict"])', (False, "not-superior"))
chk("higher defects with lower out-of-scope is no edge", "x-edge-defup", '(v["quality"]["edge"], v["verdict"])', (False, "not-superior"))
chk("a WIN_A is never superior, even with an edge and a cheap B", "x-wina-edge", '(v["outcome"], v["quality"]["edge"], v["overhead"]["R_tokens"], v["verdict"])', ("WIN_A", True, 1.5, "not-superior"))
# Labels: only a tied cost eval is measured overhead.
chk("a won cost eval carries no label", "e08-stable-cursor", '(v["outcome"], v["label"])', ("WIN_B", None))
chk("an inconclusive cost eval carries no label", "e09-typo", '(v["outcome"], v["label"])', ("INCONCLUSIVE", None))
PYEOF
tally "$T/c2.txt" "$?" "the boundary checker"

# Fisher: exact fractions on 20 tables. Each is (k_A, n_A, k_B, n_B, p). Arithmetic for two of them:
# 5/5 vs 1/5: 6 successes in 10 runs, C(10,6)=210; table x (A successes) weighs C(5,x)C(5,6-x) = 0,5,50,100,50,5 for x=0..5;
#   the observed x=5 weighs 5, and x=1 also 5, so p=(5+5)/210=1/21 (the design's 0.024 counts one tail only).
# 5/10 vs 5/10: no table is likelier than the central one at 10 successes in 20 runs, so p=1.
python3 -I - "$SCORE" << 'PYEOF' > "$T/f.txt" 2>&1
import importlib.util, sys
sys.dont_write_bytecode = True
from fractions import Fraction as F
spec = importlib.util.spec_from_file_location("score", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
TABLES = [
    (1, 5, 5, 5, F(1, 21)), (5, 5, 1, 5, F(1, 21)), (0, 5, 4, 5, F(1, 21)), (4, 5, 0, 5, F(1, 21)),
    (2, 5, 5, 5, F(1, 6)), (0, 5, 3, 5, F(1, 6)), (3, 5, 5, 5, F(4, 9)), (0, 5, 2, 5, F(4, 9)),
    (1, 5, 4, 5, F(13, 63)), (2, 5, 4, 5, F(11, 21)), (1, 5, 3, 5, F(11, 21)), (0, 5, 5, 5, F(1, 126)),
    (5, 10, 5, 10, F(1)), (2, 10, 7, 10, F(293, 4199)), (3, 10, 7, 10, F(8263, 46189)),
    (4, 10, 6, 10, F(30313, 46189)), (0, 10, 3, 10, F(4, 19)), (2, 3, 4, 5, F(1)),
    (5, 10, 6, 10, F(1)), (4, 10, 0, 10, F(28, 323)),
]
assert len(TABLES) == 20
for ka, na, kb, nb, want in TABLES:
    got = m.fisher_two_sided(ka, na, kb, nb)
    good = abs(got - float(want)) < 1e-12
    print(("ok   " if good else "FAIL ") + f"fisher {ka}/{na} vs {kb}/{nb} = {want}" + ("" if good else f" (got {got!r})"))
for p, want in ((0.0999, True), (0.10, False), (0.1001, False), (0.0, True)):
    print(("ok   " if m.p_decisive(p) is want else "FAIL ") + f"p_decisive({p}) is {want} (p < 0.10)")
PYEOF
tally "$T/f.txt" "$?" "the Fisher checker"

head -n 1 "$T/rows.jsonl" | python3 -I -c 'import json,sys;d=json.loads(sys.stdin.read());del d["tokens_total"];print(json.dumps(d))' > "$T/bad.jsonl"
python3 "$SCORE" --validate-rows "$T/bad.jsonl" > "$T/vbad.txt"; rc=$?
check "a row missing a key is rejected" "$rc" "1"
check "the missing key is named" "$(grep -c 'missing tokens_total' "$T/vbad.txt")" "1"
# The retired budget status: run_pass is set false so only the status can be the defect.
head -n 1 "$T/rows.jsonl" | sed 's/"completion_status": "complete"/"completion_status": "budget"/; s/"run_pass": true/"run_pass": false/' > "$T/bad2.jsonl"
python3 "$SCORE" --validate-rows "$T/bad2.jsonl" > "$T/vbad2.txt"; rc=$?
check "the retired budget status is rejected" "$rc" "1"
check "the retired budget status is named" "$(grep -c "bad completion_status 'budget'" "$T/vbad2.txt")" "1"
# --- provenance, the re-review survivors and bytecode (abt-u14b) ---
check "the test exports PYTHONDONTWRITEBYTECODE" "${PYTHONDONTWRITEBYTECODE:-}" "1"
python3 -I - "$SCORE" "$T" << 'PYEOF' > "$T/c3.txt" 2>&1
import copy, json, subprocess, sys
SCORE, T = sys.argv[1:3]
d = json.load(open(T + "/r.json"))
md = open(T + "/r.md").read().splitlines()
V = d["evals"]

def chk(name, got, want):
    print(("ok   " + name) if got == want else f"FAIL {name} (want {want!r}, got {got!r})")

def ev(name, eval_id, expr, want):
    chk(name, eval(expr, {"v": V[eval_id]}), want)

MIXED = '(v["outcome"], v["verdict"], v["outcome_reason"], v["outcome_rule"])'
def mixed(name, eval_id, fields, verdict="inconclusive"):
    ev(name, eval_id, MIXED, ("INCONCLUSIVE", verdict, "mixed provenance: " + fields, None))

ev("rows that share their provenance still decide", "y-prov-ok", '(v["outcome"], v["outcome_reason"])', ("WIN_B", None))
mixed("a stale harness commit in arm A is mixed provenance", "y-prov-harness", "harness_commit")
mixed("a stale harness commit in arm B is mixed provenance", "y-prov-harness-b", "harness_commit")
mixed("a stale plugin commit in arm B is mixed provenance", "y-prov-plugin", "plugin_commit")
mixed("a null plugin commit next to a real one is mixed provenance", "y-prov-plugin-null", "plugin_commit")
mixed("a plugin commit on one arm A row is mixed provenance", "y-prov-plugin-a", "plugin_commit")
mixed("a different prompt hash is mixed provenance", "y-prov-prompt", "prompt_sha")
mixed("a different fixture commit is mixed provenance", "y-prov-fixture", "fixture_commit")
mixed("two stale fields are both named, in field order", "y-prov-two", "harness_commit,prompt_sha")
mixed("mixed provenance does not lift a stall override", "y-prov-stall", "harness_commit", verdict="not-superior")
ev("mixed provenance keeps the pass counts", "y-prov-harness", '(v["k_A"], v["k_B"], v["n_A"], v["n_B"])', (0, 4, 5, 5))
chk("the markdown shows the mixed provenance reason", sum(1 for l in md if l.startswith("| y-prov-harness |") and "INCONCLUSIVE (mixed provenance: harness_commit)" in l), 1)
chk("the markdown shows a decided provenance control as decided", sum(1 for l in md if l.startswith("| y-prov-ok |") and "WIN_B" in l and "mixed" not in l), 1)

# The six survivors of the abt-u14 re-review.
ev("an eval with only arm B rows does not crash and is short N", "y-only-b", '(v["outcome"], v["outcome_reason"], v["verdict"], v["quality"]["edge"])', ("INCONCLUSIVE", "short N: A=0 B=5", "inconclusive", False))
ev("an eval with only arm A rows does not crash and is short N", "y-only-a", '(v["outcome"], v["outcome_reason"], v["verdict"], v["quality"]["edge"])', ("INCONCLUSIVE", "short N: A=5 B=0", "inconclusive", False))
ev("a tie with an edge and no complete arm A run is mixed, never superior", "y-no-complete-a", '(v["outcome"], v["overhead"]["R_tokens"], v["quality"]["edge"], v["verdict"])', ("TIE", None, True, "mixed"))
# OD-13: the stall override applies to an undecided outcome too; the outcome itself stays INCONCLUSIVE.
ev("a pilot with a stalled arm B row is not-superior while the outcome stays INCONCLUSIVE", "y-pilot-stall", '(v["outcome"], v["outcome_reason"], v["verdict"], v["stalled_human_B"])', ("INCONCLUSIVE", "short N: A=1 B=1", "not-superior", 1))
ev("a 1-run gap with a stalled arm B row is not-superior while the outcome stays INCONCLUSIVE", "y-diff1-stall", '(v["outcome"], v["outcome_reason"], v["verdict"])', ("INCONCLUSIVE", "1-run gap", "not-superior"))
ev("a pilot with no stall stays inconclusive", "x-n-pilot", '(v["outcome"], v["verdict"])', ("INCONCLUSIVE", "inconclusive"))

base = [json.loads(l) for l in open(T + "/rows.jsonl")]
def clone(src, new):
    out = []
    for r in base:
        if r["eval_id"] == src:
            c = copy.deepcopy(r)
            c["eval_id"] = new
            c["run_id"] = c["run_id"].replace(src, new, 1)
            out.append(c)
    return out

def write(name, rows):
    with open(T + "/" + name, "w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")

def run(name):
    p = subprocess.run([sys.executable, SCORE, T + "/" + name, "--out-json", T + "/" + name + ".json"], capture_output=True, text=True)
    rep = None
    try:
        rep = json.load(open(T + "/" + name + ".json"))
    except (OSError, ValueError):
        pass
    return p, rep

tie = "x-tie-noedge"
ul = clone("x-winb", "y-pu")
extra = copy.deepcopy(ul[0])
extra.update(rep=90, run_id="y-pu/A/uniform/90", completion_status="usage-limit", run_pass=False, harness_commit="old")
write("p-usage.jsonl", ul + [extra])
p, rep = run("p-usage.jsonl")
chk("a usage-limit row from another harness is exempt from the provenance rule", (p.returncode, rep["evals"]["y-pu"]["outcome"], rep["evals"]["y-pu"]["outcome_reason"], rep["evals"]["y-pu"]["n_A"], rep["usage_limit_rows_excluded"]), (0, "WIN_B", None, 5, 1))
write("p-cost.jsonl", clone(tie, "e08-stable-cursor") + clone(tie, "e09-typo") + clone(tie, "e05-tags-feature") + clone(tie, "y-plain-tie"))
p, rep = run("p-cost.jsonl")
chk("the cost-eval file scores", p.returncode, 0)
labels = {e: v["label"] for e, v in rep["evals"].items()} if rep else {}
chk("a tied e05, e08 and e09 carry the measured-overhead label, a plain tie none", labels,
    {"e05-tags-feature": "measured-overhead", "e08-stable-cursor": "measured-overhead", "e09-typo": "measured-overhead", "y-plain-tie": None})

write("p-e2.jsonl", clone(tie, "e02-preview-mutation"))
write("p-e4.jsonl", clone(tie, "e04-search-injection"))
write("p-both.jsonl", clone(tie, "e02-preview-mutation") + clone(tie, "e04-search-injection"))
for name, want in (("p-e2.jsonl", None), ("p-e4.jsonl", None), ("p-both.jsonl", True)):
    p, rep = run(name)
    chk(f"core_no_win_a_e2_e4 for {name}", (p.returncode, rep["aggregate"]["core_no_win_a_e2_e4"] if rep else "no report"), (0, want))

write("p-clash.jsonl", clone(tie, "e02-preview-mutation") + clone(tie, "e02-other"))
p, rep = run("p-clash.jsonl")
chk("two e02 ids stop the scorer with exit 1", p.returncode, 1)
chk("the clash is named on stderr", "share the prefix 'e02'" in p.stderr, True)
write("p-clash4.jsonl", clone(tie, "e04-search-injection") + clone(tie, "e04-other"))
p, rep = run("p-clash4.jsonl")
chk("two e04 ids stop the scorer with exit 1", (p.returncode, "share the prefix 'e04'" in p.stderr), (1, True))
write("p-clash7.jsonl", clone(tie, "e07-first") + clone(tie, "e07-second"))
p, rep = run("p-clash7.jsonl")
chk("two e07 ids stop the scorer with exit 1", (p.returncode, "share the prefix 'e07'" in p.stderr), (1, True))

cache = clone(tie, "y-cache")[:1]
cache[0]["tokens_cache_read"] = 7
write("p-cache.jsonl", cache)
p = subprocess.run([sys.executable, SCORE, "--validate-rows", T + "/p-cache.jsonl"], capture_output=True, text=True)
chk("tokens_cache_read is not part of tokens_total", (p.returncode, p.stdout.strip()), (0, "rows ok: 1"))
PYEOF
tally "$T/c3.txt" "$?" "the provenance checker"
check "the score test leaves no bytecode behind" "$(ls "$REPO_ROOT"/eval/abtest/__pycache__/score.* 2> /dev/null | wc -l | tr -d ' ')" "0"

echo "abtest-score: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && [ "$pass" -gt 0 ] && echo "All abtest-score checks passed."
exit "$fail"
