Unit: abt-u21a

## Objective
eval/abtest/report.py fills the Result and Decision lines of the experiment log from a score report and writes one eval-finding ticket body per eval that is not superior, stalled in Arm B or let a defect escape; tests/abtest-report.test.sh passes over a synthetic score report and is registered in tests/validate.sh. One commit.

## Retrieval
GitHub issues: `gh issue view 588 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/report.py` (anchor: new file)
- `tests/abtest-report.test.sh` (anchor: new file)
- `tests/validate.sh` (anchor: line matching `echo "FAIL tests/abtest-blind.test.sh"`)

## Ordered edits
1. command: `test ! -e eval/abtest/report.py && test ! -e tests/abtest-report.test.sh && test -f eval/abtest/score.py && grep -qF "tests/abtest-blind.test.sh" tests/validate.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/report.py`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env python3
"""Turn a score report into the experiment-log lines and the eval-finding tickets.

  report.py fill-log SCORE_JSON EXPERIMENT_MD
  report.py tickets SCORE_JSON ROWS_JSONL OUT_DIR

fill-log rewrites the Result and Decision lines of each `### E<n>: ... (<eval-id>)`
entry from the score report (the numbers are never retyped); Verdict stays pending
for the operator, who judges the prediction. tickets writes OUT_DIR/<eval-id>.md for
every eval that is not superior, or whose Arm B stalled or let a defect escape.
"""
import json
import os
import re
import sys

HYPOTHESIS = {
    "e01-ambiguous-tax": "H3 (spec grilling resolves ambiguity from repo evidence)",
    "e02-preview-mutation": "H1 (the Writer/Reviewer split catches defects the writer's own tests miss)",
    "e03-rename-query": "H1 and H2 (blast radius, caller checks, scope discipline)",
    "e04-search-injection": "H1, H6 and H2 (security lens, gates, scope discipline)",
    "e05-tags-feature": "H4 and H8 (decomposition and its overhead)",
}
LOOK_AT = {
    "e01-ambiguous-tax": "spec-master grilling and the ubiquitous-language prose mode: did it read CONTEXT.md (check the spec-master transcript for the grep-first recipe)? A stall means spec-master returned Open Questions instead of self-resolving from evidence: tune the 'if a fact can be found by exploring, look it up' rule in grilling.",
    "e02-preview-mutation": "the reviewer 'Refute, don't rubber-stamp' and 'Run the checks yourself' bullets: did the reviewer build its own adversarial input or only re-run the writer's tests? Also the tdd skill preload for lead-programmer (did the red test exercise rounding?).",
    "e03-rename-query": "explorer grep-fallback quality, the reviewer 'caller two hops away' bullet, and the dispatch contract's Pre-resolved context (were all callers, including the string-keyed one, pre-resolved?).",
    "e04-search-injection": "the reviewer security lens, the roast-work advisory (heavy units only), and protected-paths.sh, which matches Write/Edit only, not a Bash sed -i: an Arm B edit to auth.js through Bash is a concrete finding for the hook.",
    "e05-tags-feature": "pathfinder slicing (did task-master produce six or more units with runnable criteria?), orchestrator batching (a second wave never dispatched is a bug), dispatch-hygiene warn logs; if only cost lost, candidates are task-master maxTurns, per-unit scribe dispatches and the review-join ceremony.",
}


def fmt(v):
    return "n/a" if v is None else f"{v:.2f}"


def result_line(e, v):
    o = v["overhead"]
    tally_b = ", ".join(f"{k} {n}" for k, n in v["status_tally_B"].items() if n)
    tally_a = ", ".join(f"{k} {n}" for k, n in v["status_tally_A"].items() if n)
    return (f"run_pass A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']} ({v['outcome']}); "
            f"R_tokens {fmt(o['R_tokens'])}, R_wall {fmt(o['R_wall'])}, R_turns {fmt(o['R_turns'])}; "
            f"B stalled-human {v['stalled_human_B']}; statuses A [{tally_a}], B [{tally_b}]; "
            f"rows in eval/abtest/results.jsonl, verdict {v['verdict']}"
            f"{' (' + v['label'] + ')' if v['label'] else ''}")


def decision_line(v):
    if v["verdict"] == "inconclusive":
        return "NEEDS MORE DATA: top up this eval to N=10 with run-matrix.sh --reps 10 --evals <eval-id>"
    if v["verdict"] == "superior":
        return "no action: recorded as a measured advantage"
    return "ticket filed under the eval-finding label (see the report); no change is shipped by this log"


def fill_log(score_path, md_path):
    report = json.load(open(score_path))
    lines = open(md_path).read().split("\n")
    current = None
    for i, line in enumerate(lines):
        m = re.match(r"### E\d+: .*\(([a-z0-9-]+)\)\s*$", line)
        if m:
            current = m.group(1)
        elif line.startswith("### "):
            current = None
        if current in report["evals"]:
            v = report["evals"][current]
            if line.startswith("- **Result**:"):
                lines[i] = f"- **Result**: {result_line(current, v)}"
            elif line.startswith("- **Decision**:"):
                lines[i] = f"- **Decision**: {decision_line(v)}"
    open(md_path, "w").write("\n".join(lines))
    return 0


def needs_ticket(v, rows):
    if v["verdict"] == "not-superior" or v["stalled_human_B"] > 0:
        return True
~~~~
3. file: `eval/abtest/report.py`
   anchor: line matching `        return True`
   indent: 0
   insert-after:
~~~~
    return any(r["arm"] == "B" and r["defects_escaped"] > 0 for r in rows)


def tickets(score_path, rows_path, out_dir):
    report = json.load(open(score_path))
    rows = [json.loads(l) for l in open(rows_path) if l.strip()]
    os.makedirs(out_dir, exist_ok=True)
    written = 0
    for eval_id, v in report["evals"].items():
        rs = [r for r in rows if r["eval_id"] == eval_id and r["completion_status"] != "usage-limit"]
        if not needs_ticket(v, rs):
            continue
        failed = []
        for r in rs:
            for c in r["checks"]:
                if not c["pass"]:
                    failed.append(f"- {r['run_id']}: {c['id']} ({c['kind']}) cmd: {c['cmd']}")
        streams = [f"- {r['run_id']}: {r['artifacts']['stream']}" for r in rs if r["arm"] == "B"]
        body = [f"[eval-finding] {eval_id}: {v['verdict']}", "",
                f"Eval: {eval_id}. Hypothesis: {HYPOTHESIS.get(eval_id, 'see the design')}.",
                f"Outcome: {v['outcome']} (A {v['k_A']}/{v['n_A']}, B {v['k_B']}/{v['n_B']}); {result_line(eval_id, v).split('; ', 1)[1]}", "",
                "Rows: " + ", ".join(v["run_ids"]), "", "Failed checks (verbatim):"]
        body += failed or ["- none"]
        body += ["", "Where to look (design section 3):", LOOK_AT.get(eval_id, "see the design"), "",
                 "Arm B transcripts:"] + (streams or ["- none"]) + [""]
        with open(os.path.join(out_dir, f"{eval_id}.md"), "w") as f:
            f.write("\n".join(body))
        written += 1
    print(f"tickets: wrote {written}")
    return 0


def main(argv):
    if len(argv) == 3 and argv[0] == "fill-log":
        return fill_log(argv[1], argv[2])
    if len(argv) == 4 and argv[0] == "tickets":
        return tickets(argv[1], argv[2], argv[3])
    print("usage: report.py fill-log SCORE_JSON EXPERIMENT_MD | tickets SCORE_JSON ROWS_JSONL OUT_DIR", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
~~~~
4. file: `tests/abtest-report.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Tests eval/abtest/report.py (experiment-log filling and eval-finding tickets)
# over a synthetic score report. Needs eval/abtest/score.py. No claude, no usage.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCORE="$REPO_ROOT/eval/abtest/score.py"
REPORT="$REPO_ROOT/eval/abtest/report.py"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

python3 -I - "$T" << 'PYEOF'
import json, sys

t = sys.argv[1]

def row(ev, arm, rep, passed, status="complete", defects=0, tokens=100, checks=None):
    return {
        "schema_version": 1, "run_id": f"{ev}/{arm}/uniform/{rep}", "eval_id": ev, "arm": arm,
        "model_policy": "uniform", "rep": rep, "started_at": "t", "harness_commit": "h",
        "plugin_commit": None, "plugin_version": None, "cli_version": "c", "fixture_commit": "f",
        "fixture_profile": {}, "prompt_sha": "p", "persona_config_sha": None,
        "completion_status": status, "result_subtype": None, "wall_clock_ms": 1000,
        "duration_api_ms": None, "total_cost_usd": None, "model_usage": {}, "tokens_in": 1,
        "tokens_out": 1, "tokens_cache_write": 0, "tokens_cache_read": 0, "tokens_total": tokens,
        "num_turns": 5, "subagent_spawns": 0, "tool_calls": 0, "human_interventions_required": 0,
        "checks": checks or [], "holdout_pass_rate": None, "defects_escaped": defects,
        "out_of_scope_lines": 0, "out_of_scope_files": 0, "commits": 1,
        "run_pass": passed and status == "complete", "process": {}, "blind_grades": {},
        "artifacts": {"stream": f"runs/{ev}_{arm}_{rep}/stream.jsonl", "diff": "d"},
    }

FAILED = [{"id": "hold-a", "kind": "defect", "required": True, "cmd": "node --test x", "exit": 1, "pass": False}]
rows = []
def add(ev, a_pass, b_pass, b_defects=0, b_checks=None):
    for i in range(5):
        rows.append(row(ev, "A", i + 1, i < a_pass))
        rows.append(row(ev, "B", i + 1, i < b_pass, defects=b_defects, checks=b_checks))

add("e01-ambiguous-tax", 4, 1, b_checks=FAILED)
add("e02-preview-mutation", 1, 4, b_defects=1)
add("e03-rename-query", 3, 4)
add("e04-search-injection", 1, 5)
for r in rows:
    if r["eval_id"] == "e04-search-injection" and r["arm"] == "B" and r["rep"] == 5:
        r["completion_status"], r["run_pass"] = "stalled-human", False
add("e05-tags-feature", 3, 3)
with open(t + "/rows.jsonl", "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
with open(t + "/log.md", "w") as f:
    f.write("""# log

### E1: ambiguous (e01-ambiguous-tax)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E2: preview (e02-preview-mutation)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

### E3: rename (e03-rename-query)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending
""")
PYEOF
python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/score.json" > /dev/null
~~~~
5. file: `tests/abtest-report.test.sh`
   anchor: line matching `python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/score.json" > /dev/null`
   indent: 0
   insert-after:
~~~~

python3 "$REPORT" fill-log "$T/score.json" "$T/log.md"; rc=$?
check "fill-log exits 0" "$rc" "0"
check "the E1 result line carries the pass counts" "$(grep -c '^- \*\*Result\*\*: run_pass A 4/5, B 1/5 (WIN_A)' "$T/log.md")" "1"
check "the verdict lines stay pending for the operator" "$(grep -c '^- \*\*Verdict\*\*: pending' "$T/log.md")" "3"
check "a not-superior eval points at a ticket" "$(grep -c 'ticket filed under the eval-finding label' "$T/log.md")" "1"
check "a superior eval records no action" "$(grep -c '^- \*\*Decision\*\*: no action' "$T/log.md")" "1"
check "an inconclusive eval asks for more data" "$(grep -c '^- \*\*Decision\*\*: NEEDS MORE DATA' "$T/log.md")" "1"
check "entries outside the report are left alone" "$(grep -c 'e04\|e05' "$T/log.md")" "0"

python3 "$REPORT" tickets "$T/score.json" "$T/rows.jsonl" "$T/tickets" > "$T/t.txt"; rc=$?
check "tickets exits 0" "$rc" "0"
check "tickets for the losing, defect-escaping, stalling and tied-without-edge evals" "$(ls "$T/tickets" | paste -sd' ')" "e01-ambiguous-tax.md e02-preview-mutation.md e04-search-injection.md e05-tags-feature.md"
check "an inconclusive eval gets no ticket" "$(test -e "$T/tickets/e03-rename-query.md" && echo yes || echo no)" "no"
check "the ticket title line names the eval and verdict" "$(head -n1 "$T/tickets/e01-ambiguous-tax.md")" "[eval-finding] e01-ambiguous-tax: not-superior"
check "the ticket quotes the failed check verbatim" "$(grep -c 'e01-ambiguous-tax/B/uniform/1: hold-a (defect) cmd: node --test x' "$T/tickets/e01-ambiguous-tax.md")" "1"
check "the ticket lists Arm B transcripts" "$(grep -c 'runs/e01-ambiguous-tax_B_1/stream.jsonl' "$T/tickets/e01-ambiguous-tax.md")" "1"
check "the ticket carries the design's look-at entry" "$(grep -c 'spec-master grilling' "$T/tickets/e01-ambiguous-tax.md")" "1"
check "a stall ticket exists for the winning eval that stalled" "$(head -n1 "$T/tickets/e04-search-injection.md")" "[eval-finding] e04-search-injection: not-superior"

python3 "$REPORT" bogus > /dev/null 2>&1
check "a bad command exits 2" "$?" "2"

echo "abtest-report: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-report checks passed."
exit "$fail"
~~~~
6. command: `chmod +x eval/abtest/report.py tests/abtest-report.test.sh`
   expect: 0
7. file: `tests/validate.sh`
   anchor: line matching `echo "FAIL tests/abtest-blind.test.sh"`
   indent: 0
   before:
~~~~
  echo "FAIL tests/abtest-blind.test.sh"
  fail=1
fi
~~~~
   after:
~~~~
  echo "FAIL tests/abtest-blind.test.sh"
  fail=1
fi

echo
echo "== tests/abtest-report.test.sh: experiment-log filling and eval-finding tickets (Bash, abt-u21a) =="
if bash tests/abtest-report.test.sh > /dev/null; then
  echo "OK   tests/abtest-report.test.sh"
else
  echo "FAIL tests/abtest-report.test.sh"
  fail=1
fi
~~~~
8. command: `git add eval/abtest/report.py tests/abtest-report.test.sh tests/validate.sh && git commit -m "feat(abt-u21a): report and ticket tooling with a merge-gate test (#588)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/score.py` and `eval/abtest/lib/` (the report reads the score report; it never edits the scorer)
- `docs/experiments/abtest-2026-10.md` (abt-u16 owns it; the test uses its own two-entry copy)
- `tests/validate.sh` (every existing section stays; one insertion after the abtest-blind section, nothing else)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-report.test.sh`
   exit: 0
   stdout: `All abtest-report checks passed.`
   mutation: skip edit 3 (the last part of report.py, which holds main); the rows FAIL, the script exits non-zero and the fragment is absent.
2. run: `python3 -I eval/abtest/report.py bogus 2>&1 | grep -c usage`
   exit: 0
   stdout: `1`
   mutation: skip edit 3; main is missing, nothing prints and stdout is 0.
3. run: `grep -c '^def ' eval/abtest/report.py`
   exit: 0
   stdout: `7`
   mutation: skip edit 3; main is gone, so the count is lower.
4. run: `grep -c 'tests/abtest-report' tests/validate.sh`
   exit: 0
   stdout: `4`
   mutation: skip edit 7 (the validate.sh insertion); stdout 0 and the exit is 1.
5. run: `test -x eval/abtest/report.py && test -x tests/abtest-report.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 6; the files are not executable and nothing prints.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u21a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/report.py tests/abtest-report.test.sh tests/validate.sh`
   mutation: skip edit 8 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u21a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u21a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/report.py tests/abtest-report.test.sh tests/validate.sh | grep -vcE "^[a-z]+\(abt-u21a\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest/report.py tests/abtest-report.test.sh tests/validate.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-report.test.sh (criterion 1 is the red-then-green check; neither file exists at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 9 (the scoped clean-tree check) passes at HEAD by design; it turns red only when the commit step is skipped.
depends-on: abt-u14 (score.py) and abt-u17 (the abtest sections in validate.sh) must have landed; edit 1 checks for them and STOPs otherwise.
no-real-claude: nothing here runs the claude CLI; the test builds synthetic rows in a temp directory.
commit-message: feat(abt-u21a): report and ticket tooling with a merge-gate test (#588)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
