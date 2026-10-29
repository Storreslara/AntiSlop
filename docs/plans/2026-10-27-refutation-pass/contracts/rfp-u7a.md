Unit: rfp-u7a

## Objective
Clear three glossary notes from the rfp-u6 reviews (plan Step 7, items 1 to 3). One scribe run. This repo's
`knowledgeWrites` is `apply`, and this contract names the only knowledge file it edits, `CONTEXT.md`.
- **refutation outcome** (item 1): "unless the re-check finds a reason the artifact does not defeat it" sits
  after the gating-off parenthesis, so it reads as qualifying that clause. The qualifier moves into the
  sentence before `REFUTED:` ("after the reviewer's own re-check, which keeps a defect standing when it finds a
  reason the artifact does not defeat the claim."). It does not move to just after `REFUTED:`, so the phrases
  that rfp-u5 criterion 4 and rfp-u6c criterion 3 pin stay intact. The entry also gains the case rfp-u7b adds
  to `agents/reviewer.md`: when the rest are UNCERTAIN and the verdict is INSUFFICIENT-CONTEXT, the REFUTED
  defects go in the `refutation` advisory section.
- **FAIL ground** (item 2): the term is used by **mechanical ground** and by `agents/reviewer.md` but has no
  entry. It gets one, before **judgment defect**, and **mechanical ground** links it. Reviewer concepts go in
  `CONTEXT.md`, line grammars in `docs/harness-glossary.md` (the rfp-u5 placement rule).
- **refutation sample** (item 3): the milestone auditor's check and its counts have no entry. One entry, after
  **refutation outcome**, defines `sampled`, `held`, `prevented` and `eligible` inline, from
  `agents/milestone-auditor.md` as it stands.

No ADR: none of the three is hard to reverse, and each follows a rule already written down.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Step 7"). Contract file:
`docs/plans/2026-10-27-refutation-pass/contracts/rfp-u7a.md`, the contract of record. Dispatch rfp-u7a only
after rfp-u7b has its PASS: criterion 2 reads rfp-u7b's new INSUFFICIENT-CONTEXT sentence in
`agents/reviewer.md`, and before rfp-u7b lands it prints `no-source: …`, exit 1. rfp-u7a shares no file with
rfp-u7b to rfp-u7e. One unit is mid-review at a time.

## Glossary edits
1. file: `CONTEXT.md`
   heading: `**judgment defect**:`
   placement: insert the text below immediately before the `**judgment defect**:` line, so the new entry is
   followed by one blank line and then `**judgment defect**:`
   indent: 3
   text:
   ~~~~
   **FAIL ground**:
   (plan 2026-10-27-refutation-pass, unit rfp-u7a) — one reason a reviewer FAIL
     verdict rests on, listed in the verdict as a reproducible defect. It is
     either a [[mechanical ground]], such as a `review-precheck.sh` failure line,
     which is a FAIL ground on its own, or a [[judgment defect]]. Only the
     acceptance-criteria commands and the materiality filter make one: the
     `roast-work` and `ubiquitous-language` passes never add a FAIL ground, and
     their findings stay in the advisory sections after the verdict.
   _Avoid_: FAIL reason, FAIL cause

   ~~~~
2. file: `CONTEXT.md`
   heading: `**mechanical ground**:`
   placement: replace these two lines of that entry with the text below (the rest of the entry is unchanged)
   indent: 3
   before:
   ~~~~
   (plan 2026-10-27-refutation-pass, unit rfp-u6c) — a FAIL ground the reviewer
     established with a check rather than by reading: a `review-precheck.sh`
   ~~~~
   text:
   ~~~~
   (plan 2026-10-27-refutation-pass, unit rfp-u6c) — a [[FAIL ground]] the
     reviewer established with a check rather than by reading: a `review-precheck.sh`
   ~~~~
3. file: `CONTEXT.md`
   heading: `**refutation outcome**:`
   placement: replace these lines of that entry with the text below (the lines before and after are unchanged)
   indent: 3
   before:
   ~~~~
     re-check. REFUTED: the defect is dropped and recorded as a
     `NOTE[code]: refuted:` note on the PASS when every defect is REFUTED, or in
     the verdict's `refutation` advisory section when another defect keeps the
     FAIL (under review gating off, always in that section), unless the
     re-check finds a reason the artifact does not defeat it. CONFIRMED: it
     stays a defect. UNCERTAIN: it stays in a FAIL that happens anyway,
   ~~~~
   text:
   ~~~~
     re-check, which keeps a defect standing when it finds a reason the
     artifact does not defeat the claim. REFUTED: the defect is dropped and
     recorded as a `NOTE[code]: refuted:` note on the PASS when every defect is
     REFUTED, or in the verdict's `refutation` advisory section when another
     defect keeps the FAIL or when the rest are UNCERTAIN and the verdict is
     INSUFFICIENT-CONTEXT (under review gating off, always in that section).
     CONFIRMED: it stays a defect. UNCERTAIN: it stays in a FAIL that happens anyway,
   ~~~~
4. file: `CONTEXT.md`
   heading: `**refutation outcome**:`
   placement: insert the text below after that entry's `_Avoid_: refutation verdict` line and the one blank
   line that follows it, so the new entry is followed by one blank line and then the next entry
   (`` **`.escalated` marker**: ``)
   indent: 3
   text:
   ~~~~
   **refutation sample**:
   (plan 2026-10-27-refutation-pass, unit rfp-u7a) — the milestone auditor's
     check on the [[refutation pass]]. No later gate re-checks a refutation that
     turned a FAIL into a PASS, so at each milestone the auditor re-verifies the
     first 3 `NOTE[code]: refuted:` notes of that milestone's PASS markers (all,
     if fewer) against the code at the marker's commit. Its findings list ends
     with one line, `refutation-sample: sampled=<s> held=<h> prevented=<p>
     eligible=<p+f>`. `sampled` counts the notes it re-verified. `held` counts
     the ones it decided hold; one it cannot decide counts toward `sampled`,
     never toward `held`. `prevented` counts the PASS markers in the whole
     project that carry a `refuted:` note, each a FAIL the pass prevented.
     `eligible` adds to that the [[FAIL block]]s whose [[refutation line]] shows
     the pass ran and the FAIL survived (`refutation: confirmed=`). A refutation
     that does not hold is a finding of at least moderate severity. When
     `eligible` is 20 or more and `prevented` is under a tenth of it, the
     auditor recommends a follow-up to retire or re-scope the pass.
   _Avoid_: refutation audit, refutation spot-check

   ~~~~

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #0: the fast path has no tracker issue, so close nothing and run no `gh issue` command
- task-id: rfp-u7a
- marker first line: "PASS rfp-u7a "
- Commit once, staging only `CONTEXT.md`, with the subject `docs(rfp-u7a): FAIL ground and refutation sample entries; refutation outcome qualifier moved (#0)` and the trailer line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. A fix round is a new commit whose subject keeps `(rfp-u7a): `. Commit your own memory notes separately (`docs(agent-memory): ...`), never in this commit.

## Do NOT touch
- `agents/`, `templates/`, `adapters/`, `tests/`, `hooks/`, `bin/`, `eval/`, `scripts/` (criterion 6)
- `docs/harness-glossary.md`, every `docs/adr/` file, `docs/plans/` (criterion 6)
- `.claude/` (generated or gitignored; criterion 6)
- every other `CONTEXT.md` entry, and the rest of the **refutation outcome** and **mechanical ground**
  entries, including the wording that rfp-u5 criterion 4 and rfp-u6c criteria 1 to 5 pin (criterion 2 re-checks
  rfp-u5's phrases)

## Acceptance criteria
1. run: `bash -c 'for t in "FAIL ground" "refutation sample" "refutation outcome" "mechanical ground"; do printf "%s=%s/%s " "$t" "$(grep -cxF "**$t**:" CONTEXT.md)" "$(grep -cxF "**$t**:" docs/harness-glossary.md)"; done | sed "s/ $//"; echo'`
   exit: 0
   stdout: `FAIL ground=1/0 refutation sample=1/0 refutation outcome=1/0 mechanical ground=1/0`
   mutation: `CONTEXT.md` at b9bcdf92 prints `FAIL ground=0/0 refutation sample=0/0 refutation outcome=1/0 mechanical ground=1/0` (spec-master ran it).
2. run: `bash -c 'r=$(tr -s " \n" " " < agents/reviewer.md | tr -d "\140"); for y in "You may keep a defect standing with a stated reason" "and the REFUTED ones and your reasons go in the refutation advisory section, as in a FAIL" "(under review gating off, to the refutation section instead)"; do printf "%s" "$r" | grep -qF -- "$y" || { echo "no-source: $y"; exit 1; }; done; e=$(awk "/^\*\*refutation outcome\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; for x in "re-check, which keeps a defect standing when it finds a reason the artifact does not defeat the claim. REFUTED: the defect is dropped" "REFUTED: the defect is dropped and recorded as a NOTE[code]: refuted: note on the PASS when every defect is REFUTED" "refutation advisory section when another defect keeps the FAIL or when the rest are UNCERTAIN and the verdict is INSUFFICIENT-CONTEXT (under review gating off, always in that section). CONFIRMED: it stays a defect" "UNCERTAIN: it stays in a FAIL that happens anyway, prefixed [unconfirmed]" "REFUTED and CONFIRMED need an artifact" "the verdict is INSUFFICIENT-CONTEXT, not ESCALATE-TO-HUMAN"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo "checked late-unless=$(printf "%s" "$e" | grep -cF "always in that section), unless")"'`
   exit: 0
   stdout: `checked late-unless=0`
   mutation: leave the entry as it is at b9bcdf92; stdout gains two `missing:` lines (`re-check, which keeps a defect standing …` and `refutation advisory section when another defect keeps the FAIL or when the rest are UNCERTAIN …`) and ends `checked late-unless=1` (spec-master ran it). With `agents/reviewer.md` as it is at b9bcdf92 (before rfp-u7b), stdout is `no-source: and the REFUTED ones and your reasons go in the refutation advisory section, as in a FAIL`, exit 1: the reason this unit waits for rfp-u7b's PASS.
3. run: `bash -c 'r=$(tr -s " \n" " " < agents/reviewer.md | tr -d "\140"); for y in "is a FAIL ground on its own" "never adds a new FAIL ground"; do printf "%s" "$r" | grep -qF -- "$y" || { echo "no-source: $y"; exit 1; }; done; e=$(awk "/^\*\*FAIL ground\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; for x in "one reason a reviewer FAIL verdict rests on" "either a [[mechanical ground]], such as a review-precheck.sh failure line, which is a FAIL ground on its own, or a [[judgment defect]]" "the roast-work and ubiquitous-language passes never add a FAIL ground" "_Avoid_: FAIL reason, FAIL cause"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; m=$(awk "/^\*\*mechanical ground\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); printf "%s" "$m" | grep -qF "a [[FAIL ground]] the reviewer established with a check rather than by reading" || echo "missing: mechanical ground link"; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: `CONTEXT.md` at b9bcdf92 prints `no-entry`, exit 1 (spec-master ran it). Skip glossary edit 2; stdout gains `missing: mechanical ground link` before `checked`.
4. run: `bash -c 'r=$(tr -s " \n" " " < agents/milestone-auditor.md | tr -d "\140"); for y in "Re-verify the first 3 of them (all, if fewer)" "refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>" "one you cannot decide counts toward sampled, never toward held" "When eligible is 20 or more and p is under a tenth of it" "a finding of at least moderate severity"; do printf "%s" "$r" | grep -qF -- "$y" || { echo "no-source: $y"; exit 1; }; done; e=$(awk "/^\*\*refutation sample\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; for x in "re-verifies the first 3 NOTE[code]: refuted: notes of that milestone" "(all, if fewer) against the code at the marker" "refutation-sample: sampled=<s> held=<h> prevented=<p> eligible=<p+f>" "sampled counts the notes it re-verified" "held counts the ones it decided hold; one it cannot decide counts toward sampled, never toward held" "prevented counts the PASS markers in the whole project that carry a refuted: note" "eligible adds to that the [[FAIL block]]s whose [[refutation line]] shows the pass ran and the FAIL survived (refutation: confirmed=)" "a finding of at least moderate severity" "When eligible is 20 or more and prevented is under a tenth of it" "_Avoid_: refutation audit, refutation spot-check"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: `CONTEXT.md` at b9bcdf92 prints `no-entry`, exit 1 (spec-master ran it). Write `toward held` for `toward sampled` in the entry; stdout gains `missing: held counts the ones it decided hold; …` before `checked`. The source phrases are read from `agents/milestone-auditor.md`, so a later auditor change that drops one prints `no-source: …`, exit 1.
5. run: `node tests/context-glossary-links.test.js | tail -1`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: write `[[FAIL grounds]]` in the mechanical ground entry; the link resolves to no entry and the test fails.
6. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u7a): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vx "CONTEXT.md" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: also stage `docs/harness-glossary.md` in a `(rfp-u7a): ` commit; stdout is `1`. With no `(rfp-u7a): ` commit, stdout is `no-commits`, exit 1.
7. run: `bash -c 'git status --porcelain --untracked-files=no -- CONTEXT.md | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: leave the glossary edit unstaged; stdout is `1`. The pathspec is this unit's one file, so another unit's work in progress in the same tree does not count.

## Escalation
If any `before` text is not found exactly once, or an insertion heading is not found exactly once, STOP and
report the current text as a spec gap. If a criterion prints `no-source: …`, the source file changed after this
contract (or rfp-u7b has not landed): stop and report it. If a gate blocks a command, report it and wait.
