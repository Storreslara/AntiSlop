Unit: cos-u5

## Objective
Close the glossary notes of the refutation-pass and tg-u2 reviews: (a) `CONTEXT.md`'s FAIL block entry also names the second sense, the FAIL section of the reviewer's returned message, as `agents/reviewer.md` uses it; (b) its FAIL ground entry's "Only ... make one" sentence names every source of a FAIL ground, adding the uncommitted tracked change (the On PASS bullet) and the constitution MUST violation (the Constitution bullet); (c) new entry "verdict block" in `CONTEXT.md`; (d) new entries "dispatch message" (synonym of the personas' "dispatch prompt"), "multi-part stdout spec" and "judge" in `docs/harness-glossary.md`. Every claim an entry makes is checked against the file it describes. The `_Avoid_: FAIL reason, FAIL cause` line stays: cos-u3 already moved the personas to "FAIL ground".

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-cosmetic-closeout.md` (Step 5, Context rows 1a-1f). This file is the contract of record. Dispatch after cos-u2, cos-u3 and cos-u4 have PASSed: the entries describe cos-u2's precheck and cos-u3's reviewer wording. Executor: scribe (glossary custody); `knowledgeWrites` is `apply`.

## Affected files
- `CONTEXT.md` (anchors: line matching `  across sessions instead of relying on one agent's in-session memory.`; line matching `  which is a FAIL ground on its own, or a [[judgment defect]]. Only the`; line matching `_Avoid_: FAIL reason, FAIL cause`)
- `docs/harness-glossary.md` (anchor: the last line of the file, the one starting `(plan 2026-10-27-refutation-pass, unit rfp-u5) — the last line of every [[FAIL block]] since rfp-u3:`)

These are the only paths in scope.

## Ordered edits
Use the Edit tool for every edit, never a Bash heredoc. spec-master checked every anchor occurs exactly once at ab174935.

1. file: `CONTEXT.md`
   anchor: line matching `  across sessions instead of relying on one agent's in-session memory.`
   insert-after:
~~~
  In `agents/reviewer.md`'s Verdict and Refutation pass bullets, "the FAIL
  block" also names the FAIL [[verdict block]] of the reviewer's returned
  message: the defect list and the [[refutation line]] that this on-disk block
  copies verbatim below its two header lines. Both senses hold the same
  defects; only the on-disk block has the `FAIL` and `tier:` header lines and
  the blank separator line.
~~~

2. file: `CONTEXT.md`
   before:
~~~
  which is a FAIL ground on its own, or a [[judgment defect]]. Only the
  acceptance-criteria commands and the materiality filter make one: the
~~~
   after:
~~~
  which is a FAIL ground on its own, or a [[judgment defect]]. Only the
  acceptance-criteria commands, the materiality filter, an uncommitted tracked
  change when the reviewer is about to write its marker, and a constitution
  MUST violation with no recorded deviation in the plan make one: the
~~~

3. file: `CONTEXT.md`
   anchor: line matching `_Avoid_: FAIL reason, FAIL cause`
   insert-after:
~~~

**verdict block**:
(plan 2026-10-29-cosmetic-closeout, unit cos-u5) — the part of the reviewer's
  final message that its Verdict bullet bounds with "nothing else" or "nothing
  more": the verdict line, and on a FAIL the bare defect list and the
  [[refutation line]] after it, which is also called the FAIL block of the
  message (see [[FAIL block]]). It always comes first. Only the advisory
  sections (`roast-work`, `ubiquitous-language`, then `refutation`, each only
  if it fired or ran) and the terminal STATUS line may follow it.
_Avoid_: verdict section
~~~
   (The existing blank line before `**judgment defect**:` stays, so the new entry is separated from it.)

4. file: `docs/harness-glossary.md`
   anchor: the last line of the file, starting `(plan 2026-10-27-refutation-pass, unit rfp-u5) — the last line of every [[FAIL block]] since rfp-u3:`
   insert-after (the file then ends with the `**judge**:` entry's text line and a newline):
~~~

**dispatch message** (synonym: **dispatch prompt**):
(plan 2026-10-29-cosmetic-closeout, unit cos-u5) — the first user message of a writer's transcript: the prompt the writer was dispatched with, which the personas call the dispatch prompt. `hooks/scripts/writer-scope-gate.sh` takes the writer's unit scope from it alone: its `Unit:` line, the entries of its `## Affected files` section (backticked paths, and a bullet's bare first word when it is path-shaped), its exclusions, and the unit's own cited contract file as the baseline commit holds it. A path named only in the message's prose is never in scope. Not a [[dispatch packet]], the eval-case file given to a reviewer under test.

**multi-part stdout spec**:
(plan 2026-10-29-cosmetic-closeout, unit cos-u5; tg-u1's reading, amended by cos-u2) — an acceptance criterion's `stdout:` value made of two or more backticked parts joined by the word `then`, as in `` `0` then `rc=0` ``. `bin/review-precheck.sh` reads it as one expected stdout of several lines: the parts lose their backticks and are joined by newlines, and the command's output, less one trailing newline, must equal that exactly, so a missing line, an extra line and an extra blank line all fail. Any run of spaces may surround `then`; a tab cannot, because the criterion reaches the compare as a tab-separated field. A part never holds a backtick, so a single literal that contains the word then is not split, and text after the last part, as in `` `0` then `1` (two lines) ``, makes the spec a [[judge]]. On a mismatch both sides are printed as backticked lines joined by ` then `, with a backslash, backtick, CR or tab inside a line shown as `\\`, `` \` ``, `\r` or `\t`.

**judge**:
(plan 2026-10-29-cosmetic-closeout, unit cos-u5) — a `bin/review-precheck.sh` line the script cannot decide and leaves to the reviewer; it is neither a failure line nor a pass. `criterion <n>: judge stdout exit=<rc>` when the exit code matched but the `stdout:` spec is not `empty`, one backticked literal or a [[multi-part stdout spec]]; `scope: judge <path> version-stamp-name` when a changed path's file name commonly holds a version stamp in other projects (`package.json`, `plugin.json`, `CHANGELOG.md`, `VERSION`, `pyproject.toml`, `Cargo.toml`, `setup.cfg`) and no earlier scope class settled it. The packet's first line counts them as `judge=<n>`; the reviewer settles each by hand.
~~~

5. command: `git add CONTEXT.md docs/harness-glossary.md && git commit -m "docs(cos-u5): glossary entries verdict block, dispatch message, multi-part stdout spec, judge; FAIL block and FAIL ground reconciled"`
   expect: 0
   Run `git status --short` first; if any other tracked file is modified, leave it unstaged and report it.

## Do NOT touch
- `agents/`, `adapters/`, `templates/`, `.claude/`, `bin/`, `hooks/`, `tests/`, `eval/`, `docs/adr/`, `docs/plans/`
- every other entry of `CONTEXT.md` and `docs/harness-glossary.md` (the `_Avoid_: FAIL reason, FAIL cause` line included)

## Acceptance criteria
1. run: `bash -c 'echo "verdict=$(grep -c "^\*\*verdict block\*\*:$" CONTEXT.md) dispatch=$(grep -c "^\*\*dispatch message\*\* (synonym: \*\*dispatch prompt\*\*):$" docs/harness-glossary.md) multi=$(grep -c "^\*\*multi-part stdout spec\*\*:$" docs/harness-glossary.md) judge=$(grep -c "^\*\*judge\*\*:$" docs/harness-glossary.md)"'`
   exit: 0
   stdout: `verdict=1 dispatch=1 multi=1 judge=1`
   mutation: at ab174935 it prints `verdict=0 dispatch=0 multi=0 judge=0`; pasting edit 3 twice prints `verdict=2`.
2. run: `bash -c 'e=$(awk "/^\*\*FAIL ground\*\*:/{p=1;next} p&&/^\*\*/{exit} p" CONTEXT.md | tr -s " \n" " "); r=$(tr -s " \n" " " < agents/reviewer.md); a=0; for p in "the materiality filter, an uncommitted tracked change when the reviewer is about to write its marker," "and a constitution MUST violation with no recorded deviation in the plan make one"; do printf "%s" "$e" | grep -qF -- "$p" && a=$((a+1)); done; b=0; for p in "If (1) or (2) fails, the verdict is **FAIL**, not PASS" "with no recorded deviation in the plan* is a FAIL ground."; do printf "%s" "$r" | grep -qF -- "$p" && b=$((b+1)); done; echo "entry=$a source=$b"'`
   exit: 0
   stdout: `entry=2 source=2`
   mutation: at ab174935 it prints `entry=0 source=1` (the constitution sentence there says "a FAIL reason"; cos-u3 makes it "a FAIL ground"). Dropping the On PASS FAIL sentence from `agents/reviewer.md` prints `source=1`, so the entry's claim is tied to the persona text.
3. run: `bash -c 'e=$(awk "/^\*\*FAIL block\*\*:/{p=1;next} p&&/^\*\*/{exit} p" CONTEXT.md | tr -s " \n" " "); r=$(tr -s " \n" " " < agents/reviewer.md); a=0; printf "%s" "$e" | grep -qF -- "also names the FAIL [[verdict block]] of the reviewer" && a=1; b=0; for p in "nothing more in the FAIL block" "ending the FAIL block with"; do printf "%s" "$r" | grep -qF -- "$p" && b=$((b+1)); done; echo "entry=$a source=$b"'`
   exit: 0
   stdout: `entry=1 source=2`
   mutation: at ab174935 it prints `entry=0 source=2`.
4. run: `bash -c 'e=$(awk "/^\*\*verdict block\*\*:/{p=1;next} p&&/^\*\*/{exit} p" CONTEXT.md | tr -s " \n" " "); r=$(tr -s " \n" " " < agents/reviewer.md); a=0; for p in "bounds with \"nothing else\" or \"nothing more\"" "and the terminal STATUS line may follow it."; do printf "%s" "$e" | grep -qF -- "$p" && a=$((a+1)); done; b=0; for p in "bounds the verdict block itself" "message is ONLY the verdict block, followed by nothing but the advisory sections and the terminal STATUS line"; do printf "%s" "$r" | grep -qF -- "$p" && b=$((b+1)); done; echo "entry=$a source=$b"'`
   exit: 0
   stdout: `entry=2 source=2`
   mutation: at ab174935 it prints `entry=0 source=1`; before cos-u3 lands, `source=1`.
5. run: `bash -c 'e=$(awk "/^\*\*multi-part stdout spec\*\*:/{p=1;next} p&&/^\*\*/{exit} p" docs/harness-glossary.md | tr -s " \n" " "); a=0; for p in "less one trailing newline, must equal that exactly" "Any run of spaces may surround" "(two lines)" "makes the spec a [[judge]]"; do printf "%s" "$e" | grep -qF -- "$p" && a=$((a+1)); done; out=$(bash tests/review-precheck.test.sh 2>&1); b=0; for p in "OK   (m) extra trailing blank lines fail" "OK   (m) two spaces around then" "OK   (m) text after the last part stays judge" "OK   (m) a backtick in the output is escaped"; do printf "%s\n" "$out" | grep -qxF -- "$p" && b=$((b+1)); done; echo "entry=$a source=$b"'`
   exit: 0
   stdout: `entry=4 source=4`
   mutation: before cos-u2 lands, `source=1` (only the judge case exists); at ab174935 `entry=0 source=1`.
6. run: `bash -c 'j=$(awk "/^\*\*judge\*\*:/{p=1;next} p&&/^\*\*/{exit} p" docs/harness-glossary.md | tr -s " \n" " "); d=$(awk "/^\*\*dispatch message\*\*/{p=1;next} p&&/^\*\*/{exit} p" docs/harness-glossary.md | tr -s " \n" " "); a=0; for p in "criterion <n>: judge stdout exit=<rc>" "scope: judge <path> version-stamp-name"; do printf "%s" "$j" | grep -qF -- "$p" && a=$((a+1)); done; for p in "the first user message of a writer" "a bullet" ; do printf "%s" "$d" | grep -qF -- "$p" && a=$((a+1)); done; b=0; grep -qF "echo \"criterion \$n: judge stdout exit=\$rc\"" bin/review-precheck.sh && b=$((b+1)); grep -qF "say \"scope: judge \$p version-stamp-name\"" bin/review-precheck.sh && b=$((b+1)); grep -qF "map(select(.type == \"user\"))[0].message.content" hooks/scripts/writer-scope-gate.sh && b=$((b+1)); grep -qF "A bullet of the dispatch message" hooks/scripts/writer-scope-gate.sh && b=$((b+1)); echo "entry=$a source=$b"'`
   exit: 0
   stdout: `entry=4 source=4`
   mutation: at ab174935 it prints `entry=0 source=4`. A change of the gate to read the last user message (`[-1]`) prints `source=3`.
7. run: `bash -c 'node tests/context-glossary-links.test.js >/dev/null 2>&1; echo $?'`
   exit: 0
   stdout: `0`
   mutation: writing `[[verdict blocks]]` (no such heading) in edit 1 makes the link test fail and stdout `1`.
8. run: `bash -c 'echo "personas=$(git grep -n "FAIL reason" -- agents adapters .claude/agents | wc -l | tr -d " ") avoid=$(grep -c "^_Avoid_: FAIL reason, FAIL cause$" CONTEXT.md)"'`
   exit: 0
   stdout: `personas=0 avoid=1`
   mutation: before cos-u3 lands, `personas=14`; deleting the `_Avoid_` line prints `avoid=0`.
9. run: `bash -c 'cs=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(cos-u5\): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "CONTEXT\.md|docs/harness-glossary\.md" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: committing an `agents/reviewer.md` edit under a `(cos-u5): ` subject prints `1`.
10. run: `bash -c 'git status --porcelain --untracked-files=no -- CONTEXT.md docs/harness-glossary.md | wc -l | tr -d " "'`
    exit: 0
    stdout: `0`
    mutation: leaving edit 4 uncommitted prints `1`.
11. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms; about 280 s)
    exit: 0
    stdout: `0`
    mutation: the broken link of criterion 7 also fails `tests/context-glossary-links.test.js` inside validate.sh and stdout is `1`. Run this after the commit, with no other unit's edits uncommitted in the tree.

## Pre-resolved context
- tdd: no; a glossary edit. Criteria 2 to 6 are claim-anchored: each checks the entry's sentence and the line of the persona, script or gate that makes it true, so a correct-looking entry over the wrong code fails.
- blast-radius: `tests/context-glossary-links.test.js` resolves `[[links]]` across both glossaries (headings `^\*\*[^*]+\*\*`, synonym headings `**a** (synonym: **b**):` supported, case- and backtick-insensitive); `tests/doc-relative-links.test.js` checks relative links. `[[verdict block]]`, `[[refutation line]]`, `[[FAIL block]]`, `[[dispatch packet]]`, `[[multi-part stdout spec]]` and `[[judge]]` all resolve once edits 1 to 4 are in.
- commit-message: docs(cos-u5): glossary entries verdict block, dispatch message, multi-part stdout spec, judge; FAIL block and FAIL ground reconciled
- Sources checked by spec-master: the gate's dispatch message is `jq -rs 'map(select(.type == "user"))[0].message.content ...'` (`hooks/scripts/writer-scope-gate.sh:80-82`); its scope parse is `:150-171`. The precheck's judge lines are `bin/review-precheck.sh:105` and `:140`; `us_version_name` is `hooks/scripts/lib/unit-scope.sh:144-147`. The On PASS uncommitted-tree FAIL is `agents/reviewer.md:196-199`; the constitution FAIL ground is `:69-71`.
- The glossary is not a spec: no entry names a line number.

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If an anchor or `before` block is not found exactly once, stop and report the current text. If the Edit tool is unavailable (`exists but is not enabled in this context`), use a `python3` heredoc that asserts the old text occurs exactly once before replacing it. If a source half of criteria 2 to 6 prints less than expected, cos-u2 or cos-u3 has not landed or has changed: report it, do not reword the entry to match.
