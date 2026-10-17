Unit: abt-u21a

## Objective
Fix of the FAIL of 2026-10-17T22:50:08Z, round 2 of 3. tests/abtest-report.test.sh gains the rows that pin the changes of abt-u21a-fix1: the Decision for a superior eval with an escaped defect, the Fisher p, directional mark and per-check tallies in the Result line, fill-log refusing a log whose evals differ from the report or malformed JSON, tickets refusing a non-empty OUT_DIR, a bad eval id and rows of another policy, the bad-row Decision, idempotence and the header reset. Each row is red against report.py with its feature removed (proof lines). The decision-table below is the wording every Decision cell must have; fix3 walks it. One commit.

## Retrieval
GitHub issues: `gh issue view 588 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`.

## Affected files
- `tests/abtest-report.test.sh` (anchor: line matching `SCORE="$REPO_ROOT/eval/abtest/score.py"`)

## Ordered edits
1. command: `git log --format=%s | grep -q "^fix(abt-u21a): one ticket predicate" && grep -q "def finding_reasons" eval/abtest/report.py && ! grep -q "fill-log is idempotent" tests/abtest-report.test.sh && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `tests/abtest-report.test.sh`
   anchor: line matching `### E5: tags (e05-tags-feature)`
   indent: 0
   before:
~~~~
### E5: tags (e05-tags-feature)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending
~~~~
   after:
~~~~
### E5: tags (e05-tags-feature)

- **Result**: pending
- **Verdict**: pending
- **Decision**: pending

## Verdict rules

- **Decision**: pending (outside every entry)
~~~~
3. file: `tests/abtest-report.test.sh`
   anchor: line matching `python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/score.json" > /dev/null`
   indent: 0
   before:
~~~~
python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/score.json" > /dev/null

~~~~
   after:
~~~~
python3 "$SCORE" "$T/rows.jsonl" --out-json "$T/score.json" > /dev/null

cp "$T/log.md" "$T/log-pending.md"
~~~~
4. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "every not-superior, stalling or defect-escaping eval points at a ticket" "$(grep -c '^- \*\*Decision\*\*: ticket filed under the eval-finding label' "$T/log.md")" "4"`
   indent: 0
   insert-after:
~~~~
check "a superior eval with an escaped defect says a ticket is filed" "$(grep -c '^- \*\*Decision\*\*: ticket filed under the eval-finding label (an Arm B run let a defect escape in 5 run(s)); no change is shipped by this log; verdict superior: recorded as a measured advantage (directional' "$T/log.md")" "1"
~~~~
5. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "an inconclusive eval asks for more data" "$(grep -c '^- \*\*Decision\*\*: NEEDS MORE DATA' "$T/log.md")" "1"`
   indent: 0
   insert-after:
~~~~
check "the E2 result line keeps the Fisher p and the directional mark" "$(grep -c 'Fisher p 0.21; .*verdict superior (directional, p=0.21)' "$T/log.md")" "1"
check "the E1 result line carries the per-check pass counts per arm" "$(grep -c 'run_pass A 4/5, B 1/5 (WIN_A).*checks passed per arm (of the usable rows) A \[none\], B \[hold-a 0/5\]' "$T/log.md")" "1"
check "a header after the last entry resets the entry scope" "$(grep -c '^- \*\*Decision\*\*: pending (outside every entry)' "$T/log.md")" "1"
cp "$T/log.md" "$T/log-filled.md"
python3 "$REPORT" fill-log "$T/score.json" "$T/log.md" "$T/rows.jsonl" > /dev/null
check "fill-log is idempotent" "$(cmp -s "$T/log.md" "$T/log-filled.md" && echo same || echo different)" "same"
grep -v 'e05-tags-feature' "$T/log-pending.md" | sed '/^### E5/,/^## Verdict/{/^## Verdict/!d}' > "$T/log-short.md"
cp "$T/log-short.md" "$T/log-short.before"
python3 "$REPORT" fill-log "$T/score.json" "$T/log-short.md" "$T/rows.jsonl" > /dev/null 2>&1; rc=$?
check "a log missing an eval of the report exits non-zero" "$rc" "1"
check "and the log is left unchanged" "$(cmp -s "$T/log-short.md" "$T/log-short.before" && echo same || echo different)" "same"
{ cat "$T/log-pending.md"; printf '\n### E6: extra (e06-extra-entry)\n\n- **Result**: pending\n- **Verdict**: pending\n- **Decision**: pending\n'; } > "$T/log-extra.md"
cp "$T/log-extra.md" "$T/log-extra.before"
python3 "$REPORT" fill-log "$T/score.json" "$T/log-extra.md" "$T/rows.jsonl" > /dev/null 2>&1; rc=$?
check "a log holding an eval the report lacks exits non-zero" "$rc $(cmp -s "$T/log-extra.md" "$T/log-extra.before" && echo same || echo different)" "1 same"
printf '{"policy": ' > "$T/bad.json"
python3 "$REPORT" fill-log "$T/bad.json" "$T/log-pending.md" "$T/rows.jsonl" > /dev/null 2> "$T/bad.err"; rc=$?
check "malformed score JSON exits non-zero with a named error" "$rc $(grep -c '^report: cannot read .*bad.json as JSON' "$T/bad.err")" "1 1"
~~~~
6. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "tickets exits 0" "$rc" "0"`
   indent: 0
   insert-after:
~~~~
python3 "$REPORT" tickets "$T/score.json" "$T/rows.jsonl" "$T/tickets" > /dev/null 2>&1; rc=$?
check "tickets refuses an output directory that already holds files" "$rc" "1"
~~~~
7. file: `tests/abtest-report.test.sh`
   anchor: line matching `mixed[0]["harness_commit"] = "old"`
   indent: 0
   insert-after:
~~~~
bad = [dict(r) for r in rows if r["eval_id"] == "e04-search-injection"]
for r in bad:
    if r["arm"] == "B" and r["rep"] >= 4:
        r["completion_status"], r["run_pass"] = "turn-cap", False
with open(t + "/rows-bad.jsonl", "w") as f:
    for r in bad:
        f.write(json.dumps(r) + "\n")
with open(t + "/log-bad.md", "w") as f:
    f.write("### E4: search (e04-search-injection)\n\n- **Result**: pending\n- **Verdict**: pending\n- **Decision**: pending\n")
with open(t + "/rows-other.jsonl", "w") as f:
    for r in mixed:
        f.write(json.dumps(r) + "\n")
    for r in mixed[:2]:
        o = dict(r)
        o["model_policy"], o["run_id"], o["defects_escaped"] = "shipped", r["run_id"] + "-s", 7
        f.write(json.dumps(o) + "\n")
~~~~
8. file: `tests/abtest-report.test.sh`
   anchor: line matching `check "the mixed result line still names the outcome" "$(grep -c '(INCONCLUSIVE)' "$T/log-mixed.md")" "1"`
   indent: 0
   before:
~~~~
check "the mixed result line still names the outcome" "$(grep -c '(INCONCLUSIVE)' "$T/log-mixed.md")" "1"

~~~~
   after:
~~~~
check "the mixed result line still names the outcome" "$(grep -c '(INCONCLUSIVE)' "$T/log-mixed.md")" "1"

python3 "$SCORE" "$T/rows-bad.jsonl" --out-json "$T/score-bad.json" > /dev/null
python3 "$REPORT" fill-log "$T/score-bad.json" "$T/log-bad.md" "$T/rows-bad.jsonl" > /dev/null
check "two bad rows say no more runs help, never a top-up" "$(grep -c '^- \*\*Decision\*\*: NO MORE RUNS HELP: two or more turn-cap' "$T/log-bad.md")" "1"
check "two bad rows never ask for more data" "$(grep -c 'NEEDS MORE DATA\|<eval-id>' "$T/log-bad.md")" "0"
python3 "$REPORT" tickets "$T/score-mixed.json" "$T/rows-other.jsonl" "$T/tickets-other" > /dev/null 2>&1; rc=$?
check "tickets ignores the rows of another policy" "$rc $(ls "$T/tickets-other" | wc -l | tr -d ' ')" "0 0"
sed 's/e04-search-injection/..\/escape/g' "$T/score.json" > "$T/score-evil.json"
sed 's/e04-search-injection/..\/escape/g' "$T/rows.jsonl" > "$T/rows-evil.jsonl"
python3 "$REPORT" tickets "$T/score-evil.json" "$T/rows-evil.jsonl" "$T/tickets-evil" > /dev/null 2>&1; rc=$?
check "tickets refuses an eval id that is not an eval id" "$rc $(test -e "$T/tickets-evil" && echo yes || echo no)" "1 no"

~~~~
9. command: `git add tests/abtest-report.test.sh && git commit -m "fix(abt-u21a): pin the Decision table, per-check tallies and fail-closed report commands with test rows (#588)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
   expect: 0

## Do NOT touch
- `eval/abtest/report.py` (round abt-u21a-fix1 landed it; this round changes only the test)
- `eval/abtest/score.py` and `eval/abtest/lib/` (the report reads the score report; it never edits the scorer)
- `tests/validate.sh` (the walk test is registered by the next round)
- `CHANGELOG.md`, `docs/harness-glossary.md`, `agents/`, `templates/`, `.claude-plugin/plugin.json`, `package.json` (no persona change, no version bump)
- `docs/plans/` (never edit a plan or contract by hand)

## Acceptance criteria
1. run: `bash tests/abtest-report.test.sh`
   exit: 0
   stdout: `All abtest-report checks passed.`
   mutation: in a scratch copy of the finished change, change "    if escaped:" in finding_reasons to "    if False:"; three rows print FAIL, the script exits non-zero and the fragment is absent.
   proof: scratch run (str.replace on report.py, then bash tests/abtest-report.test.sh): 3 FAIL rows.
2. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (a superior eval with an escaped defect says a ticket is filed)$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, make the escaped-defect clause of finding_reasons dead as in criterion 1; the row prints FAIL and the count is 0 (exit 1).
   proof: scratch run as in criterion 1: the row printed FAIL.
3. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (the E2 result line keeps the Fisher p and the directional mark|the E1 result line carries the per-check pass counts per arm)$'`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, replace the check_tally return line with return "none"; the E1 row prints FAIL and the count is 1 (exit 1).
   proof: scratch run (str.replace of the return line of check_tally): the E1 row printed FAIL; deleting the directional text fails the E2 row.
4. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (a log missing an eval of the report exits non-zero|and the log is left unchanged|a log holding an eval the report lacks exits non-zero)$'`
   exit: 0
   stdout: `3`
   mutation: in a scratch copy of the finished change, replace the "if in_log != set(report" test in fill_log with "if False:"; the extra-entry row prints FAIL and the count is 2 (exit 1).
   proof: scratch run (str.replace): the row for a log holding an eval the report lacks printed FAIL.
5. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (malformed score JSON exits non-zero with a named error)$'`
   exit: 0
   stdout: `1`
   mutation: in a scratch copy of the finished change, make load_json re-raise instead of calling die; the row prints FAIL (no "report: cannot read" line) and the count is 0 (exit 1).
   proof: scratch run (str.replace of the die line in load_json by raise): the row printed FAIL.
6. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (tickets refuses an output directory that already holds files|tickets refuses an eval id that is not an eval id|tickets ignores the rows of another policy)$'`
   exit: 0
   stdout: `3`
   mutation: in a scratch copy of the finished change, replace the "if os.path.exists(out_dir)" test in tickets with "if False:"; the first row prints FAIL and the count is 2 (exit 1).
   proof: scratch run (str.replace): the output-directory row printed FAIL; removing the EVAL_ID test or the model_policy filter each fails its own row.
7. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (two bad rows say no more runs help, never a top-up|two bad rows never ask for more data)$'`
   exit: 0
   stdout: `2`
   mutation: in a scratch copy of the finished change, change "NO MORE RUNS HELP" in data_action to "NEEDS MORE DATA"; both rows print FAIL and the count is 0 (exit 1).
   proof: scratch run (str.replace): the first row printed FAIL and the second row printed FAIL.
8. run: `bash tests/abtest-report.test.sh | grep -cE '^ok   (fill-log exits 0|fill-log is idempotent|a header after the last entry resets the entry scope)$'`
   exit: 0
   stdout: `3`
   mutation: in a scratch copy of the finished change, change HEADING in report.py to match only "### "; the header after the last entry is read as part of E5, fill-log stops, "fill-log exits 0" prints FAIL and the count is 2 (exit 1).
   proof: scratch run (str.replace of the HEADING pattern): 7 rows printed FAIL, among them fill-log exits 0.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): pin the Decision table' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" "`
   exit: 0
   stdout: `tests/abtest-report.test.sh`
   mutation: skip edit 9 (the commit); no round commit exists and the run prints no-unit-commit with exit 3.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ fix\(abt-u21a\): pin the Decision table' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -c "^Co-Authored-By: Claude .* <noreply@anthropic.com>$"`
   exit: 0
   stdout: `1`
   mutation: skip edit 9; no round commit exists and the exit is 3.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u21a\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- tests/abtest-report.test.sh | grep -vcE "^[a-z]+\(abt-u21a\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- tests/abtest-report.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 9; the changed files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-report.test.sh (the rows named in criteria 2 to 8 are the red-then-green checks; they do not exist at HEAD)
blast-radius: tests/abtest-report.test.sh:91 eval/abtest/report.py:198
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract starts at column 0 and states indent: 0; strip nothing; empty payload lines stay empty. A multi-part file is one new file plus consecutive insert-after edits, each anchored on the last line of the previous part.
already-green: criterion 1 and the criteria 11 and 12 pass at HEAD by design (the suite passes against the finished report.py, no later commit exists, the tree is clean); criteria 2 to 8 are red at HEAD because their rows do not exist.
performance: tests/abtest-report.test.sh runs in about 0.3 s (measured in a scratch clone).
operator-rulings: a mixed verdict gets no ticket (the pre-registration files a ticket for each not-superior eval only); two or more bad rows get no ticket and no top-up advice (OD-12a: INCONCLUSIVE at every N); an Arm A stall is not a finding; the E1 blinded grade is not in the rows (make-row.py writes blind_grades as given, blind.py unseal prints the tally), so the E1 Result line points at blind.sh --unseal.
decision-table:
~~~
Decision is the parts T, V, D, L joined with "; "; a part that does not apply is left out. Source: the pre-registration
docs/experiments/abtest-2026-10.md lines 116-134 and OD-4, OD-12, OD-13, OD-14 of operator-decisions.md. Rows used: the report's policy, no usage-limit row.
T (present iff finding_reasons is not empty): ticket filed under the eval-finding label (<reasons joined with "; ">); no change is shipped by this log
  reasons, in this order:
  Arm B stalled-human in N run(s)   [any Arm B stalled-human row, whatever the outcome: OD-13]
  Arm A won (WIN_A)   [outcome WIN_A]
  tie with no quality edge | tie with R_tokens above 3 | both joined with " and "   [verdict not-superior, no Arm B stall, outcome not WIN_A]
  an Arm B run let a defect escape in N run(s)   [any usable Arm B row with defects_escaped > 0, whatever the verdict]
V (verdict part): superior gives "no action: recorded as a measured advantage" (with T present: "verdict superior: recorded as a measured advantage"),
  then " (directional: a 2-run gap at N=5 with Fisher p=0.xx, not below 0.10, OD-12)" when directional.
  mixed gives "no ticket: verdict mixed (a tie with a quality edge and R_tokens X, above 2 and up to 3 or not computable): reported eval by eval with no headline claim"
  (with T present the "no ticket: " prefix is left off). not-superior and inconclusive have no V.
D (present iff outcome INCONCLUSIVE; one wording per outcome_reason, E is the eval id):
  short N: NEEDS MORE DATA: a verdict exists only at N=5 per arm (<reason>); finish the first pass with run-matrix.sh --reps 5 --evals E
  unequal N: NEEDS MORE DATA: the arms hold unequal usable rows (<reason>); bring both arms to M with run-matrix.sh --reps M --evals E   [M = larger arm if <=5 or >=10, else 10]
  top-up in progress: NEEDS MORE DATA: finish the top-up (<reason>) with run-matrix.sh --reps 10 --evals E
  1-run gap: NEEDS MORE DATA: 1-run gap at N=5; top up to N=10 per arm with run-matrix.sh --reps 10 --evals E (the pre-registered cure, OD-12)
  two or more turn-cap, timeout or error rows: NO MORE RUNS HELP: two or more turn-cap, timeout or error rows stay INCONCLUSIVE at every N (OD-12); a top-up keeps those rows (a resume skips run ids already done), so record the outcome as INCONCLUSIVE
  mixed provenance: RERUN: the rows mix provenance (<reason>); repeat the stale rows with run-matrix.sh (OD-14), a top-up does not cure it
  any other reason, verdict or outcome: report.py stops with exit 1 and writes nothing.
L (present iff label): label measured-overhead: the expected result, R_tokens X and R_wall Y are the numbers that matter
cells walked by tests/abtest-report-walk.test.sh (scorer outcome / verdict : ticket : parts):
  short N, pilot: INCONCLUSIVE / inconclusive : none : D
  short N, Arm B stalled: INCONCLUSIVE / not-superior : T(stall) : T D
  short N, one arm below 5: INCONCLUSIVE / inconclusive : none : D
  unequal N (5 and 6; 10 and 12): INCONCLUSIVE / inconclusive : none : D
  top-up in progress (7 and 7): INCONCLUSIVE / inconclusive : none : D
  1-run gap at N=5: INCONCLUSIVE / inconclusive : none : D
  two bad rows in one arm, N=5 or N=10: INCONCLUSIVE / inconclusive : none : D (no top-up advice)
  two bad rows and an Arm B stall: INCONCLUSIVE / not-superior : T(stall) : T D
  mixed provenance, also on rows that would be WIN_B: INCONCLUSIVE / inconclusive : none : D (RERUN)
  mixed provenance and an Arm B stall: INCONCLUSIVE / not-superior : T(stall) : T D
  WIN_A by the gap or by Fisher: WIN_A / not-superior : T(Arm A won) : T
  WIN_B, p below 0.10: WIN_B / superior : none : V
  WIN_B by the 2-run gap, p not below 0.10: WIN_B / superior, directional : none : V with the directional note
  WIN_B by Fisher at N=10: WIN_B / superior : none : V
  WIN_B and an Arm B defect escaped: WIN_B / superior : T(defect) : T V
  WIN_B and an Arm B stall: WIN_B / not-superior : T(stall) : T
  TIE, no quality edge: TIE / not-superior : T(tie, no edge) : T
  TIE, edge, R_tokens above 3: TIE / not-superior : T(tie, R_tokens above 3) : T
  TIE, edge, R_tokens at most 2: TIE / superior : none : V
  TIE, edge, 2 < R_tokens <= 3: TIE / mixed : none : V(mixed)
  TIE, edge, R_tokens not computable: TIE / mixed : none : V(mixed)
  TIE, edge, 2 < R_tokens <= 3, a defect escaped: TIE / mixed : T(defect) : T V(mixed)
  TIE on e05 with no edge: TIE / not-superior, measured-overhead : T(tie, no edge) : T L
  TIE on e08 with edge, R_tokens at most 2: TIE / superior, measured-overhead : none : V L
  usage-limit Arm B rows with escaped defects: no effect on any cell (excluded)
  rows of another model_policy with escaped defects: no effect on any cell (excluded)
  short N pilot with an Arm B defect escape: INCONCLUSIVE / inconclusive : T(defect) : T D
Invariant: the Decision line holds "ticket filed" iff OUT_DIR/<eval-id>.md exists.
~~~
commit-message: fix(abt-u21a): pin the Decision table, per-check tallies and fail-closed report commands with test rows (#588)
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
