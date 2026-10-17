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
# end of the N-rule scenarios
with open(sys.argv[1], "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
PYEOF

python3 "$SCORE" --validate-rows "$T/rows.jsonl" > "$T/v.txt" 2>&1
check "the synthetic rows validate" "$(tail -n1 "$T/v.txt" | cut -d: -f1)" "rows ok"

python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/r.json" --out-md "$T/r.md" > /dev/null 2> "$T/score.err"
check "the scorer exits 0 on valid rows" "$?" "0"
check "the scorer wrote the JSON report" "$(test -s "$T/r.json" && echo yes || echo no)" "yes"
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
check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "24"
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

head -n 1 "$T/rows.jsonl" | python3 -I -c 'import json,sys;d=json.loads(sys.stdin.read());del d["tokens_total"];print(json.dumps(d))' > "$T/bad.jsonl"
python3 "$SCORE" --validate-rows "$T/bad.jsonl" > "$T/vbad.txt"; rc=$?
check "a row missing a key is rejected" "$rc" "1"
check "the missing key is named" "$(grep -c 'missing tokens_total' "$T/vbad.txt")" "1"
head -n 1 "$T/rows.jsonl" | sed 's/"completion_status": "complete"/"completion_status": "budget"/; s/"completion_status":"complete"/"completion_status":"budget"/' > "$T/bad2.jsonl"
python3 "$SCORE" --validate-rows "$T/bad2.jsonl" > /dev/null; rc=$?
check "the retired budget status is rejected" "$rc" "1"

echo "abtest-score: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && [ "$pass" -gt 0 ] && echo "All abtest-score checks passed."
exit "$fail"
