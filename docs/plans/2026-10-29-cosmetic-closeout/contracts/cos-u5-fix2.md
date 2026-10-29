Unit: cos-u5

## Objective
Fix the second FAIL of cos-u5 (reviewer, 2026-10-29T23:59:00Z): the entry "dispatch message" in `docs/harness-glossary.md` says the gate adds the unit-scope class fix-contract for lead-programmer. It does not: the gate passes `/dev/null` as the fix-listed argument. Reword the entry's scope sentences so every clause matches `hooks/scripts/writer-scope-gate.sh` and `hooks/scripts/lib/unit-scope.sh` as task-master re-read them at 74e516c8, and close the reviewer's three advisory gaps and the dispatch-prompt synonym note. Every other claim, link and the heading of the entry stay.

fix-of: 2026-10-29T23:59:00Z
diagnosis: none

Latest FAIL block, verbatim from the cos-u5 FAIL record:
~~~
FAIL cos-u5 2026-10-29T23:59:00Z
tier: sonnet
- docs/harness-glossary.md:3564 (entry "dispatch message", sentence new in 74e516c8): says the gate adds, for lead-programmer, "the paths of the unit-scope classes criteria, fix-contract, fail-record, plugin-version and judge". The fix-contract part is false. hooks/scripts/writer-scope-gate.sh:204 calls `us_classify "$p" "$start" "$W/listed" /dev/null "$W/crit" "$W/failrec"`, so the <fix-listed> argument is always /dev/null, and us_classify (hooks/scripts/lib/unit-scope.sh:166 `elif us_listed "$p" "$4"; then echo fix-contract`) never returns fix-contract inside the gate, because us_listed returns 1 on an empty file. The `fix-contract` label in the case at :205 is dead code, and the gate adds no path from a fix contract to a lead-programmer's scope. To trigger: source hooks/scripts/lib/unit-scope.sh, then `us_classify src/fixonly.js HEAD <listed:src/a.js> /dev/null <empty> <empty>` (the gate's call) prints `out`; with a fix-listed file holding src/fixonly.js (bin/review-precheck.sh:153's call) it prints `fix-contract`. This misses the fix contract's objective ("Reword only those scope sentences so each claim matches the gate"). Criterion 12 does not catch it because its source half anchors only the case-pattern text at :205, never the /dev/null argument at :204. Fix: drop fix-contract from the lead-programmer class list (criteria, fail-record, plugin-version and judge), or say the gate gives no fix-contract list, and re-anchor criterion 12 on line :204.
refutation: confirmed=1 refuted=0 uncertain=0
~~~
The `refutation:` line is telemetry and gets no edit.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-29-cosmetic-closeout.md` (Step 5). Original contract: `docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u5.md`; first fix: `docs/plans/2026-10-29-cosmetic-closeout/contracts/cos-u5-fix1.md`. Executor: scribe (glossary custody); `knowledgeWrites` is `apply`.

## Affected files
- `docs/harness-glossary.md` (anchor: line matching `**dispatch message** (synonym: **dispatch prompt**):`)

These are the only paths in scope. `CONTEXT.md` is not edited: its two `_Avoid_: dispatch prompt` lines (under contract of record and contract file) forbid calling the contract a dispatch prompt, which agrees with the glossary once the entry says the message is not the contract (edit 1 does).

## Ordered edits
Use the Edit tool, never a Bash heredoc. The `before` text sits on one line, the line after the entry's heading, and occurs exactly once at 74e516c8.

1. file: `docs/harness-glossary.md`
   anchor: line matching `**dispatch message** (synonym: **dispatch prompt**):`
   before:
~~~
takes the writer's unit scope from it: its `Unit:` line, the entries of its `## Affected files` section (backticked paths, and a bullet's bare first word when it is path-shaped), every `` file: `path` `` token anywhere in it, its exclusions, and the unit's own cited contract file as the baseline commit holds it. A path named only in the message's prose is in scope for every persona except lead-programmer. The gate adds the persona's own scope: when knowledgeWrites is apply, CONTEXT.md, README.md, docs/harness-glossary.md and docs/adr/* for spec-master and scribe, and every docs/* path for scribe; for lead-programmer, the paths of the unit-scope classes criteria, fix-contract, fail-record, plugin-version and judge. Not a
~~~
   after:
~~~
takes the writer's unit scope from it: its `Unit:` line, which picks the unit's own cited contract file (read as the baseline commit holds it) and the unit's FAIL record; the entries of its `## Affected files` section (backticked paths, and a bullet's bare first word when it is path-shaped); every `` file: `path` `` token anywhere in it; and its exclusions. A path under `.claude/` or `docs/plans/` is always in scope, and any other excluded path is out, both checked before every other rule, even when the prose names it. A path named only in the message's prose is in scope for every persona except lead-programmer. The gate then adds the persona's own scope. For spec-master and scribe, when knowledgeWrites is apply: CONTEXT.md, README.md, docs/harness-glossary.md and docs/adr/*. Scribe also gets every other docs/* path, whatever knowledgeWrites says. For lead-programmer, a path counts when it is one the acceptance criteria read but do not run, one named in the unit's FAIL record, one of the three version-stamp files (`.claude-plugin/plugin.json`, `package.json`, `CHANGELOG.md`) when the repo tracks `.claude-plugin/plugin.json`, or one named like a version stamp (class judge, left to the reviewer). The gate passes no fix-contract list, so a fix contract never widens a lead-programmer's scope. Call it the dispatch message or the dispatch prompt, never the contract: the [[contract of record]] and the [[contract file]] are different artifacts, and CONTEXT.md avoids "dispatch prompt" for them. Not a
~~~

2. command: `git add docs/harness-glossary.md && git commit -m "fix(cos-u5): dispatch message entry drops the fix-contract class, states the gate's persona scope"`
   expect: 0
   Run `git status --short` first; if any other tracked file is modified, leave it unstaged and report it.

## Do NOT touch
- `agents/`, `adapters/`, `templates/`, `.claude/`, `bin/`, `hooks/`, `tests/`, `eval/`, `docs/adr/`, `docs/plans/`
- `CONTEXT.md`, and every other entry of `docs/harness-glossary.md`; in the entry itself its heading, its `[[dispatch packet]]` link and every sentence outside the scope sentences edit 1 replaces

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
12. run: `bash -c 'd=$(awk "/^\*\*dispatch message\*\*/{p=1;next} p&&/^\*\*/{exit} p" docs/harness-glossary.md | tr -s " \n" " "); a=0; for p in "token anywhere in it" "is always in scope" "even when the prose names it" "is in scope for every persona except lead-programmer" "when knowledgeWrites is apply: CONTEXT.md, README.md, docs/harness-glossary.md and docs/adr/*" "Scribe also gets every other docs/* path, whatever knowledgeWrites says" "one the acceptance criteria read but do not run" "one named in the unit'"'"'s FAIL record" "when the repo tracks" "The gate passes no fix-contract list"; do printf "%s" "$d" | grep -qF -- "$p" && a=$((a+1)); done; for p in "from it alone" "never in scope" "criteria, fix-contract, fail-record" "and every docs/* path for scribe"; do printf "%s" "$d" | grep -qF -- "$p" && a=$((a+100)); done; echo "entry=$a"'`
    exit: 0
    stdout: `entry=10`
    mutation: at 74e516c8 it prints `entry=202` (two of the new phrases are not there yet and the old fix-contract and docs/* sentences are). Replacing the sentence "The gate passes no fix-contract list, so" with "The gate adds criteria, fix-contract, fail-record, so" prints `entry=109` (replayed).
13. run: `bash -c 'g=hooks/scripts/writer-scope-gate.sh; u=hooks/scripts/lib/unit-scope.sh; b=0; for p in "s/^file: " "!= lead-programmer ] && return 0" "CONTEXT.md|README.md|docs/harness-glossary.md|docs/adr/*) return 0" "docs/*) return 0 ;; esac; return 1" "if knowledge \"\$p\"; then [ \"\$kw\" = apply ] && return 0; return 1; fi" "knowledge \"\$p\" && [ \"\$kw\" = apply ] && return 0; return 1" "us_listed \"\$p\" \"\$W/listed\" && return 0" ": > \"\$W/failrec\"; [ -z \"\$unit\" ]"; do grep -qF -- "$p" $g && b=$((b+1)); done; for p in "us_named_in \"\$p\" \"\$5\" && ! us_executed_in \"\$p\" \"\$5\"; then echo criteria" "us_named_in \"\$p\" \"\$6\"; then echo fail-record" "us_plugin_version \"\$p\" \"\$2\"; then echo plugin-version" "us_version_name \"\$p\"; then echo judge" ".claude-plugin/plugin.json|package.json|CHANGELOG.md) return 0"; do grep -qF -- "$p" $u && b=$((b+1)); done; l1=$(grep -nF "case \"\$p\" in .claude/*|docs/plans/*) return 0" $g | head -1 | cut -d: -f1); l2=$(grep -nF "us_excluded \"\$p\" \"\$W/excl\" && return 1" $g | head -1 | cut -d: -f1); l3=$(grep -nF "us_named_in \"\$p\" \"\$W/ptok\"" $g | head -1 | cut -d: -f1); [ -n "$l1" ] && [ -n "$l2" ] && [ -n "$l3" ] && [ "$l1" -lt "$l2" ] && [ "$l2" -lt "$l3" ] && b=$((b+1)); echo "source=$b"'`
    exit: 0
    stdout: `source=14`
    mutation: changing the gate's `!= lead-programmer` test to `== lead-programmer` prints `source=13`; moving the `.claude/*|docs/plans/*` case line below the `us_excluded` line prints `source=13`; deleting the `elif us_version_name` line of `hooks/scripts/lib/unit-scope.sh` prints `source=13`. Each ties one clause of the entry to the line that makes it true.
14. run: `bash -c 'grep -cF "us_classify \"\$p\" \"\$start\" \"\$W/listed\" /dev/null \"\$W/crit\" \"\$W/failrec\"" hooks/scripts/writer-scope-gate.sh'`
    exit: 0
    stdout: `1`
    mutation: replacing `/dev/null` in that call with `"$W/fix"` makes grep print `0` and exit 1. This anchors where the data comes from: the fix-listed argument of the gate's call, the line the first fix left unanchored.
15. run: `bash -c 'd=$(mktemp -d); printf "src/a.js\n" > "$d/listed"; : > "$d/e"; printf "src/fixonly.js\n" > "$d/fix"; . hooks/scripts/lib/unit-scope.sh; echo "gate=$(us_classify src/fixonly.js HEAD "$d/listed" /dev/null "$d/e" "$d/e") withfix=$(us_classify src/fixonly.js HEAD "$d/listed" "$d/fix" "$d/e" "$d/e")"'`
    exit: 0
    stdout: `gate=out withfix=fix-contract`
    mutation: deleting the `elif us_listed "$p" "$4"; then echo fix-contract` line of `hooks/scripts/lib/unit-scope.sh` in a scratch copy prints `gate=out withfix=out`. With `/dev/null` as the fix-listed argument (criterion 14) the gate's call is the first form, which is what makes "passes no fix-contract list" true; the class stays for `bin/review-precheck.sh`.
16. run: `bash -c 'x=$(grep -c "^_Avoid_:.*dispatch prompt" CONTEXT.md); y=$(awk "/^\*\*contract of record\*\*/{p=1;next} p&&/^\*\*/{exit} p" CONTEXT.md | grep -c "^_Avoid_:.*dispatch prompt"); z=$(awk "/^\*\*contract file\*\*/{p=1;next} p&&/^\*\*/{exit} p" CONTEXT.md | grep -c "^_Avoid_:.*dispatch prompt"); echo "avoid=$x record=$y file=$z"'`
    exit: 0
    stdout: `avoid=2 record=1 file=1`
    mutation: deleting the `_Avoid_` line under contract file prints `avoid=1 record=1 file=0`, and the entry's last new sentence then names an avoidance CONTEXT.md no longer holds.

## Pre-resolved context
- commit-message: fix(cos-u5): dispatch message entry drops the fix-contract class, states the gate's persona scope
- Re-read by task-master at 74e516c8, every clause of the new text against the code: `hooks/scripts/writer-scope-gate.sh:80-82` first user message; `:151,:172-176,:186` the `Unit:` line picks the own contract (read with `git show "$start:..."`) and the FAIL record; `:152-157` Affected-files entries and bare first words; `:184` `file:` tokens; `:196` `.claude/*|docs/plans/*` return 0 before `:197` exclusions, then `:198` listed, `:199` prose-named for non-lead-programmer; `:204` the call with `/dev/null` as fix-listed, so `hooks/scripts/lib/unit-scope.sh:164` never fires in the gate; `:207-208` spec-master knowledge under apply; `:209-211` scribe knowledge under apply, other `docs/*` always. Classes in `unit-scope.sh`: `:162` criteria (read, not run), `:163` fail-record, `:165` plugin-version (repo must track `.claude-plugin/plugin.json`, `:139`), `:166` judge (`:147` names). The class `listed` is the Affected-files rule and is not repeated. `bin/review-precheck.sh:153` still passes a real fix-listed file, so the class stays in the library.
- Not claimed on purpose: the gate's stdin-vs-transcript details, directory-prefix and glob matching of entries, and the rule that another unit's cited contract counts only when nothing is listed.
- tdd: no; a glossary edit. Criteria 12 to 16 are claim-anchored: each checks the entry's sentence and the gate or library line (or a replay of it) that makes it true.
- blast-radius: `tests/context-glossary-links.test.js` resolves `[[links]]` across both glossaries; `[[contract of record]]` and `[[contract file]]` are headings of `CONTEXT.md` (lines near 460 and 477) and `[[dispatch packet]]` is unchanged. Criteria 1 to 11 are the original ones and still hold against the new text: criterion 6 reads "the first user message of a writer" and "a bullet", both kept; criterion 1 counts headings; criterion 9 holds because the commit touches only `docs/harness-glossary.md`. The first fix's criterion 12 is replaced by 12 to 16.
- Open note, not a gap: the two glossaries already agree on the synonym (the `_Avoid_` lines forbid "dispatch prompt" for the contract, not for the message); the sentence in edit 1 states it, and criterion 16 ties it to `CONTEXT.md`.

## Escalation
If any instruction cannot be followed exactly as written, STOP and report a spec gap; do not improvise. If an anchor or `before` block is not found exactly once, stop and report the current text. If the Edit tool is unavailable (`exists but is not enabled in this context`), use a `python3` heredoc that asserts the old text occurs exactly once before replacing it. If criterion 13 or 15 prints less than expected, the gate or library changed: report it, do not reword the entry to match.
