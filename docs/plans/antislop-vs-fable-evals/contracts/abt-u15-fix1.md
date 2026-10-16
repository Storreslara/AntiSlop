Unit: abt-u15

## Objective
eval/abtest/lib/blind.py redacts plural persona names, Unit:/STATUS: lines anywhere in a line, AntiSlop, Arm A/B, .claude paths, PASS/FAIL marker text and no-hyphen scope tokens; build refuses a stale or empty set and creates item directories in id order; tests/abtest-blind.test.sh fails closed and tallies unseal per arm. One commit.

## Retrieval
GitHub issues: `gh issue view 584 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/lib/blind.py` (anchor: line matching `REDACT = [`)
- `tests/abtest-blind.test.sh` (anchor: line matching `check "ids differ between builds"`)

## Ordered edits
1. command: `test "$(grep -cF 'keep, drop = [], False' eval/abtest/lib/blind.py)" = 1 && test "$(grep -cF 'sealed, used = {}, set()' eval/abtest/lib/blind.py)" = 1 && test "$(grep -cF 'ids differ between builds' tests/abtest-blind.test.sh)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/blind.py`
   anchor: line matching `REDACT = [`
   indent: 0
   before:
~~~~
PERSONAS = r"orchestrator|spec-master|task-master|lead-programmer|reviewer|scribe|explorer|milestone-auditor|researcher|agent-auditor"
REDACT = [
    (re.compile(rf"\b(?:{PERSONAS})\b", re.IGNORECASE), "[agent]"),
    (re.compile(r"^Unit: .*$", re.MULTILINE), "[line removed]"),
    (re.compile(r"^STATUS: .*$", re.MULTILINE), "[line removed]"),
    (re.compile(r"\([A-Za-z0-9]+(?:-[A-Za-z0-9._#]+)+\)"), "(scope)"),
]
~~~~
   after:
~~~~
PERSONAS = r"orchestrator|spec[- ]master|task[- ]master|lead[- ]programmer|reviewer|scribe|explorer|milestone[- ]auditor|researcher|agent[- ]auditor"
REDACT = [
    (re.compile(r"\.claude(?:/\S*)?"), "[path]"),
    (re.compile(r"^.*\b(?:Unit|STATUS):.*$", re.MULTILINE), "[line removed]"),
    (re.compile(rf"\b(?:{PERSONAS})[A-Za-z]*", re.IGNORECASE), "[agent]"),
    (re.compile(r"anti-?slop", re.IGNORECASE), "[tool]"),
    (re.compile(r"\b(?:Arm [AB]|arm-[ab])\b"), "[arm]"),
    (re.compile(r"\b(?:PASS|FAIL) (?=\S*[A-Za-z])\S*\d\S*"), "[marker]"),
    (re.compile(r"\((?:#\d+|[A-Za-z]{1,6}\d+)\)"), "(scope)"),
    (re.compile(r"\([A-Za-z0-9]+(?:-[A-Za-z0-9._#]+)+\)"), "(scope)"),
]
~~~~
3. file: `eval/abtest/lib/blind.py`
   anchor: line matching `keep, drop = [], False`
   before: `keep, drop = [], False`
   after: `keep = []`
4. file: `eval/abtest/lib/blind.py`
   anchor: line matching `    sealed, used = {}, set()`
   indent: 0
   before:
~~~~
    blind_dir = os.path.join(out, "blind")
    os.makedirs(blind_dir, exist_ok=True)
    sealed, used = {}, set()
    for r in rows:
        while True:
            item = secrets.token_hex(4)
            if item not in used:
                used.add(item)
                break
~~~~
   after:
~~~~
    if not rows:
        print(f"blind: no usable runs of {eval_id} in {rows_path}", file=sys.stderr)
        return 1
    blind_dir = os.path.join(out, "blind")
    if os.path.exists(os.path.join(out, "sealed-map.json")) or (os.path.isdir(blind_dir) and os.listdir(blind_dir)):
        print(f"blind: refusing to build into {out}: it already holds a blind set; use a fresh directory", file=sys.stderr)
        return 1
    os.makedirs(blind_dir, exist_ok=True)
    sealed, items = {}, {}
    for r in rows:
        while True:
            item = secrets.token_hex(4)
            if item not in items:
                items[item] = r
                break
    # Item directories are created in id order, so their timestamps never show the run order.
    for item in sorted(items):
        r = items[item]
~~~~
5. file: `tests/abtest-blind.test.sh`
   anchor: line matching `TEXT = "The reviewer approved it.`
   indent: 0
   before:
~~~~
TEXT = "The reviewer approved it.\nUnit: abt-x\nSTATUS: complete\nfeat(e01-ambiguous-tax): done by lead-programmer\nAll finished."
~~~~
   after:
~~~~
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
~~~~
6. file: `tests/abtest-blind.test.sh`
   anchor: line matching `no arm identifier leaks into the grader files`
   indent: 0
   before:
~~~~
check "no arm identifier leaks into the grader files" "$(grep -rcE 'reviewer|lead-programmer|Unit: |STATUS: |\(e[0-9]{2}-' "$OUT/blind" | grep -vc ':0$')" "0"
~~~~
   after:
~~~~
LEAK='\b(reviewer|orchestrator|scribe|explorer|researcher|lead[- ]programmer|spec[- ]master|task[- ]master|milestone-auditor|agent-auditor)|\b(Unit|STATUS):|anti-?slop|Arm [AB]|arm-[ab]\b|\.claude|\bPASS [a-z]|\(e[0-9]{2}-|\(gh[0-9]+\)|\(#[0-9]+\)'
check "the leak pattern sees the leaks in the unredacted summaries (positive control)" "$(grep -rliE "$LEAK" --include=summary.json "$T/runs" | wc -l | tr -d ' ')" "6"
check "the grader holds four reports and four diffs" "$(find "$OUT/blind" -type f 2> /dev/null | wc -l | tr -d ' ')" "8"
check "no arm identifier leaks into the grader files" "$(grep -rliE "$LEAK" "$OUT/blind" 2> /dev/null | wc -l | tr -d ' ')" "0"
check "words that merely contain a persona name survive" "$(cat "$OUT"/blind/*/report.md | grep -c 'Describe the inscribed text')" "4"
~~~~
7. file: `tests/abtest-blind.test.sh`
   anchor: line matching `check "ids differ between builds"`
   indent: 0
   before:
~~~~
bash "$BLIND" "$T/rows.jsonl" "$T/out2" > /dev/null
check "ids differ between builds" "$(ls "$OUT/blind" "$T/out2/blind" | grep -E '^[0-9a-f]{8}$' | sort | uniq -d | wc -l | tr -d ' ')" "0"
~~~~
   after:
~~~~
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
~~~~
8. file: `tests/abtest-blind.test.sh`
   anchor: line matching `w.writerow([item, "" if i == 0`
   indent: 0
   insert-after:
~~~~
tot = {"A": [0, 0], "B": [0, 0]}
for i, item in enumerate(sorted(m)):
    if i == 0:
        continue
    arm = m[item]["arm"]
    tot[arm][1] += 1
    tot[arm][0] += 1 if arm == "B" else 0
with open(out + "/expected-tally.txt", "w") as f:
    f.write(f"unsealed: A assumptions_cites_glossary={tot['A'][0]}/{tot['A'][1]} B assumptions_cites_glossary={tot['B'][0]}/{tot['B'][1]} ungraded=1")
~~~~
9. file: `tests/abtest-blind.test.sh`
   anchor: line matching `tally="$(bash "$BLIND" --unseal`
   indent: 0
   before:
~~~~
tally="$(bash "$BLIND" --unseal "$OUT" "$OUT/grades.csv")"
case "$tally" in
  unsealed:*ungraded=1) ok "unseal prints a tally and counts the ungraded item" ;;
  *) bad "unseal output was '$tally'" ;;
esac
~~~~
   after:
~~~~
tally="$(bash "$BLIND" --unseal "$OUT" "$OUT/grades.csv")"; rc5=$?
exp="$(cat "$OUT/expected-tally.txt" 2> /dev/null)"
check "unseal exits 0" "$rc5" "0"
check "unseal prints the per-arm tally the map and the grades give" "$([ -n "$exp" ] && [ "$tally" = "$exp" ] && echo match || echo "no match: got '$tally' want '$exp'")" "match"
~~~~
10. command: `git add eval/abtest/lib/blind.py tests/abtest-blind.test.sh && git commit -m "fix(abt-u15): blinding redacts every arm identifier, refuses stale sets, unseal tally is tested per arm (#584)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/blind.sh` (unchanged; it only dispatches to blind.py)
- `eval/abtest/lib/stream.py`, `eval/abtest/lib/make-row.py` (other units own them)
- `eval/abtest/run-matrix.sh`, `eval/abtest/arms/`, `eval/abtest/checks/`, `eval/abtest/fixtures/` (other units own them)
- `eval/harness/`, `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-blind.test.sh`
   exit: 0
   stdout: `All abtest-blind checks passed.`
   mutation: skip edit 2; the leak row FAILs, the script exits non-zero and the fragment is absent.
2. run: `bash tests/abtest-blind.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `23`
   mutation: skip edit 9; the old shape-only row replaces two rows and the count is 22.
3. run: `python3 -I -c 'import importlib.util as u;s=u.spec_from_file_location("b","eval/abtest/lib/blind.py");m=u.module_from_spec(s);s.loader.exec_module(m);print(m.redact("The reviewers signed off\n**STATUS: complete**\n  Unit: x\nfeat(gh584): AntiSlop Arm B").replace(chr(10),"|"))'`
   exit: 0
   stdout: `The [agent] signed off|[line removed]|[line removed]|feat(scope): [tool] [arm]`
   mutation: skip edit 2; the plural, the bolded and indented lines, the no-hyphen scope, AntiSlop and Arm B all pass through and the line differs.
4. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   no arm identifier leaks into the grader files'`
   exit: 0
   stdout: `1`
   mutation: skip edit 2; the redacted report keeps the plural, indented and bolded lines, so the broader leak grep finds hits and the row FAILs (stdout 0, exit 1).
5. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   words that merely contain a persona name survive'`
   exit: 0
   stdout: `1`
   mutation: skip edit 5; the fixture text no longer holds the Describe line, so the report count is 0 and the row FAILs (stdout 0, exit 1).
6. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   the grader holds four reports and four diffs'`
   exit: 0
   stdout: `1`
   mutation: skip edit 6; the row is gone (stdout 0, exit 1).
7. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   the second build wrote four items'`
   exit: 0
   stdout: `1`
   mutation: skip edit 7; the row is gone (stdout 0, exit 1).
8. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   a build into a directory that already holds a blind set is refused'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; the second build into the same directory succeeds, so the row FAILs (stdout 0, exit 1).
9. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   a build with no usable runs is refused'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; the empty build writes an empty set and exits 0, so the row FAILs (stdout 0, exit 1).
10. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   item directories are created in id order, not in run order'`
   exit: 0
   stdout: `1`
   mutation: skip edit 4; directories are created in run order, so sorted=8/8 is not printed and the row FAILs (stdout 0, exit 1).
11. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   unseal prints the per-arm tally the map and the grades give'`
   exit: 0
   stdout: `1`
   mutation: skip edit 8; the expected tally file is never written, the comparison reads no match and the row FAILs (stdout 0, exit 1).
12. run: `grep -c 'keep, drop' eval/abtest/lib/blind.py`
   exit: 1
   stdout: `0`
   mutation: skip edit 3; the dead variable is back, stdout 1, exit 0.
13. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" " | sed "s/^/files: /"`
   exit: 0
   stdout: `files: eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   mutation: skip edit 10 (the commit); the newest abt-u15 commit is the original and the list names three files, starting files: eval/abtest/blind.sh.
14. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -cE "^(fix\(abt-u15\): blinding redacts every arm identifier|Co-Authored-By: Claude .* <noreply@anthropic.com>$)"`
   exit: 0
   stdout: `2`
   mutation: skip edit 10; the newest abt-u15 commit is the original (subject feat(...)), so only the trailer line matches and stdout is 1.
15. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/blind.sh eval/abtest/lib/blind.py tests/abtest-blind.test.sh | grep -vcE "^[a-z]+\(abt-u15\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
16. run: `git status --porcelain -- eval/abtest/blind.sh eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 10; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-blind.test.sh (criteria 1 and 2 are red-then-green: the new rows FAIL at HEAD)
blast-radius: eval/abtest/blind.sh:9 eval/abtest/blind.sh:11
fix-of: 2026-10-16T22:03:13Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. Inline-code payloads are literal. The before payloads are exact copies of the committed text: copy, do not retype.
why: the FAIL showed the redaction letting arm identifiers through on realistic input (plural persona names, Unit:/STATUS: lines that are indented, bolded or quoted) while the unit's own leak grep counted them as leaks, and the unseal row never checked a per-arm count (an A/B swap stayed green). The roast items are folded in: the redaction is now at least as broad as the test's leak grep, the build refuses a stale or empty set, item directories are created in id order so directory timestamps never show the run order, and every new test row fails closed.
fail-closed-tests: every new row compares a count against a non-empty expected value and is paired with a presence count (eight grader files, four items, a positive control that the leak grep sees the unredacted text), so a missing directory, a crash or an empty output reads as FAIL. The tally row compares against a tally computed from the sealed map by separate code and refuses an empty expectation.
not-covered: persona names inside ASSUMPTIONS.md content stay unredacted by design (design section 2.6 redacts report text only). diff.patch paths docs/wiki, docs/adr, microworlds and a nested sub/.claude are not filtered: the u12 pathspec and the DROP list here cover only top-level .claude/ and docs/plans/. The u12 contract is NOT amended: that pathspec also feeds make-row scope counting, and CONTEXT.md and docs/adr exist in the T2 baseline so they cannot be dropped wholesale. A later change can widen DROP in blind.py only (for example a (^|/)\.claude/ pattern).
operator-note: a second build into the same OUT now exits 1 with "refusing"; to rebuild, delete OUT first. Unit abt-u21 builds once into a fresh directory, so its contract is unaffected.
already-green: criterion 1 and criterion 4 pass at HEAD because the committed suite and its old leak row are green on the old inputs; they are red-then-green only through the new fixture text, which edit 5 adds, and are proven by the skip edit mutations. Criterion 15 (the untagged-tail count) and criterion 16 (the scoped clean-tree check) pass at HEAD by design and turn red only when a later commit is untagged or the commit step is skipped.
no-real-claude: nothing here runs the claude CLI; the test builds synthetic run directories in a temp directory.
gate-names: the test builds the marker directory name from two parts on purpose; apply every edit with the Write or Edit tool.
commit-message: fix(abt-u15): blinding redacts every arm identifier, refuses stale sets, unseal tally is tested per arm (#584)
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
