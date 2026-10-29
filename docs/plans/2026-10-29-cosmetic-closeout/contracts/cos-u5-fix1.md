Unit: cos-u5

## Objective
Fix the FAIL of cos-u5 (reviewer, 2026-10-29): the entry "dispatch message" in `docs/harness-glossary.md` says `hooks/scripts/writer-scope-gate.sh` takes the unit scope "from it alone" and that a path named only in the prose "is never in scope". The gate does otherwise. Reword only those scope sentences so each claim matches the gate; every other claim, link and the heading of the entry stay.

fix-of: 2026-10-29T00:00:00Z
diagnosis: none

Latest FAIL block, verbatim from the cos-u5 FAIL record:
~~~
FAIL cos-u5 2026-10-29T00:00:00Z
tier: sonnet
- docs/harness-glossary.md:3563 (entry "dispatch message"): says hooks/scripts/writer-scope-gate.sh takes the writer's unit scope "from it alone" and that "A path named only in the message's prose is never in scope". False for scribe and spec-master: hooks/scripts/writer-scope-gate.sh:199 `us_named_in "$p" "$W/ptok" && [ "$persona" != lead-programmer ] && return 0` puts a path named anywhere in the dispatch message's text in scope for every persona except lead-programmer. The enumeration of scope sources is also incomplete: :184 adds every `file: \`path\`` token from the message, :209-210 add persona knowledge-write scope (CONTEXT.md, README.md, docs/harness-glossary.md, docs/adr/*, and docs/* for scribe, under knowledgeWrites=apply), and for lead-programmer the us_classify classes criteria/fail-record/plugin-version/judge also count. Trigger: read the cited lines; or dispatch a scribe whose message names a path only in prose and run the gate on a change to it. The contract's objective requires "every claim an entry makes is checked against the file it describes"; criterion 6 only anchors "the first user message of a writer" and "a bullet", so it passes while this claim is wrong. Fix: reword the entry's scope sentences to what the gate does (say the prose-path rule holds for lead-programmer only, name the `file:` tokens and the persona-specific additions, or drop "from it alone" and "never in scope"), via a fix contract.
refutation: confirmed=1 refuted=0 uncertain=0
~~~
The `refutation:` line is telemetry and gets no edit.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-cosmetic-closeout.md` (Step 5). Original contract: `docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u5.md`. Executor: scribe (glossary custody); `knowledgeWrites` is `apply`.

## Affected files
- `docs/harness-glossary.md` (anchor: line matching `**dispatch message** (synonym: **dispatch prompt**):`)

These are the only paths in scope.

## Ordered edits
Use the Edit tool, never a Bash heredoc. The `before` text sits on one line, the line after the entry's heading, and occurs exactly once at 98f514bd.

1. file: `docs/harness-glossary.md`
   anchor: line matching `**dispatch message** (synonym: **dispatch prompt**):`
   before:
~~~
takes the writer's unit scope from it alone: its `Unit:` line, the entries of its `## Affected files` section (backticked paths, and a bullet's bare first word when it is path-shaped), its exclusions, and the unit's own cited contract file as the baseline commit holds it. A path named only in the message's prose is never in scope. Not a
~~~
   after:
~~~
takes the writer's unit scope from it: its `Unit:` line, the entries of its `## Affected files` section (backticked paths, and a bullet's bare first word when it is path-shaped), every `` file: `path` `` token anywhere in it, its exclusions, and the unit's own cited contract file as the baseline commit holds it. A path named only in the message's prose is in scope for every persona except lead-programmer. The gate adds the persona's own scope: when knowledgeWrites is apply, CONTEXT.md, README.md, docs/harness-glossary.md and docs/adr/* for spec-master and scribe, and every docs/* path for scribe; for lead-programmer, the paths of the unit-scope classes criteria, fix-contract, fail-record, plugin-version and judge. Not a
~~~

2. command: `git add docs/harness-glossary.md && git commit -m "fix(cos-u5): dispatch message entry states the gate's real scope rules"`
   expect: 0
   Run `git status --short` first; if any other tracked file is modified, leave it unstaged and report it.

## Do NOT touch
- `agents/`, `adapters/`, `templates/`, `.claude/`, `bin/`, `hooks/`, `tests/`, `eval/`, `docs/adr/`, `docs/plans/`
- `CONTEXT.md`, and every other entry of `docs/harness-glossary.md`; in the entry itself its heading, its `[[dispatch packet]]` link and every sentence outside the two scope sentences

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
12. run: `bash -c 'd=$(awk "/^\*\*dispatch message\*\*/{p=1;next} p&&/^\*\*/{exit} p" docs/harness-glossary.md | tr -s " \n" " "); a=0; for p in "token anywhere in it" "is in scope for every persona except lead-programmer" "when knowledgeWrites is apply, CONTEXT.md, README.md, docs/harness-glossary.md and docs/adr/* for spec-master and scribe, and every docs/* path for scribe" "criteria, fix-contract, fail-record, plugin-version and judge"; do printf "%s" "$d" | grep -qF -- "$p" && a=$((a+1)); done; printf "%s" "$d" | grep -qF -e "from it alone" -e "never in scope" && a=$((a+10)); b=0; for p in "s/^file: " "!= lead-programmer ] && return 0" "listed|criteria|fail-record|fix-contract|plugin-version|judge) return 0" "CONTEXT.md|README.md|docs/harness-glossary.md|docs/adr/*) return 0" "docs/*) return 0 ;; esac; return 1"; do grep -qF -- "$p" hooks/scripts/writer-scope-gate.sh && b=$((b+1)); done; echo "entry=$a source=$b"'`
    exit: 0
    stdout: `entry=4 source=5`
    mutation: at 98f514bd it prints `entry=10 source=5` (the old absolute claims are still there and none of the new sentences). Changing the gate's `!= lead-programmer` test to `== lead-programmer` prints `source=4`, so the sentence is tied to the gate line.

## Pre-resolved context
- commit-message: fix(cos-u5): dispatch message entry states the gate's real scope rules
- Sources checked by task-master at 98f514bd: `hooks/scripts/writer-scope-gate.sh:184` (`file:` tokens into the listed set), `:199` (prose-named path in scope unless lead-programmer), `:205` (lead-programmer classes), `:208`, `:210-211` (knowledge writes under apply; `docs/*` for scribe). Criteria 1 to 11 are the original ones and still apply; criterion 6 still holds (the first user message of a writer, a bullet). Criterion 9 holds because this commit touches only `docs/harness-glossary.md`.
- tdd: no; a glossary edit. Criteria 2 to 6 are claim-anchored: each checks the entry's sentence and the line of the persona, script or gate that makes it true, so a correct-looking entry over the wrong code fails.
- blast-radius: `tests/context-glossary-links.test.js` resolves `[[links]]` across both glossaries (headings `^\*\*[^*]+\*\*`, synonym headings `**a** (synonym: **b**):` supported, case- and backtick-insensitive); `tests/doc-relative-links.test.js` checks relative links. `[[verdict block]]`, `[[refutation line]]`, `[[FAIL block]]`, `[[dispatch packet]]`, `[[multi-part stdout spec]]` and `[[judge]]` all resolve once edits 1 to 4 are in.
- Sources checked by spec-master: the gate's dispatch message is `jq -rs 'map(select(.type == "user"))[0].message.content ...'` (`hooks/scripts/writer-scope-gate.sh:80-82`); its scope parse is `:150-171`. The precheck's judge lines are `bin/review-precheck.sh:105` and `:140`; `us_version_name` is `hooks/scripts/lib/unit-scope.sh:144-147`. The On PASS uncommitted-tree FAIL is `agents/reviewer.md:196-199`; the constitution FAIL ground is `:69-71`.
- The glossary is not a spec: no entry names a line number.

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If an anchor or `before` block is not found exactly once, stop and report the current text. If the Edit tool is unavailable (`exists but is not enabled in this context`), use a `python3` heredoc that asserts the old text occurs exactly once before replacing it. If a source half of criteria 2 to 6 prints less than expected, cos-u2 or cos-u3 has not landed or has changed: report it, do not reword the entry to match.
