---
name: escalation-packet follow-ups (epa-2, epa-3)
description: epa-2 PASS (60ff302, 0.31.157) and epa-3 PASS (ac1e511, 0.31.158) carry-forward gaps for the escalation layout, viewer tests, and parity probes, kept in one place
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

**Closed:** the epa-1 gap (orchestrator.md step 3 lacked the "without the Read tool's line-number prefixes" clause) was closed by epa-3.

**Why:** these are the reviewers' non-blocking notes for epa-2 and epa-3, which the plan does not record anywhere else. **How to apply:** before any follow-up that touches the escalation layout or the viewer tests, re-check each item against current sources; items 1 and 2 may already be fixed.
