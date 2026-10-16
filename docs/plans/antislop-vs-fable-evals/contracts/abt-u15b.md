Unit: abt-u15b

## Objective
blind.py drops any .claude path (also nested) plus docs/wiki and docs/adr from the grader diff, redacts persona, pending-review, pass marker, pathfinder, roast-work and domain-modeling with word boundaries, removes a Unit: or STATUS: line only when its value looks like a unit id or a status word (case-insensitively) and keeps a path's trailing punctuation; tests/abtest-blind.test.sh covers each rule, both halves of the refusal and a leak scan that fails on a missing directory. One commit.

## Retrieval
GitHub issues: `gh issue view 596 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `eval/abtest/lib/blind.py` (anchor: line matching `PERSONAS = r"orchestrator`)
- `tests/abtest-blind.test.sh` (anchor: line matching `+PASS e01`)

## Ordered edits
1. command: `test -f eval/abtest/lib/blind.py && test -f tests/abtest-blind.test.sh && ! grep -q UNIT_ID eval/abtest/lib/blind.py && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/blind.py`
   anchor: line matching `PERSONAS = r"orchestrator`
   indent: 0
   insert-after:
~~~~
# A Unit: line is dropped only when its value looks like a unit id (letters, then a separator or a digit),
# a STATUS: line only when its value is complete or incomplete; "Unit: percent" and "Price per Unit: $5" stay.
UNIT_ID = r"(?:[A-Za-z]+[-._#][A-Za-z0-9._#-]*|[A-Za-z]+[0-9][A-Za-z0-9._#-]*)"
STATUS_VALUE = r"(?:complete|incomplete\b.*)"
~~~~
3. file: `eval/abtest/lib/blind.py`
   anchor: line matching `(?:/\S*)?`
   before: `    (re.compile(r"\.claude(?:/\S*)?"), "[path]"),`
   after: `    (re.compile(r"\.claude(?:/[\w./-]*[\w/-])?"), "[path]"),`
4. file: `eval/abtest/lib/blind.py`
   anchor: line matching `Unit|STATUS`
   before: `    (re.compile(r"^.*\b(?:Unit|STATUS):.*$", re.MULTILINE), "[line removed]"),`
   after: `    (re.compile(rf"^.*\b(?:Unit:\s*{UNIT_ID}|STATUS:\s*{STATUS_VALUE})\W*$", re.MULTILINE | re.IGNORECASE), "[line removed]"),`
5. file: `eval/abtest/lib/blind.py`
   anchor: line matching `"[agent]"),`
   indent: 0
   insert-after:
~~~~
    (re.compile(r"\b(?:personas?|pending-review|pathfinder|roast-work|domain-modeling)\b|(?<![A-Za-z])\.?pass markers?\b", re.IGNORECASE), "[term]"),
~~~~
6. file: `eval/abtest/lib/blind.py`
   anchor: line matching `DROP = (`
   before: `DROP = (re.compile(r"\.(pass|fail)$"), re.compile(r"^\.claude/"), re.compile(r"^docs/plans/"))`
   after: `DROP = (re.compile(r"\.(pass|fail)$"), re.compile(r"(^|/)\.claude/"), re.compile(r"^docs/plans/"), re.compile(r"(^|/)docs/(wiki|adr)/"))`
7. file: `tests/abtest-blind.test.sh`
   anchor: line matching `+PASS e01`
   indent: 0
   insert-after:
~~~~
diff --git a/sub/.claude/nested.md b/sub/.claude/nested.md
+nested secret
diff --git a/docs/wiki/w.md b/docs/wiki/w.md
+wiki secret
diff --git a/docs/adr/0001-x.md b/docs/adr/0001-x.md
+adr secret
diff --git a/CONTEXT.md b/CONTEXT.md
+glossary line
~~~~
8. file: `tests/abtest-blind.test.sh`
   anchor: line matching `    "Describe the inscribed text with a (post-discount) price.",`
   indent: 0
   insert-after:
~~~~
    "unit: abt-lower",
    "Status: Complete",
    "STATUS: incomplete - ran out of turns",
    "The personas, the pending-review flag and a .pass marker came from pathfinder, roast-work and domain-modeling.",
    "A bypass marker and personal notes survive; so does Price per Unit: $5.",
    "- Unit: percent",
    "See .claude/agents/x.md, then (see .claude/foo) and .claude.",
~~~~
9. file: `tests/abtest-blind.test.sh`
   anchor: line matching `LEAK='`
   before: `LEAK='\b(reviewer|orchestrator|scribe|explorer|researcher|lead[- ]programmer|spec[- ]master|task[- ]master|milestone-auditor|agent-auditor)|\b(Unit|STATUS):|anti-?slop|Arm [AB]|arm-[ab]\b|\.claude|\bPASS [a-z]|\(e[0-9]{2}-|\(gh[0-9]+\)|\(#[0-9]+\)'`
   after: `LEAK='\b(reviewer|orchestrator|scribe|explorer|researcher|lead[- ]programmer|spec[- ]master|task[- ]master|milestone-auditor|agent-auditor)|\bUnit: *[A-Za-z]+[-._#0-9]|\bSTATUS: *(in)?complete|anti-?slop|Arm [AB]|arm-[ab]\b|\.claude|\bPASS [a-z]|\(e[0-9]{2}-|\(gh[0-9]+\)|\(#[0-9]+\)|\bpersonas?\b|pending-review|(^|[^A-Za-z])\.?pass markers?|pathfinder|roast-work|domain-modeling|^unit: abt-lower'`
10. file: `tests/abtest-blind.test.sh`
   anchor: line matching `no arm identifier leaks into the grader files`
   indent: 0
   before:
~~~~
check "no arm identifier leaks into the grader files" "$(grep -rliE "$LEAK" "$OUT/blind" 2> /dev/null | wc -l | tr -d ' ')" "0"
~~~~
   after:
~~~~
check "the grader directory holds the four items before the leak scan" "$(ls "$OUT/blind" | grep -cE '^[0-9a-f]{8}$')" "4"
leaks="$(grep -rliE "$LEAK" "$OUT/blind")"; lrc=$?
check "no arm identifier leaks into the grader files (grep found nothing and did not error)" "$lrc|$leaks" "1|"
~~~~
11. file: `tests/abtest-blind.test.sh`
   anchor: line matching `the diff drops persona files`
   indent: 0
   before:
~~~~
check "the diff drops persona files, plans and markers" "$(cat "$OUT"/blind/*/diff.patch | grep -cE 'claude|docs/plans|PASS e01|secret persona')" "0"
~~~~
   after:
~~~~
check "the diff drops persona files, plans and markers" "$(cat "$OUT"/blind/*/diff.patch | grep -cE 'claude|docs/plans|docs/wiki|docs/adr|PASS e01|secret persona|nested secret|wiki secret|adr secret')" "0"
check "the diff keeps a CONTEXT.md change (E1 never hides the glossary file)" "$(cat "$OUT"/blind/*/diff.patch | grep -c '^+glossary line')" "4"
check "a lowercase unit line and a mixed-case status line are removed" "$(cat "$OUT"/blind/*/report.md | grep -ciE 'abt-lower|Status: Complete')" "0"
check "an incomplete status line is removed" "$(cat "$OUT"/blind/*/report.md | grep -c 'ran out of turns')" "0"
check "a Unit: line with a plain-word value survives" "$(cat "$OUT"/blind/*/report.md | grep -c -- '^- Unit: percent')" "4"
check "a Unit: price inside a sentence survives" "$(cat "$OUT"/blind/*/report.md | grep -c 'Price per Unit: \$5')" "4"
check "bypass marker and personal survive the new terms" "$(cat "$OUT"/blind/*/report.md | grep -c 'A bypass marker and personal notes survive')" "4"
check "the new terms are redacted" "$(cat "$OUT"/blind/*/report.md | grep -c 'The \[term\], the \[term\] flag and a \[term\] came from \[term\], \[term\] and \[term\].')" "4"
check "a redacted .claude path keeps its trailing punctuation" "$(cat "$OUT"/blind/*/report.md | grep -c 'See \[path\], then (see \[path\]) and \[path\].')" "4"
~~~~
12. file: `tests/abtest-blind.test.sh`
   anchor: line matching `check "the refused build left the four items alone"`
   indent: 0
   insert-after:
~~~~

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
~~~~
13. command: `git add eval/abtest/lib/blind.py tests/abtest-blind.test.sh && git commit -m "fix(abt-u15b): blinding drops nested and wiki paths, redacts more terms and keeps benign Unit lines (#596)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/blind.sh` (the wrapper is unchanged)
- `eval/abtest/lib/stream.py`, `eval/abtest/lib/make-row.py`, `eval/abtest/score.py`, `eval/abtest/run-matrix.sh` (other units own them)
- `tests/validate.sh` (merge-gate registration is unit abt-u17)
- `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-blind.test.sh`
   exit: 0
   stdout: `All abtest-blind checks passed.`
   mutation: skip edit 4 (the Unit and STATUS rule); the lowercase unit line leaks, the leak row FAILs, the script exits non-zero and the fragment is absent.
   proof: mutation matrix, run in a scratch copy of the finished change, each making bash tests/abtest-blind.test.sh exit non-zero: B1 restore the anchored .claude DROP; B2 delete the docs wiki and adr DROP; B3 let UNIT_ID match any word; B4 drop re.IGNORECASE from the Unit rule; B5 delete the terms rule; B6 delete the lookbehind from the pass marker term; B7 restore the greedy path pattern; B8 delete the sealed-map half of the refusal; B9 delete the non-empty blind half of the refusal; B10 point the leak scan at a missing directory.
2. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   .*\(survive\|keeps\)'`
   exit: 0
   stdout: `8`
   mutation: skip edit 11 (the new survivor rows); the count of ok lines naming survive or keeps drops.
3. run: `grep -c 'docs/(wiki|adr)' eval/abtest/lib/blind.py`
   exit: 0
   stdout: `1`
   mutation: skip edit 6 (the DROP widening); stdout 0 and the exit is 1.
4. run: `grep -c 'UNIT_ID' eval/abtest/lib/blind.py`
   exit: 0
   stdout: `2`
   mutation: skip edit 2 (the definitions); the rule names nothing and the count is 1.
5. run: `grep -c 'refusing' tests/abtest-blind.test.sh`
   exit: 0
   stdout: `3`
   mutation: skip edit 12 (the two new refusal rows); the count is 1.
6. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   mutation: skip edit 13 (the commit); no unit commit exists and the run prints no-unit-commit with exit 3.
7. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 13; no unit commit exists and the exit is 3.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/blind.py tests/abtest-blind.test.sh | grep -vcE "^[a-z]+\(abt-u15b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
9. run: `git status --porcelain -- eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 13; the new files stay untracked and are listed.

## Pre-resolved context
tdd: yes tests/abtest-blind.test.sh (criteria 3 to 5 and the new survivor rows are the red-then-green checks)
blast-radius: eval/abtest/lib/blind.py:17
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 (the suite passes at HEAD) and criterion 9 (the scoped clean-tree check) pass at HEAD by design; the new rows inside criterion 1 and criteria 2 to 5 are red before the change.
extends-landed-code: abt-u15 is on master (commit eba818a2, fix contract abt-u15-fix1). Every edit is an insertion or a small replacement anchored on lines that exist there; no file is rewritten. Do not touch the abt-u15 contract files.
decision: CONTEXT.md and README.md stay in the grader diff. abt-u07 has the E1 plant create them and its reference.patch and checks never edit them, so an edit to either is out-of-scope work, but the grader judges ASSUMPTIONS.md against the glossary and must see the glossary file if it changed. Residual risk: an Arm B scribe edit to CONTEXT.md is visible to the grader.
fail-closed: every new row compares an explicit expected value; the leak scan row fails on a missing directory (grep exit 2) because it asserts the grep exit status is 1.
no-real-claude: no command in this contract runs the real claude CLI.
commit-message: fix(abt-u15b): blinding drops nested and wiki paths, redacts more terms and keeps benign Unit lines (#596)
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
diagnosis: none
review-packet:
~~~
unit: abt-u15b (#596)
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
