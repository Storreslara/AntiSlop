Unit: abt-u15b

## Objective
blind.py removes a Unit: or STATUS: line whenever its value starts with a unit id (a bare issue number included), also when the id is followed by more text, when the label is bolded, or when the id sits on the next line; it redacts a .claude path with a tilde or any other non-space character whole, keeping the trailing punctuation; the test fixture and the leak pattern cover each shape. Fixes the reviewer FAIL of 2026-10-17T19:05:24Z (commit 38ac0ade stays in history). One commit.

## Retrieval
GitHub issues: `gh issue view 596 --repo Storreslara/AntiSlop`. Siblings: `gh issue list --repo Storreslara/AntiSlop --label plan/antislop-vs-fable-evals`. Spec: `docs/plans/antislop-vs-fable-evals.md`; operator overrides (win on conflict): `docs/plans/antislop-vs-fable-evals/operator-decisions.md`. Original contract: `docs/plans/antislop-vs-fable-evals/contracts/abt-u15b.md`.

## Affected files
- `eval/abtest/lib/blind.py` (anchor: line matching `UNIT_ID = r"`)
- `tests/abtest-blind.test.sh` (anchor: line matching `"- Unit: percent",`)

## Ordered edits
1. command: `test "$(grep -cF 'Unit:\s*{UNIT_ID}' eval/abtest/lib/blind.py)" = 1 && test -z "$(git status --porcelain --untracked-files=no -- . ':!.claude/agent-memory')"`
   expect: 0
2. file: `eval/abtest/lib/blind.py`
   anchor: line matching `UNIT_ID = r"`
   before: `UNIT_ID = r"(?:[A-Za-z]+[-._#][A-Za-z0-9._#-]*|[A-Za-z]+[0-9][A-Za-z0-9._#-]*)"`
   after: `UNIT_ID = r"(?:[A-Za-z]+[-._#][A-Za-z0-9._#-]*|[A-Za-z]+[0-9][A-Za-z0-9._#-]*|#[0-9]+)"`
3. file: `eval/abtest/lib/blind.py`
   anchor: line matching `\.claude(?:/`
   before: `    (re.compile(r"\.claude(?:/[\w./-]*[\w/-])?"), "[path]"),`
   after: `    (re.compile(r"\.claude(?:/\S*[\w/~-])?"), "[path]"),`
4. file: `eval/abtest/lib/blind.py`
   anchor: line matching `Unit:\s*{UNIT_ID}`
   before: `    (re.compile(rf"^.*\b(?:Unit:\s*{UNIT_ID}|STATUS:\s*{STATUS_VALUE})\W*$", re.MULTILINE | re.IGNORECASE), "[line removed]"),`
   after: `    (re.compile(rf"^.*\b(?:Unit:\**[ \t]*{UNIT_ID}.*|STATUS:\**[ \t]*{STATUS_VALUE}\W*)$", re.MULTILINE | re.IGNORECASE), "[line removed]"),`
5. file: `tests/abtest-blind.test.sh`
   anchor: line matching `"- Unit: percent",`
   indent: 0
   insert-after:
~~~~
    "Unit: abt-x (#1) done",
    "**Unit:** abt-x",
    "Unit: #596",
    "Unit: e01-ambiguous-tax - dispatched to the lead",
    "**STATUS:** complete",
    "Unit:",
    "abt-keep next line",
    "Also .claude/x~y and .claude/agent-memory/a_b.md.",
~~~~
6. file: `tests/abtest-blind.test.sh`
   anchor: line matching `LEAK='`
   before: `|\bUnit: *[A-Za-z]+[-._#0-9]|\bSTATUS: *(in)?complete|`
   after: `|\bUnit:\** *(#[0-9]|[A-Za-z]+[-._#0-9])|\bSTATUS:\** *(in)?complete|`
7. file: `tests/abtest-blind.test.sh`
   anchor: line matching `check "a redacted .claude path keeps its trailing punctuation"`
   indent: 0
   insert-after:
~~~~
check "a Unit: line with text after the id, a bolded one and a bare issue number are removed" "$(cat "$OUT"/blind/*/report.md | grep -cE 'abt-x|Unit: #596|dispatched to the lead')" "0"
check "a bolded STATUS: line is removed" "$(cat "$OUT"/blind/*/report.md | grep -c 'STATUS')" "0"
check "a bare Unit: line does not take the next line with it, both survive" "$(cat "$OUT"/blind/*/report.md | grep -cxE 'Unit:|abt-keep next line')" "8"
check "paths with a tilde or an underscore are redacted whole and keep the trailing dot" "$(cat "$OUT"/blind/*/report.md | grep -c 'Also \[path\] and \[path\]\.')" "4"
~~~~
8. command: `git add eval/abtest/lib/blind.py tests/abtest-blind.test.sh && git commit -m "fix(abt-u15b): Unit and STATUS lines go whatever follows the id and tilde paths are redacted whole (#596)" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"`
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
   mutation: skip edit 4 (the Unit and STATUS rule); the removed-line rows and the leak row FAIL and the script exits non-zero.
2. run: `bash tests/abtest-blind.test.sh | grep -c '^ok '`
   exit: 0
   stdout: `40`
   mutation: skip edit 7 (the four new rows); the count is 36.
3. run: `bash tests/abtest-blind.test.sh | grep -c '^ok   .*\(survive\|keeps\)'`
   exit: 0
   stdout: `9`
   mutation: skip edit 5 (the fixture lines); the bare-line row FAILs and the count is 8.
4. run: `python3 -I -c 'import importlib.util as u;s=u.spec_from_file_location("b","eval/abtest/lib/blind.py");m=u.module_from_spec(s);s.loader.exec_module(m);print(m.redact("Unit: abt-u15b (#596)\nUnit: abt-u15b done\n**Unit:** abt-u15b\nUnit: #596\nUnit: e01-ambiguous-tax - dispatched\n**STATUS:** complete\nUnit: percent\nPrice per Unit: $5\nUnit:\nabt-keep").replace(chr(10),"|"))'`
   exit: 0
   stdout: `[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|[line removed]|Unit: percent|Price per Unit: $5|Unit:|abt-keep`
   mutation: skip edit 4; the first line prints as `Unit: abt-u15b (scope)` and the line differs.
5. run: `python3 -I -c 'import importlib.util as u;s=u.spec_from_file_location("b","eval/abtest/lib/blind.py");m=u.module_from_spec(s);s.loader.exec_module(m);print(m.redact("Also .claude/x~y and .claude/agent-memory/a_b.md. See (.claude/foo), then .claude."))'`
   exit: 0
   stdout: `Also [path] and [path]. See ([path]), then [path].`
   mutation: skip edit 3 (the path rule); the first path prints as `[path]~y` and the line differs.
6. run: `grep -cF '|#[0-9]+)"' eval/abtest/lib/blind.py`
   exit: 0
   stdout: `1`
   mutation: skip edit 2 (the bare issue number alternative); stdout 0 and the exit is 1.
7. run: `grep -cF 'Unit:\** *(#[0-9]|' tests/abtest-blind.test.sh`
   exit: 0
   stdout: `1`
   mutation: skip edit 6 (the widened leak pattern); stdout 0 and the exit is 1.
8. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; c=$(echo "$L" | sed -n 1p); echo "$(echo "$L" | wc -l | tr -d ' ') commits; $(git diff --name-only "$c~1..$c" | LC_ALL=C sort | paste -sd" ")"`
   exit: 0
   stdout: `2 commits; eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   mutation: skip edit 8 (the commit); only the original unit commit exists and the run prints 1 commits.
9. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; git log -1 --format=%B "$(echo "$L" | sed -n 1p)" | grep -cE "^(fix\(abt-u15b\): Unit and STATUS lines go whatever follows the id|Co-Authored-By: Claude .* <noreply@anthropic.com>$)"`
   exit: 0
   stdout: `2`
   mutation: skip edit 8; the newest unit commit is the original (a different subject), so only the trailer line matches and stdout is 1.
10. run: `L=$(git log --format='%H %s' | grep -E '^[0-9a-f]+ [a-z]+\(abt-u15b\): ' | cut -d' ' -f1); test -n "$L" || { echo no-unit-commit; exit 3; }; E=$(echo "$L" | head -1); git log --format=%s "$E..HEAD" -- eval/abtest/lib/blind.py tests/abtest-blind.test.sh | grep -vcE "^[a-z]+\(abt-u15b\): "`
   exit: 1
   stdout: `0`
   mutation: add a commit with subject `fix: x` touching one content file after the unit commit; stdout 1.
   proof: scratch run: with no later commit the count printed 0 (exit 1); a later untagged commit is counted by grep -v, so stdout is 1.
11. run: `git status --porcelain -- eval/abtest/lib/blind.py tests/abtest-blind.test.sh`
   exit: 0
   stdout: empty
   mutation: skip edit 8; the two edited files stay modified and are listed.

## Pre-resolved context
tdd: yes tests/abtest-blind.test.sh (criteria 2 to 5 are red-then-green: the new rows and the redact() lines FAIL at HEAD 38ac0ade)
blast-radius: eval/abtest/lib/blind.py:22 eval/abtest/lib/blind.py:25 eval/abtest/lib/blind.py:26
fix-of: 2026-10-17T19:05:24Z
gate-refusal: if any hook refuses a Bash command, STOP and report the refusal text; never route around it (no scratch-file, renamed-path or reworded-command workaround). Write every file with the Write or Edit tool, not a Bash heredoc.
payload-indent: every fenced payload in this contract states indent: 0 and is inserted exactly as written, including the four leading spaces of the fixture lines (they sit inside a Python list); strip nothing; empty payload lines stay empty. Inline-code payloads are literal. The before payloads are exact copies of the committed text at 38ac0ade: copy, do not retype.
why: the FAIL showed the narrowed Unit rule (it needed the id to end the line) leaving Unit: lines in Arm B output that the previous broad rule removed: an id followed by text, a bolded label, a bare issue number. The rule now removes a line when the value STARTS with a unit id. The label separator is [ \t]* so "Unit:" at the end of a line cannot take the next line. STATUS gets the same bold and same-line handling. The path rule accepts any non-space run (tilde, plus, at, percent) and still ends on a word character, a slash, a tilde or a hyphen so trailing punctuation survives.
judgement-calls: folded in because each is one provable line: [ \t]* instead of \s*, the bare issue number (#596), the bolded STATUS label, the path stop characters. Not folded in: a space inside a .claude path (the path cannot be bounded, "a b.md" leaves "b.md").
fail-closed-tests: every new row compares a count against an expected value and is paired with a presence count (the survivor row expects 8 hits of the bare lines, the path row expects 4), so an empty report reads as FAIL.
already-green: criteria 10 and 11 pass at HEAD by design (no later untagged commit, and a clean scoped tree) and turn red only when a later commit is untagged or an edit is left uncommitted; the first removed-line row of edit 7 is vacuous without the fixture of edit 5 and is red only through it.
replay: the finished change was replayed in a git clone --no-hardlinks of HEAD 38ac0ade: the suite printed 40 ok lines, 9 survivor or keeps lines, "All abtest-blind checks passed."; skipping edit 2, 3, 4, 5 or 7 made the suite exit non-zero or the count drop as each mutation line states.
no-real-claude: nothing here runs the claude CLI; the test builds synthetic run directories in a temp directory.
gate-names: the test builds the marker directory name from two parts on purpose; apply every edit with the Write or Edit tool.
commit-message: fix(abt-u15b): Unit and STATUS lines go whatever follows the id and tilde paths are redacted whole (#596)
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
~~~

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise.
