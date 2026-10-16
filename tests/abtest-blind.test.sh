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
TEXT = "\n".join([
    "The reviewer approved it.",
    "The reviewers signed off; scribes and orchestrators agree, as do the Lead Programmer and the spec master.",
    "Unit: abt-x",
    "STATUS: complete",
    "  Unit: cart-tax",
    "**STATUS: complete**",
    "> STATUS: complete",
    "feat(e01-ambiguous-tax): done by lead-programmer",
    "fix(gh584): a scope without a hyphen, closes (#584)",
    "AntiSlop shipped antislop:pathfinder to Arm B and arm-a.",
    "Marker " + MARK + " reads PASS abt-u15 2026-10-16T00:00:00Z.",
    "Describe the inscribed text with a (post-discount) price.",
    "All finished.",
])
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
LEAK='\b(reviewer|orchestrator|scribe|explorer|researcher|lead[- ]programmer|spec[- ]master|task[- ]master|milestone-auditor|agent-auditor)|\b(Unit|STATUS):|anti-?slop|Arm [AB]|arm-[ab]\b|\.claude|\bPASS [a-z]|\(e[0-9]{2}-|\(gh[0-9]+\)|\(#[0-9]+\)'
check "the leak pattern sees the leaks in the unredacted summaries (positive control)" "$(grep -rliE "$LEAK" --include=summary.json "$T/runs" | wc -l | tr -d ' ')" "6"
check "the grader holds four reports and four diffs" "$(find "$OUT/blind" -type f 2> /dev/null | wc -l | tr -d ' ')" "8"
check "no arm identifier leaks into the grader files" "$(grep -rliE "$LEAK" "$OUT/blind" 2> /dev/null | wc -l | tr -d ' ')" "0"
check "words that merely contain a persona name survive" "$(cat "$OUT"/blind/*/report.md | grep -c 'Describe the inscribed text')" "4"
check "the diff keeps the ASSUMPTIONS.md section" "$(cat "$OUT"/blind/*/diff.patch | grep -c '^+- Tax follows CONTEXT.md.')" "4"
check "the diff drops persona files, plans and markers" "$(cat "$OUT"/blind/*/diff.patch | grep -cE 'claude|docs/plans|PASS e01|secret persona')" "0"
check "the report keeps neutral text" "$(cat "$OUT"/blind/*/report.md | grep -c 'All finished.')" "4"
check "the sealed map sits outside blind/" "$(test -f "$OUT/sealed-map.json" && echo yes)" "yes"
check "the map names two runs per arm" "$(python3 -I -c 'import json,sys;m=json.load(open(sys.argv[1])).values();print(sorted(v["arm"] for v in m))' "$OUT/sealed-map.json")" "['A', 'A', 'B', 'B']"
check "the grades template has a header and four rows" "$(wc -l < "$OUT/grades-template.csv" | tr -d ' ')" "5"
bash "$BLIND" "$T/rows.jsonl" "$T/out2" > /dev/null; rc2=$?
check "the second build exits 0" "$rc2" "0"
check "the second build wrote four items" "$(ls "$T/out2/blind" 2> /dev/null | grep -cE '^[0-9a-f]{8}$')" "4"
check "ids differ between builds" "$(ls "$OUT/blind" "$T/out2/blind" 2> /dev/null | grep -E '^[0-9a-f]{8}$' | sort | uniq -d | wc -l | tr -d ' ')" "0"

# A second build into a directory that already holds a blind set is refused and changes nothing.
before_map="$(md5sum "$OUT/sealed-map.json" 2> /dev/null | cut -d' ' -f1)"
bash "$BLIND" "$T/rows.jsonl" "$OUT" > /dev/null 2> "$T/stale.err"; rc3=$?
after_map="$(md5sum "$OUT/sealed-map.json" 2> /dev/null | cut -d' ' -f1)"
check "a build into a directory that already holds a blind set is refused" "$([ "$rc3" -ne 0 ] && grep -q 'refusing' "$T/stale.err" && echo refused)" "refused"
check "the refused build left the sealed map alone" "$([ -n "$before_map" ] && [ "$after_map" = "$before_map" ] && echo same)" "same"
check "the refused build left the four items alone" "$(ls "$OUT/blind" | grep -cE '^[0-9a-f]{8}$')" "4"

# A build with no usable runs is an error, not an empty set.
bash "$BLIND" "$T/rows.jsonl" "$T/out3" --eval e99-none > /dev/null 2> "$T/none.err"; rc4=$?
check "a build with no usable runs is refused" "$([ "$rc4" -ne 0 ] && grep -q 'no usable runs' "$T/none.err" && [ ! -e "$T/out3/sealed-map.json" ] && echo refused)" "refused"

# Item directories are created in id order: build eight sets in-process and watch the creation calls.
python3 -I - "$REPO_ROOT" "$T" << 'PYEOF' > "$T/order.txt" 2>&1
import contextlib
import importlib.util
import io
import json
import os
import sys

root, t = sys.argv[1:3]
spec = importlib.util.spec_from_file_location("blind", root + "/eval/abtest/lib/blind.py")
blind = importlib.util.module_from_spec(spec)
spec.loader.exec_module(blind)
rows = [json.loads(l) for l in open(t + "/rows.jsonl") if l.strip()]
run_order = [r["run_id"] for r in rows if r["eval_id"] == "e01-ambiguous-tax" and r["completion_status"] != "usage-limit"]
real_makedirs = os.makedirs
created = []


def spy(path, *args, **kwargs):
    if os.path.basename(os.path.dirname(path)) == "blind":
        created.append(os.path.basename(path))
    return real_makedirs(path, *args, **kwargs)


os.makedirs = spy
n_sorted = 0
shuffled = False
for n in range(8):
    del created[:]
    out = f"{t}/order{n}"
    with contextlib.redirect_stdout(io.StringIO()):
        rc = blind.build(t + "/rows.jsonl", out, "e01-ambiguous-tax")
    sealed = json.load(open(out + "/sealed-map.json"))
    if rc == 0 and len(created) == 4 and created == sorted(created):
        n_sorted += 1
    if [sealed[i]["run_id"] for i in created] != run_order:
        shuffled = True
print(f"order: sorted={n_sorted}/8 shuffled={'yes' if shuffled else 'no'}")
PYEOF
check "item directories are created in id order, not in run order" "$(tail -n 1 "$T/order.txt")" "order: sorted=8/8 shuffled=yes"

# Grade: 1 for an item whose map arm is B, 0 for A, but leave the first item ungraded.
python3 -I - "$OUT" << 'PYEOF'
import csv, json, sys

out = sys.argv[1]
m = json.load(open(out + "/sealed-map.json"))
with open(out + "/grades.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "assumptions_cites_glossary"])
    for i, item in enumerate(sorted(m)):
        w.writerow([item, "" if i == 0 else ("1" if m[item]["arm"] == "B" else "0")])
tot = {"A": [0, 0], "B": [0, 0]}
for i, item in enumerate(sorted(m)):
    if i == 0:
        continue
    arm = m[item]["arm"]
    tot[arm][1] += 1
    tot[arm][0] += 1 if arm == "B" else 0
with open(out + "/expected-tally.txt", "w") as f:
    f.write(f"unsealed: A assumptions_cites_glossary={tot['A'][0]}/{tot['A'][1]} B assumptions_cites_glossary={tot['B'][0]}/{tot['B'][1]} ungraded=1")
PYEOF
tally="$(bash "$BLIND" --unseal "$OUT" "$OUT/grades.csv")"; rc5=$?
exp="$(cat "$OUT/expected-tally.txt" 2> /dev/null)"
check "unseal exits 0" "$rc5" "0"
check "unseal prints the per-arm tally the map and the grades give" "$([ -n "$exp" ] && [ "$tally" = "$exp" ] && echo match || echo "no match: got '$tally' want '$exp'")" "match"

echo "abtest-blind: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "All abtest-blind checks passed."
exit "$fail"
