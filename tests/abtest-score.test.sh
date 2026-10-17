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
