---
name: hyg-3 completion
description: PASS 2026-10-05; second shell glossary entry added to docs/harness-glossary.md
metadata:
  type: project
---

hyg-3 (commit cc50c3e, 2026-10-05) ships documentation improvements to `docs/harness-glossary.md`:

**G5: One FP-ext-1 mention** (versus two in prior prose)
- Consolidated duplicate references in frozen family table entry

**G6: New "second shell" glossary entry**
- States the qp-1 recognition rule as `glob_scan_shell_payloads()` implements it
- Describes the regex boundary classes and option-word handling (measured in prior probe Clarifications)
- Replaces duplicate copies in frozen family table and expansion-named token entries (they now point to the new entry)
- Clarifies the rule applies when lex success; on lex failure, every glob is scanned anyway (per gate script)

**Reviewer note (non-blocking):**
- Glossary entries (lines ~2424–2426 and ~2359) say "every glob live" on lex failure but should note the gate first strips quoted-heredoc bodies (`glob_strip_quoted_heredoc_bodies`, gate script lines ~442, 595–624)
- A later docs unit could add "minus quoted-heredoc bodies" for precision
- Not a blocker; wording is copied verbatim from plan and matches the gate's R-QP-b excluded case

**Tests:**
- `python3 hyg3-check.py docs/harness-glossary.md fcfcc47`: rc 0, 42 ok / 0 FAIL (base had rc 1, 23 FAIL)
- `node tests/context-glossary-links.test.js && node tests/protocol-doc-drift.test.js`: rc 0
- hyg-1 pins.sh extraction: fail=0
- Scope: git diff shows only `docs/harness-glossary.md`

**Plan:** docs/plans/2026-10-04-hygiene-cleanup.md (G5, G6 items).
