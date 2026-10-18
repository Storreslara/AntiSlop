Unit: abt-u21a

## Objective
Fix of the FAIL of 2026-10-17T22:50:08Z, round 3 of 5 (from the review of round 2). (a) The Decision table had no cell for a short, unequal or half-finished N when an arm already holds two or more turn-cap, timeout or error rows: score.py checks N first, so report.py said NEEDS MORE DATA although OD-12(a) keeps the outcome INCONCLUSIVE at every N. data_action now reads the bad-row counts from the status tallies and says NO MORE RUNS HELP in every such cell (a mixed-provenance RERUN gets the same fact appended). (b) Short-N advice reaches its target in one step. (c) The Result line names the rows file. (d) The directional note names the real gap. (e) An eval id is checked with fullmatch. (f) tests/abtest-report.test.sh pins all of it and the surviving mutants of round 2. One commit; rounds 4 and 5 add the walk and grid tests.

## Retrieval
GitHub issues: `gh issue view 588 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/report.py` (anchor: line matching `def data_action(eval_id, v):`)
- `tests/abtest-report.test.sh` (anchor: line matching `check "fill-log exits 0" "$rc" "0"`)

## Ordered edits
1. command: `git log --format=%s | grep -q "^fix(abt-u21a): pin the Decision table" && grep -q "def finding_reasons" eval/abtest/report.py && ! grep -q "def next_n" eval/abtest/report.py && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/report.py`
   anchor: line matching `if not EVAL_ID.match(eval_id):`
   indent: 0
   before:
~~~~
        if not EVAL_ID.match(eval_id):
~~~~
   after:
~~~~
        if not EVAL_ID.fullmatch(eval_id):
~~~~
3. file: `eval/abtest/report.py`
   anchor: line matching `def result_line(e, v, rows):`
   indent: 0
   before:
~~~~
def result_line(e, v, rows):
~~~~
   after:
~~~~
def result_line(e, v, rows, src):
~~~~
4. file: `eval/abtest/report.py`
   anchor: line matching `f"rows in eval/abtest/results.jsonl, verdict {v['verdict']}{directional}"`
   indent: 0
   before:
~~~~
            f"rows in eval/abtest/results.jsonl, verdict {v['verdict']}{directional}"
~~~~
   after:
~~~~
            f"rows in {src}, verdict {v['verdict']}{directional}"
~~~~
5. file: `eval/abtest/report.py`
   anchor: line matching `return bool(finding_reasons(v, rows))`
   indent: 0
   insert-after:
~~~~


BAD = ("turn-cap", "timeout", "error")


def bad_counts(v):
    """Turn-cap, timeout and error rows of Arm A and Arm B: the rows no top-up cures (OD-12)."""
    return tuple(sum(v["status_tally_" + arm].get(s, 0) for s in BAD) for arm in "AB")


def next_n(v):
    """The one run-matrix --reps target that cures a short, unequal or half-finished count."""
    top = max(v["n_A"], v["n_B"])
    return 5 if top <= 5 else (10 if top < 10 else top)
~~~~
6. file: `eval/abtest/report.py`
   anchor: line matching `"""What the operator does about an INCONCLUSIVE `
   indent: 0
   before:
~~~~
    """What the operator does about an INCONCLUSIVE outcome. One wording per outcome_reason class (OD-12, OD-14)."""
~~~~
   after:
~~~~
    """What the operator does about an INCONCLUSIVE outcome. One wording per outcome_reason class (OD-12, OD-14).
    score.py checks N before the bad rows, so its reason can name N while two bad rows already decide (OD-12)."""
~~~~
7. file: `eval/abtest/report.py`
   anchor: line matching `run = f"run-matrix.sh --reps {{}} --evals {eval_id}"`
   indent: 0
   insert-after:
~~~~
    bad_a, bad_b = bad_counts(v)
    stuck = bad_a >= 2 or bad_b >= 2 or reason.startswith("two or more turn-cap")
~~~~
8. file: `eval/abtest/report.py`
   anchor: line matching `return f"RERUN: the rows mix provenance ({reason}); repeat the stale rows with run-matrix.sh (OD-14), a top-up does not cure it"`
   indent: 0
   before:
~~~~
        return f"RERUN: the rows mix provenance ({reason}); repeat the stale rows with run-matrix.sh (OD-14), a top-up does not cure it"
~~~~
   after:
~~~~
        text = f"RERUN: the rows mix provenance ({reason}); repeat the stale rows with run-matrix.sh (OD-14), a top-up does not cure it"
        if stuck:
            text += (f"; two or more turn-cap, timeout or error rows in one arm (A {bad_a}, B {bad_b}) also keep it INCONCLUSIVE "
                     "at every N (OD-12), unless the repeat replaces them")
        return text
    if stuck:
        text = ("NO MORE RUNS HELP: two or more turn-cap, timeout or error rows stay INCONCLUSIVE at every N (OD-12); "
                "a top-up keeps those rows (a resume skips run ids already done), so record the outcome as INCONCLUSIVE")
        if not reason.startswith("two or more turn-cap"):
            text += f"; the scorer names {reason} first, but the bad rows (A {bad_a}, B {bad_b}) decide"
        return text
~~~~
9. file: `eval/abtest/report.py`
   anchor: line matching `return f"NEEDS MORE DATA: a verdict exists only `
   indent: 0
   before:
~~~~
        return f"NEEDS MORE DATA: a verdict exists only at N=5 per arm ({reason}); finish the first pass with {run.format(5)}"
~~~~
   after:
~~~~
        target = next_n(v)
        if target == 5:
            return f"NEEDS MORE DATA: a verdict exists only at N=5 per arm ({reason}); finish the first pass with {run.format(5)}"
        return (f"NEEDS MORE DATA: a verdict exists only at N=5 or at equal counts of 10 or more ({reason}); "
                f"bring both arms to {target} with {run.format(target)}")
~~~~
10. file: `eval/abtest/report.py`
   anchor: line matching `target = top if (top <= 5 or top >= 10) else 10`
   indent: 0
   before:
~~~~
        top = max(v["n_A"], v["n_B"])
        target = top if (top <= 5 or top >= 10) else 10
~~~~
   after:
~~~~
        target = next_n(v)
~~~~
11. file: `eval/abtest/report.py`
   anchor: line matching `if reason.startswith("two or more turn-cap"):`
   indent: 0
   before:
~~~~
    if reason.startswith("two or more turn-cap"):
        return ("NO MORE RUNS HELP: two or more turn-cap, timeout or error rows stay INCONCLUSIVE at every N (OD-12); "
                "a top-up keeps those rows (a resume skips run ids already done), so record the outcome as INCONCLUSIVE")
    die(f"{eval_id}: no wording for the INCONCLUSIVE reason {reason!r}")
~~~~
   after:
~~~~
    die(f"{eval_id}: no wording for the INCONCLUSIVE reason {reason!r}")
~~~~
12. file: `eval/abtest/report.py`
   anchor: line matching `note += f" (directional: a 2-run gap at N=5 with Fisher p={fmt(v['fisher_p'])}, not below 0.10, OD-12)"`
   indent: 0
   before:
~~~~
            note += f" (directional: a 2-run gap at N=5 with Fisher p={fmt(v['fisher_p'])}, not below 0.10, OD-12)"
~~~~
   after:
~~~~
            note += f" (directional: a {v['k_B'] - v['k_A']}-run gap at N=5 with Fisher p={fmt(v['fisher_p'])}, not below 0.10, OD-12)"
~~~~
13. file: `eval/abtest/report.py`
   anchor: line matching `rows_path = rows_path or os.environ.get("ABT_RES`
   indent: 0
   before:
~~~~
    rows_path = rows_path or os.environ.get("ABT_RESULTS") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "results.jsonl")
~~~~
   after:
~~~~
    default = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results.jsonl")
    rows_path = rows_path or os.environ.get("ABT_RESULTS") or default
    src = "eval/abtest/results.jsonl" if rows_path == default else rows_path
~~~~
14. file: `eval/abtest/report.py`
   anchor: line matching `lines[i] = f"- **Result**: {result_line(current, v, rows)}"`
   indent: 0
   before:
~~~~
                lines[i] = f"- **Result**: {result_line(current, v, rows)}"
~~~~
   after:
~~~~
                lines[i] = f"- **Result**: {result_line(current, v, rows, src)}"
~~~~
15. file: `eval/abtest/report.py`
   anchor: line matching `f"Result: {result_line(eval_id, v, rs)}",`
   indent: 0
   before:
~~~~
                f"Result: {result_line(eval_id, v, rs)}",
~~~~
   after:
~~~~
                f"Result: {result_line(eval_id, v, rs, rows_path)}",
~~~~
16. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "fill-log exits 0" "$rc" "0"`
   indent: 0
   insert-after:
~~~~
check "the result line names the rows file it was built from" "$(grep -cF "rows in $T/rows.jsonl, verdict" "$T/log.md")" "5"
cp "$T/log-pending.md" "$T/log-env.md"
ABT_RESULTS="$T/rows.jsonl" python3 "$REPORT" fill-log "$T/score.json" "$T/log-env.md" > /dev/null
check "ABT_RESULTS names the rows file when none is passed" "$(grep -cF "rows in $T/rows.jsonl, verdict" "$T/log-env.md")" "5"
~~~~
17. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "the E2 result line keeps the Fisher p and`
   indent: 0
   insert-after:
~~~~
check "the E2 decision names its 3-run gap and its Fisher p" "$(grep -cF 'verdict superior: recorded as a measured advantage (directional: a 3-run gap at N=5 with Fisher p=0.21, not below 0.10, OD-12)' "$T/log.md")" "1"
~~~~
18. file: `tests/abtest-report.test.sh`
   anchor: line matching `f.write("### E3: rename (e03-rename-query)\n\n- `
   indent: 0
   insert-after:
~~~~
v2 = [dict(r) for r in rows]
for r in v2:
    if r["eval_id"] == "e03-rename-query" and r["arm"] == "A" and r["rep"] == 1:
        r["harness_commit"] = "old"
with open(t + "/rows-v2.jsonl", "w") as f:
    for r in v2:
        f.write(json.dumps(r) + "\n")
e4 = [r for r in rows if r["eval_id"] == "e04-search-injection"]
a_rows = [dict(r) for r in e4 if r["arm"] == "A"]
b_rows = [dict(r) for r in e4 if r["arm"] == "B"]
for r in b_rows:
    if r["rep"] >= 4:
        r["completion_status"], r["run_pass"] = "turn-cap", False
stuck = a_rows[:3] + b_rows
wide = a_rows + [dict(a_rows[0], rep=n, run_id=f"e04-search-injection/A/uniform/{n}") for n in (6, 7)] + [r for r in e4 if r["arm"] == "B"][:3]
stuckmix = [dict(r) for r in stuck]
stuckmix[0]["harness_commit"] = "old"
for tag, rs in (("stuck", stuck), ("wide", wide), ("stuckmix", stuckmix)):
    with open(f"{t}/rows-{tag}.jsonl", "w") as f:
        for r in rs:
            f.write(json.dumps(r) + "\n")
~~~~
19. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "the mixed result line still names the out`
   indent: 0
   insert-after:
~~~~

python3 "$SCORE" "$T/rows-v2.jsonl" --out-json "$T/score-v2.json" > /dev/null
cp "$T/log.md" "$T/log-v2.md"
python3 "$REPORT" fill-log "$T/score-v2.json" "$T/log-v2.md" "$T/rows-v2.jsonl" > /dev/null
cp "$T/log-pending.md" "$T/log-v2-fresh.md"
python3 "$REPORT" fill-log "$T/score-v2.json" "$T/log-v2-fresh.md" "$T/rows-v2.jsonl" > /dev/null
check "re-filling an already filled log rewrites every line from the new report" "$(cmp -s "$T/log-v2.md" "$T/log-v2-fresh.md" && echo same || echo different) $(grep -c '^- \*\*Decision\*\*: RERUN' "$T/log-v2.md")" "same 1"
printf '### E4: search (e04-search-injection)\n\n- **Result**: pending\n- **Verdict**: pending\n- **Decision**: pending\n' > "$T/log-e04.md"
for tag in stuck wide stuckmix; do
  python3 "$SCORE" "$T/rows-$tag.jsonl" --out-json "$T/score-$tag.json" > /dev/null
  cp "$T/log-e04.md" "$T/log-$tag.md"
  python3 "$REPORT" fill-log "$T/score-$tag.json" "$T/log-$tag.md" "$T/rows-$tag.jsonl" > /dev/null
done
check "two bad rows beat a short N: no more runs help" "$(grep -cF 'NO MORE RUNS HELP: two or more turn-cap, timeout or error rows stay INCONCLUSIVE at every N (OD-12)' "$T/log-stuck.md") $(grep -cF 'the scorer names short N: A=3 B=5 first, but the bad rows (A 0, B 2) decide' "$T/log-stuck.md") $(grep -c 'NEEDS MORE DATA' "$T/log-stuck.md")" "1 1 0"
check "a short N with one arm past 5 rows is cured in one step" "$(grep -cF 'NEEDS MORE DATA: a verdict exists only at N=5 or at equal counts of 10 or more (short N: A=7 B=3); bring both arms to 10 with run-matrix.sh --reps 10 --evals e04-search-injection' "$T/log-wide.md") $(grep -c 'finish the first pass' "$T/log-wide.md")" "1 0"
check "mixed provenance with two bad rows says both" "$(grep -cF 'RERUN: the rows mix provenance (mixed provenance: harness_commit)' "$T/log-stuckmix.md") $(grep -cF 'also keep it INCONCLUSIVE at every N (OD-12), unless the repeat replaces them' "$T/log-stuckmix.md") $(grep -c 'NO MORE RUNS HELP\|NEEDS MORE DATA' "$T/log-stuckmix.md")" "1 1 0"
~~~~
20. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "tickets ignores the rows of another polic`
   indent: 0
   insert-after:
~~~~
check "tickets with nothing to file still leaves an empty directory (abt-u21 git adds it)" "$(test -d "$T/tickets-other" && echo dir || echo none) $(ls -A "$T/tickets-other" | wc -l | tr -d ' ')" "dir 0"
~~~~
21. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "tickets refuses an eval id that is not an`
   indent: 0
   insert-after:
~~~~
python3 -I - "$T" << 'PYEOF'
import json, sys

t = sys.argv[1]
for tag, new in (("nl", "e04-search-injection\n"), ("dots", "e04-x/../escape")):
    rep = json.load(open(t + "/score.json"))
    rep["evals"][new] = rep["evals"].pop("e04-search-injection")
    rows = [json.loads(l) for l in open(t + "/rows.jsonl")]
    for r in rows:
        if r["eval_id"] == "e04-search-injection":
            r["eval_id"] = new
    with open(f"{t}/score-{tag}.json", "w") as f:
        json.dump(rep, f)
    with open(f"{t}/rows-{tag}.jsonl", "w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")
rep = json.load(open(t + "/score.json"))
rep["evals"]["e01-ambiguous-tax"]["verdict"] = "bogus"
with open(t + "/score-bogus.json", "w") as f:
    json.dump(rep, f)
PYEOF
for tag in nl dots; do
  python3 "$REPORT" tickets "$T/score-$tag.json" "$T/rows-$tag.jsonl" "$T/tickets-$tag" > /dev/null 2> "$T/$tag.err"; rc=$?
  check "tickets refuses the eval id of the $tag case and writes nothing" "$rc $(test -e "$T/tickets-$tag" && echo yes || echo no) $(grep -c 'does not match' "$T/$tag.err")" "1 no 1"
done
printf 'keep\n' > "$T/tickets-file"
python3 "$REPORT" tickets "$T/score.json" "$T/rows.jsonl" "$T/tickets-file" > /dev/null 2> "$T/file.err"; rc=$?
check "tickets refuses an output path that is a plain file and leaves it alone" "$rc $(grep -c 'not an empty directory' "$T/file.err") $(cat "$T/tickets-file")" "1 1 keep"
printf '{"run_id": 1}\nnot json\n' > "$T/rows-garbage.jsonl"
cp "$T/log-pending.md" "$T/log-garbage.md"
python3 "$REPORT" fill-log "$T/score.json" "$T/log-garbage.md" "$T/rows-garbage.jsonl" > /dev/null 2> "$T/garbage.err"; rc=$?
check "fill-log names a rows file that is not JSON lines" "$rc $(grep -c '^report: cannot read .*rows-garbage.jsonl as JSON lines' "$T/garbage.err") $(grep -c Traceback "$T/garbage.err")" "1 1 0"
python3 "$REPORT" tickets "$T/score.json" "$T/missing.jsonl" "$T/tickets-missing" > /dev/null 2> "$T/missing.err"; rc=$?
check "tickets names a rows file that does not exist and writes nothing" "$rc $(grep -c '^report: cannot read .*missing.jsonl as JSON lines' "$T/missing.err") $(test -e "$T/tickets-missing" && echo yes || echo no)" "1 1 no"
cp "$T/log-pending.md" "$T/log-bogus.md"
python3 "$REPORT" fill-log "$T/score-bogus.json" "$T/log-bogus.md" "$T/rows.jsonl" > /dev/null 2> "$T/bogus.err"; rc=$?
check "fill-log refuses a verdict it has no wording for and leaves the log alone" "$rc $(grep -c "no wording for verdict 'bogus'" "$T/bogus.err") $(cmp -s "$T/log-bogus.md" "$T/log-pending.md" && echo same || echo different)" "1 1 same"
python3 "$REPORT" tickets "$T/score-bogus.json" "$T/rows.jsonl" "$T/tickets-bogus" > /dev/null 2>&1; rc=$?
check "tickets refuses it too and creates no directory" "$rc $(test -e "$T/tickets-bogus" && echo yes || echo no)" "1 no"
awk '{print} /^- \*\*Decision\*\*: pending$/ && !d {print; d=1}' "$T/log-pending.md" > "$T/log-dup.md"
cp "$T/log-dup.md" "$T/log-dup.before"
python3 "$REPORT" fill-log "$T/score.json" "$T/log-dup.md" "$T/rows.jsonl" > /dev/null 2> "$T/dup.err"; rc=$?
check "an entry with two Decision lines is refused before the log is written" "$rc $(grep -c 'must hold exactly one' "$T/dup.err") $(cmp -s "$T/log-dup.md" "$T/log-dup.before" && echo same || echo different)" "1 1 same"
~~~~
22. command: `git add eval/abtest/report.py tests/abtest-report.test.sh && git commit -m "fix(abt-u21a): bad rows decide at every N, one-step short-N advice, exact eval ids and pinned error paths (#588)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `tests/validate.sh` (the walk and grid tests are registered by rounds 4 and 5; this round adds no section)
- `eval/abtest/score.py` and `eval/abtest/lib/` (the report and the tests read the scorer's output; the scorer's check order is not changed, see decision-table in Pre-resolved context)
- `CHANGELOG.md`, `docs/harness-glossary.md`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)
- `eval/abtest/results.jsonl`, `eval/reports/` and `docs/experiments/abtest-2026-10.md` (written by the operator unit abt-u21, not by a fix round)

## Acceptance criteria
1. run: `bash tests/abtest-report.test.sh`
   exit: 0
   stdout: `All abtest-report checks passed.`
   mutation: skip edit 8 (the RERUN and NO MORE RUNS HELP block in report.py); the two bad-row rows and the mixed-with-bad row print FAIL and the fragment is absent.
2. run: `bash tests/abtest-report.test.sh | grep -c '^ok   two bad rows beat a short N: no more runs help$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the row prints FAIL (the Decision says NEEDS MORE DATA) and the count is 0 (exit 1).
3. run: `bash tests/abtest-report.test.sh | grep -c '^ok   a short N with one arm past 5 rows is cured in one step$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 9 (the short-N wording in report.py); the Decision keeps the two-step advice, the row prints FAIL and the count is 0 (exit 1).
4. run: `bash tests/abtest-report.test.sh | grep -c '^ok   mixed provenance with two bad rows says both$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the RERUN sentence loses the bad-row clause, the row prints FAIL and the count is 0 (exit 1).
5. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (the result line names the rows file it was built from|ABT_RESULTS names the rows file when none is passed)$'`
   exit: 0
   stdout: `2`
   mutation: skip edit 4 (the result line prints the rows path); both rows print FAIL and the count is 0 (exit 1).
6. run: `bash tests/abtest-report.test.sh | grep -c '^ok   the E2 decision names its 3-run gap and its Fisher p$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 12 (the directional note names the real gap); the note keeps saying a 2-run gap, the row prints FAIL and the count is 0 (exit 1).
7. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   tickets refuses the eval id of the (nl|dots) case and writes nothing$'`
   exit: 0
   stdout: `2`
   mutation: skip edit 2 (fullmatch); the id with a trailing newline is accepted, its row prints FAIL and the count is 1 (exit 0, fragment 2 absent).
8. run: `bash tests/abtest-report.test.sh | grep -c '^ok   tickets refuses an output path that is a plain file and leaves it alone$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, replace "(not os.path.isdir(out_dir) or os.listdir(out_dir))" with "(os.listdir(out_dir))" in report.py; the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run (str.replace, then the test): the row printed FAIL (want 1 1 keep, got 1 0 keep).
9. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (fill-log names a rows file that is not JSON lines|tickets names a rows file that does not exist and writes nothing)$'`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, replace "except (OSError, ValueError) as e:" in load_rows with "except (OSError,) as e:"; the first row prints FAIL and the count is 1 (exit 0, fragment 2 absent).
   proof: scratch run (str.replace, then the test): the fill-log row printed FAIL (want 1 1 0, got 1 0 1).
10. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (fill-log refuses a verdict it has no wording for and leaves the log alone|tickets refuses it too and creates no directory)$'`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, replace 'if v["verdict"] not in VERDICTS or v["outcome"] not in OUTCOMES:' with "if False:", or move "os.makedirs(out_dir, exist_ok=True)" to just after "planned = {}"; the count is below 2.
   proof: scratch runs (str.replace, then the test): the guard-off run failed both rows; the early-makedirs run failed the second (want 1 no, got 1 yes).
11. run: `bash tests/abtest-report.test.sh | grep -c '^ok   an entry with two Decision lines is refused before the log is written$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, replace "if seen.get((e, key), 0) != 1:" with "if False:", or write the log above the "for e in report" check loop; the row prints FAIL and the count is 0 (exit 1).
   proof: scratch runs (str.replace, then the test): both mutations failed the row.
12. run: `bash tests/abtest-report.test.sh | grep -c '^ok   re-filling an already filled log rewrites every line from the new report$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, replace 'if line.startswith("- **Result**:"):' with 'if line == "- **Result**: pending":' in fill_log; the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run (str.replace, then the test): the row printed FAIL (want same 1, got different 0).
13. run: `bash tests/abtest-report.test.sh | grep -c '^ok   tickets with nothing to file still leaves an empty directory (abt-u21 git adds it)$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, wrap the "os.makedirs(out_dir, exist_ok=True)" that precedes the ticket-writing loop in "if planned:"; the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run (str.replace, then the test): the row printed FAIL (want dir 0, got none 0).
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): bad rows decide at every N' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/report.py tests/abtest-report.test.sh`
   mutation: skip edit 22 (the commit); no round commit exists and the run prints no-unit-commit with exit 3.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): bad rows decide at every N' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 22; no round commit exists and the exit is 3.
16. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u21a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/report.py tests/abtest-report.test.sh | grep -vcE "^[a-z]+\(abt-u21a\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the round commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
17. run: `git status --porcelain -- eval/abtest/report.py tests/abtest-report.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 22; the changed files stay modified (or new files untracked) and are listed.

## Pre-resolved context
tdd: yes tests/abtest-report.test.sh (the rows named in criteria 2 to 13 are the red-then-green checks; they do not exist at HEAD)
blast-radius: eval/abtest/report.py:150 eval/abtest/report.py:108 eval/abtest/report.py:198 eval/abtest/report.py:238
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty (edits 5 and 19 begin with empty lines that belong to the text).
already-green: criterion 1 (the suite passes without the new rows), 16 and 17 pass at HEAD by design; criteria 2 to 13 are red at HEAD because their rows do not exist (8 to 13 guard code that is already correct and kill surviving mutants).
performance: tests/abtest-report.test.sh runs in about 0.4 s in a scratch clone.
decision-table-v2:
~~~
Replaces the D rows of decision-table in contracts/abt-u21a-fix2.md (T, V, L unchanged). Sources: OD-4, OD-12(a), OD-13, OD-14; docs/experiments/abtest-2026-10.md lines 116-134; score.py outcome() read end to end.
score.py checks N first, then two or more bad rows (turn-cap, timeout, error) in either arm, then the gap or Fisher rule; mixed provenance replaces any outcome last.
OD-12(a): two or more bad rows in one arm keep the outcome INCONCLUSIVE at every N, and a resume skips run ids that already hold a row, so no run-matrix.sh call cures them. The scorer's order only changes
which reason it prints, never the outcome, so report.py reads the counts from status_tally_A and status_tally_B and score.py is not changed. No operator decision is needed.
D, first match wins (a, b = bad rows of Arm A, Arm B; E = eval id; reason = the scorer's outcome_reason):
  1 mixed provenance: RERUN: the rows mix provenance (<reason>); repeat the stale rows with run-matrix.sh (OD-14), a top-up does not cure it
      + when a >= 2 or b >= 2: "; two or more turn-cap, timeout or error rows in one arm (A a, B b) also keep it INCONCLUSIVE at every N (OD-12), unless the repeat replaces them"
  2 a >= 2 or b >= 2 (or reason starts "two or more turn-cap"), at ANY N: NO MORE RUNS HELP: two or more turn-cap, timeout or error rows stay INCONCLUSIVE at every N (OD-12); a top-up keeps those rows (a resume skips run ids already done), so record the outcome as INCONCLUSIVE
      + when reason is another class: "; the scorer names <reason> first, but the bad rows (A a, B b) decide"
  3 short N, T = 5 if the larger arm holds at most 5 rows, 10 if 6 to 9, else its count. T = 5: NEEDS MORE DATA: a verdict exists only at N=5 per arm (<reason>); finish the first pass with run-matrix.sh --reps 5 --evals E
      T > 5: NEEDS MORE DATA: a verdict exists only at N=5 or at equal counts of 10 or more (<reason>); bring both arms to T with run-matrix.sh --reps T --evals E
  4 unequal N: NEEDS MORE DATA: the arms hold unequal usable rows (<reason>); bring both arms to T with run-matrix.sh --reps T --evals E   (T as in 3)
  5 top-up in progress, 6 1-run gap: as in fix2.
Tickets do not depend on D: an Arm B stall or an escaped defect in an Arm B row files a ticket at every N and reason; Arm A defects and usage-limit rows never do.
Every cell of N bucket x bad rows (0, 1, 2 per arm) x provenance x Arm B stall x defect has the D above and the T of fix2; rounds 4 and 5 pin them.
Directional note: "a <k_B - k_A>-run gap at N=5 with Fisher p=<p>, not below 0.10, OD-12". Result line ends "rows in <rows path as given, or ABT_RESULTS, or eval/abtest/results.jsonl by default>, verdict ...".
tickets: OUT_DIR is created only after every Decision has wording (a failing run leaves no directory); with no ticket to file an EMPTY directory is left, because contracts/abt-u21.md edit 10 git-adds
eval/reports/tickets and git refuses a missing path (an empty directory is accepted).
~~~
open-question-gate-blocks: design 5.5 lists gate_blocks>0 on an unexpected path as a ticket trigger; no operator decision defines it. finding_reasons stays unchanged (round 4 pins that); do not add the trigger.
commit-message: fix(abt-u21a): bad rows decide at every N, one-step short-N advice, exact eval ids and pinned error paths (#588)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u21a (#588)
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
