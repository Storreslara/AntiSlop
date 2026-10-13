---
name: escalation-packet follow-ups (epa, epf)
description: epa-2 (60ff302, 0.31.157), epa-3 (ac1e511, 0.31.158) and epa-4 (d5b479f, 0.31.159) carry-forward gaps for the escalation layout, card/fold marker, viewer tests, and parity probes, and the epf run that closed them (epf-1..6, 2026-10-13) with its new carry-forward items, kept in one place
metadata:
  type: project
---

**epa-2: PASS 2026-10-12, commit 60ff302, version 0.31.157.** Scribe pass (5a26e69) aligned two glossary entries and minted **terminal reader**.

- **literate change summary** and **worked example** match the shipped wording: a `>` blockquote line, and `**Before:**` / `**After:**` lines.
- **terminal reader** is the plain-text layout contract. **epa-3 (PASS 2026-10-12, ac1e511, 0.31.158)** added `view.sh`, which renders in colour only when a renderer exists and otherwise falls back to `cat`, so the plain-text layout still holds. If a later unit adds a layout rule, update the entry rather than adding a second term.
- **epa-3 scribe pass:** the **packet viewer** CONTEXT.md entry said "comprehension tooling"; reworded to "a viewer for **comprehension material** only", the existing term. No other glossary change.

## Carry-forward (not applied: plan, tests and agents are off-limits to scribe)

1. **AC2.3 loop masks failures (epa-2 plan Step 2).** The `for` loop returns only the last file's status, so an earlier file containing the old phrase passes silently. Fix in the plan: `|| exit 1` inside the loop body.
2. **Parity probes incomplete for the two ports (epa-2).** `ESCALATION_PROBES` (tests/adapter-protocol-parity.test.js) lacks `**After:**`, the `### <n>.` heading, and the `>` blockquote line for the codex and cursor ports, although AC2.1 greps for some of them. Candidate follow-up unit.
3. **Open Question 1 still needs a tracker issue (epa-2).** The dashboard markdown-lite renderer has no table support, so `| Where | What to check |` will not render there. Recorded non-blocking with a default applied. Not filed by scribe; a human or the lead should file it.
4. **Viewer fallback order is not pinned (epa-3).** tests/packet-view-script.test.sh T4-T7 never check the order glow, bat, batcat, rich, cat. Swapping glow and bat stays green. Fix: a both-present case.
5. **Missing-file guard is not pinned (epa-3).** T8 misses a dropped `[ -f "$p" ] || continue`. Fix: assert stderr is empty.
6. **Copy-vs-copy comparison (epa-3).** T1 compares the four copies with each other, not with the plan's canonical block. A drift in all four at once would pass.
7. **AC3.2 counts echo lines only; AC3.3 probe is weak (epa-3).** The `view.sh` probe is satisfied by the block's own comment lines. Candidate probe: a prose string such as "`run.sh` and `view.sh` commands".
8. **Latent parser issue (epa-3, out of unit scope).** bin/cli.js:720-729 `parseProtocolSections` splits on `## ` and ignores code fences, so a `## ` line inside a fenced block would split a section. Latent, not triggered by the current block.
9. **Stale criterion text (epa-3 note).** docs/plans/2026-10-01-in-session-escalation-decision.md:928 holds an old criterion whose phrase no longer matches orchestrator step 4. Nothing live reads it.
10. **AC4.6 as written returns rc=1 (epa-4 note, plan 2026-10-12-escalation-packet-aesthetics.md).** `${a:=$(mktemp)}` inside a pipeline-element redirect leaves `a`/`b` empty in the parent shell. Fix in the plan: `a=$(mktemp); b=$(mktemp)`.
11. **AC4.4 is met by the wrong text (epa-4).** It is satisfied by the template's approve table row (~templates/persona-protocol.md:671), not the prose sentence. Fix: `grep -c` threshold of at least 2.
12. **No rule for older `.escalated` markers (epa-4).** Markers written before epa-4 have no `---` fold line or `decide:` line, but orchestrator steps 1 and 5 assume both. Candidate fix: print the whole marker, and use a default Q1 description when the fold is absent.
13. **Dash drift in the card (epa-4).** The card writes `examples: none - <reason>` with a hyphen. reviewer.md (~377) and the template (~514) use an em dash. Candidate: align the card to the em dash, then re-run the six-copy byte-identity check.
14. **Card bullet renders wrong (epa-4, cosmetic).** In agents/reviewer.md the card block at column 0 ends the bullet, so the "In the same action" text renders as a separate paragraph.

## epf closure (epf-1..6, PASS 2026-10-13; 1f261e7, 4b56fb7, 811449d, 11919a8, 6c994d5, 1b14288)

Items 1-14 above are closed; do not re-check them:
- 1, 6(partly), 7, 10, 11 (plan criteria AC1.3, AC2.2, AC2.3, AC3.2, AC3.3, AC4.4, AC4.6): epf-6 erratum on the 2026-10-12 plan. Item 3 (OQ1/R4) resolved by epf-4 + epf-6.
- 2: epf-2 added 4 `// epf-2` parity probes. 4, 5: epf-3 (O1-O4 order cases, stderr-empty T8). 6: epf-3 T1b golden copy.
- 3: epf-4 (markdown-lite pipe tables, TB1-TB10). 8: epf-5 (parseProtocolSections ignores fenced `## `, F1-F3).
- 9: epf-6 fixed the stale line at 2026-10-01 plan :928.
- 12: epf-1 (old marker printed whole; default Q1 text; parity-pinned). 13: epf-2 (skip token is now ASCII hyphen `examples: none - <reason>`). 14: epf-2 (card follow-on is a list item).

### New carry-forward (epf reviewers' non-blocking notes)

a. CONTEXT.md escalation card entry lacked the no-fold clause: FIXED by this scribe pass (also added "old-format marker" as a parenthetical alias under **fold line**).
b. templates/persona-protocol.md ~609 is a ~200-column line.
c. agents/reviewer.md:333 "per the bullet after next" is wrong; should name the "Resolving a standing escalation" bullet (~418).
d. No validate.sh test checks the hyphen-only skip token or the list-item-after-card (only epf2-ac1/ac2).
e. "Durable escalation packet" in reviewer.md restates the glossary term "Escalation packet".
f. markdown-lite: the table body loop absorbs any following pipe-containing line (`- item | x`, `# h | x`, fences); no vm-load test of the injected client script; mdSplitRow misparses an escaped backslash before a trailing pipe; briefing and auditor panes now render tables too.
g. parseProtocolSections: a line with an inline code span is treated as a fence opener; no unclosed-fence fixture; trailing `\r` rejects the closer.
h. tests/packet-view-script.test.sh:113 O4 `grep -q raw` could match a random mktemp suffix.
i. Contract wording defects: epf3-ac2 and epf6-ac2 print several lines; range.sh prints `1 `; contract trailers named Sonnet though haiku ran.
j. epf-4 reviewer's full validate.sh once exited 1 under ~5 concurrent runs (not reproduced; gate G passed clean at HEAD).

**Closed:** the epa-1 gap (orchestrator.md step 3 lacked the "without the Read tool's line-number prefixes" clause) was closed by epa-3.

**Why:** these are the reviewers' non-blocking notes for epa-2 and epa-3, which the plan does not record anywhere else. **How to apply:** before any follow-up that touches the escalation layout or the viewer tests, re-check each item against current sources; items a-j above are the live list.
