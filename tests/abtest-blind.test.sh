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
diff --git a/sub/.claude/nested.md b/sub/.claude/nested.md
+nested secret
diff --git a/docs/wiki/w.md b/docs/wiki/w.md
+wiki secret
diff --git a/docs/adr/0001-x.md b/docs/adr/0001-x.md
+adr secret
diff --git a/CLAUDE.md b/CLAUDE.md
+claude md secret
diff --git a/.claude-plugin/plugin.json b/.claude-plugin/plugin.json
+plugin secret
diff --git a/microworlds/m.md b/microworlds/m.md
+microworld secret
diff --git a/wiki/x.md b/wiki/x.md
+root wiki secret
diff --git a/sub/docs/plans/q.md b/sub/docs/plans/q.md
+nested plan secret
diff --git a/CONTEXT.md b/CONTEXT.md
+glossary line
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
    "unit: abt-lower",
    "Status: Complete",
    "STATUS: incomplete - ran out of turns",
    "The personas, the pending-review flag and a .pass marker came from pathfinder, roast-work and domain-modeling.",
    "A bypass marker and personal notes survive; so does Price per Unit: $5.",
    "- Unit: percent",
    "Unit: abt-x (#1) done",
    "**Unit:** abt-x",
    "Unit: #596",
    "Unit: e01-ambiguous-tax - dispatched to the lead",
    "**STATUS:** complete",
    "Unit:",
    "abt-keep next line",
    "- Unit: `lgc-1`. The only file it changes is x",
    "Unit: \"abt-x\"",
    "Unit: [abt-x]",
    "Unit: 596",
    "STATUS: complete \u2014 design review delivered; no files created or modified.",
    "**Unit**: abt-x",
    "__Unit:__ abt-x",
    "Unit : abt-x",
    "Unit:\u00a0abt-x",
    "Unit\u00a0: abt-x",
    "Unit: not-an-id words",
    "Status: some new value",
    "It ended ready-for-review after ESCALATE-TO-HUMAN, with a wip-handoff file, an INSUFFICIENT-CONTEXT verdict and a SPEC-GAP.",
    "Also .claude/x~y and .claude/agent-memory/a_b.md.",
    "See .claude/agents/x.md, then (see .claude/foo) and .claude.",
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
LEAK='\b(reviewer|orchestrator|scribe|explorer|researcher|lead[- ]programmer|spec[- ]master|task[- ]master|milestone-auditor|agent-auditor)|\bUnit:\** *(#[0-9]|[A-Za-z]+[-._#0-9])|\bSTATUS:\** *(in)?complete|anti-?slop|Arm [AB]|arm-[ab]\b|\.claude|\bPASS [a-z]|\(e[0-9]{2}-|\(gh[0-9]+\)|\(#[0-9]+\)|\bpersonas?\b|pending-review|(^|[^A-Za-z])\.?pass markers?|pathfinder|roast-work|domain-modeling|^unit: abt-lower'
check "the leak pattern sees the leaks in the unredacted summaries (positive control)" "$(grep -rliE "$LEAK" --include=summary.json "$T/runs" | wc -l | tr -d ' ')" "6"
check "the grader holds four reports and four diffs" "$(find "$OUT/blind" -type f 2> /dev/null | wc -l | tr -d ' ')" "8"
check "the grader directory holds the four items before the leak scan" "$(ls "$OUT/blind" | grep -cE '^[0-9a-f]{8}$')" "4"
leaks="$(grep -rliE "$LEAK" "$OUT/blind")"; lrc=$?
check "no arm identifier leaks into the grader files (grep found nothing and did not error)" "$lrc|$leaks" "1|"
check "words that merely contain a persona name survive" "$(cat "$OUT"/blind/*/report.md | grep -c 'Describe the inscribed text')" "4"
check "the diff keeps the ASSUMPTIONS.md section" "$(cat "$OUT"/blind/*/diff.patch | grep -c '^+- Tax follows CONTEXT.md.')" "4"
check "the diff drops persona files, plans and markers" "$(cat "$OUT"/blind/*/diff.patch | grep -cE 'claude|docs/plans|docs/wiki|docs/adr|PASS e01|secret persona|nested secret|wiki secret|adr secret|claude md secret|plugin secret|microworld secret|root wiki secret|nested plan secret')" "0"
check "the diff keeps a CONTEXT.md change (E1 never hides the glossary file)" "$(cat "$OUT"/blind/*/diff.patch | grep -c '^+glossary line')" "4"
check "a lowercase unit line and a mixed-case status line are removed" "$(cat "$OUT"/blind/*/report.md | grep -ciE 'abt-lower|Status: Complete')" "0"
check "an incomplete status line is removed" "$(cat "$OUT"/blind/*/report.md | grep -c 'ran out of turns')" "0"
check "a Unit: line with a plain-word value survives" "$(cat "$OUT"/blind/*/report.md | grep -c -- '^- Unit: percent')" "4"
check "a Unit: price inside a sentence survives" "$(cat "$OUT"/blind/*/report.md | grep -c 'Price per Unit: \$5')" "4"
check "bypass marker and personal survive the new terms" "$(cat "$OUT"/blind/*/report.md | grep -c 'A bypass marker and personal notes survive')" "4"
check "the new terms are redacted" "$(cat "$OUT"/blind/*/report.md | grep -c 'The \[term\], the \[term\] flag and a \[term\] came from \[term\], \[term\] and \[term\].')" "4"
check "a redacted .claude path keeps its trailing punctuation" "$(cat "$OUT"/blind/*/report.md | grep -c 'See \[path\], then (see \[path\]) and \[path\].')" "4"
check "a Unit: line with text after the id, a bolded one and a bare issue number are removed" "$(cat "$OUT"/blind/*/report.md | grep -cE 'abt-x|Unit: #596|dispatched to the lead')" "0"
check "a bolded STATUS: line is removed" "$(cat "$OUT"/blind/*/report.md | grep -c 'STATUS')" "0"
check "a bare Unit: line is removed and does not take the next line with it" "$(cat "$OUT"/blind/*/report.md | grep -cx 'abt-keep next line')|$(cat "$OUT"/blind/*/report.md | grep -cx 'Unit:')" "4|0"
check "paths with a tilde or an underscore are redacted whole and keep the trailing dot" "$(cat "$OUT"/blind/*/report.md | grep -c 'Also \[path\] and \[path\]\.')" "4"
check "Unit: lines of any wrapping, spacing or value and a STATUS: line with text after complete are all removed" "$(cat "$OUT"/blind/*/report.md | grep -cE 'lgc-1|abt-x|Unit: 596|design review delivered|not-an-id|some new value')" "0"
check "the new Arm B terms are redacted" "$(cat "$OUT"/blind/*/report.md | grep -c 'It ended \[term\] after \[term\], with a \[term\] file, an \[term\] verdict and a \[term\]\.')" "4"
check "no Unit: or STATUS: label of any shape reaches the grader apart from the two benign lines" "$(cat "$OUT"/blind/*/report.md | grep -aiE '(^|[^A-Za-z])(unit|status)[^A-Za-z0-9]{0,6}:' | grep -vcE 'Unit: percent|Price per Unit: \$5')|$(cat "$OUT"/blind/*/report.md | grep -aicE '(^|[^A-Za-z])(unit|status)[^A-Za-z0-9]{0,6}:')" "0|8"
check "the new Unit: and STATUS: shapes are in the unredacted summaries (positive control)" "$(for p in 'lgc-1' 'Unit: 596' 'design review delivered' 'not-an-id' 'some new value' '__Unit:__ abt-x' 'Unit : abt-x' 'Unit:\u00a0abt-x' 'Unit\u00a0: abt-x'; do grep -rlF --include=summary.json -- "$p" "$T/runs" | wc -l | tr -d ' '; done | paste -sd' ')" "6 6 6 6 6 6 6 6 6"
check "the new diff paths are in the unredacted run diffs (positive control)" "$(for p in 'claude md secret' 'plugin secret' 'microworld secret' 'root wiki secret' 'nested plan secret'; do grep -rlF --include=diff.patch -- "$p" "$T/runs" | wc -l | tr -d ' '; done | paste -sd' ')" "6 6 6 6 6"
# A committed sample of real agent lines from this repo's own session transcripts: none may survive redact().
cat > "$T/corpus.txt" << 'CORPUS_EOF'
   - Missing: fixture with `### Unit: <id>` in docs/plans/ file with measurable commit date
  - **`Unit:` matching:** it stops dropping legitimate lines such as "Price per Unit: $5", and makes the `Unit:`/`STATUS:` match case-insensitive to agree with the test.
  - Line 173: comment names the rule: `"Unit: <id>" first line + "Mode: advisory" second line`
  - Line 175: payload fixture: `$'Unit: adv-1\nMode: advisory\n\n'`
**STATUS: Analysis complete, graph-derived + grep fallback**
**STATUS: complete**
**STATUS: incomplete — spec gap: conflicting trailer specifications in dispatch instruction vs. contract**
**STATUS:** complete
**Unit**: blf-1 (#529)
**Unit:** abt-u02e (#604, umbrella #567)
**Unit:** hcb-step5-measure (issue #467)
**Unit:** hdc-5
**Unit:** item11-3-record-override-disposition
**Unit:** ocig-1 (Step 1 of `docs/plans/2026-10-05-outcomeci-series-gate-trial.md`)
**Unit:** ocigf-3 (scribe completion)
- "36 specs embed inline `### Unit:` contracts" is **26**; no pattern I tested yields 36.
- **Ambiguous "the line":** `agents/orchestrator.md:148-156` now reads as if "the line" means the `Implementer tier:` line, not the `Unit:` line.
- **C:** read the reviewer's own `Unit:` line from its transcript.
- **Rule broken:** it also made a whole-doc `trust-model.md` edit that touches a bijection-tested file, and it sent no `STATUS:` line.
- **Unit token pattern:** the `Unit:` pattern can match across a line break, and `includes(id)` would also pass.
- **`STATUS: complete` with trailing text:** for example `STATUS: complete — design review delivered; ...`.
- **`Unit:` with a wrapped id:** an id in backticks, quotes or brackets, or a bare number, as in ``- Unit: `lgc-1`. ...``. Real lines like this appear in this repo's own session transcripts.
- Unit: ptr-u2, issue #553, commit `7e619c5`, range `c9313b3..7e619c5` (includes the scribe commit `67c8bc1`).
- `**Unit:** abt-u15b`
- `Unit: #596`
- `Unit: abt-u15b (#596)`
- `Unit: abt-u15b done`
- `Unit: e01-ambiguous-tax — dispatched to the lead`
- `tests/dispatch-hygiene.test.sh` — Unit: <task-id> syntax validation (line 602)
Confirmed independently — `05e14d9` exists, tree clean, checks out despite the missing `STATUS:` line.
Final report was delivered via `SubagentHandback` with the full advisory review packet and `STATUS: complete`.
Lov-3 passed review at `798a6a0`, and lov-4 is built at `caaff17`. The implementer ended with `STATUS: incomplete — spec gap`, but I don't read it as a real gap, so I sent the unit to the reviewer.
STATUS: Partial — Q1 and Q4 complete; Q2, Q3, Q5 marked incomplete.
STATUS: complete
STATUS: complete (handoff delivered; the underlying unit itself remains incomplete per the report, correctly flagged with STATUS: incomplete inside that handoff).
STATUS: complete — no changes made
STATUS: complete</parameter>
STATUS: complete`)
STATUS: complete`})
STATUS: incomplete — GitHub API continues to block `gh issue close 524`; preconditions valid; no action taken after second failure
STATUS: incomplete — csg-2 (lead-programmer) must land first
STATUS: incomplete — merge gate (four ranges plus the real nested leak guard) running in the background; scribe pass for lgc-1 follows once it passes
STATUS: incomplete — stop-gate demands a verdict for hcb-posttool, a unit I was never dispatched to review; reported the coupling gap and waiting.
STATUS: incomplete — waiting on lead-programmer a15d11c4b0b39f083 for ocigf-3
That stall notice is another watchdog false alarm. The lead-programmer's ocigf-3 report was complete and ended with `STATUS: complete`, so I'm ignoring it. The reviewer is still working on `ocigf-3`.
The commit `a3b79a03` exists. The report arrived inside the watchdog notice instead of as a separate message, but it is complete and ends with `STATUS: complete`, so I'm routing it to review.
The narrowed `Unit:` rule in `blind.py:26` only removes a line when the unit id is the last thing on it. These lines now reach your grader, where the parent commit stripped them:
The report was already fully delivered (ends with `STATUS: complete`) despite the turn-limit notification — treating as complete. Dispatching the reviewer for item17-4.
U4 is only partly done. The edits are finished and its own test passes, but it couldn't commit, so it reported `STATUS: incomplete`.
When it reports ready-for-review, I'll run the reviewer-tier check and dispatch the reviewer with `Unit: ocig-1`. `ocig-2` waits for the reviewer's PASS.
| tests/dispatch-hygiene.test.sh (line 602) | Unit: <task-id> and Mode: advisory syntax validation (dispatch-hygiene.sh gate) |
CORPUS_EOF
python3 -I -c 'import importlib.util,sys;s=importlib.util.spec_from_file_location("b",sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);print(m.redact(open(sys.argv[2],encoding="utf-8").read()),end="")' "$REPO_ROOT/eval/abtest/lib/blind.py" "$T/corpus.txt" > "$T/corpus.out"
check "the committed sample holds 51 real agent lines that carry a Unit: or STATUS: label" "$(wc -l < "$T/corpus.txt" | tr -d ' ')" "51"
check "every line of the real sample is removed whole" "$(grep -cx '\[line removed\]' "$T/corpus.out")|$(grep -cvx '\[line removed\]' "$T/corpus.out")" "51|0"
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

# The sealed map alone, or a non-empty blind/ alone, is enough to refuse a build.
mkdir -p "$T/out4/blind"
printf '{}\n' > "$T/out4/sealed-map.json"
bash "$BLIND" "$T/rows.jsonl" "$T/out4" > /dev/null 2> "$T/map.err"; rc5=$?
check "a directory holding only a sealed map is refused" "$([ "$rc5" -ne 0 ] && grep -q 'refusing' "$T/map.err" && echo refused)" "refused"
check "the map-only refusal left blind/ empty and the map unchanged" "$(ls "$T/out4/blind" | wc -l | tr -d ' ')|$(cat "$T/out4/sealed-map.json")" "0|{}"
mkdir -p "$T/out5/blind/aaaaaaaa"
bash "$BLIND" "$T/rows.jsonl" "$T/out5" > /dev/null 2> "$T/dir.err"; rc6=$?
check "a directory holding only a non-empty blind/ is refused" "$([ "$rc6" -ne 0 ] && grep -q 'refusing' "$T/dir.err" && echo refused)" "refused"
check "the blind/-only refusal wrote no sealed map" "$(test -e "$T/out5/sealed-map.json" && echo wrote || echo none)" "none"

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
