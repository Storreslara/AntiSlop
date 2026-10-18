Unit: abt-u21a

## Objective
Fix of the FAIL of 2026-10-17T22:50:08Z, round 5 of 5. tests/abtest-report-grid.test.sh walks the whole undecided half of the Decision table: 8 N buckets (pilot, short, short with one arm past 5 rows, unequal, unequal large, top-up, N=5, N=10) x bad rows per arm (six combinations of 0, 1 and 2 per arm) x provenance (one value or mixed) x Arm B stall and escaped defect, with usage-limit rows on every other cell: 348 cells run through the real score.py, fill-log and tickets. Per cell it asserts the scorer outcome and verdict, the one Decision wording of decision-table-v2 (abt-u21a-fix3.md), written out in the test and not taken from report.py, and the ticket state. tests/validate.sh runs it. One commit.

## Retrieval
GitHub issues: `gh issue view 588 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `tests/abtest-report-grid.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "FAIL tests/abtest-report-walk.test.sh"`)

## Ordered edits
1. command: `git log --format=%s | grep -q "^fix(abt-u21a): walk the decided cells" && test -f tests/abtest-report-walk.test.sh && test ! -e tests/abtest-report-grid.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `tests/abtest-report-grid.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Walks the whole undecided half of the Decision table of eval/abtest/report.py: every N bucket (pilot, short,
# short with one arm past 5 rows, unequal, unequal large, top-up, N=5, N=10) x bad rows per arm (turn-cap,
# timeout, error: 0, 1 or 2) x provenance (one value or mixed) x Arm B stall / escaped defect, with usage-limit
# rows on every other cell. It runs the REAL score.py and report.py and asserts, per cell, the scorer outcome,
# the one Decision wording of the table (operator decisions OD-4, OD-12, OD-13, OD-14) and the ticket state.
# The wordings are written out below, not taken from report.py. No claude, no usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

python3 -I - "$T" "$REPO_ROOT/eval/abtest/score.py" "$REPO_ROOT/eval/abtest/report.py" << 'PYEOF' | tee "$T/out.txt"
import json, os, subprocess, sys

t, score_py, report_py = sys.argv[1:4]
passed_n = 0
failed_n = 0


def check(name, got, want):
    global passed_n, failed_n
    if got == want:
        passed_n += 1
        print(f"ok   {name}")
    else:
        failed_n += 1
        print(f"FAIL {name} (want {want!r}, got {got!r})")


def run(*args):
    return subprocess.run([sys.executable, "-I", *args], capture_output=True, text=True)


def row(ev, arm, rep, status="complete", passed=False, defects=0, harness="h"):
    ok = passed and status == "complete"
    return {
        "schema_version": 1, "run_id": f"{ev}/{arm}/uniform/{rep}", "eval_id": ev, "arm": arm,
        "model_policy": "uniform", "rep": rep, "started_at": "t", "plugin_version": None, "cli_version": "c",
        "fixture_profile": {}, "persona_config_sha": None, "completion_status": status, "result_subtype": None,
        "wall_clock_ms": 1000, "duration_api_ms": None, "total_cost_usd": None, "model_usage": {},
        "tokens_in": 100, "tokens_out": 0, "tokens_cache_write": 0, "tokens_cache_read": 0,
        "tokens_total": 100, "num_turns": 5, "subagent_spawns": 0, "tool_calls": 0,
        "human_interventions_required": 0,
        "checks": [{"id": "chk-a", "kind": "defect", "required": True, "cmd": "node --test x", "exit": 0 if ok else 1, "pass": ok}],
        "holdout_pass_rate": None, "defects_escaped": defects, "out_of_scope_lines": 0, "out_of_scope_files": 0,
        "commits": 1, "run_pass": ok, "process": {}, "blind_grades": {},
        "artifacts": {"stream": f"runs/{ev}_{arm}_{rep}/stream.jsonl", "diff": "d"},
        "harness_commit": harness, "plugin_commit": None, "prompt_sha": "p", "fixture_commit": "f",
    }


STUCK = ("turn-cap", "timeout", "error")
# bucket: rows in Arm A, rows in Arm B, the one Decision wording of an undecided cell without two bad rows
ADVICE = {
    "pilot": (1, 1, "NEEDS MORE DATA: a verdict exists only at N=5 per arm (short N: A=1 B=1); finish the first pass with run-matrix.sh --reps 5 --evals {ev}"),
    "short": (3, 5, "NEEDS MORE DATA: a verdict exists only at N=5 per arm (short N: A=3 B=5); finish the first pass with run-matrix.sh --reps 5 --evals {ev}"),
    "short-wide": (7, 3, "NEEDS MORE DATA: a verdict exists only at N=5 or at equal counts of 10 or more (short N: A=7 B=3); bring both arms to 10 with run-matrix.sh --reps 10 --evals {ev}"),
    "unequal": (5, 6, "NEEDS MORE DATA: the arms hold unequal usable rows (unequal N: A=5 B=6); bring both arms to 10 with run-matrix.sh --reps 10 --evals {ev}"),
    "unequal-large": (10, 12, "NEEDS MORE DATA: the arms hold unequal usable rows (unequal N: A=10 B=12); bring both arms to 12 with run-matrix.sh --reps 12 --evals {ev}"),
    "topup": (7, 7, "NEEDS MORE DATA: finish the top-up (top-up in progress: A=7 B=7, needs 10 per arm) with run-matrix.sh --reps 10 --evals {ev}"),
    "n5": (5, 5, None),
    "n10": (10, 10, None),
}
CELLS = []
for bucket, (na, nb, advice) in ADVICE.items():
    for bad_a, bad_b in ((0, 0), (1, 0), (0, 1), (2, 0), (0, 2), (1, 1)):
        for mixed in (False, True):
            for extra in ("none", "stall", "defect", "both"):
                stall = extra in ("stall", "both")
                if na < bad_a or nb < bad_b + stall or (mixed and na < 2):
                    continue
                CELLS.append(dict(bucket=bucket, na=na, nb=nb, advice=advice, bad_a=bad_a, bad_b=bad_b, mixed=mixed, stall=stall,
                                  defect=extra in ("defect", "both"),
                                  name=f"g-{bucket}-a{bad_a}b{bad_b}-{'mix' if mixed else 'one'}-{extra}"))

rows, log = [], ["# grid log", ""]
for idx, c in enumerate(CELLS):
~~~~
3. file: `tests/abtest-report-grid.test.sh`
   anchor: line matching `for idx, c in enumerate(CELLS):`
   indent: 0
   insert-after:
~~~~
    ev = c["ev"] = "e50-" + c["name"]
    for i in range(c["na"]):
        status = STUCK[i % 3] if i < c["bad_a"] else "complete"
        rows.append(row(ev, "A", i + 1, status, passed=i == c["bad_a"], harness="old" if c["mixed"] and i == c["na"] - 1 else "h"))
    for i in range(c["nb"]):
        status = STUCK[(i + 2) % 3] if i < c["bad_b"] else ("stalled-human" if c["stall"] and i == c["bad_b"] else "complete")
        rows.append(row(ev, "B", i + 1, status, passed=True, defects=1 if c["defect"] and i == 0 else 0))
    if idx % 2:
        rows += [row(ev, "B", 90 + i, "usage-limit", defects=3) for i in range(2)]
    log += [f"### E{idx + 1}: {c['name']} ({ev})", "", "- **Result**: pending", "- **Verdict**: pending", "- **Decision**: pending", ""]
with open(t + "/rows.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
with open(t + "/log.md", "w") as f:
    f.write("\n".join(log))

p = run(score_py, t + "/rows.jsonl", "--out-json", t + "/score.json")
check("score.py scores the grid rows", p.returncode, 0)
report = json.load(open(t + "/score.json"))
p = run(report_py, "fill-log", t + "/score.json", t + "/log.md", t + "/rows.jsonl")
check("fill-log exits 0 over the whole grid", p.returncode, 0)
p = run(report_py, "tickets", t + "/score.json", t + "/rows.jsonl", t + "/tickets")
check("tickets exits 0 over the whole grid", p.returncode, 0)
entries = {}
for block in open(t + "/log.md").read().split("### ")[1:]:
    entries[block.split("(")[1].split(")")[0]] = {line.split("**")[1]: line.split(": ", 1)[1] for line in block.split("\n") if line.startswith("- **")}

problems, covered = [], set()
for c in CELLS:
    ev, v = c["ev"], report["evals"][c["ev"]]
    decision = entries[ev]["Decision"]
    stuck = c["bad_a"] >= 2 or c["bad_b"] >= 2
    decided = c["bucket"] in ("n5", "n10") and not stuck and not c["mixed"]
    want_verdict = "not-superior" if c["stall"] else ("superior" if decided else "inconclusive")
    frags, absent = [], []
    if c["mixed"]:
        frags.append("RERUN: the rows mix provenance (mixed provenance: harness_commit)")
        absent += ["NEEDS MORE DATA", "NO MORE RUNS HELP"]
        (frags if stuck else absent).append("also keep it INCONCLUSIVE at every N (OD-12), unless the repeat replaces them")
    elif stuck:
        frags.append("NO MORE RUNS HELP: two or more turn-cap, timeout or error rows stay INCONCLUSIVE at every N (OD-12)")
        absent += ["NEEDS MORE DATA", "RERUN"]
        (absent if c["bucket"] in ("n5", "n10") else frags).append(f"first, but the bad rows (A {c['bad_a']}, B {c['bad_b']}) decide")
    elif not decided:
        frags.append(c["advice"].format(ev=ev))
        absent += ["NO MORE RUNS HELP", "RERUN"]
    else:
        absent += ["NEEDS MORE DATA", "NO MORE RUNS HELP", "RERUN"]
    (absent if (c["stall"] or not decided) else frags).append("recorded as a measured advantage")
    if c["stall"]:
        frags.append("Arm B stalled-human in 1 run(s)")
    if c["defect"]:
        frags.append("an Arm B run let a defect escape in 1 run(s)")
    ticket = c["stall"] or c["defect"]
    got = [v["outcome"], v["verdict"], "ticket filed" in decision, os.path.exists(f"{t}/tickets/{ev}.md")]
    want = ["WIN_B" if decided else "INCONCLUSIVE", want_verdict, ticket, ticket]
    if got != want:
        problems.append(f"{c['name']}: outcome, verdict, ticket in Decision, ticket file: want {want}, got {got}")
    problems += [f"{c['name']}: Decision lacks '{f}': {decision}" for f in frags if f not in decision]
    problems += [f"{c['name']}: Decision holds '{f}': {decision}" for f in absent if f in decision]
    if ticket and f"Decision: {decision}" not in open(f"{t}/tickets/{ev}.md").read().split("\n"):
        problems.append(f"{c['name']}: the ticket carries another Decision")
    covered.add((v["outcome"], v["verdict"]))
    covered.add(("reason", (v["outcome_reason"] or "").split(":")[0].split(" rows")[0][:20]))

check(f"the grid holds {len(CELLS)} cells", len(CELLS), 348)
check("every cell has the Decision wording and ticket state of the table", problems[:5], [])
check("the grid covers every undecided outcome and verdict pair", sorted(c for c in covered if c[0] != "reason"),
      sorted([("INCONCLUSIVE", "inconclusive"), ("INCONCLUSIVE", "not-superior"), ("WIN_B", "not-superior"), ("WIN_B", "superior")]))
check("the grid covers every undecided reason class", sorted(c[1] for c in covered if c[0] == "reason" and c[1]),
      sorted(["mixed provenance", "short N", "top-up in progress", "two or more turn-cap", "unequal N"]))
check("the usage-limit rows were excluded by the scorer", report["usage_limit_rows_excluded"], 2 * (len(CELLS) // 2))
sys.exit(1 if failed_n else 0)

PYEOF
rc=${PIPESTATUS[0]}
pass=$(grep -c '^ok   ' "$T/out.txt")
fail=$(grep -c '^FAIL ' "$T/out.txt")
~~~~
4. file: `tests/abtest-report-grid.test.sh`
   anchor: line matching `fail=$(grep -c '^FAIL ' "$T/out.txt")`
   indent: 0
   insert-after:
~~~~
echo "abtest-report-grid: $pass passed, $fail failed"
if [ "$rc" -eq 0 ] && [ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]; then
  echo "All abtest-report-grid checks passed."
  exit 0
fi
exit 1
~~~~
5. command: `chmod +x tests/abtest-report-grid.test.sh`
   expect: 0
6. file: `tests/validate.sh`
   anchor: line matching `echo "FAIL tests/abtest-report-walk.test.sh"`
   indent: 0
   before:
~~~~
  echo "FAIL tests/abtest-report-walk.test.sh"
  fail=1
fi
~~~~
   after:
~~~~
  echo "FAIL tests/abtest-report-walk.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-report-grid.test.sh: the undecided Decision table walked over N, bad rows, provenance and stalls (Bash, abt-u21a) =="
if bash tests/abtest-report-grid.test.sh > /dev/null; then
  echo "OK   tests/abtest-report-grid.test.sh"
else
  echo "FAIL tests/abtest-report-grid.test.sh"
  fail=1
fi
~~~~
7. command: `git add tests/abtest-report-grid.test.sh tests/validate.sh && git commit -m "fix(abt-u21a): grid the undecided Decision table over N, bad rows, provenance and stalls (#588)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/report.py` and `tests/abtest-report.test.sh` (round abt-u21a-fix3 landed them; this round adds a test beside them)
- `eval/abtest/score.py` and `eval/abtest/lib/` (the report and the tests read the scorer's output; the scorer's check order is not changed, see decision-table in Pre-resolved context)
- `CHANGELOG.md`, `docs/harness-glossary.md`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)
- `eval/abtest/results.jsonl`, `eval/reports/` and `docs/experiments/abtest-2026-10.md` (written by the operator unit abt-u21, not by a fix round)
- `tests/validate.sh` (every existing section stays; one insertion after the previous abtest-report section, nothing else)

## Acceptance criteria
1. run: `bash tests/abtest-report-grid.test.sh`
   exit: 0
   stdout: `All abtest-report-grid checks passed.`
   mutation: skip edit 4 (the last part of the grid test); the file ends before the heredoc terminator and the fragment is absent.
2. run: `bash tests/abtest-report-grid.test.sh | grep -c '^ok   every cell has the Decision wording and ticket state of the table$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, let data_action ignore the bad rows of Arm B (replace "stuck = bad_a >= 2 or bad_b >= 2 or" with "stuck = bad_a >= 2 or"), or revert the short-N advice to a fixed --reps 5, or drop the bad-row clause of the mixed-provenance RERUN; the cells g-short-a0b2-one-none, g-short-wide-a0b0-one-none or g-short-a2b0-mix-none print a table violation, the row prints FAIL and the count is 0 (exit 1).
   proof: scratch runs (str.replace on report.py, then the grid test): each of the three mutations failed this row; so did stuck taken from the scorer reason alone, a missing "the scorer names ... first" suffix and a fixed top-up target.
3. run: `bash tests/abtest-report-grid.test.sh | grep -c '^ok   the grid holds 348 cells$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, delete the "unequal-large" entry from ADVICE; the cell count changes, the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run (python str.replace deleting the entry, then the grid test): the row printed FAIL.
4. run: `bash tests/abtest-report-grid.test.sh | grep -c '^ok   the grid covers'`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, delete the "topup" entry from ADVICE; the reason coverage row prints FAIL and the count is 1 (exit 0, fragment 2 absent).
   proof: scratch run (python str.replace deleting the entry, then the grid test): the reason coverage row printed FAIL.
5. run: `bash tests/abtest-report-grid.test.sh | grep -c '^ok   the usage-limit rows were excluded by the scorer$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, replace "if idx % 2:" with "if idx % 3:"; the number of usage-limit rows no longer matches, the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run (python str.replace, then the grid test): the row printed FAIL.
6. run: `bash tests/abtest-report-grid.test.sh | grep -cE '^ok   (fill-log|tickets) exits 0 over the whole grid$'`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, make data_action skip the mixed-provenance branch (replace 'if reason.startswith("mixed provenance"):' with "if False:"); report.py stops with no wording, both rows print FAIL and the count is 0 (exit 1).
   proof: scratch run (str.replace on report.py, then the grid test): both rows printed FAIL.
7. run: `grep -c 'tests/abtest-report-grid' tests/validate.sh`
   exit: 0
   stdout: `4`
   mutation: skip edit 6 (the validate.sh section); stdout 0 and the exit is 1.
8. run: `test -x tests/abtest-report-grid.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 5; the file is not executable and nothing prints.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): grid the undecided' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `tests/abtest-report-grid.test.sh tests/validate.sh`
   mutation: skip edit 7 (the commit); no round commit exists and the run prints no-unit-commit with exit 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): grid the undecided' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; no round commit exists and the exit is 3.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u21a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- tests/abtest-report-grid.test.sh tests/validate.sh | grep -vcE "^[a-z]+\(abt-u21a\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the round commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- tests/abtest-report-grid.test.sh tests/validate.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 7; the changed files stay modified (or new files untracked) and are listed.

## Pre-resolved context
tdd: yes tests/abtest-report-grid.test.sh (criteria 1 to 9 are the red-then-green checks; the file does not exist at HEAD)
blast-radius: eval/abtest/report.py:198 tests/validate.sh:1489
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: the criteria that count commits or the tree (untagged tail, clean tree) pass at HEAD by design; the others are red at HEAD because tests/abtest-report-grid.test.sh and its commit do not exist.
performance: 348 cells, about 4000 rows through one score.py run, two fill-log runs and one tickets run; about 0.4 s in a scratch clone.
cell-table: ADVICE in the test lists the eight buckets with the literal advice wording of each; the oracle is the decision-table-v2 precedence (mixed provenance, then two or more bad rows, then the N advice). Decided cells (N=5 or 10, no bad pair, one provenance) must say neither NEEDS MORE DATA nor NO MORE RUNS HELP nor RERUN.
commit-message: fix(abt-u21a): grid the undecided Decision table over N, bad rows, provenance and stalls (#588)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
