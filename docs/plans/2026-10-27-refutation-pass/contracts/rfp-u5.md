Unit: rfp-u5

## Objective
Record the refutation pass in the two glossaries and land its ADR (plan Step 5, D1 to D8). One scribe run,
after both rfp-u3 and rfp-u4 have a PASS marker. This repo's `knowledgeWrites` is `apply`, and this contract
names every knowledge file it edits.
- `CONTEXT.md`: the **FAIL block** entry gains the `[unconfirmed]` prefix and the last-line
  **refutation line**; three new entries follow it: **judgment defect**, **refutation pass** (it records
  that "Refute, don't rubber-stamp" keeps its own meaning) and **refutation outcome**.
- `docs/harness-glossary.md`: a new **refutation line** entry with its grammar, as the file's last entry.
- `docs/adr/0043-refutation-pass-inside-reviewer-turn.md`: the plan's ADR draft, numbered. 0043 is the next
  free number at 3bd60f56 (the highest is 0042; 0007 is a known hole and stays one). If another ADR has taken
  0043 by dispatch, use the next free number everywhere it appears (see Escalation).

Each acceptance criterion checks a claim against its live source, not only the presence of words: the cap
and the model are read from `agents/reviewer.md`, the line grammar from `templates/persona-protocol.md`, the
sample size and count command from `agents/milestone-auditor.md`, and the ADR's "no hook, marker, ladder or
orchestrator change" from the commits of rfp-u1 to rfp-u4. A criterion that prints `no-source` means rfp-u3
or rfp-u4 has not landed.

## Retrieval
Fast path, no tracker issue. Spec: `docs/plans/2026-10-27-refutation-pass.md` ("Units and order", "Step 5",
"ADR draft", "Per-defect protocol", "FAIL-record readers"). Contract file:
`docs/plans/2026-10-27-refutation-pass/contracts/rfp-u5.md`, the contract of record. Dispatch only after
rfp-u3 and rfp-u4 both have a PASS marker; the dispatch quotes both PASS first lines.

## Glossary edits
1. file: `CONTEXT.md`
   heading: `**FAIL block**:`
   placement: replace these two lines of that paragraph with the text below
   indent: 3
   before:
   ~~~~
     [[Escalation ladder]] never reads it), followed by the defect list verbatim,
     then a blank separator line.
   ~~~~
   text:
   ~~~~
     [[Escalation ladder]] never reads it), followed by the defect list verbatim,
     in which a defect prefixed `[unconfirmed]` is one the [[refutation pass]]
     could neither prove nor disprove (a fix reproduces it before changing
     code), then the [[refutation line]] as the block's last line, then a blank
     separator line. The refutation line is telemetry, never a defect, and it
     stays last because `bin/escalation-card.sh` takes the first non-empty line
     after `tier:` as the block's first defect.
   ~~~~
2. file: `CONTEXT.md`
   heading: `**FAIL block**:`
   placement: insert after the paragraph of this entry, separated by one blank line (directly before the `.escalated` marker entry), with one blank line between the three new entries
   indent: 3
   text:
   ~~~~
   **judgment defect**:
   (plan 2026-10-27-refutation-pass, unit rfp-u5) — a FAIL defect the reviewer
     found by reading code, not by a check it ran. Its opposite is a mechanical
     ground: a `review-precheck.sh` failure line, an uncommitted tree, an
     out-of-scope path, or a command the reviewer ran that shows the failure. A
     defect the reviewer reproduced with a command counts as mechanical. Only
     judgment defects go through the [[refutation pass]].
   _Avoid_: soft defect, opinion defect

   **refutation pass**:
   (plan 2026-10-27-refutation-pass, unit rfp-u5) — the reviewer's step before a
     FAIL verdict whose grounds are all [[judgment defect]]s, 1 to 3 of them after
     merging duplicates. The reviewer pipes them into
     `.claude/bin/refutation-brief.sh` and spawns one foreground, unnamed
     `explorer` on `sonnet` to disprove each against the whole file, its callers
     and the baseline. It then re-checks each artifact itself, states why it
     proves or defeats the claim, and may keep a defect standing. The pass writes
     no marker, and a FAIL it prevents writes no [[FAIL block]], so the
     [[FAIL-block count]] counts only FAILs that survived it. It is skipped, with
     the reason on the [[refutation line]], on any mechanical ground, on more
     than 3 judgment defects, on the resume after an INSUFFICIENT-CONTEXT it
     caused, and when no subagent can be spawned. The reviewer instructions
     shipped only after the replay gate in `eval/refutation-replay/` passed.
     "Refute, don't rubber-stamp" in `agents/reviewer.md` keeps its own meaning:
     attacking the change under review, not this pass.
   _Avoid_: refuter, second review, verifier

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
3. file: `docs/harness-glossary.md`
   heading: `**mutant never built**:`
   placement: insert after the paragraph of this entry (the last entry of the file), separated by one blank line
   indent: 3
   text:
   ~~~~
   **refutation line**:
   (plan 2026-10-27-refutation-pass, unit rfp-u5) — the last line of every [[FAIL block]] since rfp-u3: `refutation: confirmed=<a> refuted=<b> uncertain=<c>` when the reviewer's [[refutation pass]] ran (`a` counts the defects that stood or were CONFIRMED), or `refutation: skipped=<mechanical|over-cap|resume|no-subagent>` when it did not. The codex and cursor ports run no pass and always write `skipped=no-subagent`. The line is telemetry, never a defect: a fix contract gives it no criterion. It stays last because `bin/escalation-card.sh` takes the first non-empty line after `tier:` as the first defect, and its words match none of the FAIL classes of `scripts/unit-outcomes.js` (both pinned by `tests/fail-record-refutation.test.sh`). The milestone auditor counts the lines starting `refutation: confirmed=` as FAILs that survived a pass, against the `.pass` markers carrying a `NOTE[code]: refuted:` note as prevented FAILs. Under review gating off no record exists, and the line goes in the verdict text.
   ~~~~

## Doc edits
none — make no other doc changes
prune: none

## ADR
0043 The refutation pass runs inside the reviewer's turn, behind a replay gate
file: docs/adr/0043-refutation-pass-inside-reviewer-turn.md
body:
indent: 3
   ~~~~
   # ADR 0043: The refutation pass runs inside the reviewer's turn, behind a replay gate

   Date: 2026-10-27
   Status: Accepted
   Related: ADR-0002, ADR-0016

   ## Context

   A FAIL verdict whose defect is hallucinated, or already mitigated by code the reviewer did not read, still uses up an Escalation-ladder attempt, because the ladder's `n` is the FAIL-block count. A wrong refutation is the costly direction: the reviewer's PASS is the terminal gate, so a real defect refuted away ships.

   ## Decision

   Before returning FAIL, the reviewer pipes at most 3 judgment defects into `bin/refutation-brief.sh` (installed as `.claude/bin/refutation-brief.sh`) and spawns one foreground, unnamed `explorer` on `sonnet` with its output as the prompt, to disprove each defect against the whole file, its callers and the baseline. The reviewer re-checks each artifact itself, states its own reason, and may keep a defect standing. Only defects that survive reach the FAIL record, whose every block now ends with a `refutation:` telemetry line. The reviewer instructions shipped only after an offline replay of past real defects passed its gate (`eval/refutation-replay/score.py --gate`), and the milestone auditor samples up to 3 live `refuted:` notes per milestone.

   ## Consequences

   - No hook, marker, ladder or orchestrator change. A PASS reached through a refutation writes the same marker, stamp and flag state as any other PASS, and a prevented FAIL writes no FAIL block.
   - The FAIL-record format gains a last line, and a defect the pass could not settle carries the `[unconfirmed]` prefix.
   - The pass's answer is evidence; the verdict stays the reviewer's.
   - The codex and cursor ports run no pass and write `refutation: skipped=no-subagent`.

   ## Alternatives rejected

   - An orchestrator-dispatched refutation after the FAIL: `n` has already gone up, so undoing it needs a new marker or a `ladder-tier.sh` change, plus fix-contract filtering and a second route-gate shape.
   - A nested `Mode: advisory` reviewer: the reviewer-dispatch caller allowlist refuses it.
   - A new `refuter` persona: it costs a persona file, ports, personaSelection and cli.js lists, and buys nothing over `explorer`.

   ## Why the three ADR tests hold

   - Hard to reverse: moving the pass to the orchestrator needs state machinery, and the telemetry format would already be in consumer records.
   - Surprising without context: a second check before FAIL reads like a second dispatch, and it is not one.
   - A real trade-off: the alternatives above were weighed against one subagent round-trip on the FAIL path.
   ~~~~

## Close conditions
- issue #0: the fast path has no tracker issue, so close nothing and run no `gh issue` command
- task-id: rfp-u5
- marker first line: "PASS rfp-u5 "
- Commit once, staging only `CONTEXT.md`, `docs/harness-glossary.md` and the ADR file, with the subject `docs(rfp-u5): glossary entries and ADR 0043 for the reviewer's refutation pass (#0)` (with the number actually used) and the trailer line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. A fix round is a new commit whose subject keeps `(rfp-u5): `. Commit your own memory notes separately (`docs(agent-memory): ...`), never in this commit.

## Do NOT touch
- `agents/`, `templates/`, `adapters/` (rfp-u3's and rfp-u4's; criterion 10)
- `tests/`, `hooks/`, `bin/`, `eval/`, `scripts/` (criterion 10)
- `docs/plans/` (spec-master keeps the plan's status line; criterion 10)
- `.claude/` (generated or gitignored; criterion 10)
- every existing ADR file (numbering takes the next free number, never renames one; criterion 7)

## Acceptance criteria
1. run: `bash -c 'for t in "judgment defect" "refutation pass" "refutation outcome" "refutation line"; do printf "%s %s %s\n" "$t" "$(grep -cxF "**$t**:" CONTEXT.md)" "$(grep -cxF "**$t**:" docs/harness-glossary.md)"; done'`
   exit: 0
   stdout: `judgment defect 1 0` then `refutation pass 1 0` then `refutation outcome 1 0` then `refutation line 0 1`
   mutation: also add a `**refutation line**:` entry to `CONTEXT.md`; the last line reads `refutation line 1 1` (a term lives in one glossary). Skipping glossary edit 2 prints `0 0` on the first three lines.
2. run: `bash -c 'e=$(awk "/^\*\*refutation line\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" docs/harness-glossary.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; p=$(tr -s " \n" " " < templates/persona-protocol.md | tr -d "\140"); s=$(printf "%s" "$p" | grep -oE "refutation: skipped=<[^>]*>" | head -1); c=$(printf "%s" "$p" | grep -oE "refutation: confirmed=<a> refuted=<b> uncertain=<c>" | head -1); grep -qE "grep -rh .\^refutation: confirmed=. --include=" agents/milestone-auditor.md || { echo no-auditor-count; exit 1; }; [ -n "$s" ] && [ -n "$c" ] || { echo no-protocol-grammar; exit 1; }; for x in "the last line of every [[FAIL block]]" "$c when the reviewer" "$s when it did not" "always write skipped=no-subagent" "telemetry, never a defect: a fix contract gives it no criterion" "first non-empty line after tier: as the first defect" "counts the lines starting refutation: confirmed= as FAILs that survived a pass" "carrying a NOTE[code]: refuted: note as prevented FAILs"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: write the skip set in glossary edit 3 as `<mechanical|over-cap|resume>`; stdout gains `missing: refutation: skipped=<mechanical|over-cap|resume|no-subagent> when it did not` before `checked` (spec-master ran it). The grammar is read from `templates/persona-protocol.md`, so a later protocol change makes this entry fail the same way. Before rfp-u3 or rfp-u4 lands, stdout is `no-protocol-grammar` or `no-auditor-count`, exit 1.
3. run: `bash -c 'r=$(tr -s " \n" " " < agents/reviewer.md | tr -d "\140"); n=$(printf "%s" "$r" | grep -oE "more than [0-9]+ judgment defects" | grep -oE "[0-9]+" | head -1); m=$(printf "%s" "$r" | grep -oE "with model: [a-z]+, in the foreground" | cut -d" " -f3 | tr -d ","); [ -n "$n" ] && [ -n "$m" ] || { echo no-source; exit 1; }; printf "%s" "$r" | grep -qF "Refute, don" || { echo no-refute-bullet; exit 1; }; e=$(awk "/^\*\*refutation pass\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; for x in "1 to $n of them after merging duplicates" "more than $n judgment defects" "one foreground, unnamed explorer on $m" "may keep a defect standing" "The pass writes no marker, and a FAIL it prevents writes no [[FAIL block]]" "Refute, don" "attacking the change under review, not this pass" "_Avoid_: refuter"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: write `1 to 5 of them` in the refutation pass entry; stdout gains `missing: 1 to 3 of them after merging duplicates`. Changing `more than 3 judgment defects` to 5 in a scratch copy of `agents/reviewer.md` instead makes the unedited entry fail twice (spec-master ran both): the cap and the model are read from the reviewer, not typed here.
4. run: `bash -c 'r=$(tr -s " \n" " " < agents/reviewer.md | tr -d "\140"); for y in "stands as found" "NOTE[code]: refuted:" "prefixed [unconfirmed]" "return INSUFFICIENT-CONTEXT"; do printf "%s" "$r" | grep -qF -- "$y" || { echo "no-source: $y"; exit 1; }; done; e=$(awk "/^\*\*refutation outcome\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; for x in "REFUTED: the defect is dropped and recorded as a NOTE[code]: refuted: note on the PASS" "CONFIRMED: it stays a defect" "UNCERTAIN: it stays in a FAIL that happens anyway, prefixed [unconfirmed]" "stands as found" "REFUTED and CONFIRMED need an artifact" "the verdict is INSUFFICIENT-CONTEXT, not ESCALATE-TO-HUMAN"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: drop `, not ESCALATE-TO-HUMAN` from the refutation outcome entry; stdout gains `missing: the verdict is INSUFFICIENT-CONTEXT, not ESCALATE-TO-HUMAN` (spec-master ran it).
5. run: `bash -c 'r=$(tr -s " \n" " " < agents/reviewer.md | tr -d "\140"); printf "%s" "$r" | grep -qF "a review-precheck.sh failure line, an uncommitted tree, an out-of-scope path" || { echo no-source; exit 1; }; e=$(awk "/^\*\*judgment defect\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; for x in "found by reading code, not by a check it ran" "a review-precheck.sh failure line, an uncommitted tree, an out-of-scope path, or a command the reviewer ran that shows the failure" "reproduced with a command counts as mechanical" "Only judgment defects go through the [[refutation pass]]"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: drop `out-of-scope` from the judgment defect entry; stdout gains the `missing: a review-precheck.sh failure line, …` line (spec-master ran it).
6. run: `bash -c 'bash tests/fail-record-refutation.test.sh >/dev/null || { echo readers-test-red; exit 1; }; e=$(awk "/^\*\*FAIL block\*\*:\$/{f=1;next} f&&/^(\*\*|#)/{exit} f" CONTEXT.md | tr -s " \n" " " | tr -d "\140"); [ -n "$e" ] || { echo no-entry; exit 1; }; for x in "first line exactly FAIL <task-id> <UTC ISO-8601 timestamp>" "second line tier: <haiku|sonnet|opus|unknown>" "followed by the defect list verbatim, in which a defect prefixed [unconfirmed] is one the [[refutation pass]] could neither prove nor disprove" "then the [[refutation line]] as the block" "last line, then a blank separator line" "telemetry, never a defect" "first non-empty line after tier: as the block" "(^FAIL <task-id> )"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: write `as the block's first line` in glossary edit 1; stdout gains `missing: last line, then a blank separator line` (spec-master ran it). The claim itself is behaviour-checked: the command first runs rfp-u3's `tests/fail-record-refutation.test.sh`, whose case (c) fails when a `refutation:` line comes first.
7. run: `bash -c 'f=$(ls docs/adr | grep -E "^[0-9]{4}-refutation-pass-inside-reviewer-turn\.md$"); [ "$(printf "%s\n" "$f" | grep -c .)" = 1 ] || { echo "adr files: [$f]"; exit 1; }; n=${f%%-*}; cs=$(git log --format="%H %s" | grep -F "(rfp-u5): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; b=$(printf "%s\n" $cs | tail -1); hi=$(git ls-tree --name-only "$b^" docs/adr/ | sed "s#^docs/adr/##" | grep -oE "^[0-9]{4}" | sort -n | tail -1); w=$(printf "%04d" $((10#$hi + 1))); [ "$n" = "$w" ] || echo "number $n, expected $w"; [ "$(ls docs/adr | grep -oE "^[0-9]{4}" | sort | uniq -d | grep -c .)" = 0 ] || echo duplicate-number; head -1 "docs/adr/$f" | grep -qE "^# ADR $n: The refutation pass runs inside the reviewer.s turn, behind a replay gate$" || echo bad-title; grep -qx "Status: Accepted" "docs/adr/$f" || echo no-status; h=$(grep -E "^## " "docs/adr/$f" | tr "\n" "|"); [ "$h" = "## Context|## Decision|## Consequences|## Alternatives rejected|## Why the three ADR tests hold|" ] || echo "headings: $h"; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: name the file `0044-…` with a `# ADR 0044:` title while 0043 is free; stdout gains `number 0044, expected 0043` (spec-master ran it). With no `(rfp-u5): ` commit, stdout is `no-commits`, exit 1; with no ADR file, `adr files: []`, exit 1.
8. run: `bash -c 'r=$(tr -s " \n" " " < agents/reviewer.md | tr -d "\140"); n=$(printf "%s" "$r" | grep -oE "more than [0-9]+ judgment defects" | grep -oE "[0-9]+" | head -1); m=$(printf "%s" "$r" | grep -oE "with model: [a-z]+, in the foreground" | cut -d" " -f3 | tr -d ","); k=$(tr -s " \n" " " < agents/milestone-auditor.md | grep -oE "Re-verify the first [0-9]+ of them" | grep -oE "[0-9]+"); [ -n "$n" ] && [ -n "$m" ] && [ -n "$k" ] || { echo no-source; exit 1; }; [ -f bin/refutation-brief.sh ] && [ -f eval/refutation-replay/score.py ] || { echo no-artifacts; exit 1; }; e=$(cat docs/adr/[0-9][0-9][0-9][0-9]-refutation-pass-inside-reviewer-turn.md | tr -s " \n" " " | tr -d "\140"); for x in "pipes at most $n judgment defects into bin/refutation-brief.sh" "spawns one foreground, unnamed explorer on $m" "may keep a defect standing" "ends with a refutation: telemetry line" "eval/refutation-replay/score.py --gate" "samples up to $k live refuted: notes per milestone" "An orchestrator-dispatched refutation after the FAIL" "A nested Mode: advisory reviewer: the reviewer-dispatch caller allowlist refuses it" "A new refuter persona" "the verdict stays the reviewer" "write refutation: skipped=no-subagent"; do printf "%s" "$e" | grep -qF -- "$x" || echo "missing: $x"; done; echo checked'`
   exit: 0
   stdout: `checked`
   mutation: write `at most 5 judgment defects` in the ADR's Decision; stdout gains `missing: pipes at most 3 judgment defects into bin/refutation-brief.sh` (spec-master ran it). The 3, `sonnet` and the sample size are read from `agents/reviewer.md` and `agents/milestone-auditor.md`.
9. run: `bash -c 'cs=$(git log --format="%H %s" | grep -E "^[0-9a-f]+ [a-z]+\(rfp-u[1-4]\): " | cut -d" " -f1); u=$(git log --format="%s" | grep -oE "^[a-z]+\(rfp-u[1-4]\): " | grep -oE "rfp-u[1-4]" | sort -u | grep -c .); [ "$u" = 4 ] || { echo "units-with-commits=$u"; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -E "^(hooks/|\.claude/hooks/|agents/orchestrator\.md$|bin/(ladder-tier|fail-count|escalation-card)\.sh$)" | sed "s/^/claim-false: /"; grep -qF "No hook, marker, ladder or orchestrator change." docs/adr/[0-9][0-9][0-9][0-9]-refutation-pass-inside-reviewer-turn.md && echo claim-stated'`
   exit: 0
   stdout: `claim-stated`
   mutation: a `(rfp-u3): ` commit that also edits `hooks/scripts/stop-gate.sh` adds `claim-false: hooks/scripts/stop-gate.sh` before `claim-stated` (spec-master ran it): the ADR's consequence is checked against what rfp-u1 to rfp-u4 actually committed. Fewer than four of those units with a commit prints `units-with-commits=<n>`, exit 1.
10. run: `bash -c 'cs=$(git log --format="%H %s" | grep -F "(rfp-u5): " | cut -d" " -f1); [ -n "$cs" ] || { echo no-commits; exit 1; }; for c in $cs; do git show --name-only --format= "$c"; done | sort -u | grep -vxE "CONTEXT\.md|docs/harness-glossary\.md|docs/adr/[0-9]{4}-refutation-pass-inside-reviewer-turn\.md" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: also stage an `agents/reviewer.md` edit in a `(rfp-u5): ` commit; stdout is `1` (spec-master ran it). With no `(rfp-u5): ` commit, stdout is `no-commits`, exit 1.
11. run: `node tests/context-glossary-links.test.js | tail -1`
   exit: 0
   stdout: `All context-glossary-links checks passed.`
   mutation: add the link `[[no such term]]` to an entry; the test fails.
12. run: `node tests/ubiquitous-language.test.js | tail -1`
   exit: 0
   stdout: `OK   skills/ubiquitous-language/SKILL.md passes all 4 structural/distinguishability checks`
   mutation: set `UL_TEST_MUTATE=1`; the test exits non-zero (it checks skills/ubiquitous-language/SKILL.md, not the entries).
   proof: `UL_TEST_MUTATE=1 node tests/ubiquitous-language.test.js` exits non-zero.
13. run: `bash -c 'git status --porcelain --untracked-files=no -- . ":!.claude/agent-memory" | wc -l | tr -d " "'`
   exit: 0
   stdout: `0`
   mutation: leave the glossary edit unstaged; stdout is non-zero.

## Escalation
If any item cannot be applied exactly, STOP and report a spec gap. If a criterion prints `no-source`,
`no-protocol-grammar`, `no-auditor-count`, `no-artifacts` or `units-with-commits=<n>`, rfp-u1 to rfp-u4 have
not all landed: stop and report it. If `docs/adr/0043-*` already exists at dispatch, use the next free number
N in the ADR's file name, its `# ADR N:` title line and the commit subject, and name N in your report;
criterion 7 computes the expected number itself. If a gate blocks a command, report it and wait.
