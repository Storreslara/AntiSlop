Unit: rfp-u6c

## Objective
Clear three glossary advisory notes from the rfp-u5 review (plan Step 6, items 8 to 10). One scribe run. This
repo's `knowledgeWrites` is `apply`, and this contract names the only knowledge file it edits, `CONTEXT.md`.
- **refutation outcome**: the entry says a REFUTED defect is "recorded as a `NOTE[code]: refuted:` note on the
  PASS". `agents/reviewer.md` writes that note only when every defect is REFUTED; in a FAIL that keeps
  another defect, "the REFUTED ones and your reasons go in the `refutation` advisory section", and under review
  gating off the note goes to that section too. The entry gains that clause.
- **refutation pass**: its `_Avoid_:` line lists bare "verifier", but `CONTEXT.md:57` calls the reviewer "the
  independent verifier". The avoid word becomes "refutation verifier".
- **mechanical ground**: defined only inside the **judgment defect** entry, yet it decides which FAILs skip the
  pass and yields the `skipped=mechanical` token. It gets its own entry, right after **judgment defect**, and
  both **judgment defect** and **refutation pass** link it.

ADR 0043 needs no edit: it never says where a REFUTED defect is recorded (it says only that "the milestone
auditor samples up to 3 live `refuted:` notes per milestone", which stays true), and it does not use
"verifier" or "mechanical ground".

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order", "Step 6").
Contract file: `docs/plans/2026-10-27-refutation-pass/contracts/rfp-u6c.md`, the contract of record.
rfp-u5 has its PASS (57ec2d70). rfp-u6a, rfp-u6b and rfp-u6c share no file and may go in any order; one unit
is mid-review at a time.

## Glossary edits
1. file: `CONTEXT.md`
   heading: `**judgment defect**:`
   placement: replace the whole entry (its heading line to its `_Avoid_:` line) with the text below, which
   adds the **mechanical ground** entry after it, separated by one blank line
   indent: 3
   before:
   ~~~~
   **judgment defect**:
   (plan 2026-10-27-refutation-pass, unit rfp-u5) — a FAIL defect the reviewer
     found by reading code, not by a check it ran. Its opposite is a mechanical
     ground: a `review-precheck.sh` failure line, an uncommitted tree, an
     out-of-scope path, or a command the reviewer ran that shows the failure. A
     defect the reviewer reproduced with a command counts as mechanical. Only
     judgment defects go through the [[refutation pass]].
   _Avoid_: soft defect, opinion defect
   ~~~~
   text:
   ~~~~
   **judgment defect**:
   (plan 2026-10-27-refutation-pass, unit rfp-u5) — a FAIL defect the reviewer
     found by reading code, not by a check it ran. Its opposite is a
     [[mechanical ground]]: a `review-precheck.sh` failure line, an uncommitted
     tree, an out-of-scope path, or a command the reviewer ran that shows the
     failure. A defect the reviewer reproduced with a command counts as
     mechanical. Only judgment defects go through the [[refutation pass]].
   _Avoid_: soft defect, opinion defect

   **mechanical ground**:
   (plan 2026-10-27-refutation-pass, unit rfp-u6c) — a FAIL ground the reviewer
     established with a check rather than by reading: a `review-precheck.sh`
     failure line, an uncommitted tree, an out-of-scope path, or a command the
     reviewer ran that shows the failure, which is how a reproduced defect
     becomes one. It is the opposite of a [[judgment defect]], and it is never
     sent to the [[refutation pass]]: one mechanical ground in a FAIL skips the
     whole pass, every defect stays as found, and the [[refutation line]] reads
     `refutation: skipped=mechanical`.
   _Avoid_: hard defect, objective defect
   ~~~~
2. file: `CONTEXT.md`
   heading: `**refutation pass**:`
   placement: replace these lines of that entry with the text below
   indent: 3
   before:
   ~~~~
     the reason on the [[refutation line]], on any mechanical ground, on more
   ~~~~
   text:
   ~~~~
     the reason on the [[refutation line]], on any [[mechanical ground]], on more
   ~~~~
3. file: `CONTEXT.md`
   heading: `**refutation pass**:`
   placement: replace the entry's `_Avoid_:` line with the text below
   indent: 3
   before:
   ~~~~
   _Avoid_: refuter, second review, verifier
   ~~~~
   text:
   ~~~~
   _Avoid_: refuter, second review, refutation verifier
   ~~~~
4. file: `CONTEXT.md`
   heading: `**refutation outcome**:`
   placement: replace the whole entry (its heading line to its `_Avoid_:` line) with the text below
   indent: 3
   before:
   ~~~~
   **refutation outcome**:
   (plan 2026-10-27-refutation-pass, unit rfp-u5) — the answer the
     [[refutation pass]] settles for one defect, after the reviewer's own
     re-check. REFUTED: the defect is dropped and recorded as a
     `NOTE[code]: refuted:` note on the PASS, unless the re-check finds a reason
     the artifact does not defeat it. CONFIRMED: it stays a defect. UNCERTAIN: it
     stays in a FAIL that happens anyway, prefixed `[unconfirmed]`. A defect whose
     artifact does not reproduce, or that got no answer, stands as found. REFUTED
     and CONFIRMED need an artifact. When only UNCERTAIN defects remain, the
     verdict is INSUFFICIENT-CONTEXT, not ESCALATE-TO-HUMAN. The verdict itself
     stays the reviewer's.
   _Avoid_: refutation verdict
   ~~~~
   text:
   ~~~~
   **refutation outcome**:
   (plan 2026-10-27-refutation-pass, unit rfp-u5) — the answer the
     [[refutation pass]] settles for one defect, after the reviewer's own
     re-check. REFUTED: the defect is dropped and recorded as a
     `NOTE[code]: refuted:` note on the PASS when every defect is REFUTED, or in
     the verdict's `refutation` advisory section when another defect keeps the
     FAIL (under review gating off, always in that section), unless the
     re-check finds a reason the artifact does not defeat it. CONFIRMED: it
     stays a defect. UNCERTAIN: it stays in a FAIL that happens anyway,
     prefixed `[unconfirmed]`. A defect whose artifact does not reproduce, or
     that got no answer, stands as found. REFUTED and CONFIRMED need an
     artifact. When only UNCERTAIN defects remain, the verdict is
     INSUFFICIENT-CONTEXT, not ESCALATE-TO-HUMAN. The verdict itself stays the
     reviewer's.
   _Avoid_: refutation verdict
   ~~~~

## Doc edits
none — make no other doc changes
prune: none

## ADR
none

## Close conditions
- issue #0: the fast path has no tracker issue, so close nothing and run no `gh issue` command
- task-id: rfp-u6c
- marker first line: "PASS rfp-u6c "
- Commit once, staging only `CONTEXT.md`, with the subject `docs(rfp-u6c): mechanical ground entry; refutation outcome and avoid-list fixes (#0)` and the trailer line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. A fix round is a new commit whose subject keeps `(rfp-u6c): `. Commit your own memory notes separately (`docs(agent-memory): ...`), never in this commit.

## Do NOT touch
- `agents/`, `templates/`, `adapters/`, `tests/`, `hooks/`, `bin/`, `eval/`, `scripts/` (criterion 6)
- `docs/harness-glossary.md`, every `docs/adr/` file, `docs/plans/` (criterion 6)
- `.claude/` (generated or gitignored; criterion 6)
- every other `CONTEXT.md` entry, including the rfp-u5 wording that rfp-u5's criteria 4 and 5 pin (criteria 3 and 4 re-check it)

## Acceptance criteria
1. run: `bash -c 'for t in "mechanical ground" "judgment defect" "refutation pass" "refutation outcome"; do printf "%s=%s/%s " "$t" "$(grep -cxF "**$t**:" CONTEXT.md)" "$(grep -cxF "**$t**:" docs/harness-glossary.md)"; done | sed "s/ $//"; echo'`
   exit: 0
   stdout: `mechanical ground=1/0 judgment defect=1/0 refutation pass=1/0 refutation outcome=1/0`
   mutation: skip glossary edit 1; the first field reads `mechanical ground=0/0`, criterion 2 prints `no-entry` and criterion 5 fails on the dangling `[[mechanical ground]]` link (`2 context-glossary-links check(s) FAILED.`) (spec-master ran it).
2. run: `bash -c 'r=$(tr -s " \n" " " < agents/reviewer.md | tr -d "\140"); for y in "a review-precheck.sh failure line, an uncommitted tree, an out-of-scope path, or a command you ran that shows the failure is mechanical" "any mechanical ground (skipped=mechanical)" "Skip the pass, keeping every defect as found"; do printf "%s" "$r" | grep -qF -- "$y" || { echo "no-source: $y"; exit 1; }; done; e=$(awk "/^\*\*mechanical ground\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; for x in "established with a check rather than by reading" "a review-precheck.sh failure line, an uncommitted tree, an out-of-scope path, or a command the reviewer ran that shows the failure" "the opposite of a [[judgment defect]]" "one mechanical ground in a FAIL skips the whole pass, every defect stays as found" "the [[refutation line]] reads refutation: skipped=mechanical" "_Avoid_: hard defect, objective defect"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: write `skips that defect` for `skips the whole pass` in the entry; stdout gains `missing: one mechanical ground in a FAIL skips the whole pass, every defect stays as found` before `checked` (spec-master ran it). The three source phrases are read from `agents/reviewer.md`'s Refutation pass bullet, so a later reviewer change that drops one prints `no-source: …`, exit 1.
3. run: `bash -c 'r=$(tr -s " \n" " " < agents/reviewer.md | tr -d "\140"); for y in "the REFUTED ones and your reasons go in the refutation advisory section" "(under review gating off, to the refutation section instead)"; do printf "%s" "$r" | grep -qF -- "$y" || { echo "no-source: $y"; exit 1; }; done; e=$(awk "/^\*\*refutation outcome\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; for x in "REFUTED: the defect is dropped and recorded as a NOTE[code]: refuted: note on the PASS when every defect is REFUTED" "or in the verdict" "refutation advisory section when another defect keeps the FAIL" "(under review gating off, always in that section)" "CONFIRMED: it stays a defect" "UNCERTAIN: it stays in a FAIL that happens anyway, prefixed [unconfirmed]" "stands as found" "REFUTED and CONFIRMED need an artifact" "the verdict is INSUFFICIENT-CONTEXT, not ESCALATE-TO-HUMAN"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: leave the entry as it is at 57ec2d70; stdout gains four `missing:` lines (`… when every defect is REFUTED`, `or in the verdict`, `… another defect keeps the FAIL`, `(under review gating off, …)`) before `checked` (spec-master ran it). The last five phrases are rfp-u5's criterion 4 phrases, kept.
4. run: `bash -c 'e=$(awk "/^\*\*judgment defect\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); p=$(awk "/^\*\*refutation pass\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " "); for x in "found by reading code, not by a check it ran" "Its opposite is a [[mechanical ground]]: a review-precheck.sh failure line, an uncommitted tree, an out-of-scope path, or a command the reviewer ran that shows the failure" "reproduced with a command counts as mechanical" "Only judgment defects go through the [[refutation pass]]"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; printf "%s" "$p" | grep -qF "on any [[mechanical ground]], on more" || echo "missing: pass link"; printf "%s" "$p" | grep -qF "_Avoid_: refuter, second review, refutation verifier" || echo "missing: avoid"; grep -qF "\`reviewer\` is the independent verifier" CONTEXT.md || echo "missing: line-57 verifier"; echo "bare-verifier=$(grep -E "^_Avoid_:" CONTEXT.md | grep -cE "(: |, )verifier(,|$)")"'`
   exit: 0
   stdout: `bare-verifier=0`
   mutation: skip glossary edit 3; stdout is `missing: avoid` then `bare-verifier=1`. Skip glossary edit 2; stdout gains `missing: pass link` (spec-master ran both).
5. run: `node tests/context-glossary-links.test.js | tail -1`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: write `[[mechanical grounds]]` in the judgment defect entry; the link resolves to no entry and the test fails.
6. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u6c): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vx "CONTEXT.md" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: also stage `docs/adr/0043-refutation-pass-inside-reviewer-turn.md` in a `(rfp-u6c): ` commit; stdout is `1`. With no `(rfp-u6c): ` commit, stdout is `no-commits`, exit 1.
7. run: `bash -c 'git status --porcelain --untracked-files=no -- . ":!.claude/agent-memory" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: leave the glossary edit unstaged; stdout is `1`.

## Escalation
If any `before` text is not found exactly once, STOP and report the current text as a spec gap. If a
criterion prints `no-source: …`, `agents/reviewer.md` changed after this contract: stop and report it. If a
gate blocks a command, report it and wait.
