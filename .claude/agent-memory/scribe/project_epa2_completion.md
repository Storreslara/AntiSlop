---
name: epa-2 completion
description: epa-2 PASS 2026-10-12 (60ff302, 0.31.157); glossary wording aligned to sources, terminal reader term minted; carry-forward gaps for the plan's AC2.3 loop, parity probes, and Open Question 1
metadata:
  type: project
---

**PASS 2026-10-12, commit 60ff302, version 0.31.157.** The CHANGELOG.md entry was already present. Scribe pass (5a26e69) changed two glossary entries and minted one term.

- **literate change summary** and **worked example** now match the shipped wording: a `>` blockquote line, and `**Before:**` / `**After:**` lines (not "callout" or "lead-ins").
- **terminal reader** minted. **Why:** epa-3's `view.sh` renders the documents in colour only when a renderer exists and otherwise falls back to plain `cat`, so the plain-text layout is the contract. **How to apply:** when epa-3 lands, check its viewer text against this entry; if epa-3 adds a layout rule, update the entry rather than adding a second term.
- Editing CONTEXT.md did not trigger version-stamp discipline (not in the `agents/*.md` / `templates/` set), so no bump was needed.

## Carry-forward (not applied: plan and tests are off-limits to scribe)

1. **AC2.3 loop masks failures.** The `for` loop in plan Step 2 AC2.3 returns only the last file's status, so an earlier file containing the old phrase passes silently. Fix in the plan: put `|| exit 1` inside the loop body.
2. **Parity probes are incomplete for the two ports.** `ESCALATION_PROBES` (tests/adapter-protocol-parity.test.js) covers `| Where | What to check |`, `**Before:**` and the wrapped-paragraph sentence. It does not cover `**After:**`, the `### <n>.` heading, or the `>` blockquote line in the codex and cursor ports, although AC2.1 greps for some of them. Candidate for a follow-up unit.
3. **Open Question 1 still needs a tracker issue.** The dashboard markdown-lite renderer has no table support, so `| Where | What to check |` will not render there. Recorded as non-blocking with a default applied. Not filed by scribe; a human or the lead should file it.

**Why:** these are the reviewer's non-blocking notes for epa-2, which the plan does not record anywhere else. **How to apply:** before epa-3 or any follow-up that touches the escalation layout, re-check each item against current sources; items 1 and 2 may already have been fixed.
