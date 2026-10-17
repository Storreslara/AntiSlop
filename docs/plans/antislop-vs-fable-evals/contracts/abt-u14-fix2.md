Unit: abt-u14

## Objective
Fix round 2 of 3 for the abt-u14 FAIL (fix-of 2026-10-17T02:00:10Z). eval/abtest/score.py counts the rows dropped for another model_policy, filters the usage-limit tally by the same policy, stops with a named error when the policy matches no row, when the file has no row or no usable row, or cannot be read, and prints core_no_win_a (OD-7); the tests cover each. One commit.

## Retrieval
GitHub issues: `gh issue view 583 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/score.py` (anchor: line matching `def score(rows, policy):`)
- `tests/abtest-score.test.sh` (anchor: line matching `check "the scorer wrote the JSON report"`)

## Ordered edits
1. command: `test "$(grep -cF 'def p_decisive(p):' eval/abtest/score.py)" = 1 && test "$(grep -cF 'def is_count' eval/abtest/score.py)" = 0 && test "$(grep -cF 'tally()' tests/abtest-score.test.sh)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/score.py`
   anchor: line matching `with open(path) as f:`
   indent: 0
   before:
~~~~
    with open(path) as f:
        for n, line in enumerate(f, 1):
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError as e:
                    raise SystemExit(f"score: line {n} is not JSON: {e}")
~~~~
   after:
~~~~
    try:
        with open(path) as f:
            for n, line in enumerate(f, 1):
                line = line.strip()
                if line:
                    try:
                        rows.append(json.loads(line))
                    except json.JSONDecodeError as e:
                        raise SystemExit(f"score: line {n} is not JSON: {e}")
    except (OSError, UnicodeDecodeError) as e:
        raise SystemExit(f"score: cannot read {path}: {e}")
~~~~
3. file: `eval/abtest/score.py`
   anchor: line matching `limited = [r for r in rows if r["completion_status"] == "usage-limit"]`
   indent: 0
   before:
~~~~
    limited = [r for r in rows if r["completion_status"] == "usage-limit"]
    used = [r for r in rows if r["completion_status"] != "usage-limit" and r["model_policy"] == policy]
~~~~
   after:
~~~~
    in_policy = [r for r in rows if r["model_policy"] == policy]
    if rows and not in_policy:
        raise SystemExit(f"score: policy {policy!r} matches no row; policies present: "
                         f"{sorted({r['model_policy'] for r in rows})}")
    limited = [r for r in in_policy if r["completion_status"] == "usage-limit"]
    used = [r for r in in_policy if r["completion_status"] != "usage-limit"]
    if not used:
        raise SystemExit(f"score: no usable (non-usage-limit) row for policy {policy!r}; refusing to report an empty result")
~~~~
4. file: `eval/abtest/score.py`
   anchor: line matching `core = {e: (evals[e]["outcome"] != "WIN_A") for e in evals if e[:3] in ("e02", "e04", "e07")}`
   indent: 0
   insert-after:
~~~~
    e2e4 = [evals[e]["outcome"] != "WIN_A" for e in evals if e[:3] in ("e02", "e04")]
~~~~
5. file: `eval/abtest/score.py`
   anchor: line matching `"usage_limit_rows_excluded": len(limited),`
   indent: 0
   insert-after:
~~~~
        "rows_dropped_other_policy": len(rows) - len(in_policy),
~~~~
6. file: `eval/abtest/score.py`
   anchor: line matching `"core_no_win_a": core,`
   indent: 0
   insert-after:
~~~~
            "core_no_win_a_e2_e4": all(e2e4) if len(e2e4) == 2 else None,
~~~~
7. file: `eval/abtest/score.py`
   anchor: line matching `a = report["aggregate"]`
   indent: 0
   insert-after:
~~~~
    core = {True: "true", False: "false", None: "not evaluated (E2 or E4 absent)"}[a["core_no_win_a_e2_e4"]]
~~~~
8. file: `eval/abtest/score.py`
   anchor: line matching `lines += ["", f"Aggregate: {a['verdict']} ({a['reason']}).",`
   indent: 0
   insert-after:
~~~~
              f"core_no_win_a (no WIN_A on E2 and E4): {core}.",
~~~~
9. file: `eval/abtest/score.py`
   anchor: line matching `f"Usage-limit rows excluded from every count: {report['usage_limit_rows_excluded']}.",`
   indent: 0
   insert-after:
~~~~
              f"Rows dropped for another model_policy: {report['rows_dropped_other_policy']}.",
~~~~
10. file: `eval/abtest/score.py`
   anchor: line matching `return 1 if errors else 0`
   indent: 0
   insert-after:
~~~~
    if not rows:
        print(f"score: {a.rows} has no rows; refusing to score an empty results file", file=sys.stderr)
        return 2
~~~~
11. file: `tests/abtest-score.test.sh`
   anchor: line matching `python3 -I - "$T/rows.jsonl" << 'PYEOF'`
   indent: 0
   before:
~~~~
python3 -I - "$T/rows.jsonl" << 'PYEOF'
~~~~
   after:
~~~~
python3 -I - "$T/rows.jsonl" "$T/rows2.jsonl" << 'PYEOF'
~~~~
12. file: `tests/abtest-score.test.sh`
   anchor: line matching `# end of the N-rule scenarios`
   indent: 0
   insert-after:
~~~~
# Policy filter: uniform decides WIN_B; the shipped rows (6 + 5 = 11, one usage-limit) would be WIN_A.
sadd(rows, "x-policy", "fffff", "PPPPf")
sadd(rows, "x-policy", "PPPPfu", "fffff", policy="shipped")
# Second file: the core condition (no WIN_A on E2 and E4); E2 is WIN_A here.
rows2 = []
sadd(rows2, "e02-preview-mutation", "PPPPf", "Pffff")
sadd(rows2, "e04-search-injection", "PPfff", "PPfff")
~~~~
13. file: `tests/abtest-score.test.sh`
   anchor: line matching `with open(sys.argv[1], "w") as f:`
   indent: 0
   before:
~~~~
with open(sys.argv[1], "w") as f:
    for r in rows:
~~~~
   after:
~~~~
with open(sys.argv[1], "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
with open(sys.argv[2], "w") as f:
    for r in rows2:
~~~~
14. file: `tests/abtest-score.test.sh`
   anchor: line matching `check "the scorer wrote the JSON report" "$(test -s "$T/r.json" && echo yes || echo no)" "yes"`
   indent: 0
   insert-after:
~~~~
python3 "$SCORE" "$T/rows.jsonl" --policy shipped --out-json "$T/s.json" > /dev/null 2>&1
check "the scorer exits 0 for the shipped policy" "$?" "0"
python3 "$SCORE" "$T/rows2.jsonl" --out-json "$T/c.json" --out-md "$T/c.md" > /dev/null 2>&1
check "the scorer exits 0 on the core-condition rows" "$?" "0"
~~~~
15. file: `tests/abtest-score.test.sh`
   anchor: line matching `check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "24"`
   indent: 0
   before:
~~~~
check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "24"
~~~~
   after:
~~~~
check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "25"
~~~~
16. file: `tests/abtest-score.test.sh`
   anchor: line matching `# end of the N-rule and gap checks`
   indent: 0
   insert-after:
~~~~
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
~~~~
17. file: `tests/abtest-score.test.sh`
   anchor: line matching `say("a stopped scorer wrote no report", not os.path.exists(T + "/never.json"))`
   indent: 0
   insert-after:
~~~~
PYEOF
tally "$T/val.txt" "$?" "the fail-closed checker"
# end of the policy and fail-closed checks
~~~~
18. command: `git add eval/abtest/score.py tests/abtest-score.test.sh && git commit -m "fix(abt-u14): scorer counts rows dropped by the policy, stops on an unmatched policy or an empty file, prints core_no_win_a (#583)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
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
   mutation: skip edit 3; the policy rows FAIL, the script exits non-zero and the fragment is absent.
   proof: scratch mutation matrix after this round: 63 single-edit mutants of score.py apply; 39 are caught by this suite (exit non-zero); the other 24 (bad-row, quality-edge, R_tokens, label, stall-override and validator mutants) are caught by the rows of round 3 by design.
2. run: `python3 -I eval/abtest/score.py --validate-rows /dev/null`
   exit: 0
   stdout: `rows ok: 0`
   mutation: make --validate-rows reject an empty file; the exit is 1.
   proof: scratch run: in a copy of score.py, return 1 if errors or not rows else 0 at the end of the validate branch made this command exit 1.
3. run: `python3 -I eval/abtest/score.py /dev/null`
   exit: 2
   stdout: empty
   mutation: skip edit 10; the empty file scores as a clean report: exit 0 and a table prints.
4. run: `grep -c '^def ' eval/abtest/score.py`
   exit: 0
   stdout: `11`
   mutation: add one function to score.py; the count is 12.
   proof: scratch run: appending def extra(): pass to a copy printed 12.
5. run: `test -x eval/abtest/score.py && test -x tests/abtest-score.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: make one of the files non-executable; nothing prints and the exit is 1.
   proof: scratch run: chmod -x on a copy of either file made the command exit 1 with no output.
6. run: `bash tests/abtest-score.test.sh | grep -c '^ok   rows of another policy are counted as dropped$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the row FAILs and the count is 0.
7. run: `bash tests/abtest-score.test.sh | grep -c '^ok   the usage-limit tally follows the policy$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; the row FAILs and the count is 0.
8. run: `bash tests/abtest-score.test.sh | grep -c '^ok   a policy that matches no row stops the scorer, named$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; the row FAILs and the count is 0.
9. run: `bash tests/abtest-score.test.sh | grep -c '^ok   an empty results file stops the scorer, exit 2, named$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; the row FAILs and the count is 0.
10. run: `bash tests/abtest-score.test.sh | grep -c '^ok   a file with only usage-limit rows stops the scorer, named$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; the row FAILs and the count is 0.
11. run: `bash tests/abtest-score.test.sh | grep -c '^ok   a missing results file stops the scorer with a named error$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the row FAILs and the count is 0.
12. run: `bash tests/abtest-score.test.sh | grep -c '^ok   the core condition is false with a WIN_A on E2$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; the row FAILs and the count is 0.
13. run: `bash tests/abtest-score.test.sh | grep -c '^ok   the markdown prints the core condition false$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the row FAILs and the count is 0.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u14\): scorer counts' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/score.py tests/abtest-score.test.sh`
   mutation: skip edit 18; no round commit exists and the run prints no-unit-commit with exit 3.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u14\): scorer counts' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 18; no round commit exists and the exit is 3.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u14\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/score.py tests/abtest-score.test.sh | grep -vcE "^[a-z]+\(abt-u14\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
17. run: `git status --porcelain -- eval/abtest/score.py tests/abtest-score.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 18; the changed files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-score.test.sh (criteria 3 and 6 to 15 are red before the edits: the new rows FAIL against the round-1 scorer)
blast-radius: none
fix-of: 2026-10-17T02:00:10Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. The before payloads are exact copies of the committed text: copy, do not retype. A long insertion is several consecutive insert-after edits, each anchored on the last line of the previous part.
series: this is round 2 of 3 under one FAIL (contracts abt-u14-fix1, abt-u14-fix2, abt-u14-fix3, dispatched in that order, one commit each, Unit abt-u14 for all). The combined diff is about 46 KB, over the 30000-byte contract budget, so it is cut by feature; each round leaves the suite green. It depends on round 1 (abt-u14-fix1) having landed; edit 1 checks for it and STOPs otherwise.
why: the orchestrator folded in four review items: a misspelled --policy must not silently drop every eval, the usage-limit tally must use the same policy filter, OD-7 asks the report to print the core condition, and an empty or truncated results file must not read as a clean not-evaluated report.
rule: the policy filter keeps rows whose model_policy equals --policy; rows of other policies are counted (rows_dropped_other_policy) and printed. A file with rows but none of the policy exits 1 naming the policy and the policies present; a file with no row exits 2; a file with rows of the policy but all usage-limit exits 1. core_no_win_a_e2_e4 is true/false when both E2 and E4 are present, else null (the existing core_no_win_a dict stays).
callers: abt-u21a (report.py) reads evals and verdict only; the new keys are rows_dropped_other_policy and aggregate.core_no_win_a_e2_e4.
already-green: criteria 1, 2, 4, 5, 16 and 17 pass before the edits by design: 1 because the committed suite is green on the round-1 scorer (the new rows arrive with the edits), 2, 4 and 5 because the validate branch, the function count (this round adds no function) and the executable bits are untouched, 16 and 17 until the commit step runs; criteria 3 and 6 to 15 are the red-then-green checks.
no-real-claude: nothing here runs the claude CLI; the test builds its own synthetic rows in a temp directory.
commit-message: fix(abt-u14): scorer counts rows dropped by the policy, stops on an unmatched policy or an empty file, prints core_no_win_a (#583)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
