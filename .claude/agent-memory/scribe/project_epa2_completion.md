---
name: escalation-packet follow-ups (epa, epf, epfb)
description: epa-2..4 carry-forward gaps for the escalation layout, card/fold marker, viewer tests and parity probes; the epf run (epf-1..6, 2026-10-13) that closed items 1-14; the epfb run (epfb-1..5, 2026-10-13) that closed a-i; and the live carry-forward list (j, plus epfb notes 1-5)
metadata:
  type: project
---

**epa-2: PASS 2026-10-12, commit 60ff302, version 0.31.157.** Scribe pass (5a26e69) aligned two glossary entries and minted **terminal reader**.

- **literate change summary** and **worked example** match the shipped wording: a `>` blockquote line, and `**Before:**` / `**After:**` lines.
- **terminal reader** is the plain-text layout contract. **epa-3 (PASS 2026-10-12, ac1e511, 0.31.158)** added `view.sh`, which renders in colour only when a renderer exists and otherwise falls back to `cat`, so the plain-text layout still holds. If a later unit adds a layout rule, update the entry rather than adding a second term.
- **epa-3 scribe pass:** the **packet viewer** CONTEXT.md entry said "comprehension tooling"; reworded to "a viewer for **comprehension material** only", the existing term. No other glossary change.

## Carry-forward (epa-2..4 original list, 1-14)

Items 1-14 are closed (epf-1..6 and epfb-1..5); do not re-check them.

- 1, 6 (partly), 7, 10, 11: epf-6 erratum on the 2026-10-12 plan. Item 3 (OQ1/R4) resolved by epf-4 + epf-6.
- 2: epf-2 added 4 `// epf-2` parity probes. 4, 5: epf-3 (O1-O4 order cases, stderr-empty T8). 6: epf-3 T1b golden copy.
- 3: epf-4 (markdown-lite pipe tables, TB1-TB10). 8: epf-5 (parseProtocolSections ignores fenced `## `, F1-F3).
- 9: epf-6 fixed the stale line at 2026-10-01 plan :928.
- 12: epf-1 (old marker printed whole; default Q1 text; parity-pinned). 13: epf-2 (skip token is now ASCII hyphen `examples: none - <reason>`). 14: epf-2 (card follow-on is a list item).

## epf closure (epf-1..6, PASS 2026-10-13; 1f261e7, 4b56fb7, 811449d, 11919a8, 6c994d5, 1b14288)

Carry-forward items a-h from the epf reviewers were closed by the epfb run below (a was closed by the epf scribe pass itself). The epf-4 item i (contract wording defects) is handled by the plan's Contract hygiene rule.

**Closed:** the epa-1 gap (orchestrator.md step 3 lacked the "without the Read tool's line-number prefixes" clause) was closed by epa-3.

## epfb closure (epfb-1..5, PASS 2026-10-13; 4ce147d, 0d141c4, f0443ec, 278a94c, da2fb37; version 0.31.162)

- **a** (CONTEXT.md card entry lacked the no-fold clause): closed by the epf scribe pass.
- **b** (templates/persona-protocol.md ~609 ~200-column line): closed by epfb-1 (re-flowed to 80 cols).
- **c** (agents/reviewer.md "per the bullet after next"): closed by epfb-1 (pointer now names the "Resolving a standing escalation" bullet).
- **d** (no test for the hyphen-only skip token or list item after card): closed by epfb-2 (EB1 and EB2 in tests/adapter-protocol-parity.test.js).
- **e** ("Durable escalation packet" restates the glossary term): closed by epfb-1 (alias sentence in the CONTEXT.md Escalation packet entry).
- **f** (markdown-lite table body and escaped backslash): closed by epfb-3 (mdStartsBlock, mdSplitRow escape handling, TB11-TB17, VM1 vm-load). See new note 1 for the remaining `* ` branch gap.
- **g** (parseProtocolSections inline code span and CRLF closer): closed by epfb-4 (check F4). See new notes 2 and 3.
- **h** (O4 `grep -q raw` could match a random mktemp suffix): closed by epfb-5 (T4, T5, O4 anchored with `-qxE`).
- **i** (contract wording defects): handled by the plan's Contract hygiene rule.
- **j** (validate.sh exited 1 under ~5 concurrent runs): still unreproduced; gate G passed clean at HEAD da2fb37. Keep open as a watch item, not a defect.

## epfc closure (epfc-1..5, PASS 2026-10-13; 04f3862, 2bcf0c8, f71f5c8, 52ac70b, c9e1578; no version bump)

Closed epfb notes 1-5: 1 by epfc-1 (TB18 pins the `* ` branch of mdStartsBlock); 2 by epfc-2 (mutants (d)/(e) in docs/plans/epfb-criteria/epfb4-ac3.sh for F4 cases 3, 4); 3 by epfc-3 (no-preamble `## ` case is a documented non-goal, comment in bin/cli.js, check F5); 4 by epfc-4 (EB1 uses a local splitFences: skip token required in prose and inside the card fence); 5 by epfc-5 (CONTEXT.md Escalation packet alias names templates/persona-protocol.md; epfb1-ac3.sh pin updated). No glossary change by the scribe pass. Do not re-check these.

## epfd closure (epfd-1..3, PASS 2026-10-13; 5f98e4c, 02b131c, 4f3055b; no version bump)

Closed the epfc open items: epfd-1 made mutant (d) in docs/plans/epfb-criteria/epfb4-ac3.sh position-exact (line index, lookahead from li + 1, plus a guard line), replacing the `indexOf` lookup. epfd-2 added a bare `## ` input to F5 in tests/protocol-cross-references.test.js; a trailing-newline input was deliberately not added because F2/F4 already catch it. epfd-3 added SF1 (six direct cases) for the local splitFences helper in tests/adapter-protocol-parity.test.js; nothing exported from bin/. No glossary change. Do not re-check these.

## Live carry-forward

- **j** (validate.sh exited 1 once under concurrency): unreproduced and a documented non-goal; merge gate passed clean at HEAD after epfd. Watch item, not a defect. Nothing else is open.

**Why:** reviewers' non-blocking notes the plan does not record elsewhere. **How to apply:** before any follow-up touching the escalation layout, viewer tests, or parity probes, re-check only item j; everything else in this file is closed.
