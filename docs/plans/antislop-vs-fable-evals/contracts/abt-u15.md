Unit: abt-u15

## Objective
eval/abtest/blind.sh builds a blinded grading set for E1 (random item ids, redacted report, filtered diff, sealed id-to-arm map outside blind/, grades template) and --unseal prints the per-arm tally; tests/abtest-blind.test.sh passes over synthetic run directories. One commit.

## Retrieval
GitHub issues: `gh issue view 584 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/blind.sh` (anchor: new file)
- `eval/abtest/lib/blind.py` (anchor: new file)
- `tests/abtest-blind.test.sh` (anchor: new file)

## Ordered edits
1. command: `test ! -e eval/abtest/blind.sh && test ! -e eval/abtest/lib/blind.py && test ! -e tests/abtest-blind.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/blind.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Blinded grading set for the judgment-graded item.
# Usage: blind.sh RESULTS_JSONL OUT_DIR [--eval ID]   build OUT_DIR/blind/<id>/ for each run
#        blind.sh --unseal OUT_DIR GRADES_CSV         print the per-arm tally after grading
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${1:-}" = "--unseal" ]; then
  shift
  exec python3 -I "$HERE/lib/blind.py" unseal "$@"
fi
exec python3 -I "$HERE/lib/blind.py" build "$@"
~~~~
3. file: `eval/abtest/lib/blind.py`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env python3
"""Blind the judgment-graded item (E1: does ASSUMPTIONS.md cite the glossary?).

  blind.py build RESULTS_JSONL OUT_DIR [--eval e01-ambiguous-tax]
  blind.py unseal OUT_DIR GRADES_CSV

build writes OUT_DIR/blind/<random-id>/{diff.patch,report.md}, a grades template,
and the id-to-arm map in OUT_DIR/sealed-map.json (outside blind/, never opened by
the grader). unseal joins the graded csv to the map and prints one tally per arm.
"""
import argparse
import csv
import json
import os
import re
import secrets
import sys

PERSONAS = r"orchestrator|spec-master|task-master|lead-programmer|reviewer|scribe|explorer|milestone-auditor|researcher|agent-auditor"
REDACT = [
    (re.compile(rf"\b(?:{PERSONAS})\b", re.IGNORECASE), "[agent]"),
    (re.compile(r"^Unit: .*$", re.MULTILINE), "[line removed]"),
    (re.compile(r"^STATUS: .*$", re.MULTILINE), "[line removed]"),
    (re.compile(r"\([A-Za-z0-9]+(?:-[A-Za-z0-9._#]+)+\)"), "(scope)"),
]
DROP = (re.compile(r"\.(pass|fail)$"), re.compile(r"^\.claude/"), re.compile(r"^docs/plans/"))


def redact(text):
    for pattern, repl in REDACT:
        text = pattern.sub(repl, text)
    return text


def filter_diff(diff):
    keep, drop = [], False
    for chunk in re.split(r"(?m)^(?=diff --git )", diff):
        m = re.match(r"diff --git a/(\S+) b/", chunk)
        if m and any(p.search(m.group(1)) for p in DROP):
            continue
        keep.append(chunk)
    return "".join(keep)


def build(rows_path, out, eval_id):
    with open(rows_path) as f:
        rows = [json.loads(l) for l in f if l.strip()]
    rows = [r for r in rows if r["eval_id"] == eval_id and r["completion_status"] != "usage-limit"]
    blind_dir = os.path.join(out, "blind")
    os.makedirs(blind_dir, exist_ok=True)
    sealed, used = {}, set()
    for r in rows:
        while True:
            item = secrets.token_hex(4)
            if item not in used:
                used.add(item)
                break
        run_dir = os.path.dirname(r["artifacts"]["stream"])
        with open(r["artifacts"]["diff"]) as f:
            diff = filter_diff(f.read())
        with open(os.path.join(run_dir, "summary.json")) as f:
            text = json.load(f).get("result_text") or ""
        item_dir = os.path.join(blind_dir, item)
        os.makedirs(item_dir)
        with open(os.path.join(item_dir, "diff.patch"), "w") as f:
            f.write(diff)
        with open(os.path.join(item_dir, "report.md"), "w") as f:
            f.write(redact(text) + "\n")
        sealed[item] = {"run_id": r["run_id"], "arm": r["arm"]}
    with open(os.path.join(out, "sealed-map.json"), "w") as f:
        json.dump(sealed, f, indent=2, sort_keys=True)
        f.write("\n")
    with open(os.path.join(out, "grades-template.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "assumptions_cites_glossary"])
        for item in sorted(sealed):
            w.writerow([item, ""])
    print(f"blind: wrote {len(sealed)} items to {blind_dir}; map sealed at {os.path.join(out, 'sealed-map.json')}")
~~~~
4. file: `eval/abtest/lib/blind.py`
   anchor: line matching `    print(f"blind: wrote {len(sealed)} items to {blind_dir}; map sealed at {os.path.join(out, 'sealed-map.json')}")`
   indent: 0
   insert-after:
~~~~
    return 0


def unseal(out, grades_path):
    with open(os.path.join(out, "sealed-map.json")) as f:
        sealed = json.load(f)
    tally = {"A": [0, 0], "B": [0, 0]}
    ungraded = 0
    with open(grades_path, newline="") as f:
        for row in csv.DictReader(f):
            grade = (row.get("assumptions_cites_glossary") or "").strip()
            if grade not in ("0", "1"):
                ungraded += 1
                continue
            arm = sealed[row["id"]]["arm"]
            tally[arm][1] += 1
            tally[arm][0] += int(grade)
    print(f"unsealed: A assumptions_cites_glossary={tally['A'][0]}/{tally['A'][1]} "
          f"B assumptions_cites_glossary={tally['B'][0]}/{tally['B'][1]} ungraded={ungraded}")
    return 0


def main(argv):
    ap = argparse.ArgumentParser(prog="blind.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("rows")
    b.add_argument("out")
    b.add_argument("--eval", default="e01-ambiguous-tax")
    u = sub.add_parser("unseal")
    u.add_argument("out")
    u.add_argument("grades")
    a = ap.parse_args(argv)
    if a.cmd == "build":
        return build(a.rows, a.out, a.eval)
    return unseal(a.out, a.grades)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
~~~~
5. file: `tests/abtest-blind.test.sh`
   anchor: new file
   indent: 0
   insert-after:
~~~~
#!/usr/bin/env bash
# Tests eval/abtest/blind.sh over synthetic run directories: the grader's files
# carry no arm identifiers, the map is sealed outside blind/, ids are random,
# and unseal tallies the grades per arm.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLIND="$REPO_ROOT/eval/abtest/blind.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

# Four E1 runs, one usage-limit run and one run of another eval. The marker
# directory name is built from two parts so no shell text names it.
python3 -I - "$T" << 'PYEOF'
import json, os, sys

t = sys.argv[1]
MARK = ".claude/rev" "iewed/e01.pass"
DIFF = f"""diff --git a/ASSUMPTIONS.md b/ASSUMPTIONS.md
new file mode 100644
--- /dev/null
+++ b/ASSUMPTIONS.md
@@ -0,0 +1 @@
+- Tax follows CONTEXT.md.
diff --git a/src/pricing.js b/src/pricing.js
--- a/src/pricing.js
+++ b/src/pricing.js
@@ -1 +1 @@
-a
+b
diff --git a/.claude/agents/reviewer.md b/.claude/agents/reviewer.md
+secret persona file
diff --git a/docs/plans/p.md b/docs/plans/p.md
+plan text
diff --git a/{MARK} b/{MARK}
+PASS e01
"""
TEXT = "The reviewer approved it.\nUnit: abt-x\nSTATUS: complete\nfeat(e01-ambiguous-tax): done by lead-programmer\nAll finished."
rows = []
for name, ev, arm, status in [("r1", "e01-ambiguous-tax", "A", "complete"), ("r2", "e01-ambiguous-tax", "B", "complete"),
                              ("r3", "e01-ambiguous-tax", "A", "complete"), ("r4", "e01-ambiguous-tax", "B", "stalled-human"),
                              ("r5", "e01-ambiguous-tax", "A", "usage-limit"), ("r6", "e02-preview-mutation", "B", "complete")]:
    d = os.path.join(t, "runs", name)
    os.makedirs(d)
    with open(os.path.join(d, "summary.json"), "w") as f:
        json.dump({"result_text": TEXT}, f)
    with open(os.path.join(d, "diff.patch"), "w") as f:
        f.write(DIFF)
    open(os.path.join(d, "stream.jsonl"), "w").close()
    rows.append({"run_id": f"{ev}/{arm}/uniform/{name}", "eval_id": ev, "arm": arm, "completion_status": status,
                 "artifacts": {"stream": os.path.join(d, "stream.jsonl"), "diff": os.path.join(d, "diff.patch")}})
with open(os.path.join(t, "rows.jsonl"), "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
PYEOF

OUT="$T/out"
bash "$BLIND" "$T/rows.jsonl" "$OUT" > "$T/build.txt"; rc=$?
check "build exits 0" "$rc" "0"
check "one item per usable run of the eval" "$(ls "$OUT/blind" | wc -l | tr -d ' ')" "4"
check "item ids are 8 hex characters" "$(ls "$OUT/blind" | grep -cE '^[0-9a-f]{8}$')" "4"
check "no arm identifier leaks into the grader files" "$(grep -rcE 'reviewer|lead-programmer|Unit: |STATUS: |\(e[0-9]{2}-' "$OUT/blind" | grep -vc ':0$')" "0"
check "the diff keeps the ASSUMPTIONS.md section" "$(cat "$OUT"/blind/*/diff.patch | grep -c '^+- Tax follows CONTEXT.md.')" "4"
check "the diff drops persona files, plans and markers" "$(cat "$OUT"/blind/*/diff.patch | grep -cE 'claude|docs/plans|PASS e01|secret persona')" "0"
check "the report keeps neutral text" "$(cat "$OUT"/blind/*/report.md | grep -c 'All finished.')" "4"
check "the sealed map sits outside blind/" "$(test -f "$OUT/sealed-map.json" && echo yes)" "yes"
check "the map names two runs per arm" "$(python3 -I -c 'import json,sys;m=json.load(open(sys.argv[1])).values();print(sorted(v["arm"] for v in m))' "$OUT/sealed-map.json")" "['A', 'A', 'B', 'B']"
check "the grades template has a header and four rows" "$(wc -l < "$OUT/grades-template.csv" | tr -d ' ')" "5"
bash "$BLIND" "$T/rows.jsonl" "$T/out2" > /dev/null
check "ids differ between builds" "$(ls "$OUT/blind" "$T/out2/blind" | grep -E '^[0-9a-f]{8}$' | sort | uniq -d | wc -l | tr -d ' ')" "0"

# Grade: 1 for an item whose map arm is B, 0 for A, but leave the first item ungraded.
python3 -I - "$OUT" << 'PYEOF'
import csv, json, sys
~~~~
6. file: `tests/abtest-blind.test.sh`
   anchor: line matching `import csv, json, sys`
   indent: 0
   insert-after:
~~~~

out = sys.argv[1]
m = json.load(open(out + "/sealed-map.json"))
with open(out + "/grades.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "assumptions_cites_glossary"])
    for i, item in enumerate(sorted(m)):
        w.writerow([item, "" if i == 0 else ("1" if m[item]["arm"] == "B" else "0")])
PYEOF
tally="$(bash "$BLIND" --unseal "$OUT" "$OUT/grades.csv")"
case "$tally" in
  unsealed:*ungraded=1) ok "unseal prints a tally and counts the ungraded item" ;;
  *) bad "unseal output was '$tally'" ;;
esac

echo "abtest-blind: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-blind checks passed."
exit "$fail"
~~~~
7. command: `chmod +x eval/abtest/blind.sh eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   expect: 0
8. command: `git add eval/abtest/blind.sh eval/abtest/lib/blind.py tests/abtest-blind.test.sh && git commit -m "feat(abt-u15): blinded grading set for the E1 judgment item (#584)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/lib/stream.py`, `eval/abtest/lib/make-row.py` (other units own them)
- `eval/abtest/run-matrix.sh`, `eval/abtest/arms/`, `eval/abtest/checks/`, `eval/abtest/fixtures/` (other units own them)
- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-blind.test.sh`
   exit: 0
   stdout: `All abtest-blind checks passed.`
   mutation: skip edit 4 (the last part of blind.py, which holds main); build prints nothing, the rows FAIL and the fragment is absent.
2. run: `bash eval/abtest/blind.sh 2>/dev/null; echo "exit=$?"`
   exit: 0
   stdout: `exit=2`
   mutation: skip edit 2 (blind.sh); bash cannot open the file and prints exit=127.
3. run: `grep -c '^def ' eval/abtest/lib/blind.py`
   exit: 0
   stdout: `5`
   mutation: skip edit 4; main is gone, so the count is lower.
4. run: `test -x eval/abtest/blind.sh && test -x eval/abtest/lib/blind.py && test -x tests/abtest-blind.test.sh && echo exec-ok`
   exit: 0
   stdout: `exec-ok`
   mutation: skip edit 7; the files are not executable and nothing prints.
5. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/blind.sh eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   mutation: skip edit 8 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; no unit commit exists and the exit is 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/blind.sh eval/abtest/lib/blind.py tests/abtest-blind.test.sh | grep -vcE "^[a-z]+\(abt-u15\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
8. run: `git status --porcelain -- eval/abtest/blind.sh eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-blind.test.sh (criterion 1 is the red-then-green check; no file exists at HEAD)
blast-radius: none
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 8 (the scoped clean-tree check) passes at HEAD by design, because no file of the unit exists yet; it turns red only when the commit step is skipped.
no-real-claude: nothing here runs the claude CLI; the test builds synthetic run directories in a temp directory.
gate-names: the test builds the marker directory name from two parts on purpose; apply every edit with the Write or Edit tool.
commit-message: feat(abt-u15): blinded grading set for the E1 judgment item (#584)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u15 (#584)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
