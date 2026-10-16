---
name: ptr-u2-completion
description: ptr-u2 PASS 7e619c5 closed #553; four open follow-ups on the grep-first glossary recipe
metadata:
  type: project
---

PASS 7e619c5 (reviewed at 4950af7) closed #553. Glossary entry "grep-first recipe" added to docs/harness-glossary.md.

Open follow-ups (not fixed):
1. Anchored `^\s*_Avoid_:` misses 3 of 26 avoid lists mid-line (CONTEXT.md ~195, ~203, ~682: gateless, advisory reviewer, deprecated skill); SKILL.md:24 and scribe.md:35 claim "every avoid line". Fix: unanchor in both blocks and the test.
2. scribe.md ~29-30 says harness glossary exceeds the 2000-line Read limit, yet step 3 permits whole-file read, which truncates silently.
3. Nothing tests .claude/agents/scribe.md mirrors agents/scribe.md.
4. Earlier lanes failure was my ptr-u6 duplicate glossary entry (fixed in 4950af7).

**Why:** reviewer non-blocking notes.
**How to apply:** check before touching the recipe; see [[project_ptr_u6_completion]].
