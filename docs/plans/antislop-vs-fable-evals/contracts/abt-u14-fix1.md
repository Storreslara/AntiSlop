Unit: abt-u14

## Objective
Fix round 1 of 3 for the abt-u14 FAIL (fix-of 2026-10-17T02:00:10Z). eval/abtest/score.py gives a per-eval outcome only at the pre-registered N (OD-12): 5 usable rows per arm decide by the 2-run gap, 10 or more per arm (equal) by Fisher p < 0.10, and a pilot, a short or unequal arm or 6-9 rows is INCONCLUSIVE with a reason; it prints the Fisher p for every eval and marks a gap-rule win with p >= 0.10 as directional in the markdown. tests/abtest-score.test.sh covers it and checks the scorer's exit status. One commit.

## Retrieval
GitHub issues: `gh issue view 583 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/score.py` (anchor: line matching `def outcome(rows_a, rows_b):`)
- `tests/abtest-score.test.sh` (anchor: line matching `check "usage-limit rows are tallied"`)

## Ordered edits
1. command: `test "$(grep -cF 'if abs(kb - ka) == 1:' eval/abtest/score.py)" = 1 && test "$(grep -cF 'def p_decisive' eval/abtest/score.py)" = 0 && test "$(grep -cF 'check "usage-limit rows are tallied"' tests/abtest-score.test.sh)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/score.py`
   anchor: line matching `"process", "blind_grades", "artifacts",`
   indent: 0
   before:
~~~~
    "process", "blind_grades", "artifacts",
)
~~~~
   after:
~~~~
    "process", "blind_grades", "artifacts",
)
MIN_N = 5      # usable rows per arm in the first pass; the gap rule applies only here
FULL_N = 10    # usable rows per arm after the top-up; Fisher decides from here
ALPHA = 0.10   # spec 4.4: Fisher exact p < 0.10 at N >= 10
~~~~
3. file: `eval/abtest/score.py`
   anchor: line matching `"""Two-sided exact p-value for ka/na against kb/nb successes."""`
   indent: 0
   before:
~~~~
    """Two-sided exact p-value for ka/na against kb/nb successes."""
~~~~
   after:
~~~~
    """Two-sided exact p-value for ka/na against kb/nb successes.

    Sums the probability of every table (same margins) no more likely than the
    observed one. Checked against exact fractions on 20 tables (tests/abtest-score.test.sh).
    Errata to design 2.5 (OD-12): 5/5 vs 1/5 is p=1/21=0.048 (not 0.024: with 6 successes in 10 runs the
    tables x=1..5 weigh 5,50,100,50,5 of 210, and x=1 and x=5 are the two no likelier than 5/210);
    a 3-run gap at 10 vs 10 is p between 0.2105 (0 vs 3) and 0.3698 (3 vs 6), not ~0.07; a 4-run gap
    is p between 0.0867 (0 vs 4) and 0.1789 (3 vs 7), not below 0.05.
    """
~~~~
4. file: `eval/abtest/score.py`
   anchor: line matching `return min(1.0, sum(prob(x) for x in range(lo, hi + 1) if prob(x) <= observed * (1 + 1e-9)))`
   indent: 0
   before:
~~~~
    return min(1.0, sum(prob(x) for x in range(lo, hi + 1) if prob(x) <= observed * (1 + 1e-9)))
~~~~
   after:
~~~~
    return sum(prob(x) for x in range(lo, hi + 1) if prob(x) <= observed * (1 + 1e-9))


def p_decisive(p):
    return p < ALPHA
~~~~
5. file: `eval/abtest/score.py`
   anchor: line matching `def outcome(rows_a, rows_b):`
   indent: 0
   insert-after:
~~~~
    """Returns (outcome, k_A, k_B, fisher_p, rule, reason).

    Pre-registered N: 5 usable (non-usage-limit) rows per arm decide by the
    2-run gap; 10 or more per arm, equal in both, decide by Fisher at p < 0.10
    (a 1-run gap is only INCONCLUSIVE at N=5, because the top-up is its cure).
    Fewer than 5 rows in either arm (a pilot, a run stopped by a usage limit), unequal
    counts, or 6-9 rows (a top-up in progress) are INCONCLUSIVE, never a verdict.
    The Fisher p is computed whenever both arms have a row, whatever the rule.
    """
    na, nb = len(rows_a), len(rows_b)
~~~~
6. file: `eval/abtest/score.py`
   anchor: line matching `if not rows_a or not rows_b:`
   indent: 0
   before:
~~~~
    if not rows_a or not rows_b:
        return "INCONCLUSIVE", ka, kb, None
~~~~
   after:
~~~~
    p = fisher_two_sided(ka, na, kb, nb) if na and nb else None

    def inconclusive(reason):
        return "INCONCLUSIVE", ka, kb, p, None, reason

    if min(na, nb) < MIN_N:
        return inconclusive(f"short N: A={na} B={nb}")
    if na != nb:
        return inconclusive(f"unequal N: A={na} B={nb}")
    if na < FULL_N and na != MIN_N:
        return inconclusive(f"top-up in progress: A={na} B={nb}, needs {FULL_N} per arm")
~~~~
7. file: `eval/abtest/score.py`
   anchor: line matching `if bad(rows_a) >= 2 or bad(rows_b) >= 2:`
   indent: 0
   before:
~~~~
    if bad(rows_a) >= 2 or bad(rows_b) >= 2:
        return "INCONCLUSIVE", ka, kb, None
~~~~
   after:
~~~~
    if bad(rows_a) >= 2 or bad(rows_b) >= 2:
        return inconclusive("two or more turn-cap, timeout or error rows")
    if na >= FULL_N:
        if p_decisive(p):
            return ("WIN_B" if kb > ka else "WIN_A"), ka, kb, p, "fisher", None
        return "TIE", ka, kb, p, "fisher", None
~~~~
8. file: `eval/abtest/score.py`
   anchor: line matching `return "INCONCLUSIVE", ka, kb, None`
   indent: 0
   before:
~~~~
        return "INCONCLUSIVE", ka, kb, None
    if len(rows_a) >= 10 and len(rows_b) >= 10:
        p = fisher_two_sided(ka, len(rows_a), kb, len(rows_b))
        if p < 0.10:
            return ("WIN_B" if kb > ka else "WIN_A"), ka, kb, p
        return "TIE", ka, kb, p
~~~~
   after:
~~~~
        return inconclusive("1-run gap")
~~~~
9. file: `eval/abtest/score.py`
   anchor: line matching `return "WIN_B", ka, kb, None`
   indent: 0
   before:
~~~~
        return "WIN_B", ka, kb, None
~~~~
   after:
~~~~
        return "WIN_B", ka, kb, p, "gap", None
~~~~
10. file: `eval/abtest/score.py`
   anchor: line matching `return "WIN_A", ka, kb, None`
   indent: 0
   before:
~~~~
        return "WIN_A", ka, kb, None
    return "TIE", ka, kb, None
~~~~
   after:
~~~~
        return "WIN_A", ka, kb, p, "gap", None
    return "TIE", ka, kb, p, "gap", None
~~~~
11. file: `eval/abtest/score.py`
   anchor: line matching `out, ka, kb, p = outcome(ra, rb)`
   indent: 0
   before:
~~~~
    out, ka, kb, p = outcome(ra, rb)
~~~~
   after:
~~~~
    out, ka, kb, p, rule, reason = outcome(ra, rb)
~~~~
12. file: `eval/abtest/score.py`
   anchor: line matching `label = "measured-overhead" if (out == "TIE" and eval_id in COST_EVALS) else None`
   indent: 0
   insert-after:
~~~~
    # OD-12: a WIN_B decided by the 2-run gap whose Fisher p is not below ALPHA is only directional.
    directional = bool(verdict == "superior" and out == "WIN_B" and not p_decisive(p))
~~~~
13. file: `eval/abtest/score.py`
   anchor: line matching `"n_A": len(ra), "n_B": len(rb), "k_A": ka, "k_B": kb, "fisher_p": p, "outcome": out,`
   indent: 0
   insert-after:
~~~~
        "outcome_rule": rule, "outcome_reason": reason, "directional": directional,
~~~~
14. file: `eval/abtest/score.py`
   anchor: line matching `"| eval | A pass | B pass | outcome | R_tokens | R_wall | R_turns | B stalls | verdict |",`
   indent: 0
   before:
~~~~
             "| eval | A pass | B pass | outcome | R_tokens | R_wall | R_turns | B stalls | verdict |",
             "|---|---|---|---|---|---|---|---|---|"]
~~~~
   after:
~~~~
             "| eval | A pass | B pass | outcome | Fisher p | R_tokens | R_wall | R_turns | B stalls | verdict |",
             "|---|---|---|---|---|---|---|---|---|---|"]
~~~~
15. file: `eval/abtest/score.py`
   anchor: line matching `lines.append(f"| {e} | {v['k_A']}/{v['n_A']} | {v['k_B']}/{v['n_B']} | {v['outcome']} | {f(o['R_tokens'])} | "`
   indent: 0
   before:
~~~~
        lines.append(f"| {e} | {v['k_A']}/{v['n_A']} | {v['k_B']}/{v['n_B']} | {v['outcome']} | {f(o['R_tokens'])} | "
                     f"{f(o['R_wall'])} | {f(o['R_turns'])} | {v['stalled_human_B']} | {v['verdict']}"
~~~~
   after:
~~~~
        outc = v["outcome"] + (f" ({v['outcome_reason']})" if v["outcome_reason"] else "")
        verd = v["verdict"] + (f" (directional, p={v['fisher_p']:.2f})" if v["directional"] else "")
        lines.append(f"| {e} | {v['k_A']}/{v['n_A']} | {v['k_B']}/{v['n_B']} | {outc} | {f(v['fisher_p'])} | "
                     f"{f(o['R_tokens'])} | {f(o['R_wall'])} | {f(o['R_turns'])} | {v['stalled_human_B']} | {verd}"
~~~~
16. file: `eval/abtest/score.py`
   anchor: line matching `f"Usage-limit rows excluded from every count: {report['usage_limit_rows_excluded']}.",`
   indent: 0
   insert-after:
~~~~
              "Fisher p is the two-sided exact p-value, shown for every eval; a WIN_B decided by the 2-run gap at N=5 "
              "with p >= 0.10 is marked directional (OD-12).",
~~~~
17. file: `tests/abtest-score.test.sh`
   anchor: line matching `check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }`
   indent: 0
   insert-after:
~~~~
# tally: run a python checker that prints "ok   name" / "FAIL name" lines; a crash or no output is a FAIL.
tally() {
  local out="$1" rc="$2" what="$3"
  cat "$out"
  pass=$((pass + $(grep -c '^ok   ' "$out")))
  fail=$((fail + $(grep -c '^FAIL ' "$out")))
  if [ "$rc" -ne 0 ] || [ "$(grep -c '^ok   ' "$out")" -eq 0 ]; then bad "$what crashed or printed nothing (rc $rc)"; fi
}
~~~~
18. file: `tests/abtest-score.test.sh`
   anchor: line matching `rows.append(row(ev, "B", i + 1, i < b_pass, **(b_kw or {})))`
   indent: 0
   insert-after:
~~~~
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
~~~~
19. file: `tests/abtest-score.test.sh`
   anchor: line matching `add("e05-tags-feature", 3, 3, dict(tokens=100), dict(tokens=900))`
   indent: 0
   insert-after:
~~~~
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
~~~~
20. file: `tests/abtest-score.test.sh`
   anchor: line matching `python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/r.json" --out-md "$T/r.md" > /dev/null`
   indent: 0
   before:
~~~~
python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/r.json" --out-md "$T/r.md" > /dev/null
~~~~
   after:
~~~~
python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/r.json" --out-md "$T/r.md" > /dev/null 2> "$T/score.err"
check "the scorer exits 0 on valid rows" "$?" "0"
check "the scorer wrote the JSON report" "$(test -s "$T/r.json" && echo yes || echo no)" "yes"
~~~~
21. file: `tests/abtest-score.test.sh`
   anchor: line matching `check "usage-limit rows are tallied" "$(rep 'd["usage_limit_rows_excluded"]')" "3"`
   indent: 0
   before:
~~~~
check "usage-limit rows are tallied" "$(rep 'd["usage_limit_rows_excluded"]')" "3"
~~~~
   after:
~~~~
check "usage-limit rows are tallied" "$(rep 'd["usage_limit_rows_excluded"]')" "4"
~~~~
22. file: `tests/abtest-score.test.sh`
   anchor: line matching `check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "12"`
   indent: 0
   before:
~~~~
check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "12"
~~~~
   after:
~~~~
check "the markdown has a row per eval" "$(grep -c '^| x-' "$T/r.md")" "24"
~~~~
23. file: `tests/abtest-score.test.sh`
   anchor: line matching `check "the markdown states the cost basis" "$(grep -c 'dollar cost is not used' "$T/r.md")" "1"`
   indent: 0
   insert-after:
~~~~
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
~~~~
24. file: `tests/abtest-score.test.sh`
   anchor: line matching `[ "$fail" -eq 0 ] && echo "All abtest-score checks passed."`
   indent: 0
   before:
~~~~
[ "$fail" -eq 0 ] && echo "All abtest-score checks passed."
~~~~
   after:
~~~~
[ "$fail" -eq 0 ] && [ "$pass" -gt 0 ] && echo "All abtest-score checks passed."
~~~~
25. command: `git add eval/abtest/score.py tests/abtest-score.test.sh && git commit -m "fix(abt-u14): scorer decides only at N=5 or N>=10, prints the Fisher p and marks directional wins (#583)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
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
   mutation: skip edit 6; the N-rule rows FAIL, the script exits non-zero and the fragment is absent.
   proof: scratch mutation matrix after this round: 52 single-edit mutants of score.py apply; 28 are caught by this suite (exit non-zero); the other 24 (bad-row, quality-edge, R_tokens, label, stall-override and validator mutants) are caught by the rows of round 3 by design.
2. run: `python3 -I eval/abtest/score.py --validate-rows /dev/null`
   exit: 0
   stdout: `rows ok: 0`
   mutation: make --validate-rows reject an empty file; the exit is 1.
   proof: scratch run: in a copy of score.py, return 1 if errors or not rows else 0 at the end of the validate branch made this command exit 1.
3. run: `grep -c '^def ' eval/abtest/score.py`
   exit: 0
   stdout: `11`
   mutation: skip edit 4; p_decisive is gone, so the count is 10.
4. run: `test -x eval/abtest/score.py && test -x tests/abtest-score.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: make one of the files non-executable; nothing prints and the exit is 1.
   proof: scratch run: chmod -x on a copy of either file made the command exit 1 with no output.
5. run: `bash tests/abtest-score.test.sh | grep -c '^ok   3 vs 5 usable rows is INCONCLUSIVE, short N$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the row FAILs and the count is 0.
6. run: `bash tests/abtest-score.test.sh | grep -c '^ok   a pilot (1 vs 1) never produces a verdict$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the row FAILs and the count is 0.
7. run: `bash tests/abtest-score.test.sh | grep -c '^ok   10 vs 9 rows is INCONCLUSIVE, unequal N$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the row FAILs and the count is 0.
8. run: `bash tests/abtest-score.test.sh | grep -c '^ok   a 3-run gap at N=5 is WIN_B, superior, directional at p=0.21$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 12; the row FAILs and the count is 0.
9. run: `bash tests/abtest-score.test.sh | grep -c '^ok   the markdown marks a directional win with its p$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 15; the row FAILs and the count is 0.
10. run: `bash tests/abtest-score.test.sh | grep -c '^ok   the Fisher p is still reported below N=10$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the row FAILs and the count is 0.
11. run: `bash tests/abtest-score.test.sh | grep -c '^ok   at N=10 a 1-run gap is a Fisher TIE with p=1, not INCONCLUSIVE$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; the row FAILs and the count is 0.
12. run: `bash tests/abtest-score.test.sh | grep -c '^ok   the scorer exits 0 on valid rows$'`
   exit: 0
   stdout: `1`
   mutation: skip edit 20; the line is absent and the count is 0.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u14\): scorer decides' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/score.py tests/abtest-score.test.sh`
   mutation: skip edit 25; no round commit exists and the run prints no-unit-commit with exit 3.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u14\): scorer decides' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 25; no round commit exists and the exit is 3.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u14\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/score.py tests/abtest-score.test.sh | grep -vcE "^[a-z]+\(abt-u14\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
16. run: `git status --porcelain -- eval/abtest/score.py tests/abtest-score.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 25; the changed files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-score.test.sh (criteria 5 to 12 are red at HEAD: the new rows FAIL against the old scorer)
blast-radius: none
fix-of: 2026-10-17T02:00:10Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. The before payloads are exact copies of the committed text: copy, do not retype. A long insertion is several consecutive insert-after edits, each anchored on the last line of the previous part.
series: this is round 1 of 3 under one FAIL (contracts abt-u14-fix1, abt-u14-fix2, abt-u14-fix3, dispatched in that order, one commit each, Unit abt-u14 for all). The combined diff is about 46 KB, over the 30000-byte contract budget, so it is cut by feature; each round leaves the suite green. It has no predecessor.
why: the reviewer showed score.py outcome() labelling an eval superior from rows that do not reach N=5: 3 usable A rows against 5 B rows gave WIN_B superior, an N=1 pilot gave TIE superior, and a top-up in progress (A 5/10, B 7/9) gave WIN_B superior. The run-matrix writes pilot rows as ordinary rep-1 rows and stops on usage limits, so honest producers hit all three.
rule: usable rows are the rows of the reported policy whose status is not usage-limit. min(n_A, n_B) < 5 -> INCONCLUSIVE "short N: A=a B=b"; n_A != n_B -> "unequal N: ..."; 6 to 9 rows -> "top-up in progress: ..., needs 10 per arm"; two or more turn-cap/timeout/error rows in an arm -> INCONCLUSIVE at every N; n = 5 -> the gap rule (|gap| = 1 is INCONCLUSIVE, >= 2 wins); n >= 10 -> Fisher p < 0.10 wins, otherwise TIE (a 1-run gap is a TIE here, because the top-up is what cures INCONCLUSIVE). The design is silent on 6-9 and on a 1-run gap at N=10; the conservative reading is taken and recorded in OD-12 (docs/plans/antislop-vs-fable-evals/operator-decisions.md). Binding orchestrator decision (OD-12 b): the verdict semantics of design 4.4 are unchanged (a 2-run gap at N=5 is WIN_B); the Fisher p is printed for every eval, and a gap-rule WIN_B with p >= 0.10 reads superior (directional, p=0.xx) in the markdown while the JSON verdict stays superior with directional true.
callers: no code imports score.py; abt-u17 registers the test in validate.sh; abt-u19, abt-u20 and abt-u21 run it on results.jsonl and read the JSON keys evals, verdict, outcome, fisher_p and aggregate.verdict, none of which is renamed (outcome_rule, outcome_reason and directional are new keys).
od-12: the decisions and the errata for design section 2.5 (5/5 vs 1/5 is p=1/21 two-sided, not 0.024; a 3-run gap at 10 vs 10 is p 0.21 to 0.37; a 4-run gap 0.087 to 0.179) are recorded as OD-12; the docstring of fisher_two_sided states them.
sibling-edits: the pre-registration contract abt-u16 (Verdict rules text) was amended in the same round to state the N rule; nothing in this unit edits it.
already-green: criteria 1, 2, 4, 15 and 16 pass at HEAD by design: criterion 1 because the committed suite is green on the old scorer (the new rows arrive with the edits), 2 and 4 because the validate branch and the executable bits are untouched, 15 and 16 until the commit exists; criteria 5 to 12 are the red-then-green checks.
no-real-claude: nothing here runs the claude CLI; the test builds its own synthetic rows in a temp directory.
commit-message: fix(abt-u14): scorer decides only at N=5 or N>=10, prints the Fisher p and marks directional wins (#583)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
