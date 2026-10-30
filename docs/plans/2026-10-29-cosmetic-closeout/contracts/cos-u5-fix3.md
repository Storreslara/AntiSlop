Unit: cos-u5

## Objective
Fix the third FAIL of cos-u5 (reviewer, 2026-10-30T00:12:10Z): the entry "dispatch message" in `docs/harness-glossary.md` says "The gate passes no fix-contract list, so a fix contract never widens a lead-programmer's scope", and the "so ... never widens" part is false (the orchestrator sends the fix contract itself as the dispatch message, so its entries and `file:` tokens are the message's). Strategy: reduce the surface. Rewrite the entry's scope sentences so they state only the definition and a few rules task-master verified line by line against `hooks/scripts/writer-scope-gate.sh` (lines 80-258) and `hooks/scripts/lib/unit-scope.sh` at 93e59b22, drop every derived or negative claim, and say that the full scope rules live in the gate. The heading, the `[[dispatch packet]]` link, "the first user message of a writer", "a bullet" and the CONTEXT.md avoidance sentence stay.

fix-of: 2026-10-30T00:12:10Z
diagnosis: none

Latest FAIL block, verbatim from the cos-u5 FAIL record:
~~~
FAIL cos-u5 2026-10-30T00:12:10Z
tier: opus
- docs/harness-glossary.md:3564 (entry "dispatch message", sentence new in 93e59b22): "The gate passes no fix-contract list, so a fix contract never widens a lead-programmer's scope." The first half is true (hooks/scripts/writer-scope-gate.sh:204 passes /dev/null); the "so ... never widens" consequence is false. The orchestrator's fix re-dispatch sends the fix contract itself as the dispatch message (agents/orchestrator.md:265-266 "dispatch the lead-programmer with that fix contract"; cos-u5-fix2.md starts `Unit: cos-u5` and has its own `## Affected files`), so the fix contract's entries and `file:` tokens are the message's entries (:152-157, :184) and are `listed` for lead-programmer at :198. And when the message cites only a fix contract path and lists nothing, :178-182 read that cited contract's entries (its name `<unit>-fix<n>.md` never equals `<unit>.md`, so it takes the "another contract" fallback). To trigger: scratch repo whose baseline holds contracts/u1.md (lists src/a.js) and contracts/u1-fix1.md (lists src/fixonly.js), a lead-programmer transcript editing src/fixonly.js; first user message citing only u1.md -> gate exit 2 (blocked); message = the u1-fix1.md text plus a citation of u1.md -> exit 0; message `Unit: u1` citing only u1-fix1.md -> exit 0. Criterion 12 checks only that the phrase "The gate passes no fix-contract list" is present, so it passes. Fix: drop "so a fix contract never widens a lead-programmer's scope", or replace it with what holds (no separate fix-contract class; a fix contract counts only through the message: as the message itself, or as a cited contract when the message lists nothing), via a fix contract.
refutation: skipped=mechanical
~~~
The `refutation:` line is telemetry and gets no edit.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-cosmetic-closeout.md` (Step 5). Original contract: `docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u5.md`; earlier fixes: `cos-u5-fix1.md`, `cos-u5-fix2.md` in the same directory. Executor: scribe (glossary custody); `knowledgeWrites` is `apply`.

## Affected files
- `docs/harness-glossary.md` (anchor: line matching `**dispatch message** (synonym: **dispatch prompt**):`)

These are the only paths in scope. `CONTEXT.md` is not edited: its two `_Avoid_: dispatch prompt` lines already agree with the entry (criterion 14).

## Ordered edits
Use the Edit tool, never a Bash heredoc. The `before` text sits on one line, the line after the entry's heading, and occurs exactly once at 93e59b22. indent: 0.

1. file: `docs/harness-glossary.md`
   anchor: line matching `**dispatch message** (synonym: **dispatch prompt**):`
   indent: 0
   before:
~~~
takes the writer's unit scope from it: its `Unit:` line, which picks the unit's own cited contract file (read as the baseline commit holds it) and the unit's FAIL record; the entries of its `## Affected files` section (backticked paths, and a bullet's bare first word when it is path-shaped); every `` file: `path` `` token anywhere in it; and its exclusions. A path under `.claude/` or `docs/plans/` is always in scope, and any other excluded path is out, both checked before every other rule, even when the prose names it. A path named only in the message's prose is in scope for every persona except lead-programmer. The gate then adds the persona's own scope. For spec-master and scribe, when knowledgeWrites is apply: CONTEXT.md, README.md, docs/harness-glossary.md and docs/adr/*. Scribe also gets every other docs/* path, whatever knowledgeWrites says. For lead-programmer, a path counts when it is one the acceptance criteria read but do not run, one named in the unit's FAIL record, one of the three version-stamp files (`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`) when the repo tracks `.claude-plugin/plugin.json`, or one named like a version stamp (class judge, left to the reviewer). The gate passes no fix-contract list, so a fix contract never widens a lead-programmer's scope. Call it the dispatch message or the dispatch prompt, never the contract: the [[contract of record]] and the [[contract file]] are different artifacts, and CONTEXT.md avoids "dispatch prompt" for them. Not a
~~~
   after:
~~~
reads it to take the writer's unit scope: its `Unit:` line, the entries of its `## Affected files` section (backticked paths, and a bullet's bare first word when it is path-shaped), every `` file: `path` `` token in it, and its exclusions. The gate also reads the persona, the FAIL record of the unit, the contract files the message cites (their entries and exclusions can be added) and the `N. run:` acceptance criteria of the message. A changed path under `.claude/` or `docs/plans/` is in scope before exclusions are checked; a changed path whose name holds a quote, backslash or control character is marked out before any scope rule. The full scope rules are in the gate, not restated here. Call it the dispatch message or the dispatch prompt, not the contract: the [[contract of record]] and the [[contract file]] are different artifacts, and CONTEXT.md avoids "dispatch prompt" for them. Not a
~~~

2. command: `git add docs/harness-glossary.md && git commit -m "fix(cos-u5): dispatch message entry keeps only the verified scope rules and points at the gate"`
   expect: 0
   Run `git status --short` first; if any other tracked file is modified, leave it unstaged and report it.

## Do NOT touch
- `agents/`, `adapters/`, `templates/`, `.claude/`, `bin/`, `hooks/`, `tests/`, `eval/`, `docs/adr/`, `docs/plans/`
- `CONTEXT.md`, and every other entry of `docs/harness-glossary.md`; in the entry itself its heading, its `[[dispatch packet]]` link and the opening sentence up to `takes the writer`

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
11. run: `bash -c 'ANTISLOP_VALIDATE_LANES=4 bash tests/validate.sh >/dev/null 2>&1; echo $?'` (Bash tool timeout 600000 ms; about 280 s; one lane is flaky: C4.1a, the memory-file sweep, can fail inside a full run and passes alone and on a re-run, so on a stdout of `1` re-run once and read the failing lane before calling it a defect)
    exit: 0
    stdout: `0`
    mutation: the broken link of criterion 7 also fails `tests/context-glossary-links.test.js` inside validate.sh and stdout is `1`. Run this after the commit, with no other unit's edits uncommitted in the tree.
12. run: `bash -c 'd=$(awk "/^\*\*dispatch message\*\*/{p=1;next} p&&/^\*\*/{exit} p" docs/harness-glossary.md | tr -s " \n" " "); a=0; for p in "reads it to take the writer" "(backticked paths, and a bullet" "when it is path-shaped" "token in it, and its exclusions" "The gate also reads the persona, the FAIL record of the unit" "the contract files the message cites (their entries and exclusions can be added)" "acceptance criteria of the message" "is in scope before exclusions are checked" "holds a quote, backslash or control character is marked out before any scope rule" "The full scope rules are in the gate, not restated here" "are different artifacts, and CONTEXT.md avoids" "[[contract of record]]" "[[contract file]]" "[[dispatch packet]]"; do printf "%s" "$d" | grep -qF -- "$p" && a=$((a+1)); done; for p in "never widens" "criteria, fix-contract, fail-record" "never in scope" "from it alone" "fix-contract list" "except lead-programmer" "whatever knowledgeWrites"; do printf "%s" "$d" | grep -qF -- "$p" && a=$((a+100)); done; echo "entry=$a"'`
    exit: 0
    stdout: `entry=14`
    mutation: at 93e59b22 it prints `entry=406` (the four removed-claim phrases "never widens", "fix-contract list", "except lead-programmer", "whatever knowledgeWrites" are still there, 400, and 6 of the 14 phrases). Pasting "never widens" anywhere in the entry prints `entry=114`; deleting the sentence "The full scope rules are in the gate, not restated here." prints `entry=13`. Every phrase that stays in the entry is anchored here, and the three known-false phrases ("never widens", "criteria, fix-contract, fail-record", "never in scope" / "from it alone") are asserted absent.
13. run: `bash -c 'g=hooks/scripts/writer-scope-gate.sh; b=0; for p in "s/^Unit: //p" "us_exclusions \"\$W/prompt\" > \"\$W/excl\"" "docs/plans/[A-Za-z0-9._/-]*contracts/" "us_exclusions \"\$W/own\" >> \"\$W/excl\"" "us_exclusions \"\$W/own\" > \"\$W/excl\"" "^[0-9]+\\. run: " ": > \"\$W/failrec\"; [ -z \"\$unit\" ]" "case \"\$persona\" in"; do grep -qF -- "$p" $g && b=$((b+1)); done; l1=$(grep -nF "case \"\$p\" in .claude/*|docs/plans/*) return 0" $g | head -1 | cut -d: -f1); l2=$(grep -nF "us_excluded \"\$p\" \"\$W/excl\" && return 1" $g | head -1 | cut -d: -f1); l4=$(grep -nF "[[:cntrl:]]*) viol+=" $g | head -1 | cut -d: -f1); l5=$(grep -nF "in_scope \"\$p\" || viol+=" $g | head -1 | cut -d: -f1); [ -n "$l1" ] && [ -n "$l2" ] && [ "$l1" -lt "$l2" ] && b=$((b+1)); [ -n "$l4" ] && [ -n "$l5" ] && [ "$l4" -lt "$l5" ] && b=$((b+1)); echo "source=$b"'`
    exit: 0
    stdout: `source=10`
    mutation: each ties one clause to the gate line where its DATA comes from: `Unit:` line (:151), the message's exclusions (:158), the cited contract paths (:165), the cited contract's entries and exclusions (:175 and :181), the message's `N. run:` lines (:185), the FAIL record (:186), the persona case (:200), the `.claude/`/`docs/plans/` return before the exclusion check (:196 before :197), the quote/backslash/control-character case before `in_scope` (:238 before :239). Replayed in a scratch worktree: renaming `Unit:` to `Id:` in the sed of :151 prints `source=9`; moving the :196 line below :197 prints `source=9`; moving the :238 line below the :239 line prints `source=9`; deleting the :186 `failrec` line prints `source=9`.
14. run: `bash -c 'x=$(grep -c "^_Avoid_:.*dispatch prompt" CONTEXT.md); y=$(awk "/^\*\*contract of record\*\*/{p=1;next} p&&/^\*\*/{exit} p" CONTEXT.md | grep -c "^_Avoid_:.*dispatch prompt"); z=$(awk "/^\*\*contract file\*\*/{p=1;next} p&&/^\*\*/{exit} p" CONTEXT.md | grep -c "^_Avoid_:.*dispatch prompt"); echo "avoid=$x record=$y file=$z"'`
    exit: 0
    stdout: `avoid=2 record=1 file=1`
    mutation: deleting the `_Avoid_` line under contract file prints `avoid=1 record=1 file=0`, and the entry's "CONTEXT.md avoids" sentence then names an avoidance CONTEXT.md no longer holds.

## Pre-resolved context
commit-message: fix(cos-u5): dispatch message entry keeps only the verified scope rules and points at the gate
- Re-read by task-master at 93e59b22, each remaining clause against the code. The entry now claims only: `hooks/scripts/writer-scope-gate.sh:80-82` first user message; `:151` the `Unit:` line; `:152-157` Affected-files entries and a bullet's bare first word; `:158` the message's exclusions; `:184` `file:` tokens; the gate also reads `:200-212` the persona, `:186` the FAIL record, `:165-183` cited contracts (`:175` own contract adds entries and exclusions, `:181` the fallback replaces them when nothing is listed, hence "can be added"), `:185` the message's `N. run:` lines; `:196` `.claude/*|docs/plans/*` return 0 before `:197` the exclusion check; `:238` a changed name holding a quote, backslash or control character is a violation before `:239` `in_scope`. Nothing else is stated: no persona-by-persona list, no prose-named rule, no fix-contract statement, no `never`/`always` claim. The rules are left to the gate file, which the entry names.
- Reviewer's omission remarks, included because verified and one short clause each: own-contract exclusions and entries (:175), "acceptance criteria" is the message's own `N. run:` lines (:185), the quote/backslash/control-character case (:238).
tdd: no a glossary edit. Criteria 12 to 14 are claim-anchored: each checks the entry's phrases and the gate line (or CONTEXT.md line) that makes them true; criterion 12 also asserts the known-false phrases absent.
blast-radius: hooks/scripts/writer-scope-gate.sh:80 (read-only source of the claims); `tests/context-glossary-links.test.js` resolves `[[links]]` across both glossaries; the three links of the entry are kept. Criteria 1 to 11 are the original ones: criterion 6 reads "the first user message of a writer" and "a bullet", both kept; criterion 9 holds because the commit touches only `docs/harness-glossary.md`. Criteria 12 to 16 of the second fix are replaced by 12 to 14.
- Criterion 11 runs after the commit; lane C4.1a (memory-file sweep) is flaky inside a full run and passes alone and on a re-run: read the failing lane before calling it a defect.

review-packet:
~~~
unit: cos-u5 (fast path, no issue)
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
~~~
diagnosis: none

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If an anchor or `before` block is not found exactly once, stop and report the current text. If the Edit tool is unavailable (`exists but is not enabled in this context`), use a `python3` heredoc that asserts the old text occurs exactly once before replacing it. If criterion 13 prints less than expected, the gate changed: report it, do not reword the entry to match.
