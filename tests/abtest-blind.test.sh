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
