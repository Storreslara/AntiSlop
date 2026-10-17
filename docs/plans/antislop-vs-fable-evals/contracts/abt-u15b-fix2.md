Unit: abt-u15b

## Objective
blind.py removes every line that carries a Unit: or STATUS: label, whatever wraps the label, whatever spaces (non-breaking included) surround it and whatever follows it, and keeps only a Unit: label whose value is a price or the word percent; it also redacts the Arm B terms ready-for-review, ready-for-agent, wip-handoff, ESCALATE-TO-HUMAN, INSUFFICIENT-CONTEXT and SPEC-GAP and drops CLAUDE.md, .claude-plugin/, microworlds/, a root wiki/ and a nested docs/plans/ from the diff; a committed sample of 51 real agent lines proves none survives. Fixes the second reviewer FAIL of 2026-10-17T20:05:00Z (commits 38ac0ade and befa3a79 stay in history). One commit.

## Retrieval
GitHub issues: `gh issue view 596 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`. Original contract: `docs/plans/antislop-vs-fable-evals/contracts/abt-u15b.md`; first fix contract: `docs/plans/antislop-vs-fable-evals/contracts/abt-u15b-fix1.md` (its objective text said a bare Unit: line keeps the next line and survives; this contract replaces that: a bare label line is removed and the next line survives).

## Affected files
- `eval/abtest/lib/blind.py` (anchor: line matching `UNIT_ID = r"`)
- `tests/abtest-blind.test.sh` (anchor: line matching `"abt-keep next line",`)

## Ordered edits
1. command: `test "$(grep -cF 'STATUS_VALUE = r"' eval/abtest/lib/blind.py)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/blind.py`
   anchor: line matching `UNIT_ID = r"`
   indent: 0
   before:
~~~~
# A Unit: line is dropped only when its value looks like a unit id (letters, then a separator or a digit),
# a STATUS: line only when its value is complete or incomplete; "Unit: percent" and "Price per Unit: $5" stay.
UNIT_ID = r"(?:[A-Za-z]+[-._#][A-Za-z0-9._#-]*|[A-Za-z]+[0-9][A-Za-z0-9._#-]*|#[0-9]+)"
STATUS_VALUE = r"(?:complete|incomplete\b.*)"
~~~~
   after:
~~~~
# A line with a Unit: or STATUS: label is removed whole: whatever wraps the label (bold, code, quotes, brackets,
# underscores), whatever spaces (non-breaking ones too) surround it and whatever follows it. Fail closed: only a
# Unit: label whose value is a price or the word percent survives ("Unit: percent", "Price per Unit: $5"). A Unit:
# line only appears in Arm B output, so a surviving one is an arm tell.
LABEL_TAIL = r'(?![A-Za-z])[^\S\n]*[*_`"\'\])]*[^\S\n]*[:\uff1a]'
BENIGN_UNIT = r"[^\w$\n]*(?:\$\d[\d.,]*|percent(?:age)?)[^\w\n]*$"
~~~~
3. file: `eval/abtest/lib/blind.py`
   anchor: line matching `Unit:\**[ \t]*{UNIT_ID}`
   indent: 0
   before:
~~~~
    (re.compile(rf"^.*\b(?:Unit:\**[ \t]*{UNIT_ID}.*|STATUS:\**[ \t]*{STATUS_VALUE}\W*)$", re.MULTILINE | re.IGNORECASE), "[line removed]"),
~~~~
   after:
~~~~
    (re.compile(rf"^.*(?<![A-Za-z])(?:Unit{LABEL_TAIL}(?!{BENIGN_UNIT})|STATUS{LABEL_TAIL}).*$", re.MULTILINE | re.IGNORECASE), "[line removed]"),
~~~~
4. file: `eval/abtest/lib/blind.py`
   anchor: line matching `domain-modeling)`
   indent: 0
   before:
~~~~
    (re.compile(r"\b(?:personas?|pending-review|pathfinder|roast-work|domain-modeling)\b|(?<![A-Za-z])\.?pass markers?\b", re.IGNORECASE), "[term]"),
~~~~
   after:
~~~~
    (re.compile(r"\b(?:personas?|pending-review|pathfinder|roast-work|domain-modeling|ready-for-review|ready-for-agent|wip-handoff|ESCALATE-TO-HUMAN|INSUFFICIENT-CONTEXT|SPEC-GAP)\b|(?<![A-Za-z])\.?pass markers?\b", re.IGNORECASE), "[term]"),
~~~~
5. file: `eval/abtest/lib/blind.py`
   anchor: line matching `DROP = (`
   indent: 0
   before:
~~~~
DROP = (re.compile(r"\.(pass|fail)$"), re.compile(r"(^|/)\.claude/"), re.compile(r"^docs/plans/"), re.compile(r"(^|/)docs/(wiki|adr)/"))
~~~~
   after:
~~~~
DROP = (re.compile(r"\.(pass|fail)$"), re.compile(r"(^|/)\.claude(-plugin)?/"), re.compile(r"(^|/)CLAUDE\.md$"), re.compile(r"(^|/)(docs/plans|microworlds)/"), re.compile(r"^wiki/"), re.compile(r"(^|/)docs/(wiki|adr)/"))
~~~~
6. file: `tests/abtest-blind.test.sh`
   anchor: line matching `+adr secret`
   indent: 0
   insert-after:
~~~~
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
~~~~
7. file: `tests/abtest-blind.test.sh`
   anchor: line matching `"abt-keep next line",`
   indent: 0
   insert-after:
~~~~
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
~~~~
8. file: `tests/abtest-blind.test.sh`
   anchor: line matching `a bare Unit: line does not take`
   indent: 0
   before:
~~~~
check "a bare Unit: line does not take the next line with it, both survive" "$(cat "$OUT"/blind/*/report.md | grep -cxE 'Unit:|abt-keep next line')" "8"
~~~~
   after:
~~~~
check "a bare Unit: line is removed and does not take the next line with it" "$(cat "$OUT"/blind/*/report.md | grep -cx 'abt-keep next line')|$(cat "$OUT"/blind/*/report.md | grep -cx 'Unit:')" "4|0"
~~~~
9. file: `tests/abtest-blind.test.sh`
   anchor: line matching `the diff drops persona files`
   indent: 0
   before:
~~~~
check "the diff drops persona files, plans and markers" "$(cat "$OUT"/blind/*/diff.patch | grep -cE 'claude|docs/plans|docs/wiki|docs/adr|PASS e01|secret persona|nested secret|wiki secret|adr secret')" "0"
~~~~
   after:
~~~~
check "the diff drops persona files, plans and markers" "$(cat "$OUT"/blind/*/diff.patch | grep -cE 'claude|docs/plans|docs/wiki|docs/adr|PASS e01|secret persona|nested secret|wiki secret|adr secret|claude md secret|plugin secret|microworld secret|root wiki secret|nested plan secret')" "0"
~~~~
10. file: `tests/abtest-blind.test.sh`
   anchor: line matching `check "paths with a tilde or an underscore are redacted whole and keep the trailing dot"`
   indent: 0
   insert-after:
~~~~
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
~~~~
11. command: `git add eval/abtest/lib/blind.py tests/abtest-blind.test.sh && git commit -m "fix(abt-u15b): a Unit or STATUS label of any shape removes its line and the blinding drops more Arm B terms and paths (#596)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
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
   mutation: revert the rule, `git checkout befa3a79 -- eval/abtest/lib/blind.py` in a scratch copy of the finished change; ten rows FAIL (the variant, bare-label, new-term, leak-scan and corpus rows) and the script exits non-zero.
   proof: scratch run: 37 passed, 10 failed.
2. run: `bash tests/abtest-blind.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `47`
   mutation: skip edit 10 (the new rows and the corpus); the count is 40.
3. run: `python3 -I -c 'import importlib.util as u;s=u.spec_from_file_location("b","eval/abtest/lib/blind.py");m=u.module_from_spec(s);s.loader.exec_module(m);print(m.redact("Unit: \"abt-x\"\nUnit: [abt-x]\nUnit: 596\nSTATUS: complete — done\n**Unit**: abt-x\n__Unit:__ abt-x\nUnit : abt-x\nUnit: abt-x\nUnit : abt-x\nUnit： abt-x\nUnit:\nUnit: any words\nStatus: x\nUnit: percent\nPrice per Unit: $5.").replace(chr(10),"|"))'`
   exit: 0
   stdout: `[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|Unit: percent|Price per Unit: $5.`
   mutation: skip edit 3 (the rule); with the old rule still referencing UNIT_ID the script exits 1 with a NameError; with edit 2 skipped too the labels print unchanged.
   proof: scratch run: with the constants and the rule restored to befa3a79, the first line prints as `Unit: "abt-x"` and the line differs.
4. run: `python3 -I -c 'import importlib.util as u;s=u.spec_from_file_location("b","eval/abtest/lib/blind.py");m=u.module_from_spec(s);s.loader.exec_module(m);print(m.redact("ready-for-review ESCALATE-TO-HUMAN wip-handoff INSUFFICIENT-CONTEXT SPEC-GAP ready-for-agent"))'`
   exit: 0
   stdout: `[term] [term] [term] [term] [term] [term]`
   mutation: skip edit 4 (the terms); the line prints unchanged.
5. run: `python3 -I -c 'import importlib.util as u;s=u.spec_from_file_location("b","eval/abtest/lib/blind.py");m=u.module_from_spec(s);s.loader.exec_module(m);print(m.filter_diff("diff --git a/CLAUDE.md b/CLAUDE.md\n+a\ndiff --git a/.claude-plugin/p.json b/.claude-plugin/p.json\n+b\ndiff --git a/microworlds/m b/microworlds/m\n+c\ndiff --git a/wiki/w.md b/wiki/w.md\n+d\ndiff --git a/sub/docs/plans/q.md b/sub/docs/plans/q.md\n+e\ndiff --git a/src/a.js b/src/a.js\n+keep\n").replace(chr(10),"|"))'`
   exit: 0
   stdout: `diff --git a/src/a.js b/src/a.js|+keep|`
   mutation: skip edit 5 (the DROP list); the five dropped files print too and the line differs.
6. run: `grep -c 'STATUS_VALUE\|UNIT_ID' eval/abtest/lib/blind.py`
   exit: 1
   stdout: `0`
   mutation: skip edit 2 (the label constants); stdout 3 and the exit is 0.
7. run: `awk '/^CORPUS_EOF$/{e=1} s&&!e{n++} /<< .CORPUS_EOF.$/{s=1} END{print n+0}' tests/abtest-blind.test.sh`
   exit: 0
   stdout: `51`
   mutation: skip edit 10; stdout 0.
8. run: `grep -cF 'microworld secret' tests/abtest-blind.test.sh`
   exit: 0
   stdout: `3`
   mutation: skip edit 6 (the diff fixtures) or edit 9 (the drop row pattern); stdout 2.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); echo "$(echo "$L" | wc -l | tr -d ' ') commits; $(git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" ")"`
   exit: 0
   stdout: `3 commits; eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   mutation: skip edit 11 (the commit); only two unit commits exist and the run prints 2 commits.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -cE "^(fix\(abt-u15b\): a Unit or STATUS label of any shape|Co-Authored-By: Claude .* <noreply@anthropic.com>$)"`
   exit: 0
   stdout: `2`
   mutation: skip edit 11; the newest unit commit is fix1 (a different subject), so only the trailer line matches and stdout is 1.
11. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/blind.py tests/abtest-blind.test.sh | grep -vcE "^[a-z]+\(abt-u15b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
12. run: `git status --porcelain -- eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 11; the two edited files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-blind.test.sh (criteria 1 to 5 are red-then-green: the new rows and the redact() lines FAIL against the blind.py of befa3a79; the suite printed 37 passed, 10 failed there)
blast-radius: eval/abtest/lib/blind.py:24 eval/abtest/lib/blind.py:35 eval/abtest/blind.sh:11 tests/abtest-blind.test.sh:166
fix-of: 2026-10-17T20:05:00Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract states indent: 0 and is inserted exactly as written, including the four leading spaces of the rule line in edit 3 and of the fixture lines in edit 7 (they sit inside a Python list or the REDACT list); strip nothing; empty payload lines stay empty. Inline-code payloads are literal. The before payloads are exact copies of the committed text at befa3a79: copy, do not retype. Edit 2's before payload is the four lines from the first comment line above UNIT_ID through the STATUS_VALUE line.
why: two haiku attempts each fixed the Unit: and STATUS: shapes the reviewer had listed and each left the next shapes (an id wrapped in code, quotes or brackets; text after complete; bold or underscore wrapping; spacing before the colon; a non-breaking space). A pick-the-shapes rule cannot close this, so the rule now fails closed: a line is removed whole when it holds a Unit: or STATUS: label (LABEL_TAIL allows wrapper characters and any horizontal whitespace, NBSP included, between the word and the colon, and a full-width colon), whatever the value is. The only survivors are a Unit: label whose value is a price or the word percent (BENIGN_UNIT), the two benign lines the unit always kept. A bare label line is removed too; the line after it survives. STATUS has no benign value. Cost accepted: any report line with a Status: or Unit: label is lost to the grader, including prose such as a Graph status: line; the report is context, the graded item is ASSUMPTIONS.md. The committed sample in edit 10 is 51 real lines from this repo's own session transcripts and must stay removed whole; the leak-scan row checks the shape in the built reports without relying on the LEAK variable.
judgement-calls: folded in because each is one provable line with a row: the six Arm B terms (ready-for-review, ready-for-agent, wip-handoff, ESCALATE-TO-HUMAN, INSUFFICIENT-CONTEXT, SPEC-GAP), the DROP paths CLAUDE.md, .claude-plugin/, microworlds/, a root wiki/ and a nested docs/plans/. Not folded in (report as follow-ups): a Unit: label on its own line followed by the id on the next line leaves that id line; ids and session or issue numbers inside prose sentences (for example the sentence that names a unit without a label); a corpus refresh from newer transcripts; hiding the whole report.md when it still names Arm B vocabulary beyond the term list.
fail-closed-tests: every new row compares a count against an expected value and the removal rows are paired with positive-control rows (the fixture lines must be in the unredacted summaries and run diffs, 6 files each), so a missing fixture reads as FAIL; the leak-scan row also expects 8 benign survivors.
already-green: criterion 1 passes at HEAD because the suite is not yet edited (it is red only against the new rows), and criteria 11 and 12 pass at HEAD by design (no later untagged commit, a clean scoped tree) and turn red only when a later commit is untagged or an edit is left uncommitted.
replay: the finished change was replayed in a git clone --no-hardlinks of HEAD befa3a79: the suite printed 47 ok lines and "All abtest-blind checks passed."; the same suite against the blind.py of befa3a79 printed 37 passed, 10 failed; skipping edit 4, 5, 6, 7 or 10 made the suite fail or the count drop as each mutation line states; removing the STATUS branch, the wrapper class, the benign lookahead or the non-breaking space class from the rule each failed 3 to 7 rows.
no-real-claude: nothing here runs the claude CLI; the test builds synthetic run directories in a temp directory.
gate-names: the test builds the marker directory name from two parts on purpose; apply every edit with the Write or Edit tool.
commit-message: fix(abt-u15b): a Unit or STATUS label of any shape removes its line and the blinding drops more Arm B terms and paths (#596)
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
criterion 10: <FILL: exit and stdout>
criterion 11: <FILL: exit and stdout>
criterion 12: <FILL: exit and stdout>
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
