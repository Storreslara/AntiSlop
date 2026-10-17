Unit: abt-u14b

## Objective
score.py calls an eval INCONCLUSIVE with the reason mixed provenance: <fields> when the usable rows of one arm differ in harness_commit, plugin_commit, prompt_sha or fixture_commit (null is one value); it stops with a named error and exit 1 when two eval ids share the e02, e04 or e07 prefix; and tests/abtest-score.test.sh gains rows for every provenance field and arm, for the six survivors of the abt-u14 re-review (cache reads outside tokens_total, E2 present with E4 absent, e09-typo in the cost evals, no complete arm A run is never superior, a one-arm eval does not crash, a stall on an undecided outcome), and the PYTHONDONTWRITEBYTECODE rule; the suite goes from 158 to 190 rows. One commit.

## Retrieval
GitHub issues: `gh issue view 605 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/score.py` (anchor: line matching `COST_EVALS = (`)
- `tests/abtest-score.test.sh` (anchor: line matching `sadd(rows, "e09-typo", "P", "P")`)

## Ordered edits
1. command: `test -f eval/abtest/score.py && test -f tests/abtest-score.test.sh && ! grep -q "PROVENANCE" eval/abtest/score.py && ! grep -q "y-prov" tests/abtest-score.test.sh && grep -q "OD-14" docs/plans/antislop-vs-fable-evals/operator-decisions.md && grep -q "OD-13" docs/plans/antislop-vs-fable-evals/operator-decisions.md && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/score.py`
   anchor: line matching `COST_EVALS = (`
   indent: 0
   insert-after:
~~~~
# OD-14: the rows of one arm of one eval must come from one harness, one plugin checkout, one prompt and one fixture.
PROVENANCE = ("harness_commit", "plugin_commit", "prompt_sha", "fixture_commit")
CORE_PREFIXES = ("e02", "e04", "e07")
~~~~
3. file: `eval/abtest/score.py`
   anchor: line matching `def summarize_eval(eval_id, rows):`
   indent: 0
   before:
~~~~
def summarize_eval(eval_id, rows):
    ra = [r for r in rows if r["arm"] == "A"]
    rb = [r for r in rows if r["arm"] == "B"]
    out, ka, kb, p, rule, reason = outcome(ra, rb)
~~~~
   after:
~~~~
def mixed_provenance(rows_a, rows_b):
    """The PROVENANCE fields on which the rows of one arm disagree (null counts as one value)."""
    return [k for k in PROVENANCE
            if any(len({json.dumps(r.get(k)) for r in rows}) > 1 for rows in (rows_a, rows_b))]


def summarize_eval(eval_id, rows):
    ra = [r for r in rows if r["arm"] == "A"]
    rb = [r for r in rows if r["arm"] == "B"]
    out, ka, kb, p, rule, reason = outcome(ra, rb)
    mixed = mixed_provenance(ra, rb)
    if mixed:
        out, rule, reason = "INCONCLUSIVE", None, "mixed provenance: " + ",".join(mixed)
~~~~
4. file: `eval/abtest/score.py`
   anchor: line matching `    evals = {e: summarize_eval(e, rs)`
   indent: 0
   before:
~~~~
    evals = {e: summarize_eval(e, rs) for e, rs in sorted(by_eval.items())}
~~~~
   after:
~~~~
    for prefix in CORE_PREFIXES:
        clash = sorted(e for e in by_eval if e[:3] == prefix)
        if len(clash) > 1:
            raise SystemExit(f"score: eval ids {clash} share the prefix {prefix!r}; the core condition needs one id per eval")
    evals = {e: summarize_eval(e, rs) for e, rs in sorted(by_eval.items())}
~~~~
5. file: `tests/abtest-score.test.sh`
   anchor: line matching `set -u`
   indent: 0
   insert-after:
~~~~
export PYTHONDONTWRITEBYTECODE=1
~~~~
6. file: `tests/abtest-score.test.sh`
   anchor: line matching `import importlib.util, sys`
   indent: 0
   insert-after:
~~~~
sys.dont_write_bytecode = True
~~~~
7. file: `tests/abtest-score.test.sh`
   anchor: line matching `sadd(rows, "e09-typo", "P", "P")`
   indent: 0
   insert-after:
~~~~
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
~~~~
8. file: `tests/abtest-score.test.sh`
   anchor: line matching `check "the retired budget status is named"`
   indent: 0
   insert-after:
~~~~
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
~~~~
9. file: `tests/abtest-score.test.sh`
   anchor: line matching `labels = {e: v["label"] for e, v in rep["evals"].items()} if rep else {}`
   indent: 0
   insert-after:
~~~~
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
~~~~
10. command: `git add eval/abtest/score.py tests/abtest-score.test.sh && git commit -m "fix(abt-u14b): scorer calls an eval with mixed provenance INCONCLUSIVE and the tests kill the six re-review survivors (#605)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/lib/` and `eval/abtest/run-matrix.sh` (the runner side of OD-14 is abt-u12c)
- `eval/abtest/report.py` and `eval/reports/` (abt-u21a owns the report tooling)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/antislop-vs-fable-evals/operator-decisions.md` and the rest of `docs/plans/` (OD-13 and OD-14 are already written; never edit a plan by hand)

## Acceptance criteria
1. run: `bash tests/abtest-score.test.sh`
   exit: 0
   stdout: `All abtest-score checks passed.`
   mutation: skip edit 3 (the provenance override); the provenance rows FAIL, the script exits non-zero and the fragment is absent.
   proof: mutation matrix of 31 single edits, run in a scratch copy of the finished change, each making the suite exit non-zero: P1 drop one of the four provenance fields (harness_commit, plugin_commit, prompt_sha, fixture_commit); P2 reorder them; P3 and P4 check only arm A or only arm B; P5 need three values; P6 change the joiner; P7 change the reason text; P8 skip the override; P9 keep the old rule; P10 return TIE instead of INCONCLUSIVE; P11 compare only the first character; C1 drop the e02, e04 or e07 prefix from the clash check; C2 need three ids; C3 change the message; S1 count tokens_cache_read in tokens_total; S2 accept one core eval; S3 drop e05-tags-feature, e08-stable-cursor or e09-typo from the cost evals; S4 let a missing arm A cost ratio read as superior; S5 remove the None guard of the quality edge; S6 and S7 let the stall override skip an undecided outcome; B1 remove the export, B2 remove the bytecode flag, B3 export 0
2. run: `bash tests/abtest-score.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `190`
   mutation: skip edit 3; the provenance rows FAIL and the count drops below 190.
3. run: `bash tests/abtest-score.test.sh | grep -c '^ok   a stale harness commit in arm A is mixed provenance'`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; the row prints FAIL and the count is 0 (exit 1).
4. run: `bash tests/abtest-score.test.sh | grep -c -e '^ok   two e02 ids stop the scorer with exit 1' -e '^ok   two e04 ids stop the scorer with exit 1' -e '^ok   two e07 ids stop the scorer with exit 1'`
   exit: 0
   stdout: `3`
   mutation: skip edit 4 (the prefix check); the scorer scores the clash, the three rows print FAIL and the count is 0 (exit 1).
5. run: `grep -c '^PROVENANCE = ' eval/abtest/score.py`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the tuple is absent, stdout 0 and the exit is 1.
6. run: `rm -rf eval/abtest/__pycache__; bash tests/abtest-score.test.sh > /dev/null; ls eval/abtest/__pycache__ 2> /dev/null | wc -l`
   exit: 0
   stdout: `0`
   mutation: skip edit 6 (the bytecode flag of the Fisher checker); the test imports score.py with bytecode on and leaves score.cpython in eval/abtest/__pycache__, stdout 1.
7. run: `bash tests/abtest-score.test.sh | grep -c '^ok   the test exports PYTHONDONTWRITEBYTECODE'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the variable is unset, the row prints FAIL and the count is 0 (exit 1).
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u14b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/score.py tests/abtest-score.test.sh`
   mutation: skip edit 10 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u14b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 10; no unit commit exists and the exit is 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u14b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/score.py tests/abtest-score.test.sh | grep -vcE "^[a-z]+\(abt-u14b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- eval/abtest/score.py tests/abtest-score.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-score.test.sh (criteria 2 to 7 are the red-then-green checks: the provenance rows, the prefix rows and the bytecode rule do not exist at HEAD)
blast-radius: eval/abtest/score.py:177, eval/abtest/score.py:228, tests/abtest-score.test.sh:5
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 passes at HEAD only before the new rows exist, and criterion 11 (the scoped clean-tree check) passes at HEAD by design; criteria 2 to 7 fail at HEAD.
extends-landed-code: abt-u14 is on master (f4fe9465); every anchor is a line of that commit. score.py gains one constant block, one helper and a three-line override in summarize_eval, and a four-line check in score(); the test file gains two lines near the top, one scenario block, and one checker block after the last row.
od-14: PROVENANCE (operator decision). For each eval and arm, over the usable rows of the reported policy (usage-limit rows are already excluded), the rows must share one value of each of harness_commit, plugin_commit, prompt_sha and fixture_commit; a null plugin_commit counts as one value, so an arm A group of nulls is consistent. Otherwise the outcome is INCONCLUSIVE with outcome_rule null and outcome_reason "mixed provenance: <fields>" (the differing fields, in that order, comma-separated); k_A, k_B and the Fisher p are still reported and the markdown shows the reason. The check is per arm; it does not compare one arm with the other.
od-13: the stall override of OD-12(a) applies to an undecided outcome as well: a pilot (short N) or a 1-run gap with a stalled-human row in arm B has outcome INCONCLUSIVE and verdict not-superior. Rows pin it (y-pilot-stall, y-diff1-stall, y-prov-stall).
prefix-uniqueness: two eval ids that start with e02, e04 or e07 stop the scorer with exit 1 and the message score: eval ids [...] share the prefix ...; the core condition (no WIN_A on E2 and E4) needs one id per eval. Other prefixes are not checked, because the synthetic ids in this test share prefixes on purpose.
bytecode: the test exports PYTHONDONTWRITEBYTECODE=1 and sets sys.dont_write_bytecode before it imports score.py (python -I ignores the variable), so it never writes eval/abtest/__pycache__.
fail-closed: every row compares an explicit expected value; a crash or empty output reads as FAILURE.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u14b): scorer calls an eval with mixed provenance INCONCLUSIVE and the tests kill the six re-review survivors (#605)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u14b (#605)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
