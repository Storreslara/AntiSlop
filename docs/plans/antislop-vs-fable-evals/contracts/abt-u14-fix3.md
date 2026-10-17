Unit: abt-u14

## Objective
Fix round 3 of 3 for the abt-u14 FAIL (fix-of 2026-10-17T02:00:10Z). The row validator rejects duplicate run_ids among non-usage-limit rows, a non-boolean run_pass, run_pass true on a non-complete row, malformed token, count, wall and turn fields, and tokens_total different from input + output + cache write (OD-5), each with a named error; the boundary rows kill the 13 mutants the reviewer found and about 60 more; the Fisher tables are pinned to exact fractions. One commit.

## Retrieval
GitHub issues: `gh issue view 583 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/score.py` (anchor: line matching `def validate_rows(rows):`)
- `tests/abtest-score.test.sh` (anchor: line matching `# end of the policy and fail-closed checks`)

## Ordered edits
1. command: `test "$(grep -cF 'def is_count' eval/abtest/score.py)" = 0 && test "$(grep -cF 'rows_dropped_other_policy' eval/abtest/score.py)" -ge 1 && test "$(grep -cF 'x-bad2-B' tests/abtest-score.test.sh)" = 0 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/score.py`
   anchor: line matching `from math import comb`
   indent: 0
   before:
~~~~
from math import comb
~~~~
   after:
~~~~
from math import comb, isfinite
~~~~
3. file: `eval/abtest/score.py`
   anchor: line matching `ALPHA = 0.10   # spec 4.4: Fisher exact p < 0.10 at N >= 10`
   indent: 0
   insert-after:
~~~~
COUNT_FIELDS = ("tokens_in", "tokens_out", "tokens_cache_write", "tokens_cache_read", "tokens_total",
                "defects_escaped", "out_of_scope_lines")
~~~~
4. file: `eval/abtest/score.py`
   anchor: line matching `return rows`
   indent: 0
   before:
~~~~
    return rows


~~~~
   after:
~~~~
    return rows


def is_count(v):
    return isinstance(v, int) and not isinstance(v, bool) and v >= 0


def is_measure(v):
    """None, or a finite non-negative number (wall_clock_ms, num_turns)."""
    return v is None or (isinstance(v, (int, float)) and not isinstance(v, bool) and isfinite(v) and v >= 0)


~~~~
5. file: `eval/abtest/score.py`
   anchor: line matching `errors = []`
   indent: 0
   insert-after:
~~~~
    seen = {}
~~~~
6. file: `eval/abtest/score.py`
   anchor: line matching `for i, r in enumerate(rows, 1):`
   indent: 0
   insert-after:
~~~~
        if not isinstance(r, dict):
            errors.append(f"row {i}: not a JSON object")
            continue
~~~~
7. file: `eval/abtest/score.py`
   anchor: line matching `if r.get("completion_status") not in STATUSES:`
   indent: 0
   before:
~~~~
        if r.get("completion_status") not in STATUSES:
            errors.append(f"row {i}: bad completion_status {r.get('completion_status')!r}")
~~~~
   after:
~~~~
        status = r.get("completion_status")
        if status not in STATUSES:
            errors.append(f"row {i}: bad completion_status {status!r}")
~~~~
8. file: `eval/abtest/score.py`
   anchor: line matching `errors.append(f"row {i}: bad arm {r.get('arm')!r}")`
   indent: 0
   insert-after:
~~~~
        for k in ("run_id", "eval_id", "model_policy"):
            if k in r and (not isinstance(r[k], str) or not r[k]):
                errors.append(f"row {i}: {k} must be a non-empty string, got {r[k]!r}")
        for k in COUNT_FIELDS:
            if k in r and not is_count(r[k]):
                errors.append(f"row {i}: {k} must be a non-negative integer, got {r[k]!r}")
        for k in ("wall_clock_ms", "num_turns"):
            if k in r and not is_measure(r[k]):
                errors.append(f"row {i}: {k} must be null or a finite non-negative number, got {r[k]!r}")
        if all(is_count(r.get(k)) for k in ("tokens_in", "tokens_out", "tokens_cache_write", "tokens_total")):
            if r["tokens_total"] != r["tokens_in"] + r["tokens_out"] + r["tokens_cache_write"]:
                errors.append(f"row {i}: tokens_total {r['tokens_total']} is not tokens_in + tokens_out + tokens_cache_write")
        if "run_pass" in r:
            if not isinstance(r["run_pass"], bool):
                errors.append(f"row {i}: run_pass must be a JSON boolean, got {r['run_pass']!r}")
            elif r["run_pass"] and status != "complete":
                errors.append(f"row {i}: run_pass is true on a {status!r} row")
        rid = r.get("run_id")
        if status != "usage-limit" and isinstance(rid, str):
            if rid in seen:
                errors.append(f"row {i}: duplicate run_id {rid!r} (first at row {seen[rid]})")
            else:
                seen[rid] = i
~~~~
9. file: `tests/abtest-score.test.sh`
   anchor: line matching `"duration_api_ms": None, "total_cost_usd": None, "model_usage": {}, "tokens_in": 1,`
   indent: 0
   before:
~~~~
        "duration_api_ms": None, "total_cost_usd": None, "model_usage": {}, "tokens_in": 1,
~~~~
   after:
~~~~
        "duration_api_ms": None, "total_cost_usd": None, "model_usage": {}, "tokens_in": tokens - 1,
~~~~
10. file: `tests/abtest-score.test.sh`
   anchor: line matching `sadd(rows2, "e04-search-injection", "PPfff", "PPfff")`
   indent: 0
   insert-after:
~~~~
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
~~~~
11. file: `tests/abtest-score.test.sh`
   anchor: line matching `check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "25"`
   indent: 0
   before:
~~~~
check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "25"
~~~~
   after:
~~~~
check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "46"
~~~~
12. file: `tests/abtest-score.test.sh`
   anchor: line matching `say("a stopped scorer wrote no report", not os.path.exists(T + "/never.json"))`
   indent: 0
   insert-after:
~~~~
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
~~~~
13. file: `tests/abtest-score.test.sh`
   anchor: line matching `# end of the policy and fail-closed checks`
   indent: 0
   insert-after:
~~~~
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
~~~~
14. file: `tests/abtest-score.test.sh`
   anchor: line matching `print(("ok   " if m.p_decisive(p) is want else "FAIL ") + f"p_decisive({p}) is {want} (p < 0.10)")`
   indent: 0
   insert-after:
~~~~
PYEOF
tally "$T/f.txt" "$?" "the Fisher checker"
~~~~
15. file: `tests/abtest-score.test.sh`
   anchor: line matching `head -n 1 "$T/rows.jsonl" | sed 's/"completion_status": "complete"/"completion_status": "budget"/; s/"completion_status":"complete"/"completion_status":"budget"/' > "$T/bad2.jsonl"`
   indent: 0
   before:
~~~~
head -n 1 "$T/rows.jsonl" | sed 's/"completion_status": "complete"/"completion_status": "budget"/; s/"completion_status":"complete"/"completion_status":"budget"/' > "$T/bad2.jsonl"
python3 "$SCORE" --validate-rows "$T/bad2.jsonl" > /dev/null; rc=$?
~~~~
   after:
~~~~
# The retired budget status: run_pass is set false so only the status can be the defect.
head -n 1 "$T/rows.jsonl" | sed 's/"completion_status": "complete"/"completion_status": "budget"/; s/"run_pass": true/"run_pass": false/' > "$T/bad2.jsonl"
python3 "$SCORE" --validate-rows "$T/bad2.jsonl" > "$T/vbad2.txt"; rc=$?
~~~~
16. file: `tests/abtest-score.test.sh`
   anchor: line matching `check "the retired budget status is rejected" "$rc" "1"`
   indent: 0
   insert-after:
~~~~
check "the retired budget status is named" "$(grep -c "bad completion_status 'budget'" "$T/vbad2.txt")" "1"
~~~~
17. command: `git add eval/abtest/score.py tests/abtest-score.test.sh && git commit -m "fix(abt-u14): validator rejects duplicate ids, non-boolean run_pass and bad counts; boundary rows and Fisher tables kill the mutants (#583)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
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
   mutation: skip edit 4; the validator rows FAIL, the script exits non-zero and the fragment is absent.
   proof: scratch mutation matrix on the finished change: all 78 single-edit mutants of score.py (N rule, gap rule, bad-row rule, Fisher gate, tail and direction, directional label, quality edge, R_tokens thresholds, label, stall override, policy filter, empty and unmatched input guards, validator checks) each made bash tests/abtest-score.test.sh exit non-zero; none survived.
2. run: `python3 -I eval/abtest/score.py --validate-rows /dev/null`
   exit: 0
   stdout: `rows ok: 0`
   mutation: make --validate-rows reject an empty file; the exit is 1.
   proof: scratch run: in a copy of score.py, return 1 if errors or not rows else 0 at the end of the validate branch made this command exit 1.
3. run: `python3 -I eval/abtest/score.py /dev/null`
   exit: 2
   stdout: empty
   mutation: make the empty-file guard return 0; the exit is 0.
   proof: scratch run: with return 2 changed to return 0 in the empty-file guard of a copy, this command exited 0.
4. run: `grep -c '^def ' eval/abtest/score.py`
   exit: 0
   stdout: `13`
   mutation: skip edit 4; is_count and is_measure are gone, so the count is 11.
5. run: `test -x eval/abtest/score.py && test -x tests/abtest-score.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: make one of the files non-executable; nothing prints and the exit is 1.
   proof: scratch run: chmod -x on a copy of either file made the command exit 1 with no output.
6. run: `bash tests/abtest-score.test.sh | grep -c '^ok   a string run_pass is rejected and named$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the row FAILs and the count is 0.
7. run: `bash tests/abtest-score.test.sh | grep -c '^ok   NaN tokens_in is rejected and named$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the row FAILs and the count is 0.
8. run: `bash tests/abtest-score.test.sh | grep -c '^ok   tokens_total off by one is rejected and named$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the row FAILs and the count is 0.
9. run: `bash tests/abtest-score.test.sh | grep -c '^ok   null defects_escaped is rejected and named$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the row FAILs and the count is 0.
10. run: `bash tests/abtest-score.test.sh | grep -c '^ok   a duplicate run_id is rejected$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the row FAILs and the count is 0.
11. run: `bash tests/abtest-score.test.sh | grep -c '^ok   repeated usage-limit rows with one run_id are accepted$'`
   exit: 0
   stdout: `1`
   mutation: drop the usage-limit exemption from the duplicate check in validate_rows; the row FAILs and the count is 0.
   proof: scratch run: the mutant if isinstance(rid, str): in place of if status != "usage-limit" and isinstance(rid, str): printed FAIL for this row (count 0).
12. run: `bash tests/abtest-score.test.sh | grep -c '^ok   R_tokens exactly 3.0 is mixed (> 3 is required for not-superior)$'`
   exit: 0
   stdout: `1`
   mutation: change r_tok > 3 to r_tok >= 3 in summarize_eval; the row FAILs and the count is 0.
   proof: scratch run: that mutant printed FAIL for this row (count 0).
13. run: `bash tests/abtest-score.test.sh | grep -c '^ok   two error rows in A make the eval INCONCLUSIVE$'`
   exit: 0
   stdout: `1`
   mutation: check the bad rows of arm B only in outcome(); the row FAILs and the count is 0.
   proof: scratch run: if bad(rows_b) >= 2: in place of the two-arm test printed FAIL for this row (count 0).
14. run: `bash tests/abtest-score.test.sh | grep -c '^ok   fisher 1/5 vs 5/5 = 1/21$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 14; the row is absent and the count is 0.
15. run: `bash tests/abtest-score.test.sh | grep -c '^ok   p_decisive(0.1) is False (p < 0.10)$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 14; the row is absent and the count is 0.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u14\): validator rejects' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/score.py tests/abtest-score.test.sh`
   mutation: skip edit 17; no round commit exists and the run prints no-unit-commit with exit 3.
17. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u14\): validator rejects' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 17; no round commit exists and the exit is 3.
18. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u14\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/score.py tests/abtest-score.test.sh | grep -vcE "^[a-z]+\(abt-u14\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
19. run: `git status --porcelain -- eval/abtest/score.py tests/abtest-score.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 17; the changed files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-score.test.sh (criteria 4 and 6 to 17 are red before the edits; the boundary rows are green on the round-2 scorer by design, see mutation-matrix)
blast-radius: none
fix-of: 2026-10-17T02:00:10Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. The before payloads are exact copies of the committed text: copy, do not retype. A long insertion is several consecutive insert-after edits, each anchored on the last line of the previous part.
series: this is round 3 of 3 under one FAIL (contracts abt-u14-fix1, abt-u14-fix2, abt-u14-fix3, dispatched in that order, one commit each, Unit abt-u14 for all). The combined diff is about 46 KB, over the 30000-byte contract budget, so it is cut by feature; each round leaves the suite green. It depends on round 2 (abt-u14-fix2) having landed; edit 1 checks for it and STOPs otherwise.
why: the first review found 13 mutants of score.py that the 21 original rows never killed (p<0.10 vs <=, the Fisher gate, the bad-row threshold and arm, R_tokens boundaries, the quality edge, the label, the policy filter, the Fisher tail, the bad-status list) and a ignored exit status; the validator also let a duplicate run_id, a string run_pass or a NaN token through to a TypeError.
rule: validate_rows names each defect as row N: ... and the run exits 1; a usage-limit row may repeat a run_id (resume re-runs it); tokens_total must equal tokens_in + tokens_out + tokens_cache_write (cache_read excluded, OD-5); wall_clock_ms and num_turns may be null (num_turns is null when the CLI reports none) but never NaN, infinite or negative.
mutation-matrix: the matrix script is not part of the repository; the proof line of criterion 1 states its result. Boundary rows pass on the round-2 code on purpose (they kill mutants, not bugs); only the validator rows are red before this round.
already-green: criteria 1, 2, 3, 5, 18 and 19 pass before the edits by design: the committed suite is green on the round-2 scorer, and the validate branch, the empty-file exit and the executable bits are untouched, and the clean-tree check lists nothing until the commit step; criteria 4 and 6 to 17 are red before the edits because their rows or functions are absent. Criteria 11 to 13 and most boundary rows guard code that is already correct; they exist to kill mutants (see mutation-matrix).
no-real-claude: nothing here runs the claude CLI; the test builds its own synthetic rows in a temp directory.
commit-message: fix(abt-u14): validator rejects duplicate ids, non-boolean run_pass and bad counts; boundary rows and Fisher tables kill the mutants (#583)
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
criterion 9: <FILL: exit and stdout>
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
criterion 13: <FILL: exit and stdout>
criterion 14: <FILL: exit and stdout>
criterion 15: <FILL: exit and stdout>
criterion 16: <FILL: exit and stdout>
criterion 17: <FILL: exit and stdout>
criterion 18: <FILL: exit and stdout>
criterion 19: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
